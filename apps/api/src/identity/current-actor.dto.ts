import { ApiProperty, ApiPropertyOptional } from "@nestjs/swagger";
import {
  ActorAccess,
  ActorType,
  CurrentActorContract,
  ProviderStatus,
} from "@weyonje/contracts";

export class CurrentActorDto implements CurrentActorContract {
  @ApiProperty({ type: String, enum: ActorType, enumName: "ActorType" })
  actorType!: ActorType;

  @ApiProperty({ type: String, enum: ActorAccess, enumName: "ActorAccess" })
  access!: ActorAccess;

  @ApiProperty({ type: Boolean })
  emailVerified!: boolean;

  @ApiPropertyOptional({ type: Boolean })
  mobileMonitoringPermitted?: boolean;

  @ApiPropertyOptional({ type: Boolean })
  providerApprovalPermitted?: boolean;

  @ApiPropertyOptional({ type: Boolean })
  callCentreOperationsPermitted?: boolean;

  @ApiPropertyOptional({
    type: String,
    enum: ProviderStatus,
    enumName: "ProviderStatus",
  })
  providerStatus?: ProviderStatus;

  @ApiPropertyOptional({ type: String, example: "WSP-4A8F90CD12E3" })
  providerNumber?: string;

  @ApiPropertyOptional({
    type: String,
    example: "The submitted ESS licence could not be validated.",
  })
  providerRejectionReason?: string;
}

export class ApiErrorDto {
  @ApiPropertyOptional({ type: String, format: "date-time" })
  retryAt?: string;

  @ApiPropertyOptional({
    type: String,
    enum: ["OTP_HOURLY", "OTP_COOLDOWN", "CLIENT_REQUEST"],
  })
  limitCategory?: string;

  @ApiProperty({ type: String, example: "AUTH_ACCESS_DENIED" })
  code!: string;

  @ApiProperty({
    type: String,
    example: "This account cannot access Weyonje mobile services.",
  })
  message!: string;

  @ApiPropertyOptional({
    type: String,
    example: "2e96d4c8-5f83-4de0-957e-a7f0cff86690",
  })
  requestId?: string;
}
