import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { ConfigType } from "@nestjs/config";
import {
  AcceptRequestContract,
  ToiletType,
  ActorType,
  ApiErrorCode,
  AssignmentStatus,
  CallCentreAssignmentContract,
  CallCentreCreateRequestContract,
  CollectionOutcome,
  CreateServiceRequestContract,
  DashboardContract,
  FollowUpStatus,
  JourneyPhase,
  JourneySnapshotContract,
  JourneyStatus,
  LocationPolicyContract,
  OperationalNotificationContract,
  OperationalNotificationType,
  ProviderPendingRequestContract,
  RequestLocationKind,
  ScheduleMode,
  ServiceRequestDetailContract,
  ServiceRequestOrigin,
  ServiceRequestStatus,
  ServiceRequestSummaryContract,
  SubmitFeedbackContract,
  SubmitLocationBatchContract,
} from "@weyonje/contracts";
import { createHash, randomUUID } from "node:crypto";

import { AuthenticatedActor } from "../auth/authenticated-actor";
import { EmailSecurityService } from "../auth/email-security.service";
import { locationConfig } from "../config/location.config";
import { reminderConfig } from "../config/reminder.config";
import { JourneyGateway } from "./journey.gateway";
import { PrismaService } from "../database/prisma.service";
import { Prisma } from "../generated/prisma/client";
import {
  ActorType as PrismaActorType,
  CollectionOutcome as PrismaCollectionOutcome,
  FollowUpStatus as PrismaFollowUpStatus,
  JourneyPhase as PrismaJourneyPhase,
  JourneyStatus as PrismaJourneyStatus,
  NotificationDeliveryChannel,
  OperationalNotificationType as PrismaNotificationType,
  RequestAssignmentStatus,
  RequestLocationKind as PrismaLocationKind,
  ScheduleMode as PrismaScheduleMode,
  ServiceRequestOrigin as PrismaRequestOrigin,
  ServiceRequestStatus as PrismaRequestStatus,
  ToiletType as PrismaToiletType,
} from "../generated/prisma/enums";
import { PhoneSecurityService } from "../registration/phone-security.service";

import {
  atClientRequestStage,
  withoutDiagnostics,
  RequestStageRunner,
} from "../http/failure-diagnostics";

type TransactionClient = Prisma.TransactionClient;

const REQUEST_INCLUDE = {
  acceptedProvider: {
    select: {
      id: true,
      encryptedPhone: true,
      serviceProviderProfile: { select: { companyName: true } },
    },
  },
  feedback: true,
  followUpCase: true,
  disposalAssignment: { include: { disposalSite: true } },
  journeys: {
    include: {
      request: {
        select: {
          latitude: true,
          longitude: true,
          disposalAssignment: { include: { disposalSite: true } },
        },
      },
      positions: { orderBy: { deviceTimestamp: "desc" as const }, take: 1 },
      _count: { select: { positions: true } },
    },
  },
} as const;

@Injectable()
export class WorkflowService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly phones: PhoneSecurityService,
    private readonly emails: EmailSecurityService,
    private readonly realtime: JourneyGateway,
    @Inject(locationConfig.KEY)
    private readonly policy: ConfigType<typeof locationConfig>,
    @Inject(reminderConfig.KEY)
    private readonly reminders: ConfigType<typeof reminderConfig>,
  ) {}

  locationPolicy(): LocationPolicyContract {
    return { ...this.policy };
  }

  async clientDashboard(actor: AuthenticatedActor): Promise<DashboardContract> {
    this.assertClient(actor);
    const requests = await this.prisma.serviceRequest.findMany({
      where: { clientUserId: actor.user.id },
      orderBy: { updatedAt: "desc" },
      take: 20,
      include: REQUEST_INCLUDE,
    });
    return {
      pendingCount: requests.filter((request) => request.status === "PENDING")
        .length,
      activeCount: requests.filter((request) =>
        [
          "ACCEPTED",
          "ACTIVE",
          "COLLECTION_REPORTED",
          "COLLECTION_COMPLETED",
        ].includes(request.status),
      ).length,
      actionRequiredCount: requests.filter((request) =>
        ["COLLECTION_REPORTED", "FOLLOW_UP_REQUIRED"].includes(request.status),
      ).length,
      recentRequests: requests.map((request) => this.summary(request)),
    };
  }

  async providerDashboard(
    actor: AuthenticatedActor,
  ): Promise<DashboardContract> {
    this.assertProvider(actor);
    const [pendingCount, requests] = await Promise.all([
      this.pendingProviderRequests(actor).then((values) => values.length),
      this.prisma.serviceRequest.findMany({
        where: { acceptedProviderUserId: actor.user.id },
        orderBy: { updatedAt: "desc" },
        take: 20,
        include: REQUEST_INCLUDE,
      }),
    ]);
    return {
      ...(actor.user.serviceProviderProfile?.providerNumber
        ? { actorNumber: actor.user.serviceProviderProfile.providerNumber }
        : {}),
      pendingCount,
      activeCount: requests.filter((request) => request.status !== "COMPLETED")
        .length,
      actionRequiredCount: requests.filter((request) =>
        ["ACCEPTED", "ACTIVE", "COLLECTION_COMPLETED"].includes(request.status),
      ).length,
      recentRequests: requests.map((request) => this.summary(request)),
    };
  }

  async clientProfile(actor: AuthenticatedActor) {
    this.assertClient(actor);
    const user = await this.prisma.user.findUnique({
      where: { id: actor.user.id },
      select: {
        encryptedPhone: true,
        encryptedEmail: true,
        clientProfile: true,
      },
    });
    if (!user?.encryptedPhone || !user.clientProfile) throw this.notFound();
    const profile = user.clientProfile;
    return {
      clientName:
        profile.clientType === "INDIVIDUAL"
          ? `${profile.firstName ?? ""} ${profile.lastName ?? ""}`.trim()
          : (profile.organizationName ?? "Weyonje Client"),
      phoneNumber: this.phones.decrypt(user.encryptedPhone),
      ...(user.encryptedEmail
        ? { emailAddress: this.emails.decrypt(user.encryptedEmail) }
        : {}),
    };
  }

  async createClientRequest(
    actor: AuthenticatedActor,
    input: CreateServiceRequestContract,
  ): Promise<ServiceRequestDetailContract> {
    this.assertClient(actor);
    if (
      !input.toiletType ||
      !Object.values(ToiletType).includes(input.toiletType)
    )
      throw this.invalid("Select the type of toilet to empty.");
    const normalized = await atClientRequestStage("normalization", async () =>
      this.validateRequestInput(input),
    );
    const profile = await atClientRequestStage("profile_lookup", () =>
      this.prisma.user.findUnique({
        where: { id: actor.user.id },
        select: {
          encryptedPhone: true,
          encryptedEmail: true,
          clientProfile: true,
        },
      }),
    );
    if (!profile?.encryptedPhone || !profile.clientProfile)
      throw this.notFound();
    const clientName =
      profile.clientProfile.clientType === "INDIVIDUAL"
        ? `${profile.clientProfile.firstName ?? ""} ${profile.clientProfile.lastName ?? ""}`.trim()
        : (profile.clientProfile.organizationName ?? "Weyonje Client");
    const response = await atClientRequestStage("transaction", () =>
      this.idempotent(
        actor.user.id,
        "client.create-request",
        input.idempotencyKey,
        input,
        async (tx) => {
          const request = await atClientRequestStage("request_create", () =>
            tx.serviceRequest.create({
              data: {
                reference: requestReference(),
                origin: PrismaRequestOrigin.MOBILE_APP,
                clientUserId: actor.user.id,
                createdByUserId: actor.user.id,
                clientName,
                encryptedClientPhone: profile.encryptedPhone!,
                encryptedClientEmail: profile.encryptedEmail,
                ...normalized,
              },
              select: { id: true },
            }),
          );
          await Promise.all([
            atClientRequestStage("history_write", () =>
              tx.requestStatusHistory.create({
                data: {
                  requestId: request.id,
                  toStatus: PrismaRequestStatus.PENDING,
                  actorUserId: actor.user.id,
                },
              }),
            ),
            atClientRequestStage("audit_write", () =>
              this.audit(
                tx,
                actor.user.id,
                "request.created",
                "ServiceRequest",
                request.id,
                request.id,
              ),
            ),
            this.notify(
              tx,
              actor.user.id,
              request.id,
              PrismaNotificationType.REQUEST_CREATED,
              "Request submitted",
              "Your service request is pending Provider acceptance.",
              atClientRequestStage,
            ),
          ]);
          await atClientRequestStage("reminder_write", () =>
            this.createReminders(
              tx,
              request.id,
              actor.user.id,
              normalized.requestedServiceAt,
            ),
          );
          return { id: request.id };
        },
        atClientRequestStage,
      ),
    );
    return this.clientRequest(actor, response.id, atClientRequestStage);
  }

  async createCallCentreRequest(
    actor: AuthenticatedActor,
    input: CallCentreCreateRequestContract,
  ): Promise<ServiceRequestDetailContract> {
    this.assertCallCentre(actor);
    const normalized = this.validateRequestInput(input);
    const phone = this.phones.normalize(input.clientPhone);
    const email = input.clientEmail
      ? this.emails.normalize(input.clientEmail)
      : null;
    const response = await this.idempotent(
      actor.user.id,
      "call-centre.create-request",
      input.idempotencyKey,
      input,
      async (tx) => {
        if (input.clientUserId) {
          const client = await tx.user.findFirst({
            where: {
              id: input.clientUserId,
              actorType: PrismaActorType.CLIENT,
              isActive: true,
            },
            select: { id: true },
          });
          if (!client)
            throw this.invalid("Select an active Weyonje Client account.");
        }
        const request = await tx.serviceRequest.create({
          data: {
            reference: requestReference(),
            origin: PrismaRequestOrigin.CALL_CENTRE,
            createdByUserId: actor.user.id,
            clientUserId: input.clientUserId ?? null,
            clientName: requiredText(
              input.clientName,
              "Client name is required.",
            ),
            encryptedClientPhone: this.phones.encrypt(phone),
            encryptedClientEmail: email ? this.emails.encrypt(email) : null,
            ...normalized,
          },
          select: { id: true },
        });
        await tx.requestStatusHistory.create({
          data: {
            requestId: request.id,
            toStatus: PrismaRequestStatus.PENDING,
            actorUserId: actor.user.id,
          },
        });
        await this.audit(
          tx,
          actor.user.id,
          "call-centre.request-created",
          "ServiceRequest",
          request.id,
          request.id,
        );
        if (input.clientUserId)
          await this.createReminders(
            tx,
            request.id,
            input.clientUserId,
            normalized.requestedServiceAt,
          );
        return { id: request.id };
      },
    );
    return this.authorizedRequestDetail(actor, response.id);
  }

  async callCentreRequests(actor: AuthenticatedActor) {
    this.assertCallCentre(actor);
    const requests = await this.prisma.serviceRequest.findMany({
      where: { origin: PrismaRequestOrigin.CALL_CENTRE },
      orderBy: { updatedAt: "desc" },
      take: 200,
      include: REQUEST_INCLUDE,
    });
    return requests.map((request) => this.summary(request));
  }

  async callCentreClients(actor: AuthenticatedActor, query: string) {
    this.assertCallCentre(actor);
    const users = await this.prisma.user.findMany({
      where: {
        actorType: PrismaActorType.CLIENT,
        isActive: true,
        phoneVerifiedAt: { not: null },
      },
      orderBy: { createdAt: "desc" },
      take: 100,
      include: { clientProfile: true },
    });
    const normalized = query.trim().toLowerCase();
    return users
      .map((user) => {
        const profile = user.clientProfile!;
        const name =
          profile.organizationName ??
          [profile.firstName, profile.lastName].filter(Boolean).join(" ");
        return {
          userId: user.id,
          name,
          phoneNumber: this.phones.decrypt(user.encryptedPhone!),
          ...(user.encryptedEmail
            ? { email: this.emails.decrypt(user.encryptedEmail) }
            : {}),
        };
      })
      .filter(
        (client) =>
          !normalized ||
          client.name.toLowerCase().includes(normalized) ||
          client.phoneNumber.includes(normalized) ||
          client.email?.toLowerCase().includes(normalized),
      )
      .slice(0, 25);
  }

  async callCentreProviders(actor: AuthenticatedActor) {
    this.assertCallCentre(actor);
    const providers = await this.prisma.user.findMany({
      where: {
        actorType: PrismaActorType.SERVICE_PROVIDER,
        providerStatus: "APPROVED",
        isActive: true,
        loginEnabled: true,
      },
      orderBy: { serviceProviderProfile: { companyName: "asc" } },
      select: {
        id: true,
        serviceProviderProfile: {
          select: { companyName: true, providerNumber: true },
        },
      },
    });
    return providers.map((provider) => ({
      userId: provider.id,
      companyName: provider.serviceProviderProfile!.companyName,
      ...(provider.serviceProviderProfile!.providerNumber
        ? { providerNumber: provider.serviceProviderProfile!.providerNumber }
        : {}),
    }));
  }

  async clientRequests(
    actor: AuthenticatedActor,
  ): Promise<ServiceRequestSummaryContract[]> {
    this.assertClient(actor);
    const requests = await this.prisma.serviceRequest.findMany({
      where: { clientUserId: actor.user.id },
      orderBy: { createdAt: "desc" },
      take: 100,
      include: REQUEST_INCLUDE,
    });
    return requests.map((request) => this.summary(request));
  }

  async clientRequest(
    actor: AuthenticatedActor,
    requestId: string,
    diagnose: RequestStageRunner = withoutDiagnostics,
  ): Promise<ServiceRequestDetailContract> {
    this.assertClient(actor);
    const request = await diagnose("detail_read", () =>
      this.prisma.serviceRequest.findFirst({
        where: { id: requestId, clientUserId: actor.user.id },
        include: REQUEST_INCLUDE,
      }),
    );
    if (!request) throw this.notFound();
    return diagnose("detail_mapping", async () => this.detail(request, true));
  }

  async pendingProviderRequests(
    actor: AuthenticatedActor,
  ): Promise<ProviderPendingRequestContract[]> {
    this.assertProvider(actor);
    const requests = await this.prisma.serviceRequest.findMany({
      where: {
        status: PrismaRequestStatus.PENDING,
        OR: [
          {
            origin: PrismaRequestOrigin.MOBILE_APP,
            acceptedProviderUserId: null,
          },
          {
            origin: PrismaRequestOrigin.CALL_CENTRE,
            assignments: {
              some: {
                providerUserId: actor.user.id,
                status: RequestAssignmentStatus.PENDING,
              },
            },
          },
        ],
      },
      orderBy: { createdAt: "asc" },
      take: 100,
      include: {
        assignments: {
          where: {
            providerUserId: actor.user.id,
            status: RequestAssignmentStatus.PENDING,
          },
        },
      },
    });
    return requests.map((request) => ({
      id: request.id,
      reference: request.reference,
      origin: request.origin as ServiceRequestOrigin,
      ...(request.assignments[0]
        ? { assignmentStatus: AssignmentStatus.pending }
        : {}),
      locationLabel:
        request.origin === PrismaRequestOrigin.MOBILE_APP
          ? "Location available after acceptance"
          : "Assigned request location",
      ...(request.toiletType
        ? { toiletType: request.toiletType as never }
        : {}),
      scheduleMode: request.scheduleMode as ScheduleMode,
      ...(request.requestedServiceAt
        ? { requestedServiceAt: request.requestedServiceAt.toISOString() }
        : {}),
      createdAt: request.createdAt.toISOString(),
    }));
  }

  async providerRequest(
    actor: AuthenticatedActor,
    requestId: string,
  ): Promise<ServiceRequestDetailContract> {
    this.assertProvider(actor);
    const request = await this.prisma.serviceRequest.findUnique({
      where: { id: requestId },
      include: {
        ...REQUEST_INCLUDE,
        assignments: { where: { providerUserId: actor.user.id } },
      },
    });
    const visible =
      request &&
      (request.acceptedProviderUserId === actor.user.id ||
        (request.status === PrismaRequestStatus.PENDING &&
          request.origin === PrismaRequestOrigin.MOBILE_APP) ||
        (request.origin === PrismaRequestOrigin.CALL_CENTRE &&
          request.assignments.some(
            (assignment) =>
              assignment.status === RequestAssignmentStatus.PENDING,
          )));
    if (!visible || !request) throw this.notFound();
    const acceptedByActor = request.acceptedProviderUserId === actor.user.id;
    return this.detail(request, acceptedByActor, acceptedByActor);
  }

  async acceptRequest(
    actor: AuthenticatedActor,
    requestId: string,
    input: AcceptRequestContract,
  ): Promise<ServiceRequestDetailContract> {
    this.assertProvider(actor);
    const result = await this.idempotent(
      actor.user.id,
      `provider.accept:${requestId}`,
      input.idempotencyKey,
      input,
      async (tx) => {
        const request = await tx.serviceRequest.findUnique({
          where: { id: requestId },
          include: {
            assignments: {
              where: {
                providerUserId: actor.user.id,
                status: RequestAssignmentStatus.PENDING,
              },
            },
          },
        });
        if (!request) throw this.notFound();
        if (request.origin === PrismaRequestOrigin.MOBILE_APP) {
          if (
            !Number.isInteger(input.agreedPriceUgx) ||
            input.agreedPriceUgx! < 0 ||
            input.agreedPriceUgx! > 1_000_000_000
          ) {
            throw this.invalid(
              "Enter a non-negative whole-number agreed price in UGX.",
            );
          }
        } else if (request.assignments.length !== 1) {
          throw new ForbiddenException({
            code: ApiErrorCode.accessDenied,
            message: "This request is not assigned to this Provider.",
          });
        }
        const accepted = await tx.serviceRequest.updateMany({
          where: {
            id: requestId,
            status: PrismaRequestStatus.PENDING,
            acceptedProviderUserId: null,
          },
          data: {
            status: PrismaRequestStatus.ACCEPTED,
            acceptedProviderUserId: actor.user.id,
            acceptedAt: new Date(),
            agreedPriceUgx:
              request.origin === PrismaRequestOrigin.MOBILE_APP
                ? (input.agreedPriceUgx ?? null)
                : request.agreedPriceUgx,
          },
        });
        if (accepted.count !== 1) throw this.alreadyAccepted();
        if (request.origin === PrismaRequestOrigin.MOBILE_APP) {
          await tx.requestAssignment.create({
            data: {
              requestId,
              providerUserId: actor.user.id,
              status: RequestAssignmentStatus.ACCEPTED,
              decidedAt: new Date(),
            },
          });
        } else {
          await tx.requestAssignment.update({
            where: { id: request.assignments[0]!.id },
            data: {
              status: RequestAssignmentStatus.ACCEPTED,
              decidedAt: new Date(),
            },
          });
        }
        await tx.requestAssignment.updateMany({
          where: {
            requestId,
            providerUserId: { not: actor.user.id },
            status: RequestAssignmentStatus.PENDING,
          },
          data: {
            status: RequestAssignmentStatus.SUPERSEDED,
            decidedAt: new Date(),
          },
        });
        await this.transitionRecord(
          tx,
          requestId,
          PrismaRequestStatus.PENDING,
          PrismaRequestStatus.ACCEPTED,
          actor.user.id,
        );
        await this.audit(
          tx,
          actor.user.id,
          "request.accepted",
          "ServiceRequest",
          requestId,
          requestId,
          { agreedPriceUgx: input.agreedPriceUgx ?? null },
        );
        if (request.clientUserId) {
          await this.notify(
            tx,
            request.clientUserId,
            requestId,
            PrismaNotificationType.REQUEST_ACCEPTED,
            "Request accepted",
            "A Service Provider accepted your request.",
          );
          await this.outbox(
            tx,
            requestId,
            request.clientUserId,
            NotificationDeliveryChannel.PUSH,
            PrismaNotificationType.REQUEST_ACCEPTED,
            `request:${requestId}:accepted:push`,
          );
        } else {
          await this.outbox(
            tx,
            requestId,
            null,
            NotificationDeliveryChannel.SMS,
            PrismaNotificationType.REQUEST_ACCEPTED,
            `request:${requestId}:accepted:sms`,
          );
        }
        return { id: requestId };
      },
    );
    return this.providerRequest(actor, result.id);
  }

  async rejectAssignedRequest(
    actor: AuthenticatedActor,
    requestId: string,
    idempotencyKey: string,
  ): Promise<{ rejected: true }> {
    this.assertProvider(actor);
    return this.idempotent(
      actor.user.id,
      `provider.reject:${requestId}`,
      idempotencyKey,
      { requestId },
      async (tx) => {
        const request = await tx.serviceRequest.findUnique({
          where: { id: requestId },
        });
        if (
          !request ||
          request.origin !== PrismaRequestOrigin.CALL_CENTRE ||
          request.status !== PrismaRequestStatus.PENDING
        )
          throw this.invalidTransition();
        const updated = await tx.requestAssignment.updateMany({
          where: {
            requestId,
            providerUserId: actor.user.id,
            status: RequestAssignmentStatus.PENDING,
          },
          data: {
            status: RequestAssignmentStatus.REJECTED,
            decidedAt: new Date(),
          },
        });
        if (updated.count !== 1) throw this.invalidTransition();
        if (request.createdByUserId) {
          await this.notify(
            tx,
            request.createdByUserId,
            requestId,
            PrismaNotificationType.REQUEST_REJECTED,
            "Assignment rejected",
            "The selected Service Provider rejected the Call Centre assignment.",
          );
        }
        await this.audit(
          tx,
          actor.user.id,
          "assignment.rejected",
          "ServiceRequest",
          requestId,
          requestId,
        );
        return { rejected: true as const };
      },
    );
  }

  async assignCallCentreRequest(
    actor: AuthenticatedActor,
    requestId: string,
    input: CallCentreAssignmentContract,
  ): Promise<ServiceRequestDetailContract> {
    this.assertCallCentre(actor);
    const result = await this.idempotent(
      actor.user.id,
      `call-centre.assign:${requestId}`,
      input.idempotencyKey,
      input,
      async (tx) => {
        const [request, provider] = await Promise.all([
          tx.serviceRequest.findUnique({ where: { id: requestId } }),
          tx.user.findFirst({
            where: {
              id: input.providerUserId,
              actorType: PrismaActorType.SERVICE_PROVIDER,
              providerStatus: "APPROVED",
              isActive: true,
              loginEnabled: true,
            },
            select: { id: true },
          }),
        ]);
        if (
          !request ||
          request.origin !== PrismaRequestOrigin.CALL_CENTRE ||
          request.status !== PrismaRequestStatus.PENDING
        )
          throw this.invalidTransition();
        if (!provider)
          throw new BadRequestException({
            code: ApiErrorCode.invalidRequest,
            message: "Select an approved and active Service Provider.",
          });
        if (
          input.agreedPriceUgx !== undefined &&
          (!Number.isInteger(input.agreedPriceUgx) ||
            input.agreedPriceUgx < 0 ||
            input.agreedPriceUgx > 1_000_000_000)
        ) {
          throw this.invalid(
            "Enter a non-negative whole-number agreed price in UGX.",
          );
        }
        await tx.requestAssignment.updateMany({
          where: { requestId, status: RequestAssignmentStatus.PENDING },
          data: {
            status: RequestAssignmentStatus.SUPERSEDED,
            decidedAt: new Date(),
          },
        });
        await tx.requestAssignment.create({
          data: {
            requestId,
            providerUserId: provider.id,
            assignedByUserId: actor.user.id,
          },
        });
        if (input.agreedPriceUgx !== undefined) {
          await tx.serviceRequest.update({
            where: { id: requestId },
            data: { agreedPriceUgx: input.agreedPriceUgx },
          });
        }
        if (input.disposalSiteId)
          await this.assignDisposalSiteTx(
            tx,
            actor.user.id,
            requestId,
            input.disposalSiteId,
          );
        await this.notify(
          tx,
          provider.id,
          requestId,
          PrismaNotificationType.REQUEST_ASSIGNED,
          "New assigned request",
          "A Call Centre request was assigned to you.",
        );
        await this.createReminders(
          tx,
          requestId,
          provider.id,
          request.requestedServiceAt,
        );
        await this.outbox(
          tx,
          requestId,
          provider.id,
          NotificationDeliveryChannel.PUSH,
          PrismaNotificationType.REQUEST_ASSIGNED,
          `request:${requestId}:assigned:${provider.id}:push`,
        );
        await this.audit(
          tx,
          actor.user.id,
          "request.assigned",
          "ServiceRequest",
          requestId,
          requestId,
          {
            providerUserId: provider.id,
            agreedPriceUgx: input.agreedPriceUgx ?? null,
          },
        );
        return { id: requestId };
      },
    );
    return this.authorizedRequestDetail(actor, result.id);
  }

  async providerJobs(
    actor: AuthenticatedActor,
  ): Promise<ServiceRequestSummaryContract[]> {
    this.assertProvider(actor);
    const requests = await this.prisma.serviceRequest.findMany({
      where: { acceptedProviderUserId: actor.user.id },
      orderBy: { updatedAt: "desc" },
      take: 100,
      include: REQUEST_INCLUDE,
    });
    return requests.map((request) => this.summary(request));
  }

  providerJob(
    actor: AuthenticatedActor,
    requestId: string,
  ): Promise<ServiceRequestDetailContract> {
    return this.providerRequest(actor, requestId);
  }

  async startJourney(
    actor: AuthenticatedActor,
    requestId: string,
    phase: JourneyPhase,
    idempotencyKey: string,
  ): Promise<ServiceRequestDetailContract> {
    this.assertProvider(actor);
    const result = await this.idempotent(
      actor.user.id,
      `journey.start:${requestId}:${phase}`,
      idempotencyKey,
      { phase },
      async (tx) => {
        const request = await tx.serviceRequest.findFirst({
          where: { id: requestId, acceptedProviderUserId: actor.user.id },
          include: { feedback: true, disposalAssignment: true },
        });
        if (!request) throw this.notFound();
        const toRequest = phase === JourneyPhase.toRequest;
        if (toRequest && request.status !== PrismaRequestStatus.ACCEPTED)
          throw this.invalidTransition();
        if (
          !toRequest &&
          (request.status !== PrismaRequestStatus.COLLECTION_COMPLETED ||
            !request.feedback?.wasteCollected ||
            !request.disposalAssignment)
        )
          throw this.invalidTransition(
            "Disposal can start only after recorded collection and KCCA disposal-site assignment.",
          );
        const journeyPhase = toRequest
          ? PrismaJourneyPhase.TO_REQUEST
          : PrismaJourneyPhase.TO_DISPOSAL;
        await tx.journey.upsert({
          where: { requestId_phase: { requestId, phase: journeyPhase } },
          create: {
            requestId,
            providerUserId: actor.user.id,
            phase: journeyPhase,
            status: PrismaJourneyStatus.ACTIVE,
            startedAt: new Date(),
          },
          update: { status: PrismaJourneyStatus.ACTIVE, startedAt: new Date() },
        });
        if (toRequest) {
          await tx.serviceRequest.update({
            where: { id: requestId },
            data: { status: PrismaRequestStatus.ACTIVE },
          });
          await this.transitionRecord(
            tx,
            requestId,
            PrismaRequestStatus.ACCEPTED,
            PrismaRequestStatus.ACTIVE,
            actor.user.id,
          );
        }
        const type = toRequest
          ? PrismaNotificationType.JOURNEY_STARTED
          : PrismaNotificationType.DISPOSAL_STARTED;
        await this.notifyRelevant(
          tx,
          request,
          requestId,
          type,
          toRequest ? "Provider is on the way" : "Disposal journey started",
          toRequest
            ? "The Service Provider started the journey to the request location."
            : "The Service Provider is travelling to the assigned disposal site.",
        );
        await this.audit(
          tx,
          actor.user.id,
          toRequest ? "journey.request-started" : "journey.disposal-started",
          "ServiceRequest",
          requestId,
          requestId,
        );
        return { id: requestId };
      },
    );
    return this.providerRequest(actor, result.id);
  }

  async submitPositions(
    actor: AuthenticatedActor,
    requestId: string,
    input: SubmitLocationBatchContract,
  ): Promise<JourneySnapshotContract> {
    this.assertProvider(actor);
    const phase =
      input.phase === JourneyPhase.toRequest
        ? PrismaJourneyPhase.TO_REQUEST
        : PrismaJourneyPhase.TO_DISPOSAL;
    const samples = this.validateSamples(input.samples);
    await this.prisma.$transaction(async (tx) => {
      const journey = await tx.journey.findFirst({
        where: {
          requestId,
          providerUserId: actor.user.id,
          phase,
          status: {
            in: [PrismaJourneyStatus.ACTIVE, PrismaJourneyStatus.ARRIVED],
          },
        },
        include: {
          request: {
            include: {
              disposalAssignment: { include: { disposalSite: true } },
            },
          },
          positions: { orderBy: { deviceTimestamp: "desc" }, take: 1 },
        },
      });
      if (!journey)
        throw this.invalidTransition(
          "Location updates are accepted only for the active assigned journey.",
        );
      const latest = journey.positions[0];
      if (latest && samples[0]!.deviceTimestamp <= latest.deviceTimestamp) {
        const allExisting = await tx.journeyPosition.count({
          where: {
            journeyId: journey.id,
            sampleId: { in: samples.map((sample) => sample.sampleId) },
          },
        });
        if (allExisting !== samples.length)
          throw this.invalid("Location samples are stale or out of order.");
        return;
      }
      const destination = this.destination(journey.request, input.phase);
      const accepted = samples.map((sample) => ({
        journeyId: journey.id,
        sampleId: sample.sampleId,
        deviceTimestamp: sample.deviceTimestamp,
        latitude: sample.latitude,
        longitude: sample.longitude,
        accuracyMetres: sample.accuracyMetres,
        acceptedForArrival:
          destination !== null &&
          sample.accuracyMetres <= this.policy.arrivalMaximumAccuracyMetres &&
          distanceMetres(
            sample.latitude,
            sample.longitude,
            destination.latitude,
            destination.longitude,
          ) <= this.policy.arrivalRadiusMetres,
      }));
      await tx.journeyPosition.createMany({
        data: accepted,
        skipDuplicates: true,
      });
      if (
        journey.status === PrismaJourneyStatus.ACTIVE &&
        hasConsecutiveArrivalEvidence(
          latest?.acceptedForArrival,
          accepted.map((sample) => sample.acceptedForArrival),
        )
      ) {
        await tx.journey.update({
          where: { id: journey.id },
          data: { status: PrismaJourneyStatus.ARRIVED, arrivedAt: new Date() },
        });
        const type =
          phase === PrismaJourneyPhase.TO_REQUEST
            ? PrismaNotificationType.PROVIDER_ARRIVED
            : PrismaNotificationType.DISPOSAL_ARRIVED;
        await this.notifyRelevant(
          tx,
          journey.request,
          requestId,
          type,
          phase === PrismaJourneyPhase.TO_REQUEST
            ? "Provider arrived"
            : "Provider arrived at disposal site",
          phase === PrismaJourneyPhase.TO_REQUEST
            ? "The Service Provider arrived at the request location."
            : "The Service Provider arrived at the assigned disposal site.",
        );
      }
    });
    const snapshot = await this.tracking(actor, requestId, input.phase);
    const participants = await this.prisma.serviceRequest.findUnique({
      where: { id: requestId },
      select: {
        clientUserId: true,
        createdByUserId: true,
        acceptedProviderUserId: true,
      },
    });
    if (participants) {
      this.realtime.publishSnapshot(
        requestId,
        [
          participants.clientUserId,
          participants.createdByUserId,
          participants.acceptedProviderUserId,
        ].filter((id): id is string => id !== null),
        snapshot,
      );
    }
    return snapshot;
  }

  async reportCollection(
    actor: AuthenticatedActor,
    requestId: string,
    idempotencyKey: string,
  ): Promise<ServiceRequestDetailContract> {
    this.assertProvider(actor);
    const result = await this.idempotent(
      actor.user.id,
      `collection.report:${requestId}`,
      idempotencyKey,
      { requestId },
      async (tx) => {
        const request = await tx.serviceRequest.findFirst({
          where: { id: requestId, acceptedProviderUserId: actor.user.id },
        });
        if (!request || request.status !== PrismaRequestStatus.ACTIVE)
          throw this.invalidTransition();
        await tx.collectionReport.create({
          data: { requestId, reportedByProviderId: actor.user.id },
        });
        await tx.serviceRequest.update({
          where: { id: requestId },
          data: { status: PrismaRequestStatus.COLLECTION_REPORTED },
        });
        await tx.journey.updateMany({
          where: {
            requestId,
            phase: PrismaJourneyPhase.TO_REQUEST,
            completedAt: null,
          },
          data: {
            status: PrismaJourneyStatus.COMPLETED,
            completedAt: new Date(),
          },
        });
        await this.transitionRecord(
          tx,
          requestId,
          PrismaRequestStatus.ACTIVE,
          PrismaRequestStatus.COLLECTION_REPORTED,
          actor.user.id,
        );
        await this.notifyRelevant(
          tx,
          request,
          requestId,
          PrismaNotificationType.COLLECTION_REPORTED,
          "Confirm collection outcome",
          "The Service Provider reported collection complete. Confirm the actual outcome and provide feedback.",
        );
        await this.audit(
          tx,
          actor.user.id,
          "collection.reported",
          "ServiceRequest",
          requestId,
          requestId,
        );
        return { id: requestId };
      },
    );
    return this.providerRequest(actor, result.id);
  }

  async submitClientFeedback(
    actor: AuthenticatedActor,
    requestId: string,
    input: SubmitFeedbackContract,
  ): Promise<ServiceRequestDetailContract> {
    this.assertClient(actor);
    const request = await this.prisma.serviceRequest.findFirst({
      where: { id: requestId, clientUserId: actor.user.id },
    });
    if (!request) throw this.notFound();
    await this.submitFeedback(actor, requestId, input);
    return this.clientRequest(actor, requestId);
  }

  async submitCallCentreFeedback(
    actor: AuthenticatedActor,
    requestId: string,
    input: SubmitFeedbackContract,
  ): Promise<ServiceRequestDetailContract> {
    this.assertCallCentre(actor);
    const request = await this.prisma.serviceRequest.findFirst({
      where: { id: requestId, origin: PrismaRequestOrigin.CALL_CENTRE },
    });
    if (!request) throw this.notFound();
    await this.submitFeedback(actor, requestId, input);
    return this.authorizedRequestDetail(actor, requestId);
  }

  private async submitFeedback(
    actor: AuthenticatedActor,
    requestId: string,
    input: SubmitFeedbackContract,
  ): Promise<void> {
    await this.idempotent(
      actor.user.id,
      `feedback.submit:${requestId}`,
      input.idempotencyKey,
      input,
      async (tx) => {
        const request = await tx.serviceRequest.findUnique({
          where: { id: requestId },
          include: { disposalAssignment: true },
        });
        if (
          !request ||
          request.status !== PrismaRequestStatus.COLLECTION_REPORTED
        )
          throw this.invalidTransition();
        const outcome = input.outcome as CollectionOutcome;
        const wasteCollected = outcome !== CollectionOutcome.notDoneAtAll;
        const negative = outcome !== CollectionOutcome.completed;
        await tx.serviceFeedback.create({
          data: {
            requestId,
            submittedByUserId: actor.user.id,
            outcome: outcome as PrismaCollectionOutcome,
            feedback: requiredText(input.feedback, "Feedback is required."),
            rating: input.rating,
            wasteCollected,
          },
        });
        if (negative) {
          await tx.followUpCase.create({
            data: { requestId, outcome: outcome as PrismaCollectionOutcome },
          });
        }
        const next = wasteCollected
          ? PrismaRequestStatus.COLLECTION_COMPLETED
          : PrismaRequestStatus.FOLLOW_UP_REQUIRED;
        await tx.serviceRequest.update({
          where: { id: requestId },
          data: { status: next },
        });
        await this.transitionRecord(
          tx,
          requestId,
          PrismaRequestStatus.COLLECTION_REPORTED,
          next,
          actor.user.id,
          negative
            ? "Negative collection feedback recorded separately from disposal."
            : undefined,
        );
        if (wasteCollected && request.disposalAssignment) {
          await tx.journey.upsert({
            where: {
              requestId_phase: {
                requestId,
                phase: PrismaJourneyPhase.TO_DISPOSAL,
              },
            },
            create: {
              requestId,
              providerUserId: request.acceptedProviderUserId!,
              phase: PrismaJourneyPhase.TO_DISPOSAL,
            },
            update: {},
          });
        }
        if (request.acceptedProviderUserId) {
          await this.notify(
            tx,
            request.acceptedProviderUserId,
            requestId,
            negative
              ? PrismaNotificationType.FOLLOW_UP_REQUIRED
              : PrismaNotificationType.COLLECTION_CONFIRMED,
            negative ? "Follow-up required" : "Collection confirmed",
            negative
              ? "The collection outcome requires KCCA follow-up. Disposal remains available when waste was collected."
              : "The Client confirmed collection.",
          );
        }
        await this.notifyKcca(
          tx,
          requestId,
          negative
            ? PrismaNotificationType.FOLLOW_UP_REQUIRED
            : PrismaNotificationType.COLLECTION_CONFIRMED,
          negative ? "Collection follow-up required" : "Collection confirmed",
          negative
            ? "Negative collection feedback was recorded for follow-up."
            : "Collection was confirmed and disposal may proceed after site assignment.",
        );
        await this.audit(
          tx,
          actor.user.id,
          "feedback.submitted",
          "ServiceRequest",
          requestId,
          requestId,
          { outcome, rating: input.rating, wasteCollected },
        );
        return { recorded: true };
      },
    );
  }

  async completeDisposal(
    actor: AuthenticatedActor,
    requestId: string,
    idempotencyKey: string,
  ): Promise<ServiceRequestDetailContract> {
    this.assertProvider(actor);
    const result = await this.idempotent(
      actor.user.id,
      `disposal.complete:${requestId}`,
      idempotencyKey,
      { requestId },
      async (tx) => {
        const request = await tx.serviceRequest.findFirst({
          where: { id: requestId, acceptedProviderUserId: actor.user.id },
          include: { feedback: true },
        });
        if (
          !request ||
          request.status !== PrismaRequestStatus.COLLECTION_COMPLETED ||
          !request.feedback?.wasteCollected
        )
          throw this.invalidTransition();
        const journey = await tx.journey.findUnique({
          where: {
            requestId_phase: {
              requestId,
              phase: PrismaJourneyPhase.TO_DISPOSAL,
            },
          },
        });
        if (!journey || journey.status !== PrismaJourneyStatus.ARRIVED)
          throw this.invalidTransition(
            "Confirm disposal only after arrival at the assigned site.",
          );
        await tx.journey.update({
          where: { id: journey.id },
          data: {
            status: PrismaJourneyStatus.COMPLETED,
            completedAt: new Date(),
          },
        });
        await tx.serviceRequest.update({
          where: { id: requestId },
          data: { status: PrismaRequestStatus.COMPLETED },
        });
        await this.transitionRecord(
          tx,
          requestId,
          PrismaRequestStatus.COLLECTION_COMPLETED,
          PrismaRequestStatus.COMPLETED,
          actor.user.id,
        );
        await this.notifyKcca(
          tx,
          requestId,
          PrismaNotificationType.DISPOSAL_COMPLETED,
          "Disposal completed",
          "The Service Provider confirmed disposal completion.",
        );
        await this.notify(
          tx,
          actor.user.id,
          requestId,
          PrismaNotificationType.DISPOSAL_COMPLETED,
          "Disposal completed",
          "The job is complete.",
        );
        await this.audit(
          tx,
          actor.user.id,
          "disposal.completed",
          "ServiceRequest",
          requestId,
          requestId,
        );
        return { id: requestId };
      },
    );
    return this.providerRequest(actor, result.id);
  }

  async tracking(
    actor: AuthenticatedActor,
    requestId: string,
    phase: JourneyPhase,
  ): Promise<JourneySnapshotContract> {
    await this.assertCanMonitor(actor, requestId, phase);
    const prismaPhase =
      phase === JourneyPhase.toRequest
        ? PrismaJourneyPhase.TO_REQUEST
        : PrismaJourneyPhase.TO_DISPOSAL;
    const journey = await this.prisma.journey.findUnique({
      where: { requestId_phase: { requestId, phase: prismaPhase } },
      include: {
        request: {
          include: { disposalAssignment: { include: { disposalSite: true } } },
        },
        positions: { orderBy: { deviceTimestamp: "desc" }, take: 1 },
        _count: { select: { positions: true } },
      },
    });
    if (!journey) throw this.notFound();
    return this.journeySnapshot(journey);
  }

  async kccaMonitoring(
    actor: AuthenticatedActor,
  ): Promise<ServiceRequestSummaryContract[]> {
    this.assertKccaMonitoring(actor);
    const requests = await this.prisma.serviceRequest.findMany({
      where: {
        OR: [
          {
            origin: PrismaRequestOrigin.CALL_CENTRE,
            status: {
              in: [
                PrismaRequestStatus.ACCEPTED,
                PrismaRequestStatus.ACTIVE,
                PrismaRequestStatus.COLLECTION_REPORTED,
              ],
            },
          },
          {
            status: {
              in: [
                PrismaRequestStatus.COLLECTION_COMPLETED,
                PrismaRequestStatus.COMPLETED,
              ],
            },
            journeys: { some: { phase: PrismaJourneyPhase.TO_DISPOSAL } },
          },
        ],
      },
      orderBy: { updatedAt: "desc" },
      take: 100,
      include: REQUEST_INCLUDE,
    });
    return requests.map((request) => this.summary(request));
  }

  async upsertDisposalSite(
    actor: AuthenticatedActor,
    input: {
      id: string;
      name: string;
      address: string;
      latitude: number;
      longitude: number;
      active: boolean;
    },
  ) {
    this.assertCallCentre(actor);
    const site = await this.prisma.$transaction(async (tx) => {
      const value = await tx.disposalSite.upsert({
        where: { id: input.id },
        create: input,
        update: {
          name: input.name,
          address: input.address,
          latitude: input.latitude,
          longitude: input.longitude,
          active: input.active,
        },
      });
      await this.audit(
        tx,
        actor.user.id,
        "disposal-site.updated",
        "DisposalSite",
        value.id,
        null,
        { active: value.active },
      );
      return value;
    });
    return this.disposalSite(site);
  }

  async disposalSites(actor: AuthenticatedActor) {
    if (actor.user.actorType === PrismaActorType.SERVICE_PROVIDER)
      this.assertProvider(actor);
    else if (
      actor.user.actorType === PrismaActorType.KCCA_STAFF &&
      !actor.user.callCentreOperationsPermitted
    )
      this.assertKccaMonitoring(actor);
    else
      throw new ForbiddenException({
        code: ApiErrorCode.accessDenied,
        message: "This account cannot view disposal sites.",
      });
    const sites = await this.prisma.disposalSite.findMany({
      ...(actor.user.actorType === PrismaActorType.KCCA_STAFF &&
      actor.user.callCentreOperationsPermitted
        ? {}
        : { where: { active: true } }),
      orderBy: { name: "asc" },
    });
    return sites.map((site) => this.disposalSite(site));
  }

  async assignDisposalSite(
    actor: AuthenticatedActor,
    requestId: string,
    disposalSiteId: string,
    idempotencyKey: string,
  ) {
    this.assertCallCentre(actor);
    await this.idempotent(
      actor.user.id,
      `disposal.assign:${requestId}`,
      idempotencyKey,
      { disposalSiteId },
      async (tx) => {
        await this.assignDisposalSiteTx(
          tx,
          actor.user.id,
          requestId,
          disposalSiteId,
        );
        return { assigned: true };
      },
    );
    return this.authorizedRequestDetail(actor, requestId);
  }

  async disposalAssignmentHistory(
    actor: AuthenticatedActor,
    requestId: string,
  ) {
    this.assertCallCentre(actor);
    const exists = await this.prisma.serviceRequest.findUnique({
      where: { id: requestId },
      select: { id: true },
    });
    if (!exists) throw this.notFound();
    const history = await this.prisma.disposalAssignmentHistory.findMany({
      where: { requestId },
      orderBy: { assignedAt: "desc" },
      include: { disposalSite: { select: { id: true, name: true } } },
    });
    return history.map((item) => ({
      disposalSiteId: item.disposalSite.id,
      disposalSiteName: item.disposalSite.name,
      assignedAt: item.assignedAt.toISOString(),
    }));
  }

  async notifications(
    actor: AuthenticatedActor,
  ): Promise<OperationalNotificationContract[]> {
    const values = await this.prisma.operationalNotification.findMany({
      where: { recipientUserId: actor.user.id },
      orderBy: { createdAt: "desc" },
      take: 100,
    });
    return values.map((value) => ({
      id: value.id,
      type: value.type as OperationalNotificationType,
      title: value.title,
      message: value.message,
      ...(value.requestId ? { requestId: value.requestId } : {}),
      createdAt: value.createdAt.toISOString(),
      ...(value.readAt ? { readAt: value.readAt.toISOString() } : {}),
    }));
  }

  async markNotificationRead(
    actor: AuthenticatedActor,
    notificationId: string,
  ): Promise<{ read: true }> {
    const updated = await this.prisma.operationalNotification.updateMany({
      where: { id: notificationId, recipientUserId: actor.user.id },
      data: { readAt: new Date() },
    });
    if (updated.count !== 1) throw this.notFound();
    return { read: true };
  }

  async authorizedRequestDetail(
    actor: AuthenticatedActor,
    requestId: string,
  ): Promise<ServiceRequestDetailContract> {
    this.assertCallCentre(actor);
    const request = await this.prisma.serviceRequest.findUnique({
      where: { id: requestId },
      include: REQUEST_INCLUDE,
    });
    if (!request) throw this.notFound();
    return this.detail(request, true);
  }

  async assertCanMonitor(
    actor: AuthenticatedActor,
    requestId: string,
    phase: JourneyPhase,
  ): Promise<void> {
    const request = await this.prisma.serviceRequest.findUnique({
      where: { id: requestId },
      select: {
        clientUserId: true,
        origin: true,
        acceptedProviderUserId: true,
      },
    });
    if (!request) throw this.notFound();
    const allowed =
      request.acceptedProviderUserId === actor.user.id ||
      (phase === JourneyPhase.toRequest &&
        request.origin === PrismaRequestOrigin.MOBILE_APP &&
        request.clientUserId === actor.user.id) ||
      (actor.user.actorType === PrismaActorType.KCCA_STAFF &&
        actor.user.isActive &&
        actor.user.mobileMonitoringPermitted &&
        (phase === JourneyPhase.toDisposal ||
          request.origin === PrismaRequestOrigin.CALL_CENTRE));
    if (!allowed)
      throw new ForbiddenException({
        code: ApiErrorCode.accessDenied,
        message: "This account cannot monitor this journey.",
      });
  }

  private validateRequestInput(input: CreateServiceRequestContract) {
    const locationKind = input.locationKind as RequestLocationKind;
    const location = input.location;
    const text = clean(input.locationText);
    if (locationKind === RequestLocationKind.text) {
      if (!text || location)
        throw this.invalid(
          "Enter a text location without coordinates, or select a map/current location.",
        );
    } else if (!location || text) {
      throw this.invalid(
        "Current and map-pin locations require valid coordinates without a text-only location.",
      );
    }
    if (
      location &&
      (!finiteInRange(location.latitude, -90, 90) ||
        !finiteInRange(location.longitude, -180, 180))
    ) {
      throw this.invalid("Enter valid latitude and longitude coordinates.");
    }
    const requestedServiceAt = input.requestedServiceAt
      ? new Date(input.requestedServiceAt)
      : null;
    if (input.scheduleMode === ScheduleMode.scheduled) {
      const now = Date.now();
      if (
        !requestedServiceAt ||
        Number.isNaN(requestedServiceAt.getTime()) ||
        requestedServiceAt.getTime() <= now ||
        requestedServiceAt.getTime() > now + 90 * 86_400_000
      ) {
        throw this.invalid(
          "Choose a future service date and time within 90 days.",
        );
      }
    } else if (requestedServiceAt) {
      throw this.invalid(
        "As soon as possible requests must not include a scheduled time.",
      );
    }
    const contactName = clean(input.additionalContactName);
    const contactPhone = input.additionalContactPhone
      ? this.phones.normalize(input.additionalContactPhone)
      : null;
    if (Boolean(contactName) !== Boolean(contactPhone))
      throw this.invalid(
        "Additional contact name and phone number must be supplied together.",
      );
    return {
      locationKind: locationKind as PrismaLocationKind,
      locationText: text,
      latitude: location?.latitude ?? null,
      longitude: location?.longitude ?? null,
      toiletType: input.toiletType
        ? (input.toiletType as PrismaToiletType)
        : null,
      additionalContactName: contactName,
      encryptedAdditionalPhone: contactPhone
        ? this.phones.encrypt(contactPhone)
        : null,
      scheduleMode: input.scheduleMode as PrismaScheduleMode,
      requestedServiceAt,
    };
  }

  private validateSamples(samples: SubmitLocationBatchContract["samples"]) {
    if (samples.length < 1 || samples.length > 50)
      throw this.invalid("Submit between 1 and 50 location samples.");
    const now = Date.now();
    let previous = 0;
    const seen = new Set<string>();
    return samples.map((sample) => {
      if (
        !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
          sample.sampleId,
        ) ||
        seen.has(sample.sampleId)
      )
        throw this.invalid("Every location sample requires a unique UUID.");
      seen.add(sample.sampleId);
      const deviceTimestamp = new Date(sample.deviceTimestamp);
      if (
        Number.isNaN(deviceTimestamp.getTime()) ||
        deviceTimestamp.getTime() <= previous ||
        deviceTimestamp.getTime() > now + 300_000
      )
        throw this.invalid(
          "Location samples must be ordered and use valid timestamps.",
        );
      previous = deviceTimestamp.getTime();
      if (
        !finiteInRange(sample.latitude, -90, 90) ||
        !finiteInRange(sample.longitude, -180, 180) ||
        !finiteInRange(sample.accuracyMetres, 0, 10_000)
      )
        throw this.invalid(
          "A location sample contains invalid coordinates or accuracy.",
        );
      return { ...sample, deviceTimestamp };
    });
  }

  private destination(
    request: {
      latitude: Prisma.Decimal | null;
      longitude: Prisma.Decimal | null;
      disposalAssignment: {
        disposalSite: { latitude: Prisma.Decimal; longitude: Prisma.Decimal };
      } | null;
    },
    phase: JourneyPhase,
  ) {
    if (phase === JourneyPhase.toRequest) {
      return request.latitude !== null && request.longitude !== null
        ? {
            latitude: Number(request.latitude),
            longitude: Number(request.longitude),
          }
        : null;
    }
    return request.disposalAssignment
      ? {
          latitude: Number(request.disposalAssignment.disposalSite.latitude),
          longitude: Number(request.disposalAssignment.disposalSite.longitude),
        }
      : null;
  }

  private summary(request: any): ServiceRequestSummaryContract {
    const providerName = request.acceptedProvider?.serviceProviderProfile
      ?.companyName as string | undefined;
    return {
      id: request.id,
      reference: request.reference,
      origin: request.origin as ServiceRequestOrigin,
      status: request.status as ServiceRequestStatus,
      locationLabel: locationLabel(
        request.locationText,
        request.latitude,
        request.longitude,
      ),
      scheduleMode: request.scheduleMode as ScheduleMode,
      ...(request.requestedServiceAt
        ? { requestedServiceAt: request.requestedServiceAt.toISOString() }
        : {}),
      ...(providerName ? { providerName } : {}),
      ...(request.agreedPriceUgx !== null
        ? { agreedPriceUgx: request.agreedPriceUgx }
        : {}),
      ...(outstandingAction(request.status)
        ? { outstandingAction: outstandingAction(request.status)! }
        : {}),
      updatedAt: request.updatedAt.toISOString(),
    };
  }

  private detail(
    request: any,
    includeContacts: boolean,
    includePreciseLocation = true,
  ): ServiceRequestDetailContract {
    const summary = {
      ...this.summary(request),
      ...(!includePreciseLocation
        ? { locationLabel: "Location available after acceptance" }
        : {}),
    };
    const toRequest = request.journeys?.find(
      (journey: any) => journey.phase === PrismaJourneyPhase.TO_REQUEST,
    );
    const disposal = request.journeys?.find(
      (journey: any) => journey.phase === PrismaJourneyPhase.TO_DISPOSAL,
    );
    const providerPhone = request.acceptedProvider?.encryptedPhone
      ? this.phones.decrypt(request.acceptedProvider.encryptedPhone)
      : null;
    const toRequestSnapshot =
      toRequest && this.destination(toRequest.request, JourneyPhase.toRequest)
        ? this.journeySnapshot(toRequest)
        : null;
    const disposalSnapshot =
      disposal && this.destination(disposal.request, JourneyPhase.toDisposal)
        ? this.journeySnapshot(disposal)
        : null;
    return {
      ...summary,
      clientName: includeContacts
        ? request.clientName
        : "Client details available after acceptance",
      ...(includeContacts
        ? { clientPhone: this.phones.decrypt(request.encryptedClientPhone) }
        : {}),
      ...(includeContacts && request.encryptedClientEmail
        ? { clientEmail: this.emails.decrypt(request.encryptedClientEmail) }
        : {}),
      locationKind: request.locationKind as RequestLocationKind,
      ...(includePreciseLocation &&
      request.latitude !== null &&
      request.longitude !== null
        ? {
            location: {
              latitude: Number(request.latitude),
              longitude: Number(request.longitude),
            },
          }
        : {}),
      ...(request.toiletType
        ? { toiletType: request.toiletType as never }
        : {}),
      ...(includeContacts && request.additionalContactName
        ? { additionalContactName: request.additionalContactName }
        : {}),
      ...(includeContacts && request.encryptedAdditionalPhone
        ? {
            additionalContactPhone: this.phones.decrypt(
              request.encryptedAdditionalPhone,
            ),
          }
        : {}),
      ...(request.acceptedProviderUserId
        ? { providerUserId: request.acceptedProviderUserId }
        : {}),
      ...(providerPhone ? { providerPhone } : {}),
      ...(request.feedback
        ? {
            collectionOutcome: request.feedback.outcome as CollectionOutcome,
            wasteCollected: request.feedback.wasteCollected,
          }
        : {}),
      ...(request.followUpCase
        ? { followUpStatus: request.followUpCase.status as FollowUpStatus }
        : {}),
      ...(toRequestSnapshot ? { journeyToRequest: toRequestSnapshot } : {}),
      ...(disposalSnapshot ? { disposalJourney: disposalSnapshot } : {}),
      ...(request.disposalAssignment
        ? {
            disposalSite: this.disposalSite(
              request.disposalAssignment.disposalSite,
            ),
          }
        : {}),
      createdAt: request.createdAt.toISOString(),
    };
  }

  private journeySnapshot(journey: any): JourneySnapshotContract {
    const latest = journey.positions?.[0];
    const destination = this.destination(
      journey.request,
      journey.phase === PrismaJourneyPhase.TO_REQUEST
        ? JourneyPhase.toRequest
        : JourneyPhase.toDisposal,
    );
    if (!destination)
      throw new ConflictException({
        code: ApiErrorCode.locationUnavailable,
        message: "This journey has no coordinate destination.",
      });
    return {
      id: journey.id,
      phase: journey.phase as JourneyPhase,
      status: journey.status as JourneyStatus,
      destination,
      ...(latest
        ? {
            latestPosition: {
              sampleId: latest.sampleId,
              deviceTimestamp: latest.deviceTimestamp.toISOString(),
              latitude: Number(latest.latitude),
              longitude: Number(latest.longitude),
              accuracyMetres: Number(latest.accuracyMetres),
            },
            latestPositionReceivedAt: latest.receivedAt.toISOString(),
          }
        : {}),
      stale:
        !latest ||
        Date.now() - latest.receivedAt.getTime() >
          this.policy.staleAfterSeconds * 1000,
      ...(journey.startedAt
        ? { startedAt: journey.startedAt.toISOString() }
        : {}),
      ...(journey.arrivedAt
        ? { arrivedAt: journey.arrivedAt.toISOString() }
        : {}),
      ...(journey.completedAt
        ? { completedAt: journey.completedAt.toISOString() }
        : {}),
      positionCount: journey._count?.positions ?? 0,
    };
  }

  private disposalSite(site: {
    id: string;
    name: string;
    address: string;
    latitude: Prisma.Decimal;
    longitude: Prisma.Decimal;
    active: boolean;
  }) {
    return {
      id: site.id,
      name: site.name,
      address: site.address,
      latitude: Number(site.latitude),
      longitude: Number(site.longitude),
      active: site.active,
    };
  }

  private async assignDisposalSiteTx(
    tx: TransactionClient,
    actorUserId: string,
    requestId: string,
    siteId: string,
  ): Promise<void> {
    const [request, site] = await Promise.all([
      tx.serviceRequest.findUnique({
        where: { id: requestId },
        select: {
          id: true,
          acceptedProviderUserId: true,
          journeys: {
            where: { phase: PrismaJourneyPhase.TO_DISPOSAL },
            select: { status: true },
          },
        },
      }),
      tx.disposalSite.findFirst({
        where: { id: siteId, active: true },
        select: { id: true },
      }),
    ]);
    if (!request) throw this.notFound();
    if (request.journeys.some((journey) => journey.status !== "READY"))
      throw this.invalid(
        "The disposal-site assignment cannot change after the disposal journey starts.",
      );
    if (!site)
      throw this.invalid("Select an active KCCA-approved disposal site.");
    await tx.disposalAssignment.upsert({
      where: { requestId },
      create: {
        requestId,
        disposalSiteId: site.id,
        assignedByUserId: actorUserId,
      },
      update: {
        disposalSiteId: site.id,
        assignedByUserId: actorUserId,
        assignedAt: new Date(),
      },
    });
    await tx.disposalAssignmentHistory.create({
      data: {
        requestId,
        disposalSiteId: site.id,
        assignedByUserId: actorUserId,
      },
    });
    await this.audit(
      tx,
      actorUserId,
      "disposal-site.assigned",
      "ServiceRequest",
      requestId,
      requestId,
      { disposalSiteId: site.id },
    );
  }

  private async createReminders(
    tx: TransactionClient,
    requestId: string,
    recipientUserId: string,
    requestedServiceAt: Date | null,
  ): Promise<void> {
    if (!requestedServiceAt) return;
    for (const offsetMinutes of this.reminders.offsetsMinutes) {
      const dueAt = new Date(
        Math.max(
          Date.now(),
          requestedServiceAt.getTime() - offsetMinutes * 60_000,
        ),
      );
      for (const channel of [
        NotificationDeliveryChannel.IN_APP,
        NotificationDeliveryChannel.PUSH,
      ]) {
        await tx.outboxEvent.upsert({
          where: {
            deduplicationKey: `reminder:${requestId}:${recipientUserId}:${offsetMinutes}:${channel}`,
          },
          create: {
            requestId,
            recipientUserId,
            channel,
            eventType: PrismaNotificationType.REMINDER,
            deduplicationKey: `reminder:${requestId}:${recipientUserId}:${offsetMinutes}:${channel}`,
            nextAttemptAt: dueAt,
            payload: {
              requestedServiceAt: requestedServiceAt.toISOString(),
              offsetMinutes,
              title: "Upcoming Weyonje service",
              message: "Your scheduled Weyonje service is coming up.",
            },
          },
          update: {
            nextAttemptAt: dueAt,
            status: "PENDING",
            attempts: 0,
            deliveredAt: null,
            deadLetteredAt: null,
            payload: {
              requestedServiceAt: requestedServiceAt.toISOString(),
              offsetMinutes,
              title: "Upcoming Weyonje service",
              message: "Your scheduled Weyonje service is coming up.",
            },
          },
        });
      }
    }
  }

  private async idempotent<T extends Record<string, unknown>>(
    actorUserId: string,
    operation: string,
    key: string,
    payload: unknown,
    work: (tx: TransactionClient) => Promise<T>,
    diagnose: RequestStageRunner = withoutDiagnostics,
  ): Promise<T> {
    const fingerprint = createHash("sha256")
      .update(stableJson(payload))
      .digest("base64url");
    const execute = async () =>
      diagnose("transaction_completion", () =>
        this.prisma.$transaction(
          async (tx) => {
            const existing = await diagnose("idempotency_lookup", () =>
              tx.idempotencyRecord.findUnique({
                where: {
                  actorUserId_operation_key: { actorUserId, operation, key },
                },
              }),
            );
            if (existing) {
              if (existing.fingerprint !== fingerprint)
                throw new ConflictException({
                  code: ApiErrorCode.idempotencyConflict,
                  message:
                    "This idempotency key was already used for different data.",
                });
              return existing.response as T;
            }
            const response = await work(tx);
            await diagnose("idempotency_write", () =>
              tx.idempotencyRecord.create({
                data: {
                  actorUserId,
                  operation,
                  key,
                  fingerprint,
                  response: response as Prisma.InputJsonValue,
                  expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
                },
              }),
            );
            return response;
          },
          { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
        ),
      );
    try {
      return await execute();
    } catch (error) {
      if (isRetryableTransactionConflict(error)) {
        try {
          return await execute();
        } catch (retryError) {
          error = retryError;
        }
      }
      if (!isUniqueConflict(error)) throw error;
      const existing = await diagnose("idempotency_recovery", () =>
        this.prisma.idempotencyRecord.findUnique({
          where: { actorUserId_operation_key: { actorUserId, operation, key } },
        }),
      );
      if (!existing || existing.fingerprint !== fingerprint)
        throw new ConflictException({
          code: ApiErrorCode.idempotencyConflict,
          message: "This idempotency key was already used for different data.",
        });
      return existing.response as T;
    }
  }

  private transitionRecord(
    tx: TransactionClient,
    requestId: string,
    fromStatus: PrismaRequestStatus,
    toStatus: PrismaRequestStatus,
    actorUserId: string,
    reason?: string,
  ) {
    return tx.requestStatusHistory.create({
      data: {
        requestId,
        fromStatus,
        toStatus,
        actorUserId,
        ...(reason ? { reason } : {}),
      },
    });
  }

  private audit(
    tx: TransactionClient,
    actorUserId: string | null,
    action: string,
    targetType: string,
    targetId: string,
    requestId: string | null,
    metadata?: Prisma.InputJsonValue,
  ) {
    return tx.auditEvent.create({
      data: {
        actorUserId,
        action,
        targetType,
        targetId,
        requestId,
        ...(metadata !== undefined ? { metadata } : {}),
      },
    });
  }

  private outbox(
    tx: TransactionClient,
    requestId: string,
    recipientUserId: string | null,
    channel: NotificationDeliveryChannel,
    eventType: PrismaNotificationType,
    deduplicationKey: string,
  ) {
    return tx.outboxEvent.create({
      data: {
        requestId,
        recipientUserId,
        channel,
        eventType,
        deduplicationKey,
        payload: { requestId, recipientUserId, eventType },
      },
    });
  }

  private async notify(
    tx: TransactionClient,
    recipientUserId: string,
    requestId: string,
    type: PrismaNotificationType,
    title: string,
    message: string,
    diagnose: RequestStageRunner = withoutDiagnostics,
  ): Promise<void> {
    const notification = await diagnose("notification_write", () =>
      tx.operationalNotification.create({
        data: { recipientUserId, requestId, type, title, message },
        select: { id: true },
      }),
    );
    await diagnose("outbox_write", () =>
      this.outbox(
        tx,
        requestId,
        recipientUserId,
        NotificationDeliveryChannel.IN_APP,
        type,
        `notification:${notification.id}:in-app`,
      ),
    );
  }

  private async notifyKcca(
    tx: TransactionClient,
    requestId: string,
    type: PrismaNotificationType,
    title: string,
    message: string,
  ): Promise<void> {
    const recipients = await tx.user.findMany({
      where: {
        actorType: PrismaActorType.KCCA_STAFF,
        isActive: true,
        mobileMonitoringPermitted: true,
      },
      select: { id: true },
    });
    for (const recipient of recipients)
      await this.notify(tx, recipient.id, requestId, type, title, message);
  }

  private async notifyRelevant(
    tx: TransactionClient,
    request: {
      clientUserId: string | null;
      createdByUserId: string | null;
      origin: PrismaRequestOrigin;
    },
    requestId: string,
    type: PrismaNotificationType,
    title: string,
    message: string,
  ): Promise<void> {
    if (request.clientUserId)
      await this.notify(
        tx,
        request.clientUserId,
        requestId,
        type,
        title,
        message,
      );
    if (request.origin === PrismaRequestOrigin.CALL_CENTRE)
      await this.notifyKcca(tx, requestId, type, title, message);
  }

  private assertClient(actor: AuthenticatedActor): void {
    if (actor.user.actorType !== PrismaActorType.CLIENT || !actor.user.isActive)
      throw new ForbiddenException({
        code: ApiErrorCode.accessDenied,
        message: "Only an active Client can use this operation.",
      });
  }

  private assertProvider(actor: AuthenticatedActor): void {
    if (
      actor.user.actorType !== PrismaActorType.SERVICE_PROVIDER ||
      !actor.user.isActive ||
      actor.user.providerStatus !== "APPROVED"
    )
      throw new ForbiddenException({
        code: ApiErrorCode.accessDenied,
        message:
          "Only an approved and active Service Provider can use provider work.",
      });
  }

  private assertCallCentre(actor: AuthenticatedActor): void {
    if (
      actor.user.actorType !== PrismaActorType.KCCA_STAFF ||
      !actor.user.isActive ||
      !actor.user.callCentreOperationsPermitted
    )
      throw new ForbiddenException({
        code: ApiErrorCode.accessDenied,
        message: "This KCCA account cannot perform Call Centre operations.",
      });
  }

  private assertKccaMonitoring(actor: AuthenticatedActor): void {
    if (
      actor.user.actorType !== PrismaActorType.KCCA_STAFF ||
      !actor.user.isActive ||
      !actor.user.mobileMonitoringPermitted
    )
      throw new ForbiddenException({
        code: ApiErrorCode.accessDenied,
        message: "This KCCA account cannot monitor journeys.",
      });
  }

  private invalid(message = "The request data is invalid.") {
    return new BadRequestException({
      code: ApiErrorCode.invalidRequest,
      message,
    });
  }

  private invalidTransition(
    message = "This action is not allowed in the current state.",
  ) {
    return new ConflictException({
      code: ApiErrorCode.invalidTransition,
      message,
    });
  }

  private alreadyAccepted() {
    return new ConflictException({
      code: ApiErrorCode.requestAlreadyAccepted,
      message: "This request is no longer available.",
    });
  }

  private notFound() {
    return new NotFoundException({
      code: ApiErrorCode.requestNotFound,
      message: "The requested record was not found.",
    });
  }
}

function clean(value: string | undefined): string | null {
  const normalized = value?.trim();
  return normalized ? normalized : null;
}

function requiredText(value: string, message: string): string {
  const normalized = value.trim();
  if (!normalized)
    throw new BadRequestException({
      code: ApiErrorCode.invalidRequest,
      message,
    });
  return normalized;
}

function requestReference(): string {
  return `WRQ-${randomUUID().replaceAll("-", "").slice(0, 12).toUpperCase()}`;
}

function finiteInRange(
  value: number,
  minimum: number,
  maximum: number,
): boolean {
  return Number.isFinite(value) && value >= minimum && value <= maximum;
}

function locationLabel(
  text: string | null,
  latitude: Prisma.Decimal | null,
  longitude: Prisma.Decimal | null,
): string {
  return (
    text ??
    (latitude !== null && longitude !== null
      ? `${Number(latitude).toFixed(5)}, ${Number(longitude).toFixed(5)}`
      : "Location unavailable")
  );
}

function outstandingAction(status: PrismaRequestStatus): string | null {
  if (status === PrismaRequestStatus.COLLECTION_REPORTED)
    return "Confirm collection outcome";
  if (status === PrismaRequestStatus.FOLLOW_UP_REQUIRED)
    return "KCCA follow-up required";
  if (status === PrismaRequestStatus.ACCEPTED)
    return "Provider must initiate the job";
  if (status === PrismaRequestStatus.COLLECTION_COMPLETED)
    return "Provider must complete disposal";
  return null;
}

function stableJson(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(",")}]`;
  if (value && typeof value === "object") {
    return `{${Object.entries(value as Record<string, unknown>)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([key, nested]) => `${JSON.stringify(key)}:${stableJson(nested)}`)
      .join(",")}}`;
  }
  return JSON.stringify(value);
}

function isUniqueConflict(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    error.code === "P2002"
  );
}

function isRetryableTransactionConflict(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    error.code === "P2034"
  );
}

function distanceMetres(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {
  const radians = (degrees: number) => (degrees * Math.PI) / 180;
  const dLat = radians(lat2 - lat1);
  const dLon = radians(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(radians(lat1)) * Math.cos(radians(lat2)) * Math.sin(dLon / 2) ** 2;
  return 6_371_000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export function hasConsecutiveArrivalEvidence(
  previousAccepted: boolean | undefined,
  currentAccepted: readonly boolean[],
): boolean {
  const evidence = [
    ...(previousAccepted === undefined ? [] : [previousAccepted]),
    ...currentAccepted,
  ];
  return (
    evidence.length >= 2 && evidence.at(-1) === true && evidence.at(-2) === true
  );
}
