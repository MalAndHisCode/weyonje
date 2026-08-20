import {
  ForbiddenException,
  Inject,
  Injectable,
  OnApplicationShutdown,
} from "@nestjs/common";
import { ConfigType } from "@nestjs/config";
import { ApiErrorCode } from "@weyonje/contracts";
import { randomUUID } from "node:crypto";

import { AuthenticatedActor } from "../auth/authenticated-actor";
import { ChallengeCodeService } from "../account-security/challenge-code.service";
import { DeviceInstallationService } from "../notifications/device-installation.service";
import { EmailSecurityService } from "../auth/email-security.service";
import { deliveryConfig } from "../config/delivery.config";
import { PrismaService } from "../database/prisma.service";
import {
  ActorType,
  NotificationDeliveryChannel,
  OutboxStatus,
} from "../generated/prisma/enums";
import { PhoneSecurityService } from "../registration/phone-security.service";
import {
  DeliveryFailure,
  DeliveryReceipt,
  EmailNotificationGateway,
  OperationalSmsGateway,
  PushNotificationGateway,
} from "../workflows/notification-delivery.gateway";

interface ClaimedEvent {
  id: string;
  requestId: string | null;
  recipientUserId: string | null;
  channel: NotificationDeliveryChannel;
  eventType: string;
  payload: unknown;
  deduplicationKey: string;
  attempts: number;
  claimToken: string;
  createdAt: Date;
}

export interface DeliveryBacklogHealth {
  healthy: boolean;
  pending: number;
  retrying: number;
  processing: number;
  deadLetter: number;
  oldestReadyAt?: string;
}

@Injectable()
export class DeliveryProcessor implements OnApplicationShutdown {
  private stopping = false;
  private nextCleanupAt = 0;

  constructor(
    private readonly prisma: PrismaService,
    private readonly phones: PhoneSecurityService,
    private readonly emails: EmailSecurityService,
    private readonly push: PushNotificationGateway,
    private readonly sms: OperationalSmsGateway,
    private readonly email: EmailNotificationGateway,
    private readonly challengeCodes: ChallengeCodeService,
    private readonly devices: DeviceInstallationService,
    @Inject(deliveryConfig.KEY)
    private readonly config: ConfigType<typeof deliveryConfig>,
  ) {}

  async run(): Promise<void> {
    this.stopping = false;
    while (!this.stopping) {
      if (Date.now() >= this.nextCleanupAt) {
        await this.cleanup();
        this.nextCleanupAt = Date.now() + 24 * 60 * 60 * 1000;
      }
      const processed = await this.processBatch();
      if (processed === 0)
        await this.pause(this.config.pollIntervalMilliseconds);
    }
  }

  stop(): void {
    this.stopping = true;
  }

  onApplicationShutdown(): void {
    this.stop();
  }

  async processBatch(): Promise<number> {
    const events = await this.claim();
    for (const event of events) {
      try {
        await this.deliver(event);
      } catch {
        // deliver records the classified outcome. One event never blocks the batch.
      }
    }
    return events.length;
  }

  async cleanup(): Promise<number> {
    const before = new Date(
      Date.now() - this.config.retentionDays * 24 * 60 * 60 * 1000,
    );
    const result = await this.prisma.outboxEvent.deleteMany({
      where: {
        status: { in: [OutboxStatus.DELIVERED, OutboxStatus.DEAD_LETTER] },
        updatedAt: { lt: before },
      },
    });
    return result.count;
  }

  async health(actor?: AuthenticatedActor): Promise<DeliveryBacklogHealth> {
    if (actor) this.assertOperator(actor);
    const [pending, retrying, processing, deadLetter, oldest] =
      await this.prisma.$transaction([
        this.prisma.outboxEvent.count({
          where: { status: OutboxStatus.PENDING },
        }),
        this.prisma.outboxEvent.count({
          where: { status: OutboxStatus.FAILED },
        }),
        this.prisma.outboxEvent.count({
          where: { status: OutboxStatus.PROCESSING },
        }),
        this.prisma.outboxEvent.count({
          where: { status: OutboxStatus.DEAD_LETTER },
        }),
        this.prisma.outboxEvent.findFirst({
          where: {
            status: { in: [OutboxStatus.PENDING, OutboxStatus.FAILED] },
          },
          orderBy: { nextAttemptAt: "asc" },
          select: { nextAttemptAt: true },
        }),
      ]);
    return {
      healthy: deadLetter === 0,
      pending,
      retrying,
      processing,
      deadLetter,
      ...(oldest ? { oldestReadyAt: oldest.nextAttemptAt.toISOString() } : {}),
    };
  }

  private async claim(): Promise<ClaimedEvent[]> {
    const claimToken = randomUUID();
    const leaseSeconds = this.config.claimLeaseSeconds;
    return this.prisma.$transaction(async (tx) => {
      const rows = await tx.$queryRaw<Array<Omit<ClaimedEvent, "claimToken">>>`
      WITH candidates AS (
        SELECT "id"
        FROM "outbox_events"
        WHERE (
          ("status" IN ('PENDING', 'FAILED') AND "next_attempt_at" <= CURRENT_TIMESTAMP)
          OR ("status" = 'PROCESSING' AND "claim_expires_at" <= CURRENT_TIMESTAMP)
        )
        ORDER BY "next_attempt_at", "created_at"
        FOR UPDATE SKIP LOCKED
        LIMIT ${this.config.batchSize}
      )
      UPDATE "outbox_events" AS event
      SET "status" = 'PROCESSING',
          "attempts" = event."attempts" + 1,
          "claimed_at" = CURRENT_TIMESTAMP,
          "claim_expires_at" = CURRENT_TIMESTAMP + (${leaseSeconds} * INTERVAL '1 second'),
          "claim_token" = ${claimToken}::uuid,
          "updated_at" = CURRENT_TIMESTAMP
      FROM candidates
      WHERE event."id" = candidates."id"
      RETURNING event."id",
                event."request_id" AS "requestId",
                event."recipient_user_id" AS "recipientUserId",
                event."channel",
                event."event_type"::text AS "eventType",
                event."payload",
                event."deduplication_key" AS "deduplicationKey",
                event."attempts",
                event."created_at" AS "createdAt"
      `;
      if (rows.length > 0) {
        await tx.deliveryAttempt.createMany({
          data: rows.map((row) => ({
            outboxEventId: row.id,
            attemptNumber: row.attempts,
            channel: row.channel,
            result: "PROCESSING",
          })),
        });
      }
      return rows.map((row) => ({ ...row, claimToken }));
    });
  }

  private async deliver(event: ClaimedEvent): Promise<void> {
    const startedAt = new Date();
    try {
      const content = await this.content(event);
      const receipt = await this.dispatch(event, content);
      await this.finish(
        event,
        startedAt,
        "DELIVERED",
        receipt,
        undefined,
        content,
      );
    } catch (error) {
      const failure = classify(error);
      const permanent =
        !failure.transient || event.attempts >= this.config.maxAttempts;
      await this.finish(
        event,
        startedAt,
        permanent ? "PERMANENT_FAILURE" : "TRANSIENT_FAILURE",
        undefined,
        failure.code,
      );
      throw error;
    }
  }

  private async dispatch(
    event: ClaimedEvent,
    content: { title: string; message: string },
  ): Promise<DeliveryReceipt> {
    if (event.channel === NotificationDeliveryChannel.IN_APP) return {};
    if (event.channel === NotificationDeliveryChannel.PUSH) {
      if (!event.recipientUserId)
        throw new DeliveryFailure("PUSH_RECIPIENT_MISSING", false);
      const receipt = await this.push.send({
        idempotencyKey: event.deduplicationKey,
        recipientUserId: event.recipientUserId,
        title: content.title,
        message: content.message,
        data: {
          eventType: event.eventType,
          ...(event.requestId ? { requestId: event.requestId } : {}),
        },
        targets: await this.devices.targets(event.recipientUserId),
      });
      await this.devices.invalidate(receipt.invalidTargetIds ?? []);
      return receipt;
    }
    if (event.channel === NotificationDeliveryChannel.SMS) {
      const phone = await this.recipientPhone(event);
      return this.sms.send({
        idempotencyKey: event.deduplicationKey,
        recipientPhone: phone,
        message: content.message,
        documentedPurpose: event.eventType,
      });
    }
    const email = await this.recipientEmail(event);
    return this.email.send({
      idempotencyKey: event.deduplicationKey,
      recipientEmail: email,
      subject: content.title,
      message: content.message,
    });
  }

  private async content(event: ClaimedEvent) {
    if (event.eventType === "REMINDER") {
      const payload = payloadObject(event.payload);
      const expectedAt =
        typeof payload.requestedServiceAt === "string"
          ? new Date(payload.requestedServiceAt)
          : null;
      const request = event.requestId
        ? await this.prisma.serviceRequest.findUnique({
            where: { id: event.requestId },
            select: { requestedServiceAt: true, status: true },
          })
        : null;
      if (
        !request?.requestedServiceAt ||
        !expectedAt ||
        Number.isNaN(expectedAt.getTime()) ||
        request.requestedServiceAt.getTime() !== expectedAt.getTime() ||
        ["CANCELLED", "COMPLETED"].includes(request.status) ||
        request.requestedServiceAt <= new Date()
      )
        throw new DeliveryFailure("REMINDER_INELIGIBLE", false);
      return {
        title:
          typeof payload.title === "string"
            ? payload.title
            : "Upcoming Weyonje service",
        message:
          typeof payload.message === "string"
            ? payload.message
            : "Your scheduled Weyonje service is coming up.",
      };
    }
    const challengeId = accountChallengeId(event.payload);
    if (challengeId) {
      const challenge = await this.prisma.accountChallenge.findUnique({
        where: { id: challengeId },
        select: {
          consumedAt: true,
          expiresAt: true,
          purpose: true,
          supersededAt: true,
        },
      });
      if (
        !challenge ||
        challenge.consumedAt ||
        challenge.supersededAt ||
        challenge.expiresAt <= new Date()
      ) {
        throw new DeliveryFailure("ACCOUNT_CHALLENGE_INELIGIBLE", false);
      }
      const code = this.challengeCodes.code(challengeId);
      return challenge.purpose === "PASSWORD_RECOVERY"
        ? {
            title: "Reset your Weyonje password",
            message: `Your Weyonje password recovery code is ${code}. Do not share this code.`,
          }
        : {
            title: "Verify your Weyonje email",
            message: `Your Weyonje email verification code is ${code}. Do not share this code.`,
          };
    }
    const notification = event.recipientUserId
      ? await this.prisma.operationalNotification.findFirst({
          where: {
            recipientUserId: event.recipientUserId,
            requestId: event.requestId,
            type: event.eventType as never,
          },
          orderBy: { createdAt: "desc" },
          select: { title: true, message: true },
        })
      : null;
    return (
      notification ?? {
        title: "Weyonje update",
        message: "There is an update to your Weyonje service request.",
      }
    );
  }

  private async recipientPhone(event: ClaimedEvent): Promise<string> {
    if (event.recipientUserId) {
      const user = await this.prisma.user.findUnique({
        where: { id: event.recipientUserId },
        select: { encryptedPhone: true },
      });
      if (user?.encryptedPhone) return this.phones.decrypt(user.encryptedPhone);
    }
    if (event.requestId) {
      const request = await this.prisma.serviceRequest.findUnique({
        where: { id: event.requestId },
        select: { encryptedClientPhone: true },
      });
      if (request) return this.phones.decrypt(request.encryptedClientPhone);
    }
    throw new DeliveryFailure("SMS_RECIPIENT_MISSING", false);
  }

  private async recipientEmail(event: ClaimedEvent): Promise<string> {
    if (event.recipientUserId) {
      const user = await this.prisma.user.findUnique({
        where: { id: event.recipientUserId },
        select: { encryptedEmail: true },
      });
      if (user?.encryptedEmail) return this.emails.decrypt(user.encryptedEmail);
    }
    if (event.requestId) {
      const request = await this.prisma.serviceRequest.findUnique({
        where: { id: event.requestId },
        select: { encryptedClientEmail: true },
      });
      if (request?.encryptedClientEmail)
        return this.emails.decrypt(request.encryptedClientEmail);
    }
    throw new DeliveryFailure("EMAIL_RECIPIENT_MISSING", false);
  }

  private async finish(
    event: ClaimedEvent,
    startedAt: Date,
    result: "DELIVERED" | "TRANSIENT_FAILURE" | "PERMANENT_FAILURE",
    receipt?: DeliveryReceipt,
    errorCode?: string,
    content?: { title: string; message: string },
  ): Promise<void> {
    const completedAt = new Date();
    const delivered = result === "DELIVERED";
    const permanent = result === "PERMANENT_FAILURE";
    const nextAttemptAt = new Date(
      completedAt.getTime() + this.backoffMilliseconds(event.attempts),
    );
    await this.prisma.$transaction(async (tx) => {
      const updated = await tx.outboxEvent.updateMany({
        where: { id: event.id, claimToken: event.claimToken },
        data: {
          status: delivered
            ? OutboxStatus.DELIVERED
            : permanent
              ? OutboxStatus.DEAD_LETTER
              : OutboxStatus.FAILED,
          nextAttemptAt,
          claimedAt: null,
          claimExpiresAt: null,
          claimToken: null,
          deliveredAt: delivered ? completedAt : null,
          deadLetteredAt: permanent ? completedAt : null,
          lastErrorCode: errorCode ?? null,
        },
      });
      if (updated.count !== 1) return;
      if (
        delivered &&
        event.channel === NotificationDeliveryChannel.IN_APP &&
        event.recipientUserId &&
        content
      ) {
        await tx.operationalNotification.createMany({
          data: [
            {
              recipientUserId: event.recipientUserId,
              requestId: event.requestId,
              type: event.eventType as never,
              title: content.title,
              message: content.message,
              sourceOutboxEventId: event.id,
            },
          ],
          skipDuplicates: true,
        });
      }
      await tx.deliveryAttempt.update({
        where: {
          outboxEventId_attemptNumber: {
            outboxEventId: event.id,
            attemptNumber: event.attempts,
          },
        },
        data: {
          result,
          errorCode: errorCode ?? null,
          providerMessageId: receipt?.providerMessageId ?? null,
          startedAt,
          completedAt,
        },
      });
    });
  }

  private backoffMilliseconds(attempt: number): number {
    const seconds = Math.min(
      this.config.backoffMaximumSeconds,
      this.config.backoffBaseSeconds * 2 ** Math.max(0, attempt - 1),
    );
    return seconds * 1000;
  }

  private assertOperator(actor: AuthenticatedActor): void {
    if (
      actor.user.actorType !== ActorType.KCCA_STAFF ||
      !actor.user.isActive ||
      !actor.user.callCentreOperationsPermitted
    ) {
      throw new ForbiddenException({
        code: ApiErrorCode.accessDenied,
        message: "This KCCA account cannot inspect delivery operations.",
      });
    }
  }

  private pause(milliseconds: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, milliseconds));
  }
}

function classify(error: unknown): DeliveryFailure {
  if (error instanceof DeliveryFailure) return error;
  return new DeliveryFailure("DELIVERY_UNEXPECTED", true);
}

function accountChallengeId(payload: unknown): string | null {
  if (
    typeof payload === "object" &&
    payload !== null &&
    "accountChallengeId" in payload &&
    typeof payload.accountChallengeId === "string"
  ) {
    return payload.accountChallengeId;
  }
  return null;
}

function payloadObject(payload: unknown): Record<string, unknown> {
  return typeof payload === "object" && payload !== null
    ? (payload as Record<string, unknown>)
    : {};
}
