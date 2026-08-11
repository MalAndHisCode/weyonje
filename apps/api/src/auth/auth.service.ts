import { Injectable, UnauthorizedException } from "@nestjs/common";
import { ApiErrorCode, SessionCredentialsContract } from "@weyonje/contracts";

import { PrismaService } from "../database/prisma.service";
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
        passwordHash: true,
        passwordVersion: true,
        loginEnabled: true,
        emailVerifiedAt: true,
        authenticationLockedUntil: true,
      },
    });

    if (!user) {
      await this.passwords.verifyDummy(password);
      await this.throttles.recordFailure(emailLookup, sourceIp);
      throw this.invalidCredentials();
    }

    const passwordValid = await this.passwords.verify(
      user.passwordHash,
      password,
    );
    const now = new Date();
    const accountAllowed =
      user.loginEnabled &&
      user.emailVerifiedAt !== null &&
      (user.authenticationLockedUntil === null ||
        user.authenticationLockedUntil <= now);
    if (!passwordValid || !accountAllowed) {
      await this.throttles.recordFailure(emailLookup, sourceIp, user.id);
      throw this.invalidCredentials();
    }

    if (this.passwords.needsUpgrade(user.passwordHash)) {
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

  private invalidCredentials(): UnauthorizedException {
    return new UnauthorizedException({
      code: ApiErrorCode.invalidCredentials,
      message: "Email or password is incorrect.",
    });
  }
}
