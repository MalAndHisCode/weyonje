import { Inject, Injectable } from "@nestjs/common";
import { ConfigType } from "@nestjs/config";
import { createHmac, timingSafeEqual } from "node:crypto";

import { authConfig } from "../config/auth.config";

@Injectable()
export class ChallengeCodeService {
  constructor(
    @Inject(authConfig.KEY)
    private readonly config: ConfigType<typeof authConfig>,
  ) {}

  code(challengeId: string): string {
    const digest = createHmac("sha256", this.config.otpHashKey)
      .update(`account-challenge-code\0${challengeId}`, "utf8")
      .digest();
    return (digest.readUInt32BE(0) % 1_000_000).toString().padStart(6, "0");
  }

  hash(challengeId: string, code: string): string {
    return createHmac("sha256", this.config.otpHashKey)
      .update(`account-challenge-hash\0${challengeId}\0${code}`, "utf8")
      .digest("base64url");
  }

  matches(challengeId: string, code: string, expectedHash: string): boolean {
    const supplied = Buffer.from(this.hash(challengeId, code));
    const expected = Buffer.from(expectedHash);
    return (
      supplied.length === expected.length && timingSafeEqual(supplied, expected)
    );
  }

  subject(challengeId: string): string {
    return createHmac("sha256", this.config.otpHashKey)
      .update(`account-challenge-subject\0${challengeId}`, "utf8")
      .digest("base64url");
  }
}
