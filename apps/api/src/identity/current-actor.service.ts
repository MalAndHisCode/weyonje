import { ForbiddenException, Injectable } from "@nestjs/common";
import {
  ActorAccess,
  ActorType,
  ApiErrorCode,
  CurrentActorContract,
  ProviderStatus,
} from "@weyonje/contracts";

import { AuthenticatedActor } from "../auth/authenticated-actor";

@Injectable()
export class CurrentActorService {
  resolve(actor: AuthenticatedActor): CurrentActorContract {
    const user = actor.user;
    switch (user.actorType as string) {
      case ActorType.client:
        if (
          user.providerStatus !== null ||
          user.mobileMonitoringPermitted ||
          user.serviceProviderProfile !== null
        ) {
          throw this.inconsistent();
        }
        return {
          actorType: ActorType.client,
          access: user.isActive ? ActorAccess.eligible : ActorAccess.denied,
          emailVerified: user.emailVerifiedAt !== null,
        };
      case ActorType.serviceProvider:
        if (
          user.providerStatus === null ||
          user.mobileMonitoringPermitted ||
          !Object.values(ProviderStatus).includes(
            user.providerStatus as ProviderStatus,
          ) ||
          user.serviceProviderProfile === null
        ) {
          throw this.inconsistent();
        }
        return {
          actorType: ActorType.serviceProvider,
          emailVerified: user.emailVerifiedAt !== null,
          access:
            user.isActive && user.providerStatus === ProviderStatus.approved
              ? ActorAccess.eligible
              : ActorAccess.restricted,
          providerStatus: user.providerStatus as ProviderStatus,
          ...(user.serviceProviderProfile.providerNumber
            ? { providerNumber: user.serviceProviderProfile.providerNumber }
            : {}),
          ...(user.serviceProviderProfile.latestRejectionReason
            ? {
                providerRejectionReason:
                  user.serviceProviderProfile.latestRejectionReason,
              }
            : {}),
        };
      case ActorType.kccaStaff:
        if (
          user.providerStatus !== null ||
          user.serviceProviderProfile !== null
        ) {
          throw this.inconsistent();
        }
        return {
          actorType: ActorType.kccaStaff,
          emailVerified: user.emailVerifiedAt !== null,
          access:
            user.isActive &&
            (user.mobileMonitoringPermitted ||
              user.providerApprovalPermitted ||
              user.callCentreOperationsPermitted)
              ? ActorAccess.eligible
              : ActorAccess.denied,
          mobileMonitoringPermitted: user.mobileMonitoringPermitted,
          providerApprovalPermitted: user.providerApprovalPermitted,
          callCentreOperationsPermitted: user.callCentreOperationsPermitted,
        };
      default:
        throw this.inconsistent();
    }
  }

  private inconsistent(): ForbiddenException {
    return new ForbiddenException({
      code: ApiErrorCode.accessDenied,
      message: "This account cannot access Weyonje mobile services.",
    });
  }
}
