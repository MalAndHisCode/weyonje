ALTER TYPE "operational_notification_type" ADD VALUE IF NOT EXISTS 'PROVIDER_ACCOUNT_UPDATED';

ALTER TABLE "operational_notifications"
  ADD COLUMN "source_outbox_event_id" UUID;
CREATE UNIQUE INDEX "uq_operational_notifications_source_outbox"
  ON "operational_notifications"("source_outbox_event_id")
  WHERE "source_outbox_event_id" IS NOT NULL;

CREATE TABLE "device_installations" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "user_id" UUID NOT NULL,
  "installation_id" UUID NOT NULL,
  "environment" VARCHAR(32) NOT NULL,
  "platform" VARCHAR(32) NOT NULL,
  "token_lookup" VARCHAR(64) NOT NULL,
  "encrypted_token" VARCHAR(4096) NOT NULL,
  "active" BOOLEAN NOT NULL DEFAULT true,
  "last_seen_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "invalidated_at" TIMESTAMPTZ(3),
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "device_installations_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "device_installations_user_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "uq_device_installations_token_lookup" ON "device_installations"("token_lookup");
CREATE UNIQUE INDEX "uq_device_installations_user_installation_environment" ON "device_installations"("user_id", "installation_id", "environment");
CREATE INDEX "ix_device_installations_user_active" ON "device_installations"("user_id", "active");

CREATE TABLE "provider_status_history" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "provider_user_id" UUID NOT NULL,
  "changed_by_user_id" UUID NOT NULL,
  "from_status" "provider_status" NOT NULL,
  "to_status" "provider_status" NOT NULL,
  "reason" VARCHAR(1000),
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "provider_status_history_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "provider_status_history_provider_fkey" FOREIGN KEY ("provider_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "provider_status_history_actor_fkey" FOREIGN KEY ("changed_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE INDEX "ix_provider_status_history_subject_created"
  ON "provider_status_history"("provider_user_id", "created_at");

CREATE TABLE "disposal_assignment_history" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "request_id" UUID NOT NULL,
  "disposal_site_id" UUID NOT NULL,
  "assigned_by_user_id" UUID NOT NULL,
  "assigned_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "disposal_assignment_history_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "disposal_assignment_history_request_fkey" FOREIGN KEY ("request_id") REFERENCES "service_requests"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "disposal_assignment_history_site_fkey" FOREIGN KEY ("disposal_site_id") REFERENCES "disposal_sites"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "disposal_assignment_history_actor_fkey" FOREIGN KEY ("assigned_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE INDEX "ix_disposal_assignment_history_request_time"
  ON "disposal_assignment_history"("request_id", "assigned_at");

INSERT INTO "provider_status_history" (
  "provider_user_id", "changed_by_user_id", "from_status", "to_status", "reason", "created_at"
)
SELECT decision."provider_user_id", decision."decided_by_user_id", 'PENDING',
  CASE WHEN decision."decision" = 'APPROVED' THEN 'APPROVED'::"provider_status" ELSE 'REJECTED'::"provider_status" END,
  decision."reason", decision."created_at"
FROM "provider_approval_decisions" decision;

INSERT INTO "disposal_assignment_history" (
  "request_id", "disposal_site_id", "assigned_by_user_id", "assigned_at"
)
SELECT "request_id", "disposal_site_id", "assigned_by_user_id", "assigned_at"
FROM "disposal_assignments";
