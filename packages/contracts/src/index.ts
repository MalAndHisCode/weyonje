export enum ActorType {
  client = "CLIENT",
  serviceProvider = "SERVICE_PROVIDER",
  kccaStaff = "KCCA_STAFF",
}

export enum ActorAccess {
  eligible = "ELIGIBLE",
  restricted = "RESTRICTED",
  denied = "DENIED",
}

export enum ProviderStatus {
  pending = "PENDING",
  approved = "APPROVED",
  rejected = "REJECTED",
  inactive = "INACTIVE",
  disabled = "DISABLED",
}

export interface CurrentActorContract {
  actorType: ActorType;
  access: ActorAccess;
  providerStatus?: ProviderStatus;
}

export enum ApiErrorCode {
  authenticationRequired = "AUTHENTICATION_REQUIRED",
  invalidToken = "AUTH_INVALID_TOKEN",
  profileUnavailable = "AUTH_PROFILE_UNAVAILABLE",
  accessDenied = "AUTH_ACCESS_DENIED",
  dependencyUnavailable = "DEPENDENCY_UNAVAILABLE",
  requestTimeout = "REQUEST_TIMEOUT",
  unexpected = "UNEXPECTED_ERROR",
}

export interface ApiErrorContract {
  code: ApiErrorCode;
  message: string;
  requestId?: string;
}
