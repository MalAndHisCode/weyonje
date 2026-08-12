ALTER TYPE "throttle_scope" ADD VALUE 'PHONE';

CREATE TYPE "client_type" AS ENUM ('INDIVIDUAL', 'ORGANIZATION');
CREATE TYPE "service_provider_type" AS ENUM ('GULPER', 'EMPTIER');
CREATE TYPE "phone_challenge_purpose" AS ENUM ('REGISTRATION', 'CLIENT_SIGN_IN');
CREATE TYPE "phone_challenge_delivery_status" AS ENUM ('PENDING', 'SENT', 'FAILED');
CREATE TYPE "provider_approval_decision" AS ENUM ('APPROVED', 'REJECTED');
CREATE TYPE "notification_type" AS ENUM ('PROVIDER_REVIEW_REQUIRED', 'PROVIDER_APPROVED', 'PROVIDER_REJECTED');

ALTER TABLE "users"
  ALTER COLUMN "encrypted_email" DROP NOT NULL,
  ALTER COLUMN "email_lookup" DROP NOT NULL,
  ALTER COLUMN "password_hash" DROP NOT NULL,
  ADD COLUMN "encrypted_phone" varchar(1024),
  ADD COLUMN "phone_lookup" varchar(64),
  ADD COLUMN "phone_verified_at" timestamptz(3),
  ADD COLUMN "provider_approval_permitted" boolean NOT NULL DEFAULT false,
  ADD CONSTRAINT "uq_users_phone_lookup" UNIQUE ("phone_lookup"),
  ADD CONSTRAINT "ck_users_email_pair" CHECK (("encrypted_email" IS NULL) = ("email_lookup" IS NULL)),
  ADD CONSTRAINT "ck_users_phone_pair" CHECK (("encrypted_phone" IS NULL) = ("phone_lookup" IS NULL)),
  ADD CONSTRAINT "ck_users_provider_approval" CHECK ("actor_type" = 'KCCA_STAFF' OR "provider_approval_permitted" = false);

CREATE TABLE "client_profiles" (
  "user_id" uuid NOT NULL,
  "client_number" varchar(32),
  "client_type" "client_type" NOT NULL,
  "first_name" varchar(100),
  "last_name" varchar(100),
  "organization_name" varchar(200),
  "contact_person_name" varchar(200),
  "encrypted_contact_phone" varchar(1024),
  "created_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "pk_client_profiles" PRIMARY KEY ("user_id"),
  CONSTRAINT "uq_client_profiles_client_number" UNIQUE ("client_number"),
  CONSTRAINT "fk_client_profiles_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE,
  CONSTRAINT "ck_client_profiles_identity" CHECK (
    ("client_type" = 'INDIVIDUAL' AND "first_name" IS NOT NULL AND "last_name" IS NOT NULL AND "organization_name" IS NULL AND "contact_person_name" IS NULL AND "encrypted_contact_phone" IS NULL)
    OR
    ("client_type" = 'ORGANIZATION' AND "first_name" IS NULL AND "last_name" IS NULL AND "organization_name" IS NOT NULL AND "contact_person_name" IS NOT NULL AND "encrypted_contact_phone" IS NOT NULL)
  )
);

CREATE TABLE "service_provider_profiles" (
  "user_id" uuid NOT NULL,
  "provider_number" varchar(32),
  "ess_license_number" varchar(100) NOT NULL,
  "company_name" varchar(200) NOT NULL,
  "work_address" varchar(500) NOT NULL,
  "provider_type" "service_provider_type" NOT NULL,
  "contact_person_name" varchar(200) NOT NULL,
  "encrypted_contact_phone" varchar(1024) NOT NULL,
  "latest_rejection_reason" varchar(1000),
  "created_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "pk_service_provider_profiles" PRIMARY KEY ("user_id"),
  CONSTRAINT "uq_service_provider_profiles_provider_number" UNIQUE ("provider_number"),
  CONSTRAINT "fk_service_provider_profiles_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE
);

CREATE INDEX "ix_service_provider_profiles_ess_license" ON "service_provider_profiles" ("ess_license_number");

CREATE TABLE "phone_challenges" (
  "id" uuid NOT NULL,
  "user_id" uuid,
  "phone_lookup" varchar(64) NOT NULL,
  "encrypted_phone" varchar(1024) NOT NULL,
  "purpose" "phone_challenge_purpose" NOT NULL,
  "code_hash" varchar(64) NOT NULL,
  "expires_at" timestamptz(3) NOT NULL,
  "resend_available_at" timestamptz(3) NOT NULL,
  "attempts_remaining" integer NOT NULL DEFAULT 5,
  "consumed_at" timestamptz(3),
  "delivery_status" "phone_challenge_delivery_status" NOT NULL DEFAULT 'PENDING',
  "provider_message_id" varchar(255),
  "created_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "pk_phone_challenges" PRIMARY KEY ("id"),
  CONSTRAINT "fk_phone_challenges_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE,
  CONSTRAINT "ck_phone_challenges_attempts" CHECK ("attempts_remaining" >= 0 AND "attempts_remaining" <= 5),
  CONSTRAINT "ck_phone_challenges_expiry" CHECK ("expires_at" > "created_at"),
  CONSTRAINT "ck_phone_challenges_resend" CHECK ("resend_available_at" >= "created_at")
);

CREATE INDEX "ix_phone_challenges_phone_purpose_created" ON "phone_challenges" ("phone_lookup", "purpose", "created_at");
CREATE INDEX "ix_phone_challenges_expiry" ON "phone_challenges" ("expires_at");

CREATE TABLE "provider_approval_decisions" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "provider_user_id" uuid NOT NULL,
  "decided_by_user_id" uuid NOT NULL,
  "decision" "provider_approval_decision" NOT NULL,
  "reason" varchar(1000),
  "created_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "pk_provider_approval_decisions" PRIMARY KEY ("id"),
  CONSTRAINT "fk_provider_approval_decisions_subject" FOREIGN KEY ("provider_user_id") REFERENCES "users"("id") ON DELETE CASCADE,
  CONSTRAINT "fk_provider_approval_decisions_actor" FOREIGN KEY ("decided_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT,
  CONSTRAINT "ck_provider_approval_decisions_reason" CHECK (("decision" = 'REJECTED' AND "reason" IS NOT NULL) OR ("decision" = 'APPROVED' AND "reason" IS NULL))
);

CREATE INDEX "ix_provider_approval_decisions_subject_created" ON "provider_approval_decisions" ("provider_user_id", "created_at");

CREATE TABLE "registration_notifications" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "recipient_user_id" uuid,
  "recipient_actor_type" "actor_type",
  "type" "notification_type" NOT NULL,
  "subject_user_id" uuid NOT NULL,
  "created_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "read_at" timestamptz(3),
  CONSTRAINT "pk_registration_notifications" PRIMARY KEY ("id"),
  CONSTRAINT "fk_registration_notifications_recipient" FOREIGN KEY ("recipient_user_id") REFERENCES "users"("id") ON DELETE CASCADE,
  CONSTRAINT "ck_registration_notifications_recipient" CHECK (("recipient_user_id" IS NULL) <> ("recipient_actor_type" IS NULL))
);

CREATE INDEX "ix_registration_notifications_actor_created" ON "registration_notifications" ("recipient_actor_type", "created_at");
CREATE INDEX "ix_registration_notifications_user_created" ON "registration_notifications" ("recipient_user_id", "created_at");
