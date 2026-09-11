import { ApiProperty, ApiPropertyOptional, OmitType } from "@nestjs/swagger";
import {
  AcceptRequestContract,
  AssignmentStatus,
  CallCentreAssignmentContract,
  CallCentreCreateRequestContract,
  CollectionOutcome,
  CompleteDisposalContract,
  CreateServiceRequestContract,
  GeoPointContract,
  FollowUpStatus,
  JourneyPhase,
  JourneySnapshotContract,
  JourneyStatus,
  LocationPolicyContract,
  LocationSampleContract,
  NotificationChannel,
  OperationalNotificationContract,
  OperationalNotificationType,
  ProviderPendingRequestContract,
  RejectAssignedRequestContract,
  ReportCollectionContract,
  RequestLocationKind,
  ScheduleMode,
  ServiceRequestDetailContract,
  ServiceRequestOrigin,
  ServiceRequestStatus,
  ServiceRequestSummaryContract,
  StartJourneyContract,
  SubmitFeedbackContract,
  SubmitLocationBatchContract,
  ToiletType,
  UpsertDisposalSiteContract,
  DisposalSiteContract,
} from "@weyonje/contracts";
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsISO8601,
  IsNotEmpty,
  IsNumber,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  ValidateIf,
} from "class-validator";

export class GeoPointDto implements GeoPointContract {
  @ApiProperty({ type: Number, minimum: -90, maximum: 90 })
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude!: number;

  @ApiProperty({ type: Number, minimum: -180, maximum: 180 })
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude!: number;
}

export class CreateServiceRequestDto implements CreateServiceRequestContract {
  @ApiProperty({ type: String, format: "uuid" })
  @IsUUID()
  idempotencyKey!: string;

  @ApiProperty({ type: String, enum: RequestLocationKind })
  @IsEnum(RequestLocationKind)
  locationKind!: RequestLocationKind;

  @ApiPropertyOptional({ type: String, maxLength: 500 })
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  locationText?: string;

  @ApiPropertyOptional({ type: GeoPointDto })
  @IsOptional()
  @IsObject()
  location?: GeoPointContract;

  @ApiPropertyOptional({ type: String, enum: ToiletType })
  @IsOptional()
  @IsEnum(ToiletType)
  toiletType?: ToiletType;

  @ApiPropertyOptional({ type: String, maxLength: 200 })
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  additionalContactName?: string;

  @ApiPropertyOptional({ type: String, maxLength: 40 })
  @ValidateIf((value: CreateServiceRequestDto) =>
    Boolean(value.additionalContactName || value.additionalContactPhone),
  )
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  additionalContactPhone?: string;

  @ApiProperty({ type: String, enum: ScheduleMode })
  @IsEnum(ScheduleMode)
  scheduleMode!: ScheduleMode;

  @ApiPropertyOptional({ type: String, format: "date-time" })
  @IsOptional()
  @IsString()
  requestedServiceAt?: string;
}

export class CallCentreCreateRequestDto
  extends CreateServiceRequestDto
  implements CallCentreCreateRequestContract
{
  @ApiPropertyOptional({ type: String, format: "uuid" })
  @IsOptional()
  @IsUUID()
  clientUserId?: string;

  @ApiProperty({ type: String, maxLength: 240 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(240)
  clientName!: string;

  @ApiProperty({ type: String, maxLength: 40 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  clientPhone!: string;

  @ApiPropertyOptional({ type: String, maxLength: 254 })
  @IsOptional()
  @IsString()
  @MaxLength(254)
  clientEmail?: string;
}

export class AcceptRequestDto implements AcceptRequestContract {
  @ApiProperty({ type: String, format: "uuid" })
  @IsUUID()
  idempotencyKey!: string;

  @ApiPropertyOptional({ type: Number, minimum: 0, maximum: 1_000_000_000 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(1_000_000_000)
  agreedPriceUgx?: number;
}

export class RejectAssignedRequestDto implements RejectAssignedRequestContract {
  @ApiProperty({ type: String, format: "uuid" })
  @IsUUID()
  idempotencyKey!: string;
}

export class CallCentreAssignmentDto implements CallCentreAssignmentContract {
  @ApiProperty({ type: String, format: "uuid" })
  @IsUUID()
  idempotencyKey!: string;

  @ApiProperty({ type: String, format: "uuid" })
  @IsUUID()
  providerUserId!: string;

  @ApiPropertyOptional({ type: String, format: "uuid" })
  @IsOptional()
  @IsUUID()
  disposalSiteId?: string;

  @ApiPropertyOptional({ type: Number, minimum: 0, maximum: 1_000_000_000 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(1_000_000_000)
  agreedPriceUgx?: number;
}

export class AssignDisposalSiteDto {
  @ApiProperty({ type: String, format: "uuid" })
  @IsUUID()
  idempotencyKey!: string;

  @ApiProperty({ type: String, format: "uuid" })
  @IsUUID()
  disposalSiteId!: string;
}

export class IdempotentCommandDto
  implements
    StartJourneyContract,
    ReportCollectionContract,
    CompleteDisposalContract
{
  @ApiProperty({ type: String, format: "uuid" })
  @IsUUID()
  idempotencyKey!: string;
}

export class SubmitFeedbackDto implements SubmitFeedbackContract {
  @ApiProperty({ type: String, format: "uuid" })
  @IsUUID()
  idempotencyKey!: string;

  @ApiProperty({ type: String, enum: CollectionOutcome })
  @IsEnum(CollectionOutcome)
  outcome!: CollectionOutcome;

  @ApiProperty({ type: String, maxLength: 2000 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(2000)
  feedback!: string;

  @ApiProperty({ type: Number, minimum: 1, maximum: 5 })
  @IsInt()
  @Min(1)
  @Max(5)
  rating!: number;
}

export class SubmitLocationBatchDto implements SubmitLocationBatchContract {
  @ApiProperty({ type: String, enum: JourneyPhase })
  @IsEnum(JourneyPhase)
  phase!: JourneyPhase;

  @ApiProperty({ type: Object, isArray: true, maxItems: 50 })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(50)
  samples!: LocationSampleContract[];
}

export class DisposalSiteDto implements UpsertDisposalSiteContract {
  @ApiProperty({ type: String, format: "uuid" })
  @IsUUID()
  id!: string;

  @ApiProperty({ type: String, maxLength: 200 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  name!: string;

  @ApiProperty({ type: String, maxLength: 500 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  address!: string;

  @ApiProperty({ type: Number, minimum: -90, maximum: 90 })
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude!: number;

  @ApiProperty({ type: Number, minimum: -180, maximum: 180 })
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude!: number;

  @ApiProperty({ type: Boolean })
  @IsBoolean()
  active!: boolean;
}

export class ServiceRequestSummaryDto implements ServiceRequestSummaryContract {
  @ApiProperty({ type: String }) id!: string;
  @ApiProperty({ type: String }) reference!: string;
  @ApiProperty({ type: String, enum: ServiceRequestOrigin })
  origin!: ServiceRequestOrigin;
  @ApiProperty({ type: String, enum: ServiceRequestStatus })
  status!: ServiceRequestStatus;
  @ApiProperty({ type: String }) locationLabel!: string;
  @ApiProperty({ type: String, enum: ScheduleMode })
  scheduleMode!: ScheduleMode;
  @ApiPropertyOptional({ type: String, format: "date-time" })
  requestedServiceAt?: string;
  @ApiPropertyOptional({ type: String }) providerName?: string;
  @ApiPropertyOptional({ type: Number }) agreedPriceUgx?: number;
  @ApiPropertyOptional({ type: String }) outstandingAction?: string;
  @ApiProperty({ type: String, format: "date-time" }) updatedAt!: string;
}

export class ServiceRequestDetailDto
  extends ServiceRequestSummaryDto
  implements ServiceRequestDetailContract
{
  @ApiProperty({ type: String }) clientName!: string;
  @ApiPropertyOptional({ type: String }) clientPhone?: string;
  @ApiPropertyOptional({ type: String }) clientEmail?: string;
  @ApiProperty({ type: String, enum: RequestLocationKind })
  locationKind!: RequestLocationKind;
  @ApiPropertyOptional({ type: GeoPointDto }) location?: GeoPointContract;
  @ApiPropertyOptional({ type: String, enum: ToiletType })
  toiletType?: ToiletType;
  @ApiPropertyOptional({ type: String }) additionalContactName?: string;
  @ApiPropertyOptional({ type: String }) additionalContactPhone?: string;
  @ApiPropertyOptional({ type: String }) providerUserId?: string;
  @ApiPropertyOptional({ type: String }) providerPhone?: string;
  @ApiPropertyOptional({ type: String, enum: CollectionOutcome })
  collectionOutcome?: CollectionOutcome;
  @ApiPropertyOptional({ type: Boolean }) wasteCollected?: boolean;
  @ApiPropertyOptional({ type: String, enum: FollowUpStatus })
  followUpStatus?: FollowUpStatus;
  @ApiPropertyOptional({ type: Object })
  journeyToRequest?: JourneySnapshotContract;
  @ApiPropertyOptional({ type: Object })
  disposalJourney?: JourneySnapshotContract;
  @ApiPropertyOptional({ type: Object }) disposalSite?: DisposalSiteContract;
  @ApiProperty({ type: String, format: "date-time" }) createdAt!: string;
}

export class ProviderPendingRequestDto implements ProviderPendingRequestContract {
  @ApiProperty({ type: String }) id!: string;
  @ApiProperty({ type: String }) reference!: string;
  @ApiProperty({ type: String, enum: ServiceRequestOrigin })
  origin!: ServiceRequestOrigin;
  @ApiPropertyOptional({ type: String, enum: AssignmentStatus })
  assignmentStatus?: AssignmentStatus;
  @ApiProperty({ type: String }) locationLabel!: string;
  @ApiPropertyOptional({ type: String, enum: ToiletType })
  toiletType?: ToiletType;
  @ApiProperty({ type: String, enum: ScheduleMode })
  scheduleMode!: ScheduleMode;
  @ApiPropertyOptional({ type: String, format: "date-time" })
  requestedServiceAt?: string;
  @ApiProperty({ type: String, format: "date-time" }) createdAt!: string;
}

export class JourneySnapshotDto implements JourneySnapshotContract {
  @ApiProperty({ type: String }) id!: string;
  @ApiProperty({ type: String, enum: JourneyPhase }) phase!: JourneyPhase;
  @ApiProperty({ type: String, enum: JourneyStatus }) status!: JourneyStatus;
  @ApiProperty({ type: GeoPointDto }) destination!: GeoPointContract;
  @ApiPropertyOptional({ type: Object })
  latestPosition?: LocationSampleContract;
  @ApiPropertyOptional({ type: String, format: "date-time" })
  latestPositionReceivedAt?: string;
  @ApiProperty({ type: Boolean }) stale!: boolean;
  @ApiPropertyOptional({ type: String, format: "date-time" })
  startedAt?: string;
  @ApiPropertyOptional({ type: String, format: "date-time" })
  arrivedAt?: string;
  @ApiPropertyOptional({ type: String, format: "date-time" })
  completedAt?: string;
  @ApiProperty({ type: Number }) positionCount!: number;
}

export class OperationalNotificationDto implements OperationalNotificationContract {
  @ApiProperty({ type: String }) id!: string;
  @ApiProperty({ type: String, enum: OperationalNotificationType })
  type!: OperationalNotificationType;
  @ApiProperty({ type: String }) title!: string;
  @ApiProperty({ type: String }) message!: string;
  @ApiPropertyOptional({ type: String }) requestId?: string;
  @ApiProperty({ type: String, format: "date-time" }) createdAt!: string;
  @ApiPropertyOptional({ type: String, format: "date-time" }) readAt?: string;
}

export class LocationPolicyDto implements LocationPolicyContract {
  @ApiProperty({ type: Boolean, example: true }) provisional!: true;
  @ApiProperty({ type: Number }) sampleIntervalSeconds!: number;
  @ApiProperty({ type: Number }) sampleDistanceMetres!: number;
  @ApiProperty({ type: Number }) arrivalRadiusMetres!: number;
  @ApiProperty({ type: Number }) arrivalMaximumAccuracyMetres!: number;
  @ApiProperty({ type: Number }) staleAfterSeconds!: number;
  @ApiProperty({ type: Number }) retentionDays!: number;
  @ApiProperty({ type: Boolean }) backgroundTrackingEnabled!: boolean;
  @ApiProperty({ type: String }) approvalNotice!: string;
}

// Exporting the channel enum through Swagger keeps the provider-neutral outbox
// boundary visible without exposing provider credentials or payload internals.
export class NotificationChannelDto {
  @ApiProperty({ type: String, enum: NotificationChannel })
  channel!: NotificationChannel;
}

export class ClientRequestProfileDto {
  @ApiProperty({ type: String })
  clientName!: string;
  @ApiProperty({ type: String })
  phoneNumber!: string;
  @ApiPropertyOptional({ type: String })
  emailAddress?: string;
}
export class CreateClientServiceRequestDto extends OmitType(
  CreateServiceRequestDto,
  ["toiletType"] as const,
) {
  @ApiProperty({ type: String, enum: ToiletType })
  @IsEnum(ToiletType)
  toiletType!: ToiletType;
}

export class WithdrawClientServiceRequestDto {
  @ApiProperty({ type: String, format: "uuid" })
  @IsUUID()
  idempotencyKey!: string;

  @ApiProperty({
    type: String,
    format: "date-time",
    description:
      "Exact updatedAt from authoritative details; stale changes return CONFLICT.",
  })
  @IsISO8601({ strict: true })
  expectedUpdatedAt!: string;
}

export class UpdateClientServiceRequestDto extends WithdrawClientServiceRequestDto {
  @ApiProperty({
    enum: [RequestLocationKind.current, RequestLocationKind.mapPin],
  })
  @IsEnum({
    current: RequestLocationKind.current,
    mapPin: RequestLocationKind.mapPin,
  })
  locationKind!: RequestLocationKind.current | RequestLocationKind.mapPin;

  @ApiProperty({ type: GeoPointDto })
  @IsObject()
  location!: GeoPointContract;

  @ApiProperty({ enum: ToiletType })
  @IsEnum(ToiletType)
  toiletType!: ToiletType;

  @ApiProperty({
    type: String,
    nullable: true,
    maxLength: 200,
    description:
      "Required; null clears the contact name and must be paired with a null phone.",
  })
  @ValidateIf((_object, value) => value !== null)
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  additionalContactName!: string | null;

  @ApiProperty({
    type: String,
    nullable: true,
    maxLength: 40,
    description:
      "Required; null clears the contact phone and must be paired with a null name.",
  })
  @ValidateIf((_object, value) => value !== null)
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  additionalContactPhone!: string | null;
}
