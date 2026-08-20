import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  Req,
  UseGuards,
} from "@nestjs/common";
import {
  ApiBearerAuth,
  ApiConflictResponse,
  ApiCreatedResponse,
  ApiForbiddenResponse,
  ApiOkResponse,
  ApiOperation,
  ApiResponse,
  ApiTags,
  ApiUnauthorizedResponse,
} from "@nestjs/swagger";

import {
  AccessTokenGuard,
  AuthenticatedRequest,
} from "../auth/access-token.guard";
import { ApiErrorDto } from "../identity/current-actor.dto";
import { ProviderStatus } from "@weyonje/contracts";
import {
  ClientRegistrationDto,
  PendingProviderRegistrationDto,
  PhoneChallengeDto,
  ProviderApprovalDto,
  ProviderAdministrationDto,
  ProviderStatusChangeDto,
  ProviderRegistrationStatusDto,
  RegistrationVerificationDto,
  ResendPhoneCodeDto,
  ServiceProviderRegistrationDto,
  VerifyPhoneCodeDto,
} from "./registration.dto";
import { RegistrationService } from "./registration.service";

@ApiTags("registration")
@Controller("v1/registrations")
export class RegistrationController {
  constructor(private readonly registrations: RegistrationService) {}

  @Post("clients")
  @ApiOperation({
    summary: "Submit a Client registration and send a phone code",
  })
  @ApiCreatedResponse({ type: PhoneChallengeDto })
  @ApiConflictResponse({ type: ApiErrorDto })
  @ApiResponse({ status: 429, type: ApiErrorDto })
  registerClient(
    @Body() request: ClientRegistrationDto,
  ): Promise<PhoneChallengeDto> {
    return this.registrations.registerClient(request);
  }

  @Post("service-providers")
  @ApiOperation({
    summary: "Submit a Service Provider registration and send a phone code",
  })
  @ApiCreatedResponse({ type: PhoneChallengeDto })
  @ApiConflictResponse({ type: ApiErrorDto })
  @ApiResponse({ status: 429, type: ApiErrorDto })
  registerServiceProvider(
    @Body() request: ServiceProviderRegistrationDto,
  ): Promise<PhoneChallengeDto> {
    return this.registrations.registerServiceProvider(request);
  }

  @Post("verify-phone")
  @HttpCode(200)
  @ApiOperation({ summary: "Verify a registration phone number" })
  @ApiOkResponse({ type: RegistrationVerificationDto })
  @ApiUnauthorizedResponse({ type: ApiErrorDto })
  verifyPhone(
    @Body() request: VerifyPhoneCodeDto,
  ): Promise<RegistrationVerificationDto> {
    return this.registrations.verifyPhone(request.challengeId, request.code);
  }

  @Post("resend-phone-code")
  @HttpCode(200)
  @ApiOperation({ summary: "Replace and resend a registration phone code" })
  @ApiOkResponse({ type: PhoneChallengeDto })
  @ApiResponse({ status: 429, type: ApiErrorDto })
  resendPhoneCode(
    @Body() request: ResendPhoneCodeDto,
  ): Promise<PhoneChallengeDto> {
    return this.registrations.resendPhoneCode(request.challengeId);
  }
}

@ApiTags("provider registration review")
@ApiBearerAuth()
@UseGuards(AccessTokenGuard)
@Controller("v1/provider-registrations")
export class ProviderRegistrationController {
  constructor(private readonly registrations: RegistrationService) {}

  @Get("pending")
  @ApiOperation({
    summary: "List phone-verified Provider registrations awaiting review",
  })
  @ApiOkResponse({ type: PendingProviderRegistrationDto, isArray: true })
  @ApiUnauthorizedResponse({ type: ApiErrorDto })
  @ApiForbiddenResponse({ type: ApiErrorDto })
  pending(
    @Req() request: AuthenticatedRequest,
  ): Promise<PendingProviderRegistrationDto[]> {
    return this.registrations.pendingProviders(request.authenticatedActor!);
  }

  @Get()
  @ApiOperation({ summary: "List Providers by administration status" })
  @ApiOkResponse({ type: ProviderAdministrationDto, isArray: true })
  providers(
    @Req() request: AuthenticatedRequest,
    @Query("status") status?: ProviderStatus,
  ) {
    return this.registrations.providers(request.authenticatedActor!, status);
  }

  @Get(":providerUserId")
  @ApiOkResponse({ type: ProviderAdministrationDto })
  detail(
    @Req() request: AuthenticatedRequest,
    @Param("providerUserId", ParseUUIDPipe) providerUserId: string,
  ) {
    return this.registrations.providerAdministrationDetail(
      request.authenticatedActor!,
      providerUserId,
    );
  }

  @Post(":providerUserId/status")
  @HttpCode(200)
  @ApiOkResponse({ type: ProviderAdministrationDto })
  changeStatus(
    @Req() request: AuthenticatedRequest,
    @Param("providerUserId", ParseUUIDPipe) providerUserId: string,
    @Body() body: ProviderStatusChangeDto,
  ) {
    return this.registrations.changeProviderStatus(
      request.authenticatedActor!,
      providerUserId,
      body,
    );
  }

  @Post(":providerUserId/decision")
  @HttpCode(200)
  @ApiOperation({
    summary: "Approve or reject a pending Provider registration",
  })
  @ApiOkResponse({ type: ProviderRegistrationStatusDto })
  @ApiConflictResponse({ type: ApiErrorDto })
  @ApiForbiddenResponse({ type: ApiErrorDto })
  decide(
    @Req() request: AuthenticatedRequest,
    @Param("providerUserId", ParseUUIDPipe) providerUserId: string,
    @Body() decision: ProviderApprovalDto,
  ): Promise<ProviderRegistrationStatusDto> {
    return this.registrations.decideProvider(
      request.authenticatedActor!,
      providerUserId,
      decision,
    );
  }

  @Get("me/status")
  @ApiOperation({ summary: "Read the current Provider registration status" })
  @ApiOkResponse({ type: ProviderRegistrationStatusDto })
  @ApiForbiddenResponse({ type: ApiErrorDto })
  status(
    @Req() request: AuthenticatedRequest,
  ): Promise<ProviderRegistrationStatusDto> {
    return this.registrations.providerStatus(request.authenticatedActor!);
  }
}
