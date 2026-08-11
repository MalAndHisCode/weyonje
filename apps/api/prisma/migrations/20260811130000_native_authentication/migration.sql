CREATE TYPE "actor_type" AS ENUM ('CLIENT', 'SERVICE_PROVIDER', 'KCCA_STAFF');
CREATE TYPE "provider_status" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'INACTIVE', 'DISABLED');
CREATE TYPE "throttle_scope" AS ENUM ('EMAIL', 'IP');

CREATE TABLE "users" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "encrypted_email" varchar(1024) NOT NULL,
  "email_lookup" varchar(64) NOT NULL,
  "password_hash" varchar(512) NOT NULL,
  "actor_type" "actor_type" NOT NULL,
  "provider_status" "provider_status",
  "is_active" boolean NOT NULL DEFAULT true,
  "login_enabled" boolean NOT NULL DEFAULT true,
  "email_verified_at" timestamptz(3),
  "mobile_monitoring_permitted" boolean NOT NULL DEFAULT false,
  "password_changed_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "password_version" integer NOT NULL DEFAULT 1,
  "failed_login_count" integer NOT NULL DEFAULT 0,
  "authentication_locked_until" timestamptz(3),
  "created_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "pk_users" PRIMARY KEY ("id"),
  CONSTRAINT "uq_users_email_lookup" UNIQUE ("email_lookup"),
  CONSTRAINT "ck_users_provider_status" CHECK (
    ("actor_type" = 'SERVICE_PROVIDER' AND "provider_status" IS NOT NULL)
    OR ("actor_type" <> 'SERVICE_PROVIDER' AND "provider_status" IS NULL)
  ),
  CONSTRAINT "ck_users_mobile_monitoring" CHECK (
    "actor_type" = 'KCCA_STAFF' OR "mobile_monitoring_permitted" = false
  ),
  CONSTRAINT "ck_users_password_version" CHECK ("password_version" > 0),
  CONSTRAINT "ck_users_failed_login_count" CHECK ("failed_login_count" >= 0)
);

CREATE INDEX "ix_users_actor_type" ON "users" ("actor_type");

CREATE TABLE "authentication_sessions" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "family_id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "created_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "last_used_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "absolute_expires_at" timestamptz(3) NOT NULL,
  "revoked_at" timestamptz(3),
  "revocation_reason" varchar(64),
  "password_version" integer NOT NULL,
  CONSTRAINT "pk_authentication_sessions" PRIMARY KEY ("id"),
  CONSTRAINT "fk_authentication_sessions_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE,
  CONSTRAINT "ck_authentication_sessions_expiry" CHECK ("absolute_expires_at" > "created_at"),
  CONSTRAINT "ck_authentication_sessions_password_version" CHECK ("password_version" > 0)
);

CREATE INDEX "ix_authentication_sessions_user_id" ON "authentication_sessions" ("user_id");
CREATE INDEX "ix_authentication_sessions_family_id" ON "authentication_sessions" ("family_id");
CREATE INDEX "ix_authentication_sessions_expiry" ON "authentication_sessions" ("absolute_expires_at");

CREATE TABLE "refresh_tokens" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "session_id" uuid NOT NULL,
  "token_hash" varchar(64) NOT NULL,
  "created_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "expires_at" timestamptz(3) NOT NULL,
  "used_at" timestamptz(3),
  "revoked_at" timestamptz(3),
  "replaced_by_id" uuid,
  CONSTRAINT "pk_refresh_tokens" PRIMARY KEY ("id"),
  CONSTRAINT "uq_refresh_tokens_token_hash" UNIQUE ("token_hash"),
  CONSTRAINT "uq_refresh_tokens_replaced_by" UNIQUE ("replaced_by_id"),
  CONSTRAINT "fk_refresh_tokens_session" FOREIGN KEY ("session_id") REFERENCES "authentication_sessions"("id") ON DELETE CASCADE,
  CONSTRAINT "fk_refresh_tokens_replacement" FOREIGN KEY ("replaced_by_id") REFERENCES "refresh_tokens"("id") ON DELETE SET NULL,
  CONSTRAINT "ck_refresh_tokens_expiry" CHECK ("expires_at" > "created_at"),
  CONSTRAINT "ck_refresh_tokens_replacement" CHECK ("replaced_by_id" IS NULL OR "replaced_by_id" <> "id")
);

CREATE INDEX "ix_refresh_tokens_session_id" ON "refresh_tokens" ("session_id");
CREATE INDEX "ix_refresh_tokens_expiry" ON "refresh_tokens" ("expires_at");

CREATE TABLE "login_throttles" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "scope" "throttle_scope" NOT NULL,
  "key_hash" varchar(64) NOT NULL,
  "failed_attempts" integer NOT NULL DEFAULT 0,
  "window_started_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "locked_until" timestamptz(3),
  "expires_at" timestamptz(3) NOT NULL,
  "updated_at" timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "pk_login_throttles" PRIMARY KEY ("id"),
  CONSTRAINT "uq_login_throttles_scope_key" UNIQUE ("scope", "key_hash"),
  CONSTRAINT "ck_login_throttles_failed_attempts" CHECK ("failed_attempts" >= 0),
  CONSTRAINT "ck_login_throttles_expiry" CHECK ("expires_at" >= "window_started_at")
);

CREATE INDEX "ix_login_throttles_expiry" ON "login_throttles" ("expires_at");
