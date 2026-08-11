import { DataSource } from "typeorm";

import { CreateActorProfiles1786397000000 } from "../src/database/migrations/1786397000000-create-actor-profiles";

const describeExternal =
  process.env.RUN_EXTERNAL_INTEGRATION === "true" ? describe : describe.skip;

describeExternal("pinned CI identity and persistence services", () => {
  jest.setTimeout(30_000);

  it("exposes the configured Keycloak realm discovery and signing keys", async () => {
    const issuer = requiredEnvironment("KEYCLOAK_ISSUER");
    const discoveryResponse = await fetch(
      `${issuer}/.well-known/openid-configuration`,
    );
    expect(discoveryResponse.status).toBe(200);
    const discovery = (await discoveryResponse.json()) as {
      issuer: string;
      jwks_uri: string;
      code_challenge_methods_supported?: string[];
    };
    expect(discovery.issuer).toBe(issuer);
    expect(discovery.code_challenge_methods_supported).toContain("S256");

    const jwksResponse = await fetch(discovery.jwks_uri);
    expect(jwksResponse.status).toBe(200);
    const jwks = (await jwksResponse.json()) as { keys: unknown[] };
    expect(jwks.keys.length).toBeGreaterThan(0);
  });

  it("applies and reverses the actor-profile migration on PostgreSQL", async () => {
    const dataSource = new DataSource({
      type: "postgres",
      host: requiredEnvironment("DATABASE_HOST"),
      port: Number(requiredEnvironment("DATABASE_PORT")),
      database: requiredEnvironment("DATABASE_NAME"),
      username: requiredEnvironment("DATABASE_USER"),
      password: requiredEnvironment("DATABASE_PASSWORD"),
      migrations: [CreateActorProfiles1786397000000],
      synchronize: false,
      logging: false,
    });
    await dataSource.initialize();
    try {
      await dataSource.runMigrations({ transaction: "all" });
      await expect(
        dataSource.query(
          `INSERT INTO actor_profiles
             (keycloak_subject, actor_type, provider_status, is_active, mobile_monitoring_permitted)
           VALUES ($1, 'SERVICE_PROVIDER', NULL, true, false)`,
          ["provider-without-status"],
        ),
      ).rejects.toBeDefined();

      await dataSource.query(
        `INSERT INTO actor_profiles
           (keycloak_subject, actor_type, provider_status, is_active, mobile_monitoring_permitted)
         VALUES ($1, 'CLIENT', NULL, true, false)`,
        ["unique-subject"],
      );
      await expect(
        dataSource.query(
          `INSERT INTO actor_profiles
             (keycloak_subject, actor_type, provider_status, is_active, mobile_monitoring_permitted)
           VALUES ($1, 'CLIENT', NULL, true, false)`,
          ["unique-subject"],
        ),
      ).rejects.toBeDefined();

      await dataSource.undoLastMigration({ transaction: "all" });
      const table = (await dataSource.query(
        "SELECT to_regclass('public.actor_profiles') AS name",
      )) as Array<{ name: string | null }>;
      expect(table[0]?.name).toBeNull();
    } finally {
      if (dataSource.isInitialized) await dataSource.destroy();
    }
  });
});

function requiredEnvironment(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing integration configuration: ${name}`);
  return value;
}
