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
    mobileMonitoringPermitted: boolean;
    passwordVersion: number;
  };
}
