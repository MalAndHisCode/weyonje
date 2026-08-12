import {
  BadRequestException,
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { ConfigType } from "@nestjs/config";
import {
  ApiErrorCode,
  PhoneChallengeContract,
  PhoneCodeDeliveryStatus,
} from "@weyonje/contracts";
import {
  createHmac,
  randomInt,
  randomUUID,
  timingSafeEqual,
} from "node:crypto";

import { authConfig } from "../config/auth.config";
import { PrismaService } from "../database/prisma.service";
import {
  PhoneChallengeDeliveryStatus,
  PhoneChallengePurpose,
} from "../generated/prisma/enums";
import { PhoneSecurityService } from "./phone-security.service";
import { SmsGateway } from "./sms-gateway";

@Injectable()
export class PhoneChallengeService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly phones: PhoneSecurityService,
    private readonly sms: SmsGateway,
    @Inject(authConfig.KEY)
    private readonly config: ConfigType<typeof authConfig>,
  ) {}

  async create(
    normalizedPhone: string,
    purpose: PhoneChallengePurpose,
    userId: string | null,
  ): Promise<PhoneChallengeContract> {
    const now = new Date();
    const phoneLookup = this.phones.lookup(normalizedPhone);
    const recent = await this.prisma.phoneChallenge.count({
      where: {
        phoneLookup,
        purpose,
        createdAt: { gte: new Date(now.getTime() - 3_600_000) },
      },
    });
    if (recent >= this.config.otpMaxRequestsPerHour) {
      throw new HttpException(
        {
          code: ApiErrorCode.rateLimited,
          message:
            "Too many verification codes were requested. Try again later.",
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    const id = randomUUID();
    const code = randomInt(0, 1_000_000).toString().padStart(6, "0");
    const expiresAt = new Date(
      now.getTime() + this.config.otpTtlSeconds * 1000,
    );
    const resendAvailableAt = new Date(
      now.getTime() + this.config.otpResendSeconds * 1000,
    );
    await this.prisma.$transaction(async (transaction) => {
      await transaction.phoneChallenge.updateMany({
        where: { phoneLookup, purpose, consumedAt: null },
        data: { consumedAt: now },
      });
      await transaction.phoneChallenge.create({
        data: {
          id,
          userId,
          phoneLookup,
          encryptedPhone: this.phones.encrypt(normalizedPhone),
          purpose,
          codeHash: this.hash(id, code),
          expiresAt,
          resendAvailableAt,
          attemptsRemaining: this.config.otpMaxAttempts,
        },
      });
    });
    let deliveryStatus = PhoneCodeDeliveryStatus.sent;
    try {
      const messageId = await this.sms.sendVerificationCode(
        normalizedPhone,
        code,
      );
      await this.prisma.phoneChallenge.update({
        where: { id },
        data: {
          deliveryStatus: PhoneChallengeDeliveryStatus.SENT,
          providerMessageId: messageId,
        },
      });
    } catch (error) {
      await this.prisma.phoneChallenge.update({
        where: { id },
        data: { deliveryStatus: PhoneChallengeDeliveryStatus.FAILED },
      });
      deliveryStatus = PhoneCodeDeliveryStatus.failed;
    }
    return {
      challengeId: id,
      maskedPhone: this.phones.mask(normalizedPhone),
      expiresAt: expiresAt.toISOString(),
      resendAvailableAt: resendAvailableAt.toISOString(),
      deliveryStatus,
    };
  }

  async resend(
    challengeId: string,
    expectedPurpose?: PhoneChallengePurpose,
  ): Promise<PhoneChallengeContract> {
    const challenge = await this.prisma.phoneChallenge.findUnique({
      where: { id: challengeId },
    });
    if (
      !challenge ||
      (expectedPurpose && challenge.purpose !== expectedPurpose)
    ) {
      throw this.invalidCode();
    }
    if (challenge.resendAvailableAt > new Date()) {
      throw new BadRequestException({
        code: ApiErrorCode.invalidRequest,
        message: "Wait before requesting another verification code.",
      });
    }
    return this.create(
      this.phones.decrypt(challenge.encryptedPhone),
      challenge.purpose,
      challenge.userId,
    );
  }

  async verify(
    challengeId: string,
    code: string,
    expectedPurpose: PhoneChallengePurpose,
  ): Promise<string | null> {
    if (!/^\d{6}$/.test(code)) throw this.invalidCode();
    const challenge = await this.prisma.phoneChallenge.findUnique({
      where: { id: challengeId },
    });
    const now = new Date();
    if (
      !challenge ||
      challenge.purpose !== expectedPurpose ||
      challenge.deliveryStatus !== PhoneChallengeDeliveryStatus.SENT ||
      challenge.consumedAt !== null ||
      challenge.attemptsRemaining <= 0
    ) {
      throw this.invalidCode();
    }
    if (challenge.expiresAt <= now) {
      throw new UnauthorizedException({
        code: ApiErrorCode.verificationExpired,
        message: "The verification code has expired. Request another code.",
      });
    }
    const supplied = Buffer.from(this.hash(challenge.id, code));
    const expected = Buffer.from(challenge.codeHash);
    if (
      supplied.length !== expected.length ||
      !timingSafeEqual(supplied, expected)
    ) {
      await this.prisma.phoneChallenge.updateMany({
        where: {
          id: challenge.id,
          consumedAt: null,
          attemptsRemaining: { gt: 0 },
        },
        data: { attemptsRemaining: { decrement: 1 } },
      });
      throw this.invalidCode();
    }
    const consumed = await this.prisma.phoneChallenge.updateMany({
      where: { id: challenge.id, consumedAt: null },
      data: { consumedAt: now },
    });
    if (consumed.count !== 1) throw this.invalidCode();
    return challenge.userId;
  }

  private hash(challengeId: string, code: string): string {
    return createHmac("sha256", this.config.otpHashKey)
      .update(`${challengeId}\0${code}`, "utf8")
      .digest("base64url");
  }

  private invalidCode(): UnauthorizedException {
    return new UnauthorizedException({
      code: ApiErrorCode.invalidVerificationCode,
      message: "The verification code is incorrect or no longer usable.",
    });
  }
}
