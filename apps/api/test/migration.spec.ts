import { QueryRunner } from "typeorm";

import { CreateActorProfiles1786397000000 } from "../src/database/migrations/1786397000000-create-actor-profiles";

describe("actor profile migration", () => {
  it("creates unique subject and provider-status constraints and reverses cleanly", async () => {
    const statements: string[] = [];
    const runner = {
      query: jest.fn(async (sql: string) => statements.push(sql)),
    } as unknown as QueryRunner;
    const migration = new CreateActorProfiles1786397000000();
    await migration.up(runner);
    expect(statements.join("\n")).toContain(
      "uq_actor_profiles_keycloak_subject",
    );
    expect(statements.join("\n")).toContain(
      "ck_actor_profiles_provider_status",
    );

    statements.length = 0;
    await migration.down(runner);
    expect(statements).toEqual([
      'DROP TABLE "actor_profiles"',
      'DROP TYPE "provider_status"',
      'DROP TYPE "actor_type"',
    ]);
  });
});
