import { readFileSync } from "node:fs";
import { resolve } from "node:path";

describe("Prisma native-authentication migration", () => {
  const sql = readFileSync(
    resolve(
      __dirname,
      "../prisma/migrations/20260811130000_native_authentication/migration.sql",
    ),
    "utf8",
  );

  it("contains durable authentication tables and fail-closed constraints", () => {
    expect(sql).toContain('CREATE TABLE "users"');
    expect(sql).toContain('CREATE TABLE "authentication_sessions"');
    expect(sql).toContain('CREATE TABLE "refresh_tokens"');
    expect(sql).toContain('CREATE TABLE "login_throttles"');
    expect(sql).toContain("ck_users_provider_status");
    expect(sql).toContain("ck_users_mobile_monitoring");
    expect(sql).toContain("uq_users_email_lookup");
    expect(sql).not.toMatch(/keycloak|actor_profiles/i);
  });
});

describe("Prisma registration and phone-authentication migration", () => {
  const sql = readFileSync(
    resolve(
      __dirname,
      "../prisma/migrations/20260812150000_registration_phone_auth/migration.sql",
    ),
    "utf8",
  );

  it("adds durable registration, OTP, approval, and notification records", () => {
    expect(sql).toContain('CREATE TABLE "client_profiles"');
    expect(sql).toContain('CREATE TABLE "service_provider_profiles"');
    expect(sql).toContain('CREATE TABLE "phone_challenges"');
    expect(sql).toContain('CREATE TABLE "provider_approval_decisions"');
    expect(sql).toContain('CREATE TABLE "registration_notifications"');
    expect(sql).toContain("ck_users_email_pair");
    expect(sql).toContain("ck_users_phone_pair");
    expect(sql).toContain("ck_phone_challenges_attempts");
    expect(sql).toContain("uq_users_phone_lookup");
    expect(sql).not.toMatch(/plaintext_(phone|code|password)/i);
  });
});

describe("Prisma service workflow migration", () => {
  const sql = readFileSync(
    resolve(
      __dirname,
      "../prisma/migrations/20260819120000_service_workflows/migration.sql",
    ),
    "utf8",
  );

  it("enforces workflow ownership, scheduling, UGX, feedback, and location invariants", () => {
    expect(sql).toContain('CREATE TABLE "service_requests"');
    expect(sql).toContain('CREATE TABLE "journey_positions"');
    expect(sql).toContain('CREATE TABLE "service_feedback"');
    expect(sql).toContain('CREATE TABLE "follow_up_cases"');
    expect(sql).toContain('CREATE TABLE "disposal_assignments"');
    expect(sql).toContain('CREATE TABLE "outbox_events"');
    expect(sql).toContain('CREATE TABLE "idempotency_records"');
    expect(sql).toContain("ck_users_call_centre_operations");
    expect(sql).toContain("ck_service_requests_schedule");
    expect(sql).toContain("ck_service_requests_price");
    expect(sql).toContain("ck_service_feedback_rating");
    expect(sql).toContain("ck_service_feedback_waste");
    expect(sql).toContain("uq_request_assignments_active");
    expect(sql).toContain("uq_journey_positions_sample");
  });
});

describe("Prisma reliable delivery migration", () => {
  const sql = readFileSync(
    resolve(
      __dirname,
      "../prisma/migrations/20260820110000_reliable_delivery_foundation/migration.sql",
    ),
    "utf8",
  );

  it("adds leased claims, dead letters, and immutable delivery attempts", () => {
    expect(sql).toContain('ADD COLUMN "claim_expires_at"');
    expect(sql).toContain('ADD COLUMN "claim_token"');
    expect(sql).toContain('CREATE TABLE "delivery_attempts"');
    expect(sql).toContain("uq_delivery_attempts_event_number");
    expect(sql).toContain("ck_delivery_attempts_result");
    expect(sql).toContain("DEAD_LETTER");
  });
});

describe("Prisma account recovery and email verification migration", () => {
  const sql = readFileSync(
    resolve(
      __dirname,
      "../prisma/migrations/20260820130000_account_recovery_verification/migration.sql",
    ),
    "utf8",
  );

  it("stores only challenge hashes and immutable security events", () => {
    expect(sql).toContain('CREATE TABLE "account_challenges"');
    expect(sql).toContain('CREATE TABLE "security_events"');
    expect(sql).toContain("uq_account_challenges_active");
    expect(sql).toContain("ck_account_challenges_attempts");
    expect(sql).toContain('"secret_hash"');
    expect(sql).not.toMatch(/plaintext|verification_code|password_value/i);
  });
});

describe("Prisma KCCA administration and integration migration", () => {
  const sql = readFileSync(
    resolve(
      __dirname,
      "../prisma/migrations/20260820150000_kcca_administration_history/migration.sql",
    ),
    "utf8",
  );

  it("adds immutable histories, protected device installations, and notification deduplication", () => {
    expect(sql).toContain('CREATE TABLE "provider_status_history"');
    expect(sql).toContain('CREATE TABLE "disposal_assignment_history"');
    expect(sql).toContain('CREATE TABLE "device_installations"');
    expect(sql).toContain("uq_device_installations_token_lookup");
    expect(sql).toContain("uq_operational_notifications_source_outbox");
    expect(sql).not.toMatch(/plaintext.*token/i);
  });
});
