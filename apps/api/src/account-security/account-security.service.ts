import {
  BadRequestException,
  ConflictException,
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { ConfigType } from "@nestjs/config";
import {
  AccountChallengeContract,
  AccountChallengeMethod,
  ApiErrorCode,
} from "@weyonje/contracts";
import { randomUUID } from "node:crypto";

import { AuthenticatedActor } from "../auth/authenticated-actor";
import { EmailSecurityService } from "../auth/email-security.service";
import { PasswordService } from "../auth/password.service";
import { accountSecurityConfig } from "../config/account-security.config";
import { smsConfig } from "../config/sms.config";
import { PrismaService } from "../database/prisma.service";
import {
  AccountChallengeChannel,
  AccountChallengePurpose,
  ActorType,
  NotificationDeliveryChannel,
  OperationalNotificationType,
} from "../generated/prisma/enums";
import { ChallengeCodeService } from "./challenge-code.service";

@Injectable()
export class AccountSecurityService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly emails: EmailSecurityService,
    private readonly passwords: PasswordService,
    private readonly codes: ChallengeCodeService,
    @Inject(accountSecurityConfig.KEY)
    private readonly config: ConfigType<typeof accountSecurityConfig>,
    @Inject(smsConfig.KEY)
    private readonly smsConfiguration: ConfigType<typeof smsConfig>,
  ) {}

  async requestPasswordRecovery(
    emailValue: string,
    method: AccountChallengeMethod,
  ): Promise<AccountChallengeContract> {
    const email = this.emails.normalize(emailValue);
    const subjectHash = this.emails.lookup(email);
    await this.assertRequestRate(subjectHash, "password-recovery.request");
    const user = await this.prisma.user.findFirst({
      where: {
        emailLookup: subjectHash,
        actorType: { in: [ActorType.SERVICE_PROVIDER, ActorType.KCCA_STAFF] },
      },
      select: {
        id: true,
        emailLookup: true,
        encryptedEmail: true,
        encryptedPhone: true,
      },
    });
    if (!user || !this.methodAvailable(user, method)) {
      await this.audit(
        null,
        subjectHash,
        null,
        "password-recovery.request",
        "ACCEPTED_UNKNOWN",
      );
      return this.synthetic(method);
    }
    return this.issue(
      user,
      AccountChallengePurpose.PASSWORD_RECOVERY,
      method,
      "password-recovery.request",
    );
  }

  async resendPasswordRecovery(
    challengeId: string,
  ): Promise<AccountChallengeContract> {
    return this.resend(challengeId, AccountChallengePurpose.PASSWORD_RECOVERY);
  }

  async completePasswordRecovery(
    challengeId: string,
    code: string,
    newPassword: string,
  ): Promise<{ completed: true }> {
    const challenge = await this.validate(
      challengeId,
      code,
      AccountChallengePurpose.PASSWORD_RECOVERY,
    );
    const passwordHash = await this.passwords.hash(newPassword);
    const now = new Date();
    await this.prisma.$transaction(async (tx) => {
      const consumed = await tx.accountChallenge.updateMany({
        where: {
          id: challenge.id,
          consumedAt: null,
          supersededAt: null,
          expiresAt: { gt: now },
        },
        data: { consumedAt: now },
      });
      if (consumed.count !== 1) throw this.challengeUsed();
      await tx.user.update({
        where: { id: challenge.userId },
        data: {
          passwordHash,
          passwordChangedAt: now,
          passwordVersion: { increment: 1 },
          failedLoginCount: 0,
          authenticationLockedUntil: null,
        },
      });
      const sessions = await tx.authenticationSession.findMany({
        where: { userId: challenge.userId, revokedAt: null },
        select: { id: true },
      });
      await tx.authenticationSession.updateMany({
        where: { userId: challenge.userId, revokedAt: null },
        data: { revokedAt: now, revocationReason: "password_recovery" },
      });
      if (sessions.length > 0) {
        await tx.refreshToken.updateMany({
          where: {
            sessionId: { in: sessions.map(({ id }) => id) },
            revokedAt: null,
          },
          data: { revokedAt: now },
        });
      }
      await tx.securityEvent.create({
        data: {
          userId: challenge.userId,
          subjectHash: challenge.subjectHash,
          challengeId: challenge.id,
          action: "password-recovery.complete",
          outcome: "COMPLETED",
        },
      });
    });
    return { completed: true };
  }

  async requestEmailVerification(
    actor: AuthenticatedActor,
    method: AccountChallengeMethod,
  ): Promise<AccountChallengeContract> {
    const user = await this.prisma.user.findUnique({
      where: { id: actor.user.id },
      select: {
        id: true,
        emailLookup: true,
        encryptedEmail: true,
        encryptedPhone: true,
        emailVerifiedAt: true,
      },
    });
    if (!user?.emailLookup || !user.encryptedEmail) {
      throw new BadRequestException({
        code: ApiErrorCode.invalidRequest,
        message: "This account does not have an email address to verify.",
      });
    }
    if (user.emailVerifiedAt) {
      throw new ConflictException({
        code: ApiErrorCode.conflict,
        message: "This email address is already verified.",
      });
    }
    if (!this.methodAvailable(user, method)) {
      throw new BadRequestException({
        code: ApiErrorCode.invalidRequest,
        message: "The selected verification method is unavailable.",
      });
    }
    await this.assertRequestRate(
      user.emailLookup,
      "email-verification.request",
    );
    return this.issue(
      user,
      AccountChallengePurpose.EMAIL_VERIFICATION,
      method,
      "email-verification.request",
    );
  }

  resendEmailVerification(challengeId: string) {
    return this.resend(challengeId, AccountChallengePurpose.EMAIL_VERIFICATION);
  }

  async verifyEmail(
    challengeId: string,
    code: string,
  ): Promise<{ completed: true }> {
    const challenge = await this.validate(
      challengeId,
      code,
      AccountChallengePurpose.EMAIL_VERIFICATION,
    );
    const now = new Date();
    await this.prisma.$transaction(async (tx) => {
      const consumed = await tx.accountChallenge.updateMany({
        where: {
          id: challenge.id,
          consumedAt: null,
          supersededAt: null,
          expiresAt: { gt: now },
        },
        data: { consumedAt: now },
      });
      if (consumed.count !== 1) throw this.challengeUsed();
      await tx.user.update({
        where: { id: challenge.userId },
        data: { emailVerifiedAt: now },
      });
      await tx.securityEvent.create({
        data: {
          userId: challenge.userId,
          subjectHash: challenge.subjectHash,
          challengeId: challenge.id,
          action: "email-verification.complete",
          outcome: "COMPLETED",
        },
      });
    });
    return { completed: true };
  }

  deliveryCode(challengeId: string): string {
    return this.codes.code(challengeId);
  }

  private async issue(
    user: {
      id: string;
      emailLookup: string | null;
      encryptedEmail: string | null;
      encryptedPhone: string | null;
    },
    purpose: AccountChallengePurpose,
    method: AccountChallengeMethod,
    action: string,
  ): Promise<AccountChallengeContract> {
    const now = new Date();
    const id = randomUUID();
    const code = this.codes.code(id);
    const expiresAt = new Date(
      now.getTime() + this.config.challengeTtlSeconds * 1000,
    );
    const resendAvailableAt = new Date(
      now.getTime() + this.config.resendSeconds * 1000,
    );
    const channel =
      method === AccountChallengeMethod.phone
        ? AccountChallengeChannel.SMS
        : AccountChallengeChannel.EMAIL;
    const eventType =
      purpose === AccountChallengePurpose.PASSWORD_RECOVERY
        ? OperationalNotificationType.PASSWORD_RECOVERY
        : OperationalNotificationType.EMAIL_VERIFICATION;
    await this.prisma.$transaction(async (tx) => {
      await tx.accountChallenge.updateMany({
        where: {
          userId: user.id,
          purpose,
          consumedAt: null,
          supersededAt: null,
        },
        data: { supersededAt: now },
      });
      await tx.accountChallenge.create({
        data: {
          id,
          userId: user.id,
          purpose,
          channel,
          secretHash: this.codes.hash(id, code),
          expiresAt,
          resendAvailableAt,
          attemptsRemaining: this.config.maximumAttempts,
        },
      });
      await tx.outboxEvent.create({
        data: {
          recipientUserId: user.id,
          channel:
            method === AccountChallengeMethod.phone
              ? NotificationDeliveryChannel.SMS
              : NotificationDeliveryChannel.EMAIL,
          eventType,
          deduplicationKey: `account-challenge:${id}:delivery`,
          payload: { accountChallengeId: id },
        },
      });
      await tx.securityEvent.create({
        data: {
          userId: user.id,
          subjectHash: user.emailLookup ?? this.codes.subject(user.id),
          challengeId: id,
          action,
          outcome: "QUEUED",
        },
      });
    });
    return this.response(id, expiresAt, resendAvailableAt, method, code);
  }

  private async resend(
    challengeId: string,
    purpose: AccountChallengePurpose,
  ): Promise<AccountChallengeContract> {
    const challenge = await this.prisma.accountChallenge.findUnique({
      where: { id: challengeId },
      include: { user: true },
    });
    if (!challenge || challenge.purpose !== purpose) {
      return this.synthetic(AccountChallengeMethod.email);
    }
    if (challenge.consumedAt) throw this.challengeUsed();
    if (challenge.supersededAt) throw this.challengeSuperseded();
    if (challenge.resendAvailableAt > new Date()) {
      throw new HttpException(
        {
          code: ApiErrorCode.rateLimited,
          message: "Wait before requesting another code.",
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    const method =
      challenge.channel === AccountChallengeChannel.SMS
        ? AccountChallengeMethod.phone
        : AccountChallengeMethod.email;
    const subjectHash =
      challenge.user.emailLookup ?? this.codes.subject(challenge.userId);
    const resendAction =
      purpose === AccountChallengePurpose.PASSWORD_RECOVERY
        ? "password-recovery.resend"
        : "email-verification.resend";
    await this.assertRequestRate(subjectHash, resendAction);
    return this.issue(challenge.user, purpose, method, resendAction);
  }

  private async validate(
    challengeId: string,
    code: string,
    purpose: AccountChallengePurpose,
  ) {
    const challenge = await this.prisma.accountChallenge.findUnique({
      where: { id: challengeId },
      include: { user: { select: { emailLookup: true } } },
    });
    if (!challenge || challenge.purpose !== purpose)
      throw this.challengeInvalid();
    const subjectHash =
      challenge.user.emailLookup ?? this.codes.subject(challenge.userId);
    if (challenge.consumedAt) throw this.challengeUsed();
    if (challenge.supersededAt) throw this.challengeSuperseded();
    if (challenge.expiresAt <= new Date()) throw this.challengeExpired();
    if (challenge.attemptsRemaining <= 0) throw this.challengeInvalid();
    if (
      !/^\d{6}$/.test(code) ||
      !this.codes.matches(challenge.id, code, challenge.secretHash)
    ) {
      await this.prisma.$transaction([
        this.prisma.accountChallenge.updateMany({
          where: {
            id: challenge.id,
            consumedAt: null,
            supersededAt: null,
            attemptsRemaining: { gt: 0 },
          },
          data: { attemptsRemaining: { decrement: 1 } },
        }),
        this.prisma.securityEvent.create({
          data: {
            userId: challenge.userId,
            subjectHash,
            challengeId: challenge.id,
            action: `${purpose.toLowerCase()}.verify`,
            outcome: "INVALID_CODE",
          },
        }),
      ]);
      throw this.challengeInvalid();
    }
    return { ...challenge, subjectHash };
  }

  private methodAvailable(
    user: { encryptedEmail: string | null; encryptedPhone: string | null },
    method: AccountChallengeMethod,
  ): boolean {
    return method === AccountChallengeMethod.phone
      ? user.encryptedPhone !== null
      : user.encryptedEmail !== null;
  }

  private response(
    id: string,
    expiresAt: Date,
    resendAvailableAt: Date,
    method: AccountChallengeMethod,
    code: string,
  ): AccountChallengeContract {
    const fake =
      this.config.environment !== "production" &&
      ((method === AccountChallengeMethod.phone &&
        this.smsConfiguration.provider === "FAKE") ||
        (method === AccountChallengeMethod.email &&
          this.config.emailProvider === "FAKE"));
    return {
      challengeId: id,
      expiresAt: expiresAt.toISOString(),
      resendAvailableAt: resendAvailableAt.toISOString(),
      deliveryStatus: "QUEUED",
      ...(fake ? { developmentVerificationCode: code } : {}),
    };
  }

  private synthetic(method: AccountChallengeMethod): AccountChallengeContract {
    const now = new Date();
    const id = randomUUID();
    return this.response(
      id,
      new Date(now.getTime() + this.config.challengeTtlSeconds * 1000),
      new Date(now.getTime() + this.config.resendSeconds * 1000),
      method,
      this.codes.code(id),
    );
  }

  private async assertRequestRate(
    subjectHash: string,
    action: string,
  ): Promise<void> {
    const count = await this.prisma.securityEvent.count({
      where: {
        subjectHash,
        action,
        createdAt: { gte: new Date(Date.now() - 60 * 60 * 1000) },
      },
    });
    if (count >= this.config.maximumRequestsPerHour) {
      throw new HttpException(
        {
          code: ApiErrorCode.rateLimited,
          message: "Too many codes were requested. Try again later.",
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }

  private audit(
    userId: string | null,
    subjectHash: string,
    challengeId: string | null,
    action: string,
    outcome: string,
  ) {
    return this.prisma.securityEvent.create({
      data: { userId, subjectHash, challengeId, action, outcome },
    });
  }

  private challengeInvalid() {
    return new UnauthorizedException({
      code: ApiErrorCode.challengeInvalid,
      message: "The verification code is incorrect or no longer usable.",
    });
  }

  private challengeExpired() {
    return new UnauthorizedException({
      code: ApiErrorCode.challengeExpired,
      message: "The verification code has expired. Request another code.",
    });
  }

  private challengeUsed() {
    return new ConflictException({
      code: ApiErrorCode.challengeUsed,
      message: "This verification code was already used.",
    });
  }

  private challengeSuperseded() {
    return new ConflictException({
      code: ApiErrorCode.challengeSuperseded,
      message: "A newer verification code was requested.",
    });
  }
}
