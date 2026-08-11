import { BadRequestException, Inject, Injectable } from "@nestjs/common";
import { ConfigType } from "@nestjs/config";
import { ApiErrorCode } from "@weyonje/contracts";
import argon2 from "argon2";
import { randomBytes } from "node:crypto";

import { authConfig } from "../config/auth.config";

export const PASSWORD_MIN_LENGTH = 12;
export const PASSWORD_MAX_BYTES = 1024;
export const ARGON2_OPTIONS = {
  type: argon2.argon2id,
  memoryCost: 19_456,
  timeCost: 2,
  parallelism: 1,
  hashLength: 32,
} as const;

@Injectable()
export class PasswordService {
  private readonly dummyHash: Promise<string>;

  constructor(
    @Inject(authConfig.KEY)
    _config: ConfigType<typeof authConfig>,
  ) {
    this.dummyHash = argon2.hash(randomBytes(32), ARGON2_OPTIONS);
  }

  validateForProvisioning(password: string): void {
    this.validateMaximum(password);
    if (password.length < PASSWORD_MIN_LENGTH) {
      throw new BadRequestException({
        code: ApiErrorCode.invalidRequest,
        message: `Password must be at least ${PASSWORD_MIN_LENGTH} characters.`,
      });
    }
  }

  async hash(password: string): Promise<string> {
    this.validateForProvisioning(password);
    return argon2.hash(password, ARGON2_OPTIONS);
  }

  async verify(hash: string, password: string): Promise<boolean> {
    this.validateMaximum(password);
    try {
      return await argon2.verify(hash, password);
    } catch {
      return false;
    }
  }

  async verifyDummy(password: string): Promise<void> {
    this.validateMaximum(password);
    await argon2.verify(await this.dummyHash, password);
  }

  needsUpgrade(hash: string): boolean {
    return argon2.needsRehash(hash, ARGON2_OPTIONS);
  }

  private validateMaximum(password: string): void {
    if (Buffer.byteLength(password, "utf8") > PASSWORD_MAX_BYTES) {
      throw new BadRequestException({
        code: ApiErrorCode.invalidRequest,
        message: "Password is too long.",
      });
    }
  }
}
