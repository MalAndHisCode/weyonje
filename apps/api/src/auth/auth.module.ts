import { Module } from "@nestjs/common";

import { PhoneModule } from "../registration/phone.module";

import { AccessTokenGuard } from "./access-token.guard";
import { AuthController } from "./auth.controller";
import { AuthService } from "./auth.service";
import { EmailSecurityService } from "./email-security.service";
import { LoginThrottleService } from "./login-throttle.service";
import { PasswordService } from "./password.service";
import { SessionService } from "./session.service";
import { SignedAccessTokenGuard } from "./signed-access-token.guard";
import { TokenService } from "./token.service";

@Module({
  imports: [PhoneModule],
  controllers: [AuthController],
  providers: [
    AccessTokenGuard,
    AuthService,
    EmailSecurityService,
    LoginThrottleService,
    PasswordService,
    SessionService,
    SignedAccessTokenGuard,
    TokenService,
  ],
  exports: [
    AccessTokenGuard,
    EmailSecurityService,
    PasswordService,
    SessionService,
    TokenService,
  ],
})
export class AuthModule {}
