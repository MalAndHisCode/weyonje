import { Inject, Injectable, UnauthorizedException } from "@nestjs/common";
import { ConfigType } from "@nestjs/config";
import { ApiErrorCode } from "@weyonje/contracts";
import {
  createRemoteJWKSet,
  JWTPayload,
  jwtVerify,
  JWTVerifyGetKey,
} from "jose";

import { identityConfig } from "../config/identity.config";
import { AuthenticatedIdentity } from "./authenticated-identity";

export type TokenKeyResolver = JWTVerifyGetKey;

@Injectable()
export class TokenVerifier {
  private readonly keyResolver: TokenKeyResolver;

  constructor(
    @Inject(identityConfig.KEY)
    private readonly config: ConfigType<typeof identityConfig>,
    keyResolver?: TokenKeyResolver,
  ) {
    this.keyResolver =
      keyResolver ??
      createRemoteJWKSet(new URL(config.jwksUri), {
        timeoutDuration: 3_000,
        cooldownDuration: 30_000,
      });
  }

  async verify(accessToken: string): Promise<AuthenticatedIdentity> {
    try {
      const { payload } = await jwtVerify(accessToken, this.keyResolver, {
        issuer: this.config.issuer,
        audience: this.config.audience,
        algorithms: this.config.algorithms,
        clockTolerance: 5,
      });
      if (typeof payload.sub !== "string" || payload.sub.length === 0) {
        throw this.invalidToken();
      }
      return { subject: payload.sub, roles: this.extractRoles(payload) };
    } catch (error) {
      if (error instanceof UnauthorizedException) {
        throw error;
      }
      throw this.invalidToken();
    }
  }

  private extractRoles(payload: JWTPayload): ReadonlySet<string> {
    const roles = new Set<string>();
    const realmAccess = payload.realm_access;
    if (this.isRecord(realmAccess) && Array.isArray(realmAccess.roles)) {
      this.addStringRoles(roles, realmAccess.roles);
    }

    const resourceAccess = payload.resource_access;
    if (this.isRecord(resourceAccess)) {
      const audienceAccess = resourceAccess[this.config.audience];
      if (
        this.isRecord(audienceAccess) &&
        Array.isArray(audienceAccess.roles)
      ) {
        this.addStringRoles(roles, audienceAccess.roles);
      }
    }
    return roles;
  }

  private addStringRoles(target: Set<string>, values: unknown[]): void {
    for (const value of values) {
      if (typeof value === "string") {
        target.add(value);
      }
    }
  }

  private isRecord(value: unknown): value is Record<string, unknown> {
    return typeof value === "object" && value !== null;
  }

  private invalidToken(): UnauthorizedException {
    return new UnauthorizedException({
      code: ApiErrorCode.invalidToken,
      message: "The session is invalid or has expired. Sign in again.",
    });
  }
}
