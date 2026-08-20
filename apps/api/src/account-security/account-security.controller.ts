import {
  Body,
  Controller,
  HttpCode,
  Post,
  Req,
  UseGuards,
} from "@nestjs/common";
import {
  ApiBearerAuth,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from "@nestjs/swagger";

import {
  AccessTokenGuard,
  AuthenticatedRequest,
} from "../auth/access-token.guard";
import {
  AccountChallengeDto,
  AccountSecurityResultDto,
  ChallengeReferenceDto,
  CompletePasswordRecoveryDto,
  PasswordRecoveryRequestDto,
  RequestEmailVerificationDto,
  VerifyEmailDto,
} from "./account-security.dto";
import { AccountSecurityService } from "./account-security.service";

@ApiTags("account security")
@Controller("v1/account-security")
export class AccountSecurityController {
  constructor(private readonly security: AccountSecurityService) {}

  @Post("password-recovery/request")
  @HttpCode(200)
  @ApiOperation({ summary: "Request non-enumerating password recovery" })
  @ApiOkResponse({ type: AccountChallengeDto })
  requestRecovery(@Body() body: PasswordRecoveryRequestDto) {
    return this.security.requestPasswordRecovery(body.email, body.method);
  }

  @Post("password-recovery/resend")
  @HttpCode(200)
  @ApiOkResponse({ type: AccountChallengeDto })
  resendRecovery(@Body() body: ChallengeReferenceDto) {
    return this.security.resendPasswordRecovery(body.challengeId);
  }

  @Post("password-recovery/complete")
  @HttpCode(200)
  @ApiOkResponse({ type: AccountSecurityResultDto })
  completeRecovery(@Body() body: CompletePasswordRecoveryDto) {
    return this.security.completePasswordRecovery(
      body.challengeId,
      body.code,
      body.newPassword,
    );
  }

  @Post("email-verification/request")
  @HttpCode(200)
  @UseGuards(AccessTokenGuard)
  @ApiBearerAuth()
  @ApiOkResponse({ type: AccountChallengeDto })
  requestEmailVerification(
    @Req() request: AuthenticatedRequest,
    @Body() body: RequestEmailVerificationDto,
  ) {
    return this.security.requestEmailVerification(
      request.authenticatedActor!,
      body.method,
    );
  }

  @Post("email-verification/resend")
  @HttpCode(200)
  @ApiOkResponse({ type: AccountChallengeDto })
  resendEmailVerification(@Body() body: ChallengeReferenceDto) {
    return this.security.resendEmailVerification(body.challengeId);
  }

  @Post("email-verification/verify")
  @HttpCode(200)
  @ApiOkResponse({ type: AccountSecurityResultDto })
  verifyEmail(@Body() body: VerifyEmailDto) {
    return this.security.verifyEmail(body.challengeId, body.code);
  }
}
