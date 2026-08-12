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
  providerNumber?: string;
  providerRejectionReason?: string;
}

export interface SignInRequestContract {
  email: string;
  password: string;
}

export enum ClientType {
  individual = "INDIVIDUAL",
  organization = "ORGANIZATION",
}

export enum ServiceProviderType {
  gulper = "GULPER",
  emptier = "EMPTIER",
}

export interface ClientRegistrationRequestContract {
  clientType: ClientType;
  firstName?: string;
  lastName?: string;
  organizationName?: string;
  phoneNumber: string;
  email?: string;
  contactPersonName?: string;
  contactPersonPhone?: string;
}

export interface ServiceProviderRegistrationRequestContract {
  essLicenseNumber: string;
  companyName: string;
  phoneNumber: string;
  email: string;
  password: string;
  workAddress: string;
  providerType: ServiceProviderType;
  contactPersonName: string;
  contactPersonPhone: string;
}

export interface PhoneChallengeContract {
  challengeId: string;
  maskedPhone: string;
  expiresAt: string;
  resendAvailableAt: string;
  deliveryStatus: PhoneCodeDeliveryStatus;
}

export enum PhoneCodeDeliveryStatus {
  sent = "SENT",
  failed = "FAILED",
}

export interface VerifyPhoneCodeRequestContract {
  challengeId: string;
  code: string;
}

export interface ResendPhoneCodeRequestContract {
  challengeId: string;
}

export interface ClientCodeRequestContract {
  phoneNumber: string;
}

export enum ProviderApprovalDecision {
  approved = "APPROVED",
  rejected = "REJECTED",
}

export interface ProviderApprovalRequestContract {
  decision: ProviderApprovalDecision;
  reason?: string;
}

export interface ProviderRegistrationStatusContract {
  status: ProviderStatus;
  providerNumber?: string;
  rejectionReason?: string;
}

export interface PendingProviderRegistrationContract {
  providerUserId: string;
  essLicenseNumber: string;
  companyName: string;
  phoneNumber: string;
  email: string;
  workAddress: string;
  providerType: ServiceProviderType;
  contactPersonName: string;
  contactPersonPhone: string;
  submittedAt: string;
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
  invalidVerificationCode = "AUTH_INVALID_VERIFICATION_CODE",
  verificationExpired = "AUTH_VERIFICATION_EXPIRED",
  rateLimited = "AUTH_RATE_LIMITED",
  profileUnavailable = "AUTH_PROFILE_UNAVAILABLE",
  accessDenied = "AUTH_ACCESS_DENIED",
  invalidRequest = "INVALID_REQUEST",
  conflict = "CONFLICT",
  dependencyUnavailable = "DEPENDENCY_UNAVAILABLE",
  requestTimeout = "REQUEST_TIMEOUT",
  unexpected = "UNEXPECTED_ERROR",
}

export interface ApiErrorContract {
  code: ApiErrorCode;
  message: string;
  requestId?: string;
}
