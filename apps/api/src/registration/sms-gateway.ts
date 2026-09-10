import {
  Inject,
  Injectable,
  ServiceUnavailableException,
} from "@nestjs/common";
import { ConfigType } from "@nestjs/config";
import { ApiErrorCode } from "@weyonje/contracts";
import { randomUUID } from "node:crypto";

import { smsConfig } from "../config/sms.config";
import { composeOtpMessage } from "./otp-message";

export interface OtpMessageContext {
  challengeId: string;
  ttlSeconds: number;
}

export abstract class SmsGateway {
  abstract sendVerificationCode(
    phoneNumber: string,
    code: string,
    context: OtpMessageContext,
  ): Promise<string>;
}

@Injectable()
export class AfricasTalkingSmsGateway implements SmsGateway {
  constructor(
    @Inject(smsConfig.KEY)
    private readonly config: ConfigType<typeof smsConfig>,
  ) {}

  async sendVerificationCode(
    phoneNumber: string,
    code: string,
    context: OtpMessageContext,
  ): Promise<string> {
    const controller = new AbortController();
    const timeout = setTimeout(
      () => controller.abort(),
      this.config.timeoutMilliseconds,
    );
    try {
      const body = new URLSearchParams({
        username: this.config.username,
        to: phoneNumber,
        message: composeOtpMessage(
          code,
          context.challengeId,
          context.ttlSeconds,
          this.config.androidAppHash,
        ),
      });
      if (this.config.senderId) body.set("from", this.config.senderId);
      const response = await fetch(
        `${this.config.baseUrl}/version1/messaging`,
        {
          method: "POST",
          headers: {
            Accept: "application/json",
            "Content-Type": "application/x-www-form-urlencoded",
            apiKey: this.config.apiKey,
          },
          body,
          signal: controller.signal,
        },
      );
      if (!response.ok) throw new Error(`SMS HTTP ${response.status}`);
      const value = (await response.json()) as {
        SMSMessageData?: {
          Recipients?: Array<{
            messageId?: string;
            status?: string;
            statusCode?: number;
            number?: string;
          }>;
        };
      };
      const recipient = value.SMSMessageData?.Recipients?.[0];
      if (
        value.SMSMessageData?.Recipients?.length !== 1 ||
        typeof recipient?.messageId !== "string" ||
        !recipient.messageId.trim() ||
        recipient.number !== phoneNumber ||
        ![100, 101, 102].includes(recipient.statusCode ?? -1)
      ) {
        throw new Error("SMS provider rejected the message");
      }
      return recipient.messageId;
    } catch {
      throw new ServiceUnavailableException({
        code: ApiErrorCode.dependencyUnavailable,
        message:
          "SMS acceptance could not be confirmed. Wait before requesting a new code.",
      });
    } finally {
      clearTimeout(timeout);
    }
  }
}

@Injectable()
export class DevelopmentFakeSmsGateway implements SmsGateway {
  async sendVerificationCode(
    _phoneNumber: string,
    _code: string,
  ): Promise<string> {
    return `fake-${randomUUID()}`;
  }
}
