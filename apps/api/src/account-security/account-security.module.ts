import { Module } from "@nestjs/common";

import { AuthModule } from "../auth/auth.module";
import { AccountSecurityController } from "./account-security.controller";
import { AccountSecurityService } from "./account-security.service";
import { ChallengeCodeService } from "./challenge-code.service";

@Module({
  imports: [AuthModule],
  controllers: [AccountSecurityController],
  providers: [AccountSecurityService, ChallengeCodeService],
  exports: [AccountSecurityService, ChallengeCodeService],
})
export class AccountSecurityModule {}
