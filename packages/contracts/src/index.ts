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

export interface SignInRequestContract {
  email: string;
  password: string;
}

export interface RefreshRequestContract {
  refreshToken: string;
}

export interface SessionCredentialsContract {
  accessToken: string;
  refreshToken: string;
  accessTokenExpiresAt: string;
  refreshTokenExpiresAt: string;
}

export interface SignOutContract {
  signedOut: true;
}

export enum ApiErrorCode {
  authenticationRequired = "AUTHENTICATION_REQUIRED",
  invalidToken = "AUTH_INVALID_TOKEN",
  invalidCredentials = "AUTH_INVALID_CREDENTIALS",
  invalidSession = "AUTH_INVALID_SESSION",
  rateLimited = "AUTH_RATE_LIMITED",
  profileUnavailable = "AUTH_PROFILE_UNAVAILABLE",
  accessDenied = "AUTH_ACCESS_DENIED",
  invalidRequest = "INVALID_REQUEST",
  dependencyUnavailable = "DEPENDENCY_UNAVAILABLE",
  requestTimeout = "REQUEST_TIMEOUT",
  unexpected = "UNEXPECTED_ERROR",
}

export interface ApiErrorContract {
  code: ApiErrorCode;
  message: string;
  requestId?: string;
}
