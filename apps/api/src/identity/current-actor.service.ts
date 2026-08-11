import { ForbiddenException, Inject, Injectable } from "@nestjs/common";
import { ConfigType } from "@nestjs/config";
import { InjectRepository } from "@nestjs/typeorm";
import {
  ActorAccess,
  ActorType,
  ApiErrorCode,
  CurrentActorContract,
  ProviderStatus,
} from "@weyonje/contracts";
import { Repository } from "typeorm";

import { identityConfig } from "../config/identity.config";
import { ActorProfileEntity } from "./actor-profile.entity";
import { AuthenticatedIdentity } from "./authenticated-identity";

@Injectable()
export class CurrentActorService {
  constructor(
    @InjectRepository(ActorProfileEntity)
    private readonly profiles: Repository<ActorProfileEntity>,
    @Inject(identityConfig.KEY)
    private readonly config: ConfigType<typeof identityConfig>,
  ) {}

  async resolve(
    identity: AuthenticatedIdentity,
  ): Promise<CurrentActorContract> {
    const profile = await this.profiles.findOne({
      where: { keycloakSubject: identity.subject },
      select: {
        actorType: true,
        providerStatus: true,
        isActive: true,
        mobileMonitoringPermitted: true,
      },
    });

    if (!profile) {
      throw this.forbidden(
        ApiErrorCode.profileUnavailable,
        "This identity is not linked to a Weyonje mobile profile.",
      );
    }

    switch (profile.actorType) {
      case ActorType.client:
        this.requireRole(identity, this.config.roles.client);
        return {
          actorType: ActorType.client,
          access: profile.isActive ? ActorAccess.eligible : ActorAccess.denied,
        };
      case ActorType.serviceProvider:
        this.requireRole(identity, this.config.roles.provider);
        if (!profile.providerStatus) {
          throw this.forbidden(
            ApiErrorCode.accessDenied,
            "This account cannot access Weyonje mobile services.",
          );
        }
        return {
          actorType: ActorType.serviceProvider,
          access:
            profile.isActive &&
            profile.providerStatus === ProviderStatus.approved
              ? ActorAccess.eligible
              : ActorAccess.restricted,
          providerStatus: profile.providerStatus,
        };
      case ActorType.kccaStaff:
        this.requireRole(identity, this.config.roles.kccaMobile);
        return {
          actorType: ActorType.kccaStaff,
          access:
            profile.isActive && profile.mobileMonitoringPermitted
              ? ActorAccess.eligible
              : ActorAccess.denied,
        };
      default:
        throw this.forbidden(
          ApiErrorCode.accessDenied,
          "This account cannot access Weyonje mobile services.",
        );
    }
  }

  private requireRole(identity: AuthenticatedIdentity, role: string): void {
    if (!identity.roles.has(role)) {
      throw this.forbidden(
        ApiErrorCode.accessDenied,
        "This account cannot access Weyonje mobile services.",
      );
    }
  }

  private forbidden(code: ApiErrorCode, message: string): ForbiddenException {
    return new ForbiddenException({ code, message });
  }
}
