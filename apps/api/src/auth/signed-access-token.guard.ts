import { CanActivate, ExecutionContext, Injectable } from "@nestjs/common";

import { AuthenticatedRequest } from "./access-token.guard";
import { TokenService } from "./token.service";

/**
 * Authenticates a signed access token without requiring its session to remain
 * active. This keeps sign-out safe while allowing a repeated sign-out request
 * to return the same successful result.
 */
@Injectable()
export class SignedAccessTokenGuard implements CanActivate {
  constructor(private readonly tokens: TokenService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const match = /^Bearer ([^\s]+)$/.exec(request.headers.authorization ?? "");
    if (!match?.[1]) {
      await this.tokens.verifyAccessToken("");
      return false;
    }
    request.accessTokenClaims = await this.tokens.verifyAccessToken(match[1]);
    return true;
  }
}
