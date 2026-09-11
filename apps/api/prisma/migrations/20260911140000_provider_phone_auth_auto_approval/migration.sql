ALTER TYPE "phone_challenge_purpose" ADD VALUE 'PROVIDER_SIGN_IN';
ALTER TABLE "provider_approval_decisions" ALTER COLUMN "decided_by_user_id" DROP NOT NULL,
  ADD COLUMN "provenance" VARCHAR(40) NOT NULL DEFAULT 'KCCA_MANUAL';
ALTER TABLE "provider_status_history" ALTER COLUMN "changed_by_user_id" DROP NOT NULL,
  ADD COLUMN "provenance" VARCHAR(40) NOT NULL DEFAULT 'KCCA_MANUAL';
ALTER TABLE "provider_approval_decisions" ADD CONSTRAINT "ck_provider_decision_provenance" CHECK (
  ("provenance" = 'KCCA_MANUAL' AND "decided_by_user_id" IS NOT NULL) OR
  ("provenance" = 'SYSTEM_REGISTRATION_POLICY' AND "decided_by_user_id" IS NULL AND "decision" = 'APPROVED'));
ALTER TABLE "provider_status_history" ADD CONSTRAINT "ck_provider_status_provenance" CHECK (
  ("provenance" = 'KCCA_MANUAL' AND "changed_by_user_id" IS NOT NULL) OR
  ("provenance" = 'SYSTEM_REGISTRATION_POLICY' AND "changed_by_user_id" IS NULL AND "from_status" = 'PENDING' AND "to_status" = 'APPROVED'));
