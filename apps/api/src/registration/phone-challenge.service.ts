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

type TransactionClient = Parameters<
  Parameters<PrismaService["$transaction"]>[0]
>[0];

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
    let now = new Date();
    const phoneLookup = this.phones.lookup(normalizedPhone);
    const id = randomUUID();
    const code = randomInt(0, 1_000_000).toString().padStart(6, "0");
    const expiresAt = new Date(
      now.getTime() + this.config.otpTtlSeconds * 1000,
    );
    const resendAvailableAt = new Date(
      now.getTime() + this.config.otpResendSeconds * 1000,
    );
    await this.prisma.$transaction(async (transaction) => {
      // Serialize issuance for the protected phone/purpose, including empty sets.
      await transaction.$queryRaw`SELECT pg_advisory_xact_lock(hashtextextended(${phoneLookup + ":" + purpose}, 0))::text`;
      now = new Date();
      expiresAt.setTime(now.getTime() + this.config.otpTtlSeconds * 1000);
      resendAvailableAt.setTime(
        now.getTime() + this.config.otpResendSeconds * 1000,
      );
      const recent = await transaction.phoneChallenge.count({
        where: {
          phoneLookup,
          purpose,
          createdAt: { gte: new Date(now.getTime() - 3_600_000) },
        },
      });
      if (recent >= this.config.otpMaxRequestsPerHour) {
        const boundary = await transaction.phoneChallenge.findFirst({
          where: {
            phoneLookup,
            purpose,
            createdAt: { gte: new Date(now.getTime() - 3_600_000) },
          },
          orderBy: { createdAt: "desc" },
          skip: this.config.otpMaxRequestsPerHour - 1,
          select: { createdAt: true },
        });
        const latest = await transaction.phoneChallenge.findFirst({
          where: { phoneLookup, purpose },
          orderBy: { createdAt: "desc" },
          select: { resendAvailableAt: true },
        });
        if (!boundary)
          throw new Error("OTP rate-limit boundary is unavailable.");
        throw new HttpException(
          {
            code: ApiErrorCode.rateLimited,
            limitCategory: "OTP_HOURLY",
            retryAt: new Date(
              Math.max(
                boundary.createdAt.getTime() + 3_600_001,
                latest?.resendAvailableAt.getTime() ?? 0,
              ),
            ).toISOString(),
            message:
              "Too many verification codes were requested. Try again later.",
          },
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }

      const latest = await transaction.phoneChallenge.findFirst({
        where: { phoneLookup, purpose },
        orderBy: { createdAt: "desc" },
      });
      if (latest && latest.resendAvailableAt > now) {
        throw new BadRequestException({
          code: ApiErrorCode.invalidRequest,
          limitCategory: "OTP_COOLDOWN",
          retryAt: latest.resendAvailableAt.toISOString(),
          message: "Wait before requesting another verification code.",
        });
      }
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
        { challengeId: id, ttlSeconds: this.config.otpTtlSeconds },
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

  // Read-only recovery evidence: all applicable issuance limits must have elapsed.
  // Issuance still rechecks under its transaction lock before writing/sending.
  async nextRequestAvailableAt(
    phoneLookup: string,
    purpose: PhoneChallengePurpose,
  ): Promise<{ retryAt: Date; hourlyLimited: boolean }> {
    const now = new Date();
    const boundary = await this.prisma.phoneChallenge.findFirst({
      where: {
        phoneLookup,
        purpose,
        createdAt: { gte: new Date(now.getTime() - 3_600_000) },
      },
      orderBy: { createdAt: "desc" },
      skip: this.config.otpMaxRequestsPerHour - 1,
      select: { createdAt: true },
    });
    const latest = await this.prisma.phoneChallenge.findFirst({
      where: { phoneLookup, purpose },
      orderBy: { createdAt: "desc" },
      select: { resendAvailableAt: true },
    });
    return {
      hourlyLimited: boundary !== null,
      retryAt: new Date(
        Math.max(
          now.getTime(),
          boundary ? boundary.createdAt.getTime() + 3_600_001 : 0,
          latest?.resendAvailableAt.getTime() ?? 0,
        ),
      ),
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
      const issuanceAt = await this.nextRequestAvailableAt(
        challenge.phoneLookup,
        challenge.purpose,
      );
      throw new HttpException(
        {
          code: issuanceAt.hourlyLimited
            ? ApiErrorCode.rateLimited
            : ApiErrorCode.invalidRequest,
          limitCategory: issuanceAt.hourlyLimited
            ? "OTP_HOURLY"
            : "OTP_COOLDOWN",
          retryAt: new Date(
            Math.max(
              challenge.resendAvailableAt.getTime(),
              issuanceAt.retryAt.getTime(),
            ),
          ).toISOString(),
          message: issuanceAt.hourlyLimited
            ? "Too many verification codes were requested. Try again later."
            : "Wait before requesting another verification code.",
        },
        issuanceAt.hourlyLimited
          ? HttpStatus.TOO_MANY_REQUESTS
          : HttpStatus.BAD_REQUEST,
      );
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
    return this.verifyAndComplete(
      challengeId,
      code,
      expectedPurpose,
      async (userId) => userId,
    );
  }

  async verifyAndComplete<T>(
    challengeId: string,
    code: string,
    expectedPurpose: PhoneChallengePurpose,
    complete: (
      userId: string | null,
      transaction: TransactionClient,
      phoneLookup: string,
    ) => Promise<T>,
  ): Promise<T> {
    if (!/^\d{6}$/.test(code)) throw this.invalidCode();
    const challenge = await this.prisma.phoneChallenge.findUnique({
      where: { id: challengeId },
    });
    const now = new Date();
    if (
      !challenge ||
      challenge.purpose !== expectedPurpose ||
      challenge.deliveryStatus !== PhoneChallengeDeliveryStatus.SENT ||
      challenge.consumedAt !== null
    ) {
      throw this.invalidCode();
    }
    if (challenge.attemptsRemaining <= 0) {
      throw new HttpException(
        {
          code: ApiErrorCode.rateLimited,
          message: "No verification attempts remain. Request another code.",
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
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
    return this.prisma.$transaction(async (transaction) => {
      const consumed = await transaction.phoneChallenge.updateMany({
        where: {
          id: challenge.id,
          consumedAt: null,
          attemptsRemaining: { gt: 0 },
          expiresAt: { gt: new Date() },
          deliveryStatus: PhoneChallengeDeliveryStatus.SENT,
        },
        data: { consumedAt: now },
      });
      if (consumed.count !== 1) throw this.invalidCode();
      return complete(challenge.userId, transaction, challenge.phoneLookup);
    });
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
