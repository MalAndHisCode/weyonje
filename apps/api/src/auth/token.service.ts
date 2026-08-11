import { Inject, Injectable, UnauthorizedException } from "@nestjs/common";
import { ConfigType } from "@nestjs/config";
import { ApiErrorCode } from "@weyonje/contracts";
import { createHmac, randomBytes } from "node:crypto";
import { jwtVerify, SignJWT } from "jose";

import { authConfig } from "../config/auth.config";

export interface AccessTokenClaims {
  userId: string;
  sessionId: string;
}

export interface IssuedAccessToken {
  token: string;
  expiresAt: Date;
}

export interface GeneratedRefreshToken {
  raw: string;
  hash: string;
}

@Injectable()
export class TokenService {
  constructor(
    @Inject(authConfig.KEY)
    private readonly config: ConfigType<typeof authConfig>,
  ) {}

  async issueAccessToken(
    userId: string,
    sessionId: string,
  ): Promise<IssuedAccessToken> {
    const now = Math.floor(Date.now() / 1000);
    const expiresAt = new Date(
      (now + this.config.accessTokenTtlSeconds) * 1000,
    );
    const token = await new SignJWT({ sid: sessionId })
      .setProtectedHeader({ alg: "HS256", typ: "JWT" })
      .setSubject(userId)
      .setIssuer(this.config.issuer)
      .setAudience(this.config.audience)
      .setIssuedAt(now)
      .setExpirationTime(Math.floor(expiresAt.getTime() / 1000))
      .sign(this.config.accessTokenSecret);
    return { token, expiresAt };
  }

  async verifyAccessToken(token: string): Promise<AccessTokenClaims> {
    try {
      const { payload, protectedHeader } = await jwtVerify(
        token,
        this.config.accessTokenSecret,
        {
          algorithms: ["HS256"],
          issuer: this.config.issuer,
          audience: this.config.audience,
          clockTolerance: 5,
        },
      );
      if (
        protectedHeader.alg !== "HS256" ||
        typeof payload.sub !== "string" ||
        payload.sub.length === 0 ||
        typeof payload.sid !== "string" ||
        payload.sid.length === 0 ||
        typeof payload.iat !== "number" ||
        typeof payload.exp !== "number"
      ) {
        throw new Error("Incomplete access token");
      }
      const now = Math.floor(Date.now() / 1000);
      if (
        payload.iat > now + 5 ||
        payload.exp <= payload.iat ||
        payload.exp - payload.iat > this.config.accessTokenTtlSeconds + 5
      ) {
        throw new Error("Invalid access token lifetime");
      }
      return { userId: payload.sub, sessionId: payload.sid };
    } catch {
      throw new UnauthorizedException({
        code: ApiErrorCode.invalidToken,
        message: "The session is invalid or has expired. Sign in again.",
      });
    }
  }

  generateRefreshToken(): GeneratedRefreshToken {
    const raw = randomBytes(48).toString("base64url");
    return { raw, hash: this.hashRefreshToken(raw) };
  }

  hashRefreshToken(raw: string): string {
    return createHmac("sha256", this.config.refreshTokenHashKey)
      .update(raw, "utf8")
      .digest("base64url");
  }
}
