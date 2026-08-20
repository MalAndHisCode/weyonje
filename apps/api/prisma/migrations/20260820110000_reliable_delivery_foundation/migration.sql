ALTER TYPE "notification_delivery_channel" ADD VALUE IF NOT EXISTS 'EMAIL';
ALTER TYPE "outbox_status" ADD VALUE IF NOT EXISTS 'DEAD_LETTER';

ALTER TABLE "outbox_events"
  ADD COLUMN "claimed_at" timestamptz(3),
  ADD COLUMN "claim_expires_at" timestamptz(3),
  ADD COLUMN "claim_token" uuid,
  ADD COLUMN "dead_lettered_at" timestamptz(3),
  ADD CONSTRAINT "ck_outbox_events_claim" CHECK (
    ("status" = 'PROCESSING' AND "claimed_at" IS NOT NULL AND "claim_expires_at" IS NOT NULL AND "claim_token" IS NOT NULL)
    OR ("status" <> 'PROCESSING')
  ),
  ADD CONSTRAINT "ck_outbox_events_terminal" CHECK (
    ("status" = 'DELIVERED' AND "delivered_at" IS NOT NULL AND "dead_lettered_at" IS NULL)
    OR ("status" = 'DEAD_LETTER' AND "dead_lettered_at" IS NOT NULL AND "delivered_at" IS NULL)
    OR ("status" NOT IN ('DELIVERED', 'DEAD_LETTER') AND "delivered_at" IS NULL AND "dead_lettered_at" IS NULL)
  );

CREATE INDEX "ix_outbox_events_status_claim_expiry"
  ON "outbox_events" ("status", "claim_expires_at");

CREATE TABLE "delivery_attempts" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "outbox_event_id" uuid NOT NULL,
  "attempt_number" integer NOT NULL,
  "channel" "notification_delivery_channel" NOT NULL,
  "result" varchar(32) NOT NULL,
  "error_code" varchar(100),
  "provider_message_id" varchar(255),
  "started_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "completed_at" timestamptz(3),
  CONSTRAINT "pk_delivery_attempts" PRIMARY KEY ("id"),
  CONSTRAINT "fk_delivery_attempts_event" FOREIGN KEY ("outbox_event_id") REFERENCES "outbox_events"("id") ON DELETE CASCADE,
  CONSTRAINT "uq_delivery_attempts_event_number" UNIQUE ("outbox_event_id", "attempt_number"),
  CONSTRAINT "ck_delivery_attempts_number" CHECK ("attempt_number" > 0),
  CONSTRAINT "ck_delivery_attempts_result" CHECK ("result" IN ('PROCESSING', 'DELIVERED', 'TRANSIENT_FAILURE', 'PERMANENT_FAILURE')),
  CONSTRAINT "ck_delivery_attempts_error" CHECK (
    ("result" = 'PROCESSING' AND "completed_at" IS NULL AND "error_code" IS NULL)
    OR ("result" = 'DELIVERED' AND "completed_at" IS NOT NULL AND "error_code" IS NULL)
    OR ("result" IN ('TRANSIENT_FAILURE', 'PERMANENT_FAILURE') AND "completed_at" IS NOT NULL AND "error_code" IS NOT NULL)
  )
);

CREATE INDEX "ix_delivery_attempts_result_completed"
  ON "delivery_attempts" ("result", "completed_at");
