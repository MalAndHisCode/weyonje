import { ActorType, ProviderStatus } from "../generated/prisma/enums";

export interface AuthenticatedActor {
  sessionId: string;
  user: {
    id: string;
    actorType: ActorType;
    providerStatus: ProviderStatus | null;
    isActive: boolean;
    loginEnabled: boolean;
    emailVerifiedAt: Date | null;
    phoneVerifiedAt: Date | null;
    mobileMonitoringPermitted: boolean;
    providerApprovalPermitted: boolean;
    callCentreOperationsPermitted: boolean;
    passwordVersion: number;
    serviceProviderProfile: {
      providerNumber: string | null;
      latestRejectionReason: string | null;
    } | null;
  };
}
