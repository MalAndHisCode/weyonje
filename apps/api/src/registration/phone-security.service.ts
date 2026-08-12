import { BadRequestException, Inject, Injectable } from "@nestjs/common";
import { ConfigType } from "@nestjs/config";
import { ApiErrorCode } from "@weyonje/contracts";
import { parsePhoneNumberFromString } from "libphonenumber-js";
import {
  createCipheriv,
  createDecipheriv,
  createHmac,
  randomBytes,
} from "node:crypto";

import { authConfig } from "../config/auth.config";

const PAYLOAD_VERSION = "v1";

@Injectable()
export class PhoneSecurityService {
  constructor(
    @Inject(authConfig.KEY)
    private readonly config: ConfigType<typeof authConfig>,
  ) {}

  normalize(value: string): string {
    const parsed = parsePhoneNumberFromString(value.trim(), "UG");
    if (!parsed || parsed.country !== "UG" || !parsed.isValid()) {
      throw new BadRequestException({
        code: ApiErrorCode.invalidRequest,
        message: "Enter a valid Ugandan phone number.",
      });
    }
    return parsed.number;
  }

  lookup(normalized: string): string {
    return createHmac("sha256", this.config.phoneLookupKey)
      .update(normalized, "utf8")
      .digest("base64url");
  }

  encrypt(normalized: string): string {
    const nonce = randomBytes(12);
    const cipher = createCipheriv(
      "aes-256-gcm",
      this.config.piiEncryptionKey,
      nonce,
    );
    const ciphertext = Buffer.concat([
      cipher.update(normalized, "utf8"),
      cipher.final(),
    ]);
    return [
      PAYLOAD_VERSION,
      nonce.toString("base64url"),
      cipher.getAuthTag().toString("base64url"),
      ciphertext.toString("base64url"),
    ].join(".");
  }

  decrypt(payload: string): string {
    const [version, nonce, tag, ciphertext] = payload.split(".");
    if (version !== PAYLOAD_VERSION || !nonce || !tag || !ciphertext) {
      throw new Error("Invalid encrypted phone payload.");
    }
    const decipher = createDecipheriv(
      "aes-256-gcm",
      this.config.piiEncryptionKey,
      Buffer.from(nonce, "base64url"),
    );
    decipher.setAuthTag(Buffer.from(tag, "base64url"));
    return Buffer.concat([
      decipher.update(Buffer.from(ciphertext, "base64url")),
      decipher.final(),
    ]).toString("utf8");
  }

  mask(normalized: string): string {
    return `${normalized.slice(0, 4)} ${"•".repeat(Math.max(4, normalized.length - 7))} ${normalized.slice(-3)}`;
  }
}
