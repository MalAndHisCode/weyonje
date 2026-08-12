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
  PhoneChallengeContract,
  ProviderApprovalDecision,
  ProviderApprovalRequestContract,
  ProviderRegistrationStatusContract,
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
      await transaction.registrationNotification.create({
        data: {
          recipientUserId: providerUserId,
          type: approved
            ? NotificationType.PROVIDER_APPROVED
            : NotificationType.PROVIDER_REJECTED,
          subjectUserId: providerUserId,
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
