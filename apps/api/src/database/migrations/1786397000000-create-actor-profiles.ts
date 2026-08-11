import { MigrationInterface, QueryRunner } from "typeorm";

export class CreateActorProfiles1786397000000 implements MigrationInterface {
  name = "CreateActorProfiles1786397000000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `CREATE TYPE "actor_type" AS ENUM ('CLIENT', 'SERVICE_PROVIDER', 'KCCA_STAFF')`,
    );
    await queryRunner.query(
      `CREATE TYPE "provider_status" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'INACTIVE', 'DISABLED')`,
    );
    await queryRunner.query(`
      CREATE TABLE "actor_profiles" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "keycloak_subject" varchar(255) NOT NULL,
        "actor_type" "actor_type" NOT NULL,
        "provider_status" "provider_status",
        "is_active" boolean NOT NULL DEFAULT true,
        "mobile_monitoring_permitted" boolean NOT NULL DEFAULT false,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "pk_actor_profiles" PRIMARY KEY ("id"),
        CONSTRAINT "uq_actor_profiles_keycloak_subject" UNIQUE ("keycloak_subject"),
        CONSTRAINT "ck_actor_profiles_provider_status" CHECK (
          ("actor_type" = 'SERVICE_PROVIDER' AND "provider_status" IS NOT NULL)
          OR ("actor_type" <> 'SERVICE_PROVIDER' AND "provider_status" IS NULL)
        )
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "ix_actor_profiles_actor_type" ON "actor_profiles" ("actor_type")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "actor_profiles"`);
    await queryRunner.query(`DROP TYPE "provider_status"`);
    await queryRunner.query(`DROP TYPE "actor_type"`);
  }
}
