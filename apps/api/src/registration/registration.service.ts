import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  ActorType,
  ApiErrorCode,
  ClientRegistrationRequestContract,
  ClientType,
  PendingProviderRegistrationContract,
  ProviderAdministrationContract,
  PhoneChallengeContract,
  ProviderApprovalDecision,
  ProviderApprovalRequestContract,
  ProviderRegistrationStatusContract,
  ProviderStatusChangeContract,
  ProviderStatus,
  ServiceProviderRegistrationRequestContract,
  ServiceProviderType,
  SessionCredentialsContract,
} from "@weyonje/contracts";
import { randomUUID } from "node:crypto";

import { AuthenticatedActor } from "../auth/authenticated-actor";
import { EmailSecurityService } from "../auth/email-security.service";
import { PasswordService } from "../auth/password.service";
import { SessionService } from "../auth/session.service";
import { PrismaService } from "../database/prisma.service";
import {
  ActorType as PrismaActorType,
  ClientType as PrismaClientType,
  NotificationType,
  NotificationDeliveryChannel,
  OperationalNotificationType,
  PhoneChallengePurpose,
  ProviderApprovalDecision as PrismaApprovalDecision,
  ProviderStatus as PrismaProviderStatus,
  ServiceProviderType as PrismaServiceProviderType,
} from "../generated/prisma/enums";
import { PhoneChallengeService } from "./phone-challenge.service";
import { PhoneSecurityService } from "./phone-security.service";

@Injectable()
export class RegistrationService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly emails: EmailSecurityService,
    private readonly passwords: PasswordService,
    private readonly phones: PhoneSecurityService,
    private readonly challenges: PhoneChallengeService,
    private readonly sessions: SessionService,
  ) {}

  async registerClient(
    request: ClientRegistrationRequestContract,
  ): Promise<PhoneChallengeContract> {
    this.validateClientShape(request);
    const phone = this.phones.normalize(request.phoneNumber);
    const email = request.email ? this.emails.normalize(request.email) : null;
    const contactPhone = request.contactPersonPhone
      ? this.phones.normalize(request.contactPersonPhone)
      : null;
    await this.assertIdentifiersAvailable(phone, email);
    let user: { id: string };
    try {
      user = await this.prisma.user.create({
        data: {
          encryptedEmail: email ? this.emails.encrypt(email) : null,
          emailLookup: email ? this.emails.lookup(email) : null,
          passwordHash: null,
          encryptedPhone: this.phones.encrypt(phone),
          phoneLookup: this.phones.lookup(phone),
          actorType: PrismaActorType.CLIENT,
          providerStatus: null,
          isActive: false,
          loginEnabled: false,
          clientProfile: {
            create: {
              clientType:
                request.clientType === ClientType.individual
                  ? PrismaClientType.INDIVIDUAL
                  : PrismaClientType.ORGANIZATION,
              firstName: clean(request.firstName),
              lastName: clean(request.lastName),
              organizationName: clean(request.organizationName),
              contactPersonName: clean(request.contactPersonName),
              encryptedContactPhone: contactPhone
                ? this.phones.encrypt(contactPhone)
                : null,
            },
          },
        },
        select: { id: true },
      });
    } catch (error) {
      if (isUniqueConflict(error)) throw this.conflict();
      throw error;
    }
    return this.challenges.create(
      phone,
      PhoneChallengePurpose.REGISTRATION,
      user.id,
    );
  }

  async registerServiceProvider(
    request: ServiceProviderRegistrationRequestContract,
  ): Promise<PhoneChallengeContract> {
    const phone = this.phones.normalize(request.phoneNumber);
    const email = this.emails.normalize(request.email);
    const contactPhone = this.phones.normalize(request.contactPersonPhone);
    await this.assertIdentifiersAvailable(phone, email);
    const passwordHash = await this.passwords.hash(request.password);
    let user: { id: string };
    try {
      user = await this.prisma.user.create({
        data: {
          encryptedEmail: this.emails.encrypt(email),
          emailLookup: this.emails.lookup(email),
          passwordHash,
          encryptedPhone: this.phones.encrypt(phone),
          phoneLookup: this.phones.lookup(phone),
          actorType: PrismaActorType.SERVICE_PROVIDER,
          providerStatus: PrismaProviderStatus.PENDING,
          isActive: false,
          loginEnabled: false,
          serviceProviderProfile: {
            create: {
              essLicenseNumber: requiredText(request.essLicenseNumber),
              companyName: requiredText(request.companyName),
              workAddress: requiredText(request.workAddress),
              providerType:
                request.providerType === ServiceProviderType.gulper
                  ? PrismaServiceProviderType.GULPER
                  : PrismaServiceProviderType.EMPTIER,
              contactPersonName: requiredText(request.contactPersonName),
              encryptedContactPhone: this.phones.encrypt(contactPhone),
            },
          },
        },
        select: { id: true },
      });
    } catch (error) {
      if (isUniqueConflict(error)) throw this.conflict();
      throw error;
    }
    return this.challenges.create(
      phone,
      PhoneChallengePurpose.REGISTRATION,
      user.id,
    );
  }

  resendPhoneCode(challengeId: string): Promise<PhoneChallengeContract> {
    return this.challenges.resend(
      challengeId,
      PhoneChallengePurpose.REGISTRATION,
    );
  }

  async verifyPhone(
    challengeId: string,
    code: string,
  ): Promise<SessionCredentialsContract> {
    const userId = await this.challenges.verify(
      challengeId,
      code,
      PhoneChallengePurpose.REGISTRATION,
    );
    if (!userId) throw new NotFoundException();
    const now = new Date();
    const user = await this.prisma.$transaction(async (transaction) => {
      const current = await transaction.user.findUnique({
        where: { id: userId },
        select: {
          id: true,
          actorType: true,
          phoneVerifiedAt: true,
          passwordVersion: true,
        },
      });
      if (!current || current.phoneVerifiedAt !== null) {
        throw this.conflict("This registration has already been verified.");
      }
      await transaction.user.update({
        where: { id: current.id },
        data: {
          phoneVerifiedAt: now,
          loginEnabled: true,
          isActive: current.actorType === PrismaActorType.CLIENT,
        },
      });
      if (current.actorType === PrismaActorType.CLIENT) {
        await transaction.clientProfile.update({
          where: { userId: current.id },
          data: { clientNumber: accountNumber("WCL") },
        });
      } else if (current.actorType === PrismaActorType.SERVICE_PROVIDER) {
        await transaction.registrationNotification.create({
          data: {
            recipientActorType: PrismaActorType.KCCA_STAFF,
            type: NotificationType.PROVIDER_REVIEW_REQUIRED,
            subjectUserId: current.id,
          },
        });
      } else {
        throw new BadRequestException({
          code: ApiErrorCode.invalidRequest,
          message: "This registration cannot be verified here.",
        });
      }
      return current;
    });
    return this.sessions.create(user);
  }

  async pendingProviders(
    actor: AuthenticatedActor,
  ): Promise<PendingProviderRegistrationContract[]> {
    this.assertApprovalPermission(actor);
    const providers = await this.prisma.user.findMany({
      where: {
        actorType: PrismaActorType.SERVICE_PROVIDER,
        providerStatus: PrismaProviderStatus.PENDING,
        phoneVerifiedAt: { not: null },
      },
      orderBy: { createdAt: "asc" },
      take: 100,
      select: {
        id: true,
        encryptedEmail: true,
        encryptedPhone: true,
        createdAt: true,
        serviceProviderProfile: true,
      },
    });
    return providers.map((provider) => {
      const profile = provider.serviceProviderProfile!;
      return {
        providerUserId: provider.id,
        essLicenseNumber: profile.essLicenseNumber,
        companyName: profile.companyName,
        phoneNumber: this.phones.decrypt(provider.encryptedPhone!),
        email: this.emails.decrypt(provider.encryptedEmail!),
        workAddress: profile.workAddress,
        providerType: profile.providerType as ServiceProviderType,
        contactPersonName: profile.contactPersonName,
        contactPersonPhone: this.phones.decrypt(profile.encryptedContactPhone),
        submittedAt: provider.createdAt.toISOString(),
      };
    });
  }

  async providers(
    actor: AuthenticatedActor,
    status?: ProviderStatus,
  ): Promise<ProviderAdministrationContract[]> {
    this.assertApprovalPermission(actor);
    if (status && !Object.values(ProviderStatus).includes(status)) {
      throw new BadRequestException({
        code: ApiErrorCode.invalidRequest,
        message: "Select a recognized Provider status.",
      });
    }
    const providers = await this.prisma.user.findMany({
      where: {
        actorType: PrismaActorType.SERVICE_PROVIDER,
        ...(status ? { providerStatus: status as PrismaProviderStatus } : {}),
      },
      orderBy: { createdAt: "desc" },
      take: 200,
      include: {
        serviceProviderProfile: true,
        providerStatusHistory: { orderBy: { createdAt: "desc" } },
      },
    });
    return providers.map((provider) => this.providerAdministration(provider));
  }

  async providerAdministrationDetail(
    actor: AuthenticatedActor,
    providerUserId: string,
  ): Promise<ProviderAdministrationContract> {
    this.assertApprovalPermission(actor);
    const provider = await this.prisma.user.findFirst({
      where: {
        id: providerUserId,
        actorType: PrismaActorType.SERVICE_PROVIDER,
      },
      include: {
        serviceProviderProfile: true,
        providerStatusHistory: { orderBy: { createdAt: "desc" } },
      },
    });
    if (!provider?.serviceProviderProfile || !provider.providerStatus)
      throw new NotFoundException({
        code: ApiErrorCode.invalidRequest,
        message: "The Service Provider was not found.",
      });
    return this.providerAdministration(provider);
  }

  async changeProviderStatus(
    actor: AuthenticatedActor,
    providerUserId: string,
    input: ProviderStatusChangeContract,
  ): Promise<ProviderAdministrationContract> {
    this.assertApprovalPermission(actor);
    const allowed = [
      ProviderStatus.approved,
      ProviderStatus.inactive,
      ProviderStatus.disabled,
    ];
    if (!allowed.includes(input.status)) {
      throw new BadRequestException({
        code: ApiErrorCode.invalidRequest,
        message:
          "Only activation, deactivation, or disabling is permitted here.",
      });
    }
    const reason = clean(input.reason);
    if (input.status === ProviderStatus.disabled && !reason) {
      throw new BadRequestException({
        code: ApiErrorCode.invalidRequest,
        message: "A reason is required when disabling a Provider.",
      });
    }
    await this.prisma.$transaction(async (tx) => {
      const provider = await tx.user.findFirst({
        where: {
          id: providerUserId,
          actorType: PrismaActorType.SERVICE_PROVIDER,
        },
        select: { providerStatus: true, phoneVerifiedAt: true },
      });
      if (
        !provider?.providerStatus ||
        provider.providerStatus === PrismaProviderStatus.PENDING
      )
        throw this.conflict("Complete the pending approval decision first.");
      if (provider.providerStatus === (input.status as PrismaProviderStatus))
        throw this.conflict("The Provider already has this status.");
      if (input.status === ProviderStatus.approved && !provider.phoneVerifiedAt)
        throw this.conflict(
          "The Provider phone number must be verified before activation.",
        );
      await tx.user.update({
        where: { id: providerUserId },
        data: {
          providerStatus: input.status as PrismaProviderStatus,
          isActive: input.status === ProviderStatus.approved,
        },
      });
      const history = await tx.providerStatusHistory.create({
        data: {
          providerUserId,
          changedByUserId: actor.user.id,
          fromStatus: provider.providerStatus,
          toStatus: input.status as PrismaProviderStatus,
          reason,
        },
      });
      const title =
        input.status === ProviderStatus.approved
          ? "Provider account activated"
          : "Provider account status changed";
      await tx.operationalNotification.create({
        data: {
          recipientUserId: providerUserId,
          type: OperationalNotificationType.PROVIDER_ACCOUNT_UPDATED,
          title,
          message: "Your Weyonje Provider account status was updated by KCCA.",
        },
      });
      await tx.outboxEvent.create({
        data: {
          recipientUserId: providerUserId,
          channel: NotificationDeliveryChannel.PUSH,
          eventType: OperationalNotificationType.PROVIDER_ACCOUNT_UPDATED,
          deduplicationKey: `provider:${providerUserId}:status:${history.id}`,
          payload: { providerUserId, status: input.status },
        },
      });
    });
    return this.providerAdministrationDetail(actor, providerUserId);
  }

  async decideProvider(
    actor: AuthenticatedActor,
    providerUserId: string,
    request: ProviderApprovalRequestContract,
  ): Promise<ProviderRegistrationStatusContract> {
    this.assertApprovalPermission(actor);
    if (
      request.decision === ProviderApprovalDecision.approved &&
      request.reason !== undefined
    ) {
      throw new BadRequestException({
        code: ApiErrorCode.invalidRequest,
        message: "An approval must not include a rejection reason.",
      });
    }
    const reason = clean(request.reason);
    if (
      request.decision === ProviderApprovalDecision.rejected &&
      reason === null
    ) {
      throw new BadRequestException({
        code: ApiErrorCode.invalidRequest,
        message: "A rejection reason is required.",
      });
    }
    return this.prisma.$transaction(async (transaction) => {
      const provider = await transaction.user.findUnique({
        where: { id: providerUserId },
        select: {
          actorType: true,
          providerStatus: true,
          phoneVerifiedAt: true,
          serviceProviderProfile: true,
        },
      });
      if (
        !provider ||
        provider.actorType !== PrismaActorType.SERVICE_PROVIDER ||
        !provider.serviceProviderProfile
      ) {
        throw new NotFoundException({
          code: ApiErrorCode.invalidRequest,
          message: "The provider registration was not found.",
        });
      }
      if (
        provider.providerStatus !== PrismaProviderStatus.PENDING ||
        provider.phoneVerifiedAt === null
      ) {
        throw this.conflict("This provider registration is no longer pending.");
      }
      const approved = request.decision === ProviderApprovalDecision.approved;
      const providerNumber = approved ? accountNumber("WSP") : undefined;
      await transaction.user.update({
        where: { id: providerUserId },
        data: {
          providerStatus: approved
            ? PrismaProviderStatus.APPROVED
            : PrismaProviderStatus.REJECTED,
          isActive: approved,
        },
      });
      await transaction.serviceProviderProfile.update({
        where: { userId: providerUserId },
        data: {
          providerNumber: providerNumber ?? null,
          latestRejectionReason: approved ? null : reason,
        },
      });
      await transaction.providerApprovalDecisionRecord.create({
        data: {
          providerUserId,
          decidedByUserId: actor.user.id,
          decision: approved
            ? PrismaApprovalDecision.APPROVED
            : PrismaApprovalDecision.REJECTED,
          reason: approved ? null : reason,
        },
      });
      await transaction.providerStatusHistory.create({
        data: {
          providerUserId,
          changedByUserId: actor.user.id,
          fromStatus: PrismaProviderStatus.PENDING,
          toStatus: approved
            ? PrismaProviderStatus.APPROVED
            : PrismaProviderStatus.REJECTED,
          reason: approved ? null : reason,
        },
      });
      await transaction.registrationNotification.create({
        data: {
          recipientUserId: providerUserId,
          type: approved
            ? NotificationType.PROVIDER_APPROVED
            : NotificationType.PROVIDER_REJECTED,
          subjectUserId: providerUserId,
        },
      });
      const accountMessage = approved
        ? "KCCA approved your Weyonje Provider registration."
        : "KCCA reviewed your Weyonje Provider registration. Open Weyonje for the decision.";
      await transaction.operationalNotification.create({
        data: {
          recipientUserId: providerUserId,
          type: OperationalNotificationType.PROVIDER_ACCOUNT_UPDATED,
          title: approved ? "Provider registration approved" : "Provider registration reviewed",
          message: accountMessage,
        },
      });
      await transaction.outboxEvent.create({
        data: {
          recipientUserId: providerUserId,
          channel: NotificationDeliveryChannel.PUSH,
          eventType: OperationalNotificationType.PROVIDER_ACCOUNT_UPDATED,
          deduplicationKey: `provider:${providerUserId}:review:${approved ? "approved" : "rejected"}`,
          payload: { providerUserId, decision: approved ? "APPROVED" : "REJECTED" },
        },
      });
      return approved
        ? {
            status: ProviderStatus.approved,
            ...(providerNumber ? { providerNumber } : {}),
          }
        : {
            status: ProviderStatus.rejected,
            ...(reason ? { rejectionReason: reason } : {}),
          };
    });
  }

  async providerStatus(
    actor: AuthenticatedActor,
  ): Promise<ProviderRegistrationStatusContract> {
    if (actor.user.actorType !== PrismaActorType.SERVICE_PROVIDER) {
      throw new ForbiddenException({
        code: ApiErrorCode.accessDenied,
        message: "Only a Service Provider can view this account status.",
      });
    }
    const provider = await this.prisma.user.findUnique({
      where: { id: actor.user.id },
      select: { providerStatus: true, serviceProviderProfile: true },
    });
    if (!provider?.providerStatus || !provider.serviceProviderProfile) {
      throw new NotFoundException();
    }
    const result: ProviderRegistrationStatusContract = {
      status: provider.providerStatus as ProviderStatus,
    };
    if (provider.serviceProviderProfile.providerNumber) {
      result.providerNumber = provider.serviceProviderProfile.providerNumber;
    }
    if (provider.serviceProviderProfile.latestRejectionReason) {
      result.rejectionReason =
        provider.serviceProviderProfile.latestRejectionReason;
    }
    return result;
  }

  private providerAdministration(provider: {
    id: string;
    providerStatus: PrismaProviderStatus | null;
    isActive: boolean;
    encryptedEmail: string | null;
    encryptedPhone: string | null;
    createdAt: Date;
    serviceProviderProfile: {
      essLicenseNumber: string;
      companyName: string;
      workAddress: string;
      providerType: PrismaServiceProviderType;
      contactPersonName: string;
      encryptedContactPhone: string;
      providerNumber: string | null;
      latestRejectionReason: string | null;
    } | null;
    providerStatusHistory: Array<{
      fromStatus: PrismaProviderStatus;
      toStatus: PrismaProviderStatus;
      reason: string | null;
      createdAt: Date;
    }>;
  }): ProviderAdministrationContract {
    const profile = provider.serviceProviderProfile!;
    return {
      providerUserId: provider.id,
      status: provider.providerStatus as ProviderStatus,
      active: provider.isActive,
      essLicenseNumber: profile.essLicenseNumber,
      companyName: profile.companyName,
      phoneNumber: this.phones.decrypt(provider.encryptedPhone!),
      email: this.emails.decrypt(provider.encryptedEmail!),
      workAddress: profile.workAddress,
      providerType: profile.providerType as ServiceProviderType,
      contactPersonName: profile.contactPersonName,
      contactPersonPhone: this.phones.decrypt(profile.encryptedContactPhone),
      submittedAt: provider.createdAt.toISOString(),
      ...(profile.providerNumber
        ? { providerNumber: profile.providerNumber }
        : {}),
      ...(profile.latestRejectionReason
        ? { rejectionReason: profile.latestRejectionReason }
        : {}),
      statusHistory: provider.providerStatusHistory.map((history) => ({
        fromStatus: history.fromStatus as ProviderStatus,
        toStatus: history.toStatus as ProviderStatus,
        ...(history.reason ? { reason: history.reason } : {}),
        createdAt: history.createdAt.toISOString(),
      })),
    };
  }

  private async assertIdentifiersAvailable(
    normalizedPhone: string,
    normalizedEmail: string | null,
  ): Promise<void> {
    const conflict = await this.prisma.user.findFirst({
      where: {
        OR: [
          { phoneLookup: this.phones.lookup(normalizedPhone) },
          ...(normalizedEmail
            ? [{ emailLookup: this.emails.lookup(normalizedEmail) }]
            : []),
        ],
      },
      select: { id: true },
    });
    if (conflict) throw this.conflict();
  }

  private validateClientShape(
    request: ClientRegistrationRequestContract,
  ): void {
    const individual = request.clientType === ClientType.individual;
    const valid = individual
      ? Boolean(clean(request.firstName) && clean(request.lastName)) &&
        !request.organizationName &&
        !request.contactPersonName &&
        !request.contactPersonPhone
      : Boolean(
          clean(request.organizationName) &&
          clean(request.contactPersonName) &&
          clean(request.contactPersonPhone),
        ) &&
        !request.firstName &&
        !request.lastName;
    if (!valid) {
      throw new BadRequestException({
        code: ApiErrorCode.invalidRequest,
        message:
          "Complete only the fields required for the selected Client type.",
      });
    }
  }

  private assertApprovalPermission(actor: AuthenticatedActor): void {
    if (
      actor.user.actorType !== PrismaActorType.KCCA_STAFF ||
      !actor.user.isActive ||
      !actor.user.providerApprovalPermitted
    ) {
      throw new ForbiddenException({
        code: ApiErrorCode.accessDenied,
        message: "This KCCA account cannot review provider registrations.",
      });
    }
  }

  private conflict(
    message = "The registration details are already in use.",
  ): ConflictException {
    return new ConflictException({ code: ApiErrorCode.conflict, message });
  }
}

function clean(value: string | undefined): string | null {
  const cleaned = value?.trim();
  return cleaned ? cleaned : null;
}

function requiredText(value: string): string {
  return value.trim();
}

function accountNumber(prefix: "WCL" | "WSP"): string {
  return `${prefix}-${randomUUID().replaceAll("-", "").slice(0, 12).toUpperCase()}`;
}

function isUniqueConflict(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    error.code === "P2002"
  );
}
