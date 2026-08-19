CREATE TYPE "service_request_origin" AS ENUM ('MOBILE_APP', 'CALL_CENTRE');
CREATE TYPE "service_request_status" AS ENUM ('PENDING', 'ACCEPTED', 'ACTIVE', 'COLLECTION_REPORTED', 'COLLECTION_COMPLETED', 'FOLLOW_UP_REQUIRED', 'COMPLETED', 'CANCELLED');
CREATE TYPE "request_location_kind" AS ENUM ('CURRENT', 'MAP_PIN', 'TEXT');
CREATE TYPE "toilet_type" AS ENUM ('PIT_LATRINE', 'SEPTIC_TANK');
CREATE TYPE "schedule_mode" AS ENUM ('AS_SOON_AS_POSSIBLE', 'SCHEDULED');
CREATE TYPE "request_assignment_status" AS ENUM ('PENDING', 'ACCEPTED', 'REJECTED', 'SUPERSEDED');
CREATE TYPE "journey_phase" AS ENUM ('TO_REQUEST', 'TO_DISPOSAL');
CREATE TYPE "journey_status" AS ENUM ('READY', 'ACTIVE', 'ARRIVED', 'COMPLETED');
CREATE TYPE "collection_outcome" AS ENUM ('COMPLETED', 'LEFT_INCOMPLETE', 'NOT_DONE_AT_ALL');
CREATE TYPE "follow_up_status" AS ENUM ('OPEN', 'RESOLVED');
CREATE TYPE "operational_notification_type" AS ENUM ('REQUEST_CREATED', 'REQUEST_ASSIGNED', 'REQUEST_ACCEPTED', 'REQUEST_REJECTED', 'JOURNEY_STARTED', 'PROVIDER_ARRIVED', 'COLLECTION_REPORTED', 'COLLECTION_CONFIRMED', 'FOLLOW_UP_REQUIRED', 'DISPOSAL_READY', 'DISPOSAL_STARTED', 'DISPOSAL_ARRIVED', 'DISPOSAL_COMPLETED', 'REMINDER');
CREATE TYPE "notification_delivery_channel" AS ENUM ('IN_APP', 'SMS', 'PUSH');
CREATE TYPE "outbox_status" AS ENUM ('PENDING', 'PROCESSING', 'DELIVERED', 'FAILED');

ALTER TABLE "users"
  ADD COLUMN "call_centre_operations_permitted" boolean NOT NULL DEFAULT false,
  ADD CONSTRAINT "ck_users_call_centre_operations" CHECK ("actor_type" = 'KCCA_STAFF' OR "call_centre_operations_permitted" = false);

CREATE TABLE "service_requests" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "reference" varchar(32) NOT NULL,
  "origin" "service_request_origin" NOT NULL,
  "status" "service_request_status" NOT NULL DEFAULT 'PENDING',
  "client_user_id" uuid,
  "created_by_user_id" uuid,
  "accepted_provider_user_id" uuid,
  "client_name" varchar(240) NOT NULL,
  "encrypted_client_phone" varchar(1024) NOT NULL,
  "encrypted_client_email" varchar(1024),
  "location_kind" "request_location_kind" NOT NULL,
  "location_text" varchar(500),
  "latitude" decimal(9,6),
  "longitude" decimal(9,6),
  "toilet_type" "toilet_type",
  "additional_contact_name" varchar(200),
  "encrypted_additional_phone" varchar(1024),
  "schedule_mode" "schedule_mode" NOT NULL,
  "requested_service_at" timestamptz(3),
  "agreed_price_ugx" integer,
  "accepted_at" timestamptz(3),
  "created_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "pk_service_requests" PRIMARY KEY ("id"),
  CONSTRAINT "uq_service_requests_reference" UNIQUE ("reference"),
  CONSTRAINT "fk_service_requests_client" FOREIGN KEY ("client_user_id") REFERENCES "users"("id") ON DELETE RESTRICT,
  CONSTRAINT "fk_service_requests_creator" FOREIGN KEY ("created_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT,
  CONSTRAINT "fk_service_requests_provider" FOREIGN KEY ("accepted_provider_user_id") REFERENCES "users"("id") ON DELETE RESTRICT,
  CONSTRAINT "ck_service_requests_origin_owner" CHECK (
    ("origin" = 'MOBILE_APP' AND "client_user_id" IS NOT NULL)
    OR ("origin" = 'CALL_CENTRE' AND "client_user_id" IS NULL AND "created_by_user_id" IS NOT NULL)
  ),
  CONSTRAINT "ck_service_requests_location_pair" CHECK (("latitude" IS NULL) = ("longitude" IS NULL)),
  CONSTRAINT "ck_service_requests_location_kind" CHECK (
    ("location_kind" IN ('CURRENT', 'MAP_PIN') AND "latitude" IS NOT NULL)
    OR ("location_kind" = 'TEXT' AND "location_text" IS NOT NULL)
  ),
  CONSTRAINT "ck_service_requests_latitude" CHECK ("latitude" IS NULL OR "latitude" BETWEEN -90 AND 90),
  CONSTRAINT "ck_service_requests_longitude" CHECK ("longitude" IS NULL OR "longitude" BETWEEN -180 AND 180),
  CONSTRAINT "ck_service_requests_schedule" CHECK (
    ("schedule_mode" = 'SCHEDULED' AND "requested_service_at" IS NOT NULL)
    OR ("schedule_mode" = 'AS_SOON_AS_POSSIBLE' AND "requested_service_at" IS NULL)
  ),
  CONSTRAINT "ck_service_requests_price" CHECK ("agreed_price_ugx" IS NULL OR "agreed_price_ugx" BETWEEN 0 AND 1000000000)
);

CREATE INDEX "ix_service_requests_client_created" ON "service_requests" ("client_user_id", "created_at");
CREATE INDEX "ix_service_requests_provider_updated" ON "service_requests" ("accepted_provider_user_id", "updated_at");
CREATE INDEX "ix_service_requests_origin_status_created" ON "service_requests" ("origin", "status", "created_at");

CREATE TABLE "request_assignments" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "request_id" uuid NOT NULL,
  "provider_user_id" uuid NOT NULL,
  "assigned_by_user_id" uuid,
  "status" "request_assignment_status" NOT NULL DEFAULT 'PENDING',
  "created_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "decided_at" timestamptz(3),
  CONSTRAINT "pk_request_assignments" PRIMARY KEY ("id"),
  CONSTRAINT "fk_request_assignments_request" FOREIGN KEY ("request_id") REFERENCES "service_requests"("id") ON DELETE CASCADE,
  CONSTRAINT "fk_request_assignments_provider" FOREIGN KEY ("provider_user_id") REFERENCES "users"("id") ON DELETE RESTRICT,
  CONSTRAINT "fk_request_assignments_actor" FOREIGN KEY ("assigned_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT
);

CREATE INDEX "ix_request_assignments_provider_status" ON "request_assignments" ("provider_user_id", "status", "created_at");
CREATE INDEX "ix_request_assignments_request_status" ON "request_assignments" ("request_id", "status");
CREATE UNIQUE INDEX "uq_request_assignments_active_provider" ON "request_assignments" ("request_id", "provider_user_id") WHERE "status" IN ('PENDING', 'ACCEPTED');

CREATE TABLE "request_status_history" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "request_id" uuid NOT NULL,
  "from_status" "service_request_status",
  "to_status" "service_request_status" NOT NULL,
  "actor_user_id" uuid,
  "reason" varchar(500),
  "created_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "pk_request_status_history" PRIMARY KEY ("id"),
  CONSTRAINT "fk_request_status_history_request" FOREIGN KEY ("request_id") REFERENCES "service_requests"("id") ON DELETE CASCADE
);

CREATE INDEX "ix_request_status_history_request_created" ON "request_status_history" ("request_id", "created_at");

CREATE TABLE "journeys" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "request_id" uuid NOT NULL,
  "provider_user_id" uuid NOT NULL,
  "phase" "journey_phase" NOT NULL,
  "status" "journey_status" NOT NULL DEFAULT 'READY',
  "started_at" timestamptz(3),
  "arrived_at" timestamptz(3),
  "completed_at" timestamptz(3),
  "created_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "pk_journeys" PRIMARY KEY ("id"),
  CONSTRAINT "uq_journeys_request_phase" UNIQUE ("request_id", "phase"),
  CONSTRAINT "fk_journeys_request" FOREIGN KEY ("request_id") REFERENCES "service_requests"("id") ON DELETE CASCADE,
  CONSTRAINT "fk_journeys_provider" FOREIGN KEY ("provider_user_id") REFERENCES "users"("id") ON DELETE RESTRICT
);

CREATE INDEX "ix_journeys_provider_status" ON "journeys" ("provider_user_id", "status");

CREATE TABLE "journey_positions" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "journey_id" uuid NOT NULL,
  "sample_id" uuid NOT NULL,
  "device_timestamp" timestamptz(3) NOT NULL,
  "received_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "latitude" decimal(9,6) NOT NULL,
  "longitude" decimal(9,6) NOT NULL,
  "accuracy_metres" decimal(8,2) NOT NULL,
  "accepted_for_arrival" boolean NOT NULL DEFAULT false,
  CONSTRAINT "pk_journey_positions" PRIMARY KEY ("id"),
  CONSTRAINT "uq_journey_positions_sample" UNIQUE ("journey_id", "sample_id"),
  CONSTRAINT "fk_journey_positions_journey" FOREIGN KEY ("journey_id") REFERENCES "journeys"("id") ON DELETE CASCADE,
  CONSTRAINT "ck_journey_positions_latitude" CHECK ("latitude" BETWEEN -90 AND 90),
  CONSTRAINT "ck_journey_positions_longitude" CHECK ("longitude" BETWEEN -180 AND 180),
  CONSTRAINT "ck_journey_positions_accuracy" CHECK ("accuracy_metres" >= 0)
);

CREATE INDEX "ix_journey_positions_journey_time" ON "journey_positions" ("journey_id", "device_timestamp");
CREATE INDEX "ix_journey_positions_received" ON "journey_positions" ("received_at");

CREATE TABLE "collection_reports" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "request_id" uuid NOT NULL,
  "reported_by_provider_id" uuid NOT NULL,
  "reported_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "pk_collection_reports" PRIMARY KEY ("id"),
  CONSTRAINT "uq_collection_reports_request" UNIQUE ("request_id"),
  CONSTRAINT "fk_collection_reports_request" FOREIGN KEY ("request_id") REFERENCES "service_requests"("id") ON DELETE CASCADE,
  CONSTRAINT "fk_collection_reports_provider" FOREIGN KEY ("reported_by_provider_id") REFERENCES "users"("id") ON DELETE RESTRICT
);

CREATE TABLE "service_feedback" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "request_id" uuid NOT NULL,
  "submitted_by_user_id" uuid,
  "outcome" "collection_outcome" NOT NULL,
  "feedback" varchar(2000) NOT NULL,
  "rating" integer NOT NULL,
  "waste_collected" boolean NOT NULL,
  "submitted_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "pk_service_feedback" PRIMARY KEY ("id"),
  CONSTRAINT "uq_service_feedback_request" UNIQUE ("request_id"),
  CONSTRAINT "fk_service_feedback_request" FOREIGN KEY ("request_id") REFERENCES "service_requests"("id") ON DELETE CASCADE,
  CONSTRAINT "fk_service_feedback_submitter" FOREIGN KEY ("submitted_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT,
  CONSTRAINT "ck_service_feedback_rating" CHECK ("rating" BETWEEN 1 AND 5),
  CONSTRAINT "ck_service_feedback_waste" CHECK (
    ("outcome" IN ('COMPLETED', 'LEFT_INCOMPLETE') AND "waste_collected" = true)
    OR ("outcome" = 'NOT_DONE_AT_ALL' AND "waste_collected" = false)
  )
);

CREATE TABLE "follow_up_cases" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "request_id" uuid NOT NULL,
  "status" "follow_up_status" NOT NULL DEFAULT 'OPEN',
  "outcome" "collection_outcome" NOT NULL,
  "opened_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "resolved_at" timestamptz(3),
  "resolution" varchar(1000),
  CONSTRAINT "pk_follow_up_cases" PRIMARY KEY ("id"),
  CONSTRAINT "uq_follow_up_cases_request" UNIQUE ("request_id"),
  CONSTRAINT "fk_follow_up_cases_request" FOREIGN KEY ("request_id") REFERENCES "service_requests"("id") ON DELETE CASCADE,
  CONSTRAINT "ck_follow_up_cases_negative" CHECK ("outcome" IN ('LEFT_INCOMPLETE', 'NOT_DONE_AT_ALL')),
  CONSTRAINT "ck_follow_up_cases_resolution" CHECK (
    ("status" = 'OPEN' AND "resolved_at" IS NULL AND "resolution" IS NULL)
    OR ("status" = 'RESOLVED' AND "resolved_at" IS NOT NULL AND "resolution" IS NOT NULL)
  )
);

CREATE INDEX "ix_follow_up_cases_status_opened" ON "follow_up_cases" ("status", "opened_at");

CREATE TABLE "disposal_sites" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar(200) NOT NULL,
  "address" varchar(500) NOT NULL,
  "latitude" decimal(9,6) NOT NULL,
  "longitude" decimal(9,6) NOT NULL,
  "active" boolean NOT NULL DEFAULT true,
  "approved_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "created_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "pk_disposal_sites" PRIMARY KEY ("id"),
  CONSTRAINT "ck_disposal_sites_latitude" CHECK ("latitude" BETWEEN -90 AND 90),
  CONSTRAINT "ck_disposal_sites_longitude" CHECK ("longitude" BETWEEN -180 AND 180)
);

CREATE INDEX "ix_disposal_sites_active_name" ON "disposal_sites" ("active", "name");

CREATE TABLE "disposal_assignments" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "request_id" uuid NOT NULL,
  "disposal_site_id" uuid NOT NULL,
  "assigned_by_user_id" uuid NOT NULL,
  "assigned_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "pk_disposal_assignments" PRIMARY KEY ("id"),
  CONSTRAINT "uq_disposal_assignments_request" UNIQUE ("request_id"),
  CONSTRAINT "fk_disposal_assignments_request" FOREIGN KEY ("request_id") REFERENCES "service_requests"("id") ON DELETE CASCADE,
  CONSTRAINT "fk_disposal_assignments_site" FOREIGN KEY ("disposal_site_id") REFERENCES "disposal_sites"("id") ON DELETE RESTRICT,
  CONSTRAINT "fk_disposal_assignments_actor" FOREIGN KEY ("assigned_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT
);

CREATE TABLE "operational_notifications" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "recipient_user_id" uuid NOT NULL,
  "request_id" uuid,
  "type" "operational_notification_type" NOT NULL,
  "title" varchar(200) NOT NULL,
  "message" varchar(1000) NOT NULL,
  "created_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "read_at" timestamptz(3),
  CONSTRAINT "pk_operational_notifications" PRIMARY KEY ("id"),
  CONSTRAINT "fk_operational_notifications_recipient" FOREIGN KEY ("recipient_user_id") REFERENCES "users"("id") ON DELETE CASCADE,
  CONSTRAINT "fk_operational_notifications_request" FOREIGN KEY ("request_id") REFERENCES "service_requests"("id") ON DELETE CASCADE
);

CREATE INDEX "ix_operational_notifications_recipient_created" ON "operational_notifications" ("recipient_user_id", "created_at");

CREATE TABLE "outbox_events" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "request_id" uuid,
  "recipient_user_id" uuid,
  "channel" "notification_delivery_channel" NOT NULL,
  "event_type" "operational_notification_type" NOT NULL,
  "deduplication_key" varchar(200) NOT NULL,
  "payload" jsonb NOT NULL,
  "status" "outbox_status" NOT NULL DEFAULT 'PENDING',
  "attempts" integer NOT NULL DEFAULT 0,
  "next_attempt_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "delivered_at" timestamptz(3),
  "last_error_code" varchar(100),
  "created_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "pk_outbox_events" PRIMARY KEY ("id"),
  CONSTRAINT "uq_outbox_events_deduplication" UNIQUE ("deduplication_key"),
  CONSTRAINT "fk_outbox_events_request" FOREIGN KEY ("request_id") REFERENCES "service_requests"("id") ON DELETE CASCADE,
  CONSTRAINT "ck_outbox_events_attempts" CHECK ("attempts" >= 0)
);

CREATE INDEX "ix_outbox_events_status_next" ON "outbox_events" ("status", "next_attempt_at");

CREATE TABLE "idempotency_records" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "actor_user_id" uuid NOT NULL,
  "operation" varchar(100) NOT NULL,
  "key" varchar(100) NOT NULL,
  "fingerprint" varchar(64) NOT NULL,
  "response" jsonb NOT NULL,
  "created_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "expires_at" timestamptz(3) NOT NULL,
  CONSTRAINT "pk_idempotency_records" PRIMARY KEY ("id"),
  CONSTRAINT "uq_idempotency_actor_operation_key" UNIQUE ("actor_user_id", "operation", "key"),
  CONSTRAINT "ck_idempotency_records_expiry" CHECK ("expires_at" > "created_at")
);

CREATE INDEX "ix_idempotency_records_expiry" ON "idempotency_records" ("expires_at");

CREATE TABLE "audit_events" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "actor_user_id" uuid,
  "action" varchar(100) NOT NULL,
  "target_type" varchar(100) NOT NULL,
  "target_id" uuid NOT NULL,
  "request_id" uuid,
  "metadata" jsonb,
  "created_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "pk_audit_events" PRIMARY KEY ("id"),
  CONSTRAINT "fk_audit_events_actor" FOREIGN KEY ("actor_user_id") REFERENCES "users"("id") ON DELETE RESTRICT
);

CREATE INDEX "ix_audit_events_target_created" ON "audit_events" ("target_type", "target_id", "created_at");
