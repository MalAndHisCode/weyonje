import {
  HttpException,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import {
  ApiErrorCode,
  ClientCodeResponseContract,
  SessionCredentialsContract,
} from "@weyonje/contracts";

import { PrismaService } from "../database/prisma.service";
import { ActorType, PhoneChallengePurpose } from "../generated/prisma/enums";
import { PhoneChallengeService } from "../registration/phone-challenge.service";
import { PhoneSecurityService } from "../registration/phone-security.service";
import { EmailSecurityService } from "./email-security.service";
import { LoginThrottleService } from "./login-throttle.service";
import { PasswordService } from "./password.service";
import { SessionService } from "./session.service";

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly emails: EmailSecurityService,
    private readonly passwords: PasswordService,
    private readonly throttles: LoginThrottleService,
    private readonly sessions: SessionService,
    private readonly phones: PhoneSecurityService,
    private readonly challenges: PhoneChallengeService,
  ) {}

  async signIn(
    email: string,
    password: string,
    sourceIp: string,
  ): Promise<SessionCredentialsContract> {
    const normalizedEmail = this.emails.normalize(email);
    const emailLookup = this.emails.lookup(normalizedEmail);
    await this.throttles.assertAllowed(emailLookup, sourceIp);
    const user = await this.prisma.user.findUnique({
      where: { emailLookup },
      select: {
        id: true,
        actorType: true,
        passwordHash: true,
        passwordVersion: true,
        loginEnabled: true,
        emailVerifiedAt: true,
        phoneVerifiedAt: true,
        authenticationLockedUntil: true,
      },
    });

    if (!user) {
      await this.passwords.verifyDummy(password);
      await this.throttles.recordFailure(emailLookup, sourceIp);
      throw this.invalidCredentials();
    }

    const passwordValid = user.passwordHash
      ? await this.passwords.verify(user.passwordHash, password)
      : false;
    const now = new Date();
    const accountAllowed =
      user.loginEnabled &&
      user.actorType !== ActorType.CLIENT &&
      (user.emailVerifiedAt !== null || user.phoneVerifiedAt !== null) &&
      (user.authenticationLockedUntil === null ||
        user.authenticationLockedUntil <= now);
    if (!passwordValid || !accountAllowed) {
      await this.throttles.recordFailure(emailLookup, sourceIp, user.id);
      throw this.invalidCredentials();
    }

    if (user.passwordHash && this.passwords.needsUpgrade(user.passwordHash)) {
      await this.prisma.user.update({
        where: { id: user.id },
        data: { passwordHash: await this.passwords.hash(password) },
      });
    }
    await this.throttles.recordSuccess(emailLookup, sourceIp, user.id);
    return this.sessions.create(user);
  }

  refresh(refreshToken: string): Promise<SessionCredentialsContract> {
    return this.sessions.refresh(refreshToken);
  }

  async requestClientCode(
    phoneNumber: string,
    sourceIp: string,
  ): Promise<ClientCodeResponseContract> {
    const phone = this.phones.normalize(phoneNumber);
    const phoneLookup = this.phones.lookup(phone);
    try {
      await this.throttles.consumeClientRequest(phoneLookup, sourceIp);
    } catch (error) {
      if (error instanceof HttpException && error.getStatus() === 429) {
        const body = error.getResponse();
        if (
          typeof body === "object" &&
          "retryAt" in body &&
          typeof body.retryAt === "string"
        ) {
          const issuanceAt = await this.challenges.nextRequestAvailableAt(
            phoneLookup,
            PhoneChallengePurpose.CLIENT_SIGN_IN,
          );
          throw new HttpException(
            {
              ...body,
              retryAt: new Date(
                Math.max(
                  Date.parse(body.retryAt),
                  issuanceAt.retryAt.getTime(),
                ),
              ).toISOString(),
            },
            429,
          );
        }
      }
      throw error;
    }
    const user = await this.prisma.user.findUnique({
      where: { phoneLookup },
      select: {
        id: true,
        actorType: true,
        phoneVerifiedAt: true,
        loginEnabled: true,
        isActive: true,
      },
    });
    if (!user) return { outcome: "REGISTRATION_REQUIRED" };
    if (
      user.actorType !== ActorType.CLIENT ||
      !user.phoneVerifiedAt ||
      !user.loginEnabled ||
      !user.isActive
    ) {
      throw new UnauthorizedException({
        code: ApiErrorCode.accessDenied,
        message:
          "Client sign-in is unavailable. If registration is unfinished, return to Client Registration to complete it.",
      });
    }
    return this.challenges.create(
      phone,
      PhoneChallengePurpose.CLIENT_SIGN_IN,
      user.id,
    );
  }

  async resendClientCode(challengeId: string) {
    return this.challenges.resend(
      challengeId,
      PhoneChallengePurpose.CLIENT_SIGN_IN,
    );
  }

  async verifyClientCode(
    challengeId: string,
    code: string,
  ): Promise<SessionCredentialsContract> {
    return this.challenges.verifyAndComplete(
      challengeId,
      code,
      PhoneChallengePurpose.CLIENT_SIGN_IN,
      async (userId, transaction) => {
        if (!userId) throw this.invalidClientCode();
        const user = await transaction.user.findFirst({
          where: {
            id: userId,
            actorType: ActorType.CLIENT,
            phoneVerifiedAt: { not: null },
            loginEnabled: true,
            isActive: true,
          },
          select: { id: true, passwordVersion: true },
        });
        if (!user) throw this.invalidClientCode();
        return this.sessions.create(user, transaction);
      },
    );
  }

  private invalidCredentials(): UnauthorizedException {
    return new UnauthorizedException({
      code: ApiErrorCode.invalidCredentials,
      message: "Email or password is incorrect.",
    });
  }

  private invalidClientCode(): UnauthorizedException {
    return new UnauthorizedException({
      code: ApiErrorCode.invalidVerificationCode,
      message: "The verification code is incorrect or no longer usable.",
    });
  }
}
