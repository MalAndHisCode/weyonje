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
  developmentVerificationCode?: string;
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
  requestNotFound = "REQUEST_NOT_FOUND",
  requestAlreadyAccepted = "REQUEST_ALREADY_ACCEPTED",
  invalidTransition = "INVALID_TRANSITION",
  idempotencyConflict = "IDEMPOTENCY_CONFLICT",
  locationUnavailable = "LOCATION_UNAVAILABLE",
  locationStale = "LOCATION_STALE",
}

export interface ApiErrorContract {
  code: ApiErrorCode;
  message: string;
  requestId?: string;
}

export enum ServiceRequestOrigin {
  mobileApp = "MOBILE_APP",
  callCentre = "CALL_CENTRE",
}

export enum ServiceRequestStatus {
  pending = "PENDING",
  accepted = "ACCEPTED",
  active = "ACTIVE",
  collectionReported = "COLLECTION_REPORTED",
  collectionCompleted = "COLLECTION_COMPLETED",
  followUpRequired = "FOLLOW_UP_REQUIRED",
  completed = "COMPLETED",
  cancelled = "CANCELLED",
}

export enum RequestLocationKind {
  current = "CURRENT",
  mapPin = "MAP_PIN",
  text = "TEXT",
}

export enum ToiletType {
  pitLatrine = "PIT_LATRINE",
  septicTank = "SEPTIC_TANK",
}

export enum ScheduleMode {
  asSoonAsPossible = "AS_SOON_AS_POSSIBLE",
  scheduled = "SCHEDULED",
}

export enum AssignmentStatus {
  pending = "PENDING",
  accepted = "ACCEPTED",
  rejected = "REJECTED",
  superseded = "SUPERSEDED",
}

export enum JourneyPhase {
  toRequest = "TO_REQUEST",
  toDisposal = "TO_DISPOSAL",
}

export enum JourneyStatus {
  ready = "READY",
  active = "ACTIVE",
  arrived = "ARRIVED",
  completed = "COMPLETED",
}

export enum CollectionOutcome {
  completed = "COMPLETED",
  leftIncomplete = "LEFT_INCOMPLETE",
  notDoneAtAll = "NOT_DONE_AT_ALL",
}

export enum FollowUpStatus {
  open = "OPEN",
  resolved = "RESOLVED",
}

export enum NotificationChannel {
  inApp = "IN_APP",
  sms = "SMS",
  push = "PUSH",
}

export enum OperationalNotificationType {
  providerReviewRequired = "PROVIDER_REVIEW_REQUIRED",
  providerApproved = "PROVIDER_APPROVED",
  providerRejected = "PROVIDER_REJECTED",
  requestCreated = "REQUEST_CREATED",
  requestAssigned = "REQUEST_ASSIGNED",
  requestAccepted = "REQUEST_ACCEPTED",
  requestRejected = "REQUEST_REJECTED",
  journeyStarted = "JOURNEY_STARTED",
  providerArrived = "PROVIDER_ARRIVED",
  collectionReported = "COLLECTION_REPORTED",
  collectionConfirmed = "COLLECTION_CONFIRMED",
  followUpRequired = "FOLLOW_UP_REQUIRED",
  disposalReady = "DISPOSAL_READY",
  disposalStarted = "DISPOSAL_STARTED",
  disposalArrived = "DISPOSAL_ARRIVED",
  disposalCompleted = "DISPOSAL_COMPLETED",
  reminder = "REMINDER",
}

export interface GeoPointContract {
  latitude: number;
  longitude: number;
}

export interface CreateServiceRequestContract {
  idempotencyKey: string;
  locationKind: RequestLocationKind;
  locationText?: string;
  location?: GeoPointContract;
  toiletType?: ToiletType;
  additionalContactName?: string;
  additionalContactPhone?: string;
  scheduleMode: ScheduleMode;
  requestedServiceAt?: string;
}

export interface CallCentreCreateRequestContract extends Omit<
  CreateServiceRequestContract,
  "idempotencyKey"
> {
  idempotencyKey: string;
  clientName: string;
  clientPhone: string;
  clientEmail?: string;
}

export interface ServiceRequestSummaryContract {
  id: string;
  reference: string;
  origin: ServiceRequestOrigin;
  status: ServiceRequestStatus;
  locationLabel: string;
  scheduleMode: ScheduleMode;
  requestedServiceAt?: string;
  providerName?: string;
  agreedPriceUgx?: number;
  outstandingAction?: string;
  updatedAt: string;
}

export interface ServiceRequestDetailContract extends ServiceRequestSummaryContract {
  clientName: string;
  clientPhone?: string;
  clientEmail?: string;
  locationKind: RequestLocationKind;
  location?: GeoPointContract;
  toiletType?: ToiletType;
  additionalContactName?: string;
  additionalContactPhone?: string;
  providerUserId?: string;
  providerPhone?: string;
  collectionOutcome?: CollectionOutcome;
  wasteCollected?: boolean;
  followUpStatus?: FollowUpStatus;
  journeyToRequest?: JourneySnapshotContract;
  disposalJourney?: JourneySnapshotContract;
  disposalSite?: DisposalSiteContract;
  createdAt: string;
}

export interface ProviderPendingRequestContract {
  id: string;
  reference: string;
  origin: ServiceRequestOrigin;
  assignmentStatus?: AssignmentStatus;
  locationLabel: string;
  toiletType?: ToiletType;
  scheduleMode: ScheduleMode;
  requestedServiceAt?: string;
  createdAt: string;
}

export interface AcceptRequestContract {
  idempotencyKey: string;
  agreedPriceUgx?: number;
}

export interface RejectAssignedRequestContract {
  idempotencyKey: string;
}

export interface CallCentreAssignmentContract {
  idempotencyKey: string;
  providerUserId: string;
  disposalSiteId?: string;
  agreedPriceUgx?: number;
}

export interface StartJourneyContract {
  idempotencyKey: string;
}

export interface ReportCollectionContract {
  idempotencyKey: string;
}

export interface SubmitFeedbackContract {
  idempotencyKey: string;
  outcome: CollectionOutcome;
  feedback: string;
  rating: number;
}

export interface LocationSampleContract extends GeoPointContract {
  sampleId: string;
  deviceTimestamp: string;
  accuracyMetres: number;
}

export interface SubmitLocationBatchContract {
  phase: JourneyPhase;
  samples: LocationSampleContract[];
}

export interface JourneySnapshotContract {
  id: string;
  phase: JourneyPhase;
  status: JourneyStatus;
  destination: GeoPointContract;
  latestPosition?: LocationSampleContract;
  latestPositionReceivedAt?: string;
  stale: boolean;
  startedAt?: string;
  arrivedAt?: string;
  completedAt?: string;
  positionCount: number;
}

export interface DisposalSiteContract extends GeoPointContract {
  id: string;
  name: string;
  address: string;
}

export interface UpsertDisposalSiteContract extends DisposalSiteContract {
  active: boolean;
}

export interface CompleteDisposalContract {
  idempotencyKey: string;
}

export interface OperationalNotificationContract {
  id: string;
  type: OperationalNotificationType;
  title: string;
  message: string;
  requestId?: string;
  createdAt: string;
  readAt?: string;
}

export interface DashboardContract {
  actorNumber?: string;
  pendingCount: number;
  activeCount: number;
  actionRequiredCount: number;
  recentRequests: ServiceRequestSummaryContract[];
}

export interface LocationPolicyContract {
  provisional: true;
  sampleIntervalSeconds: number;
  sampleDistanceMetres: number;
  arrivalRadiusMetres: number;
  arrivalMaximumAccuracyMetres: number;
  staleAfterSeconds: number;
  retentionDays: number;
  backgroundTrackingEnabled: boolean;
  approvalNotice: string;
}
