ALTER TYPE "operational_notification_type" ADD VALUE IF NOT EXISTS 'PASSWORD_RECOVERY';
ALTER TYPE "operational_notification_type" ADD VALUE IF NOT EXISTS 'EMAIL_VERIFICATION';

CREATE TYPE "account_challenge_purpose" AS ENUM ('PASSWORD_RECOVERY', 'EMAIL_VERIFICATION');
CREATE TYPE "account_challenge_channel" AS ENUM ('SMS', 'EMAIL');

CREATE TABLE "account_challenges" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "purpose" "account_challenge_purpose" NOT NULL,
  "channel" "account_challenge_channel" NOT NULL,
  "secret_hash" varchar(64) NOT NULL,
  "expires_at" timestamptz(3) NOT NULL,
  "resend_available_at" timestamptz(3) NOT NULL,
  "attempts_remaining" integer NOT NULL DEFAULT 5,
  "consumed_at" timestamptz(3),
  "superseded_at" timestamptz(3),
  "created_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "pk_account_challenges" PRIMARY KEY ("id"),
  CONSTRAINT "fk_account_challenges_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE,
  CONSTRAINT "ck_account_challenges_attempts" CHECK ("attempts_remaining" BETWEEN 0 AND 10),
  CONSTRAINT "ck_account_challenges_expiry" CHECK ("expires_at" > "created_at"),
  CONSTRAINT "ck_account_challenges_resend" CHECK ("resend_available_at" >= "created_at"),
  CONSTRAINT "ck_account_challenges_terminal" CHECK ("consumed_at" IS NULL OR "superseded_at" IS NULL)
);

CREATE INDEX "ix_account_challenges_user_purpose_created"
  ON "account_challenges" ("user_id", "purpose", "created_at");
CREATE INDEX "ix_account_challenges_expiry" ON "account_challenges" ("expires_at");
CREATE UNIQUE INDEX "uq_account_challenges_active"
  ON "account_challenges" ("user_id", "purpose")
  WHERE "consumed_at" IS NULL AND "superseded_at" IS NULL;

CREATE TABLE "security_events" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid,
  "subject_hash" varchar(64) NOT NULL,
  "challenge_id" uuid,
  "action" varchar(100) NOT NULL,
  "outcome" varchar(64) NOT NULL,
  "created_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "pk_security_events" PRIMARY KEY ("id"),
  CONSTRAINT "fk_security_events_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL
);

CREATE INDEX "ix_security_events_subject_created" ON "security_events" ("subject_hash", "created_at");
CREATE INDEX "ix_security_events_user_created" ON "security_events" ("user_id", "created_at");
