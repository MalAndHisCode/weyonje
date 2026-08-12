import {
  Inject,
  Injectable,
  ServiceUnavailableException,
} from "@nestjs/common";
import { ConfigType } from "@nestjs/config";
import { ApiErrorCode } from "@weyonje/contracts";

import { smsConfig } from "../config/sms.config";

export abstract class SmsGateway {
  abstract sendVerificationCode(
    phoneNumber: string,
    code: string,
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
        message: `Your Weyonje verification code is ${code}. It expires in 10 minutes. Do not share this code.`,
        from: this.config.senderId,
      });
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
          }>;
        };
      };
      const recipient = value.SMSMessageData?.Recipients?.[0];
      if (
        !recipient?.messageId ||
        recipient.status?.toLowerCase().includes("fail") ||
        (recipient.statusCode !== undefined && recipient.statusCode >= 400)
      ) {
        throw new Error("SMS provider rejected the message");
      }
      return recipient.messageId;
    } catch {
      throw new ServiceUnavailableException({
        code: ApiErrorCode.dependencyUnavailable,
        message: "The verification code could not be sent. Try again.",
      });
    } finally {
      clearTimeout(timeout);
    }
  }
}
