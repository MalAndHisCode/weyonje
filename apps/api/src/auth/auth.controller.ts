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
  RefreshDto,
  SessionCredentialsDto,
  SignInDto,
  SignOutDto,
} from "./auth.dto";
import { AuthService } from "./auth.service";
import { SessionService } from "./session.service";
import { SignedAccessTokenGuard } from "./signed-access-token.guard";

@ApiTags("authentication")
@Controller("v1/auth")
export class AuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly sessions: SessionService,
  ) {}

  @Post("sign-in")
  @HttpCode(200)
  @ApiOperation({ summary: "Sign in with an existing Weyonje account" })
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
