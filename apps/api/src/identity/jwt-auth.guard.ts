import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { ApiErrorCode } from "@weyonje/contracts";
import { FastifyRequest } from "fastify";

import { TokenVerifier } from "./token-verifier";

export interface AuthenticatedRequest extends FastifyRequest {
  actorIdentity?: Awaited<ReturnType<TokenVerifier["verify"]>>;
}

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly verifier: TokenVerifier) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const authorization = request.headers.authorization;
    const match = /^Bearer ([^\s]+)$/.exec(authorization ?? "");
    if (!match?.[1]) {
      throw new UnauthorizedException({
        code: ApiErrorCode.authenticationRequired,
        message: "Authentication is required.",
      });
    }
    request.actorIdentity = await this.verifier.verify(match[1]);
    return true;
  }
}
