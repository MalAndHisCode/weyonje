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
