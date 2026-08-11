import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { ApiErrorCode } from "@weyonje/contracts";
import { FastifyRequest } from "fastify";

import { AuthenticatedActor } from "./authenticated-actor";
import { SessionService } from "./session.service";
import { AccessTokenClaims, TokenService } from "./token.service";

export interface AuthenticatedRequest extends FastifyRequest {
  authenticatedActor?: AuthenticatedActor;
  accessTokenClaims?: AccessTokenClaims;
}

@Injectable()
export class AccessTokenGuard implements CanActivate {
  constructor(
    private readonly tokens: TokenService,
    private readonly sessions: SessionService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const match = /^Bearer ([^\s]+)$/.exec(request.headers.authorization ?? "");
    if (!match?.[1]) {
      throw new UnauthorizedException({
        code: ApiErrorCode.authenticationRequired,
        message: "Authentication is required.",
      });
    }
    const claims = await this.tokens.verifyAccessToken(match[1]);
    request.authenticatedActor = await this.sessions.authenticateAccess(
      claims.userId,
      claims.sessionId,
    );
    return true;
  }
}
