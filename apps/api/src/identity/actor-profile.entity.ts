import { ActorType, ProviderStatus } from "@weyonje/contracts";
import {
  Check,
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from "typeorm";

@Entity({ name: "actor_profiles" })
@Check(
  "ck_actor_profiles_provider_status",
  `("actor_type" = 'SERVICE_PROVIDER' AND "provider_status" IS NOT NULL) OR ("actor_type" <> 'SERVICE_PROVIDER' AND "provider_status" IS NULL)`,
)
export class ActorProfileEntity {
  @PrimaryGeneratedColumn("uuid")
  id!: string;

  @Index("uq_actor_profiles_keycloak_subject", { unique: true })
  @Column({ name: "keycloak_subject", type: "varchar", length: 255 })
  keycloakSubject!: string;

  @Index("ix_actor_profiles_actor_type")
  @Column({
    name: "actor_type",
    type: "enum",
    enum: ActorType,
    enumName: "actor_type",
  })
  actorType!: ActorType;

  @Column({
    name: "provider_status",
    type: "enum",
    enum: ProviderStatus,
    enumName: "provider_status",
    nullable: true,
  })
  providerStatus!: ProviderStatus | null;

  @Column({ name: "is_active", type: "boolean", default: true })
  isActive!: boolean;

  @Column({
    name: "mobile_monitoring_permitted",
    type: "boolean",
    default: false,
  })
  mobileMonitoringPermitted!: boolean;

  @CreateDateColumn({ name: "created_at", type: "timestamptz" })
  createdAt!: Date;

  @UpdateDateColumn({ name: "updated_at", type: "timestamptz" })
  updatedAt!: Date;
}
