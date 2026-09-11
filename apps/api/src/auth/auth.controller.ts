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
  ApiExtraModels,
  getSchemaPath,
  ApiBody,
  ApiOkResponse,
  ApiOperation,
  ApiResponse,
  ApiTags,
  ApiUnauthorizedResponse,
} from "@nestjs/swagger";

import { ApiErrorDto } from "../identity/current-actor.dto";
import { AuthenticatedRequest } from "./access-token.guard";
import {
  ClientCodeRequestDto,
  ProviderCodeRequestDto,
  RegistrationRequiredDto,
  RefreshDto,
  SessionCredentialsDto,
  SignInDto,
  SignOutDto,
} from "./auth.dto";
import {
  PhoneChallengeDto,
  ResendPhoneCodeDto,
  VerifyPhoneCodeDto,
} from "../registration/registration.dto";
import { AuthService } from "./auth.service";
import { SessionService } from "./session.service";
import { SignedAccessTokenGuard } from "./signed-access-token.guard";

@ApiExtraModels(PhoneChallengeDto, RegistrationRequiredDto)
@ApiTags("authentication")
@Controller("v1/auth")
export class AuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly sessions: SessionService,
  ) {}

  @Post("sign-in")
  @HttpCode(200)
  @ApiOperation({ summary: "Sign in with an existing KCCA account" })
  @ApiBody({ type: SignInDto })
  @ApiOkResponse({ type: SessionCredentialsDto })
  @ApiUnauthorizedResponse({
    type: ApiErrorDto,
    description:
      "Generic response for all invalid account credentials or state.",
  })
  @ApiResponse({ status: 429, type: ApiErrorDto })
  signIn(
    @Body() request: SignInDto,
    @Req() httpRequest: AuthenticatedRequest,
  ): Promise<SessionCredentialsDto> {
    return this.auth.signIn(request.email, request.password, httpRequest.ip);
  }

  @Post("client-code/request")
  @HttpCode(200)
  @ApiOperation({
    summary: "Request a Client sign-in code or registration",
    description:
      "Returns REGISTRATION_REQUIRED only for genuine phone absence. Existing ineligible accounts receive a generic error. Valid initial requests consume protected phone/IP throttles before lookup.",
  })
  @ApiBody({ type: ClientCodeRequestDto })
  @ApiOkResponse({
    schema: {
      oneOf: [
        { $ref: getSchemaPath(PhoneChallengeDto) },
        { $ref: getSchemaPath(RegistrationRequiredDto) },
      ],
    },
  })
  @ApiResponse({ status: 429, type: ApiErrorDto })
  @ApiResponse({
    status: 400,
    type: ApiErrorDto,
    description:
      "Invalid input or OTP cooldown; retryAt is supplied for cooldown.",
  })
  @ApiUnauthorizedResponse({
    type: ApiErrorDto,
    description: "Generic unavailable response without account details.",
  })
  requestClientCode(
    @Body() request: ClientCodeRequestDto,
    @Req() httpRequest: AuthenticatedRequest,
  ): Promise<PhoneChallengeDto | RegistrationRequiredDto> {
    return this.auth.requestClientCode(request.phoneNumber, httpRequest.ip);
  }

  @Post("client-code/verify")
  @HttpCode(200)
  @ApiOperation({ summary: "Sign in a Client with a phone verification code" })
  @ApiBody({ type: VerifyPhoneCodeDto })
  @ApiOkResponse({ type: SessionCredentialsDto })
  @ApiUnauthorizedResponse({ type: ApiErrorDto })
  verifyClientCode(
    @Body() request: VerifyPhoneCodeDto,
  ): Promise<SessionCredentialsDto> {
    return this.auth.verifyClientCode(request.challengeId, request.code);
  }

  @Post("client-code/resend")
  @HttpCode(200)
  @ApiOperation({ summary: "Replace and resend a Client sign-in code" })
  @ApiBody({ type: ResendPhoneCodeDto })
  @ApiOkResponse({ type: PhoneChallengeDto })
  @ApiResponse({
    status: 400,
    type: ApiErrorDto,
    description: "OTP cooldown with retryAt.",
  })
  @ApiResponse({
    status: 429,
    type: ApiErrorDto,
    description: "Hourly issuance limit with retryAt.",
  })
  resendClientCode(
    @Body() request: ResendPhoneCodeDto,
  ): Promise<PhoneChallengeDto> {
    return this.auth.resendClientCode(request.challengeId);
  }

  @Post("provider-code/request")
  @HttpCode(200)
  @ApiOperation({
    summary: "Request a Service Provider sign-in code",
    description:
      "Verified registered phone and login eligibility required. Unknown and ineligible accounts receive the same guidance; no account is created.",
  })
  @ApiBody({ type: ProviderCodeRequestDto })
  @ApiOkResponse({ type: PhoneChallengeDto })
  @ApiUnauthorizedResponse({ type: ApiErrorDto })
  @ApiResponse({ status: 429, type: ApiErrorDto })
  requestProviderCode(
    @Body() request: ProviderCodeRequestDto,
    @Req() httpRequest: AuthenticatedRequest,
  ): Promise<PhoneChallengeDto> {
    return this.auth.requestProviderCode(request.phoneNumber, httpRequest.ip);
  }

  @Post("provider-code/verify")
  @HttpCode(200)
  @ApiOperation({
    summary: "Sign in a Provider with a phone verification code",
  })
  @ApiBody({ type: VerifyPhoneCodeDto })
  @ApiOkResponse({ type: SessionCredentialsDto })
  @ApiUnauthorizedResponse({ type: ApiErrorDto })
  verifyProviderCode(
    @Body() request: VerifyPhoneCodeDto,
  ): Promise<SessionCredentialsDto> {
    return this.auth.verifyProviderCode(request.challengeId, request.code);
  }

  @Post("provider-code/resend")
  @HttpCode(200)
  @ApiOperation({ summary: "Replace and resend a Provider sign-in code" })
  @ApiBody({ type: ResendPhoneCodeDto })
  @ApiOkResponse({ type: PhoneChallengeDto })
  @ApiResponse({
    status: 400,
    type: ApiErrorDto,
    description: "OTP cooldown with retryAt.",
  })
  @ApiResponse({
    status: 429,
    type: ApiErrorDto,
    description: "Hourly issuance limit with retryAt.",
  })
  resendProviderCode(
    @Body() request: ResendPhoneCodeDto,
  ): Promise<PhoneChallengeDto> {
    return this.auth.resendProviderCode(request.challengeId);
  }

  @Post("refresh")
  @HttpCode(200)
  @ApiOperation({ summary: "Rotate a Weyonje refresh token" })
  @ApiBody({ type: RefreshDto })
  @ApiOkResponse({ type: SessionCredentialsDto })
  @ApiUnauthorizedResponse({ type: ApiErrorDto })
  refresh(@Body() request: RefreshDto): Promise<SessionCredentialsDto> {
    return this.auth.refresh(request.refreshToken);
  }

  @Post("sign-out")
  @HttpCode(200)
  @UseGuards(SignedAccessTokenGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: "Revoke the current Weyonje session" })
  @ApiOkResponse({ type: SignOutDto })
  @ApiUnauthorizedResponse({ type: ApiErrorDto })
  async signOut(@Req() request: AuthenticatedRequest): Promise<SignOutDto> {
    const claims = request.accessTokenClaims!;
    await this.sessions.signOut(claims.userId, claims.sessionId);
    return { signedOut: true };
  }
}
