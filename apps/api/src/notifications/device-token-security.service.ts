import { Inject, Injectable } from "@nestjs/common";
import { ConfigType } from "@nestjs/config";
import {
  createCipheriv,
  createDecipheriv,
  createHmac,
  randomBytes,
} from "node:crypto";
import { authConfig } from "../config/auth.config";

@Injectable()
export class DeviceTokenSecurityService {
  constructor(
    @Inject(authConfig.KEY)
    private readonly config: ConfigType<typeof authConfig>,
  ) {}
  lookup(token: string): string {
    return createHmac("sha256", this.config.phoneLookupKey)
      .update(`fcm-token\0${token}`, "utf8")
      .digest("base64url");
  }
  encrypt(token: string): string {
    const nonce = randomBytes(12);
    const cipher = createCipheriv(
      "aes-256-gcm",
      this.config.piiEncryptionKey,
      nonce,
    );
    const encrypted = Buffer.concat([
      cipher.update(token, "utf8"),
      cipher.final(),
    ]);
    return `v1.${nonce.toString("base64url")}.${encrypted.toString("base64url")}.${cipher.getAuthTag().toString("base64url")}`;
  }
  decrypt(payload: string): string {
    const [version, nonce, encrypted, tag] = payload.split(".");
    if (version !== "v1" || !nonce || !encrypted || !tag)
      throw new Error("Protected device token is invalid.");
    const decipher = createDecipheriv(
      "aes-256-gcm",
      this.config.piiEncryptionKey,
      Buffer.from(nonce, "base64url"),
    );
    decipher.setAuthTag(Buffer.from(tag, "base64url"));
    return Buffer.concat([
      decipher.update(Buffer.from(encrypted, "base64url")),
      decipher.final(),
    ]).toString("utf8");
  }
}
