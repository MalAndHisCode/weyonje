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
