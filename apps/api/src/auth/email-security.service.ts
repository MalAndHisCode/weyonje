import {
  BadRequestException,
  Inject,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { ConfigType } from "@nestjs/config";
import { ApiErrorCode } from "@weyonje/contracts";
import {
  createCipheriv,
  createDecipheriv,
  createHmac,
  randomBytes,
} from "node:crypto";

import { authConfig } from "../config/auth.config";

const EMAIL_MAX_LENGTH = 254;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/u;
const PAYLOAD_VERSION = "v1";

@Injectable()
export class EmailSecurityService {
  constructor(
    @Inject(authConfig.KEY)
    private readonly config: ConfigType<typeof authConfig>,
  ) {}

  normalize(value: string): string {
    const normalized = value.trim().normalize("NFKC").toLowerCase();
    if (
      normalized.length === 0 ||
      normalized.length > EMAIL_MAX_LENGTH ||
      !EMAIL_PATTERN.test(normalized)
    ) {
      throw new BadRequestException({
        code: ApiErrorCode.invalidRequest,
        message: "Enter a valid email address.",
      });
    }
    return normalized;
  }

  lookup(normalizedEmail: string): string {
    return createHmac("sha256", this.config.emailLookupKey)
      .update(normalizedEmail, "utf8")
      .digest("base64url");
  }

  encrypt(normalizedEmail: string): string {
    const nonce = randomBytes(12);
    const cipher = createCipheriv(
      "aes-256-gcm",
      this.config.emailEncryptionKey,
      nonce,
    );
    const ciphertext = Buffer.concat([
      cipher.update(normalizedEmail, "utf8"),
      cipher.final(),
    ]);
    const tag = cipher.getAuthTag();
    return [
      PAYLOAD_VERSION,
      nonce.toString("base64url"),
      ciphertext.toString("base64url"),
      tag.toString("base64url"),
    ].join(".");
  }

  decrypt(payload: string): string {
    const parts = payload.split(".");
    if (parts.length !== 4 || parts[0] !== PAYLOAD_VERSION) {
      throw this.invalidPayload();
    }
    try {
      const nonce = decodePart(parts[1]!, 12);
      const ciphertext = decodePart(parts[2]!, null);
      const tag = decodePart(parts[3]!, 16);
      if (ciphertext.length === 0) throw new Error("Empty ciphertext");
      const decipher = createDecipheriv(
        "aes-256-gcm",
        this.config.emailEncryptionKey,
        nonce,
      );
      decipher.setAuthTag(tag);
      return Buffer.concat([
        decipher.update(ciphertext),
        decipher.final(),
      ]).toString("utf8");
    } catch {
      throw this.invalidPayload();
    }
  }

  private invalidPayload(): UnauthorizedException {
    return new UnauthorizedException({
      code: ApiErrorCode.invalidSession,
      message: "Protected account data is unavailable.",
    });
  }
}

function decodePart(value: string, expectedLength: number | null): Buffer {
  if (!/^[A-Za-z0-9_-]+$/.test(value)) throw new Error("Malformed payload");
  const decoded = Buffer.from(value, "base64url");
  if (expectedLength !== null && decoded.length !== expectedLength) {
    throw new Error("Malformed payload length");
  }
  return decoded;
}
