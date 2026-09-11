import { ApiProperty, ApiPropertyOptional } from "@nestjs/swagger";
import {
  ClientRegistrationRequestContract,
  ClientType,
  PendingProviderRegistrationContract,
  PhoneChallengeContract,
  PhoneCodeDeliveryStatus,
  ProviderApprovalDecision,
  ProviderApprovalRequestContract,
  ProviderAdministrationContract,
  ProviderStatusChangeContract,
  ProviderStatusHistoryContract,
  ProviderRegistrationStatusContract,
  ProviderStatus,
  ResendPhoneCodeRequestContract,
  ServiceProviderRegistrationRequestContract,
  ServiceProviderType,
  SessionCredentialsContract,
  VerifyPhoneCodeRequestContract,
} from "@weyonje/contracts";
import {
  IsEmail,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Matches,
  MaxLength,
  ValidateIf,
} from "class-validator";

export class ClientRegistrationDto implements ClientRegistrationRequestContract {
  @ApiProperty({ type: String, enum: ClientType, enumName: "ClientType" })
  @IsEnum(ClientType)
  clientType!: ClientType;

  @ApiPropertyOptional({ type: String, maxLength: 100 })
  @ValidateIf(
    (value: ClientRegistrationDto) =>
      value.clientType === ClientType.individual,
  )
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  firstName?: string;

  @ApiPropertyOptional({ type: String, maxLength: 100 })
  @ValidateIf(
    (value: ClientRegistrationDto) =>
      value.clientType === ClientType.individual,
  )
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  lastName?: string;

  @ApiPropertyOptional({ type: String, maxLength: 200 })
  @ValidateIf(
    (value: ClientRegistrationDto) =>
      value.clientType === ClientType.organization,
  )
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  organizationName?: string;

  @ApiProperty({ type: String, example: "+256 700 000000", maxLength: 40 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  phoneNumber!: string;

  @ApiPropertyOptional({ type: String, format: "email", maxLength: 254 })
  @IsOptional()
  @IsEmail()
  @MaxLength(254)
  email?: string;

  @ApiPropertyOptional({ type: String, maxLength: 200 })
  @ValidateIf(
    (value: ClientRegistrationDto) =>
      value.clientType === ClientType.organization,
  )
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  contactPersonName?: string;

  @ApiPropertyOptional({ type: String, maxLength: 40 })
  @ValidateIf(
    (value: ClientRegistrationDto) =>
      value.clientType === ClientType.organization,
  )
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  contactPersonPhone?: string;
}

export class ServiceProviderRegistrationDto implements ServiceProviderRegistrationRequestContract {
  @ApiProperty({ type: String, maxLength: 100 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  essLicenseNumber!: string;

  @ApiProperty({ type: String, maxLength: 200 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  companyName!: string;

  @ApiProperty({ type: String, maxLength: 40 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  phoneNumber!: string;

  @ApiProperty({ type: String, format: "email", maxLength: 254 })
  @IsEmail()
  @MaxLength(254)
  email!: string;

  @ApiProperty({ type: String, maxLength: 500 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  workAddress!: string;

  @ApiProperty({
    type: String,
    enum: ServiceProviderType,
    enumName: "ServiceProviderType",
  })
  @IsEnum(ServiceProviderType)
  providerType!: ServiceProviderType;

  @ApiProperty({ type: String, maxLength: 200 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  contactPersonName!: string;

  @ApiProperty({ type: String, maxLength: 40 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  contactPersonPhone!: string;
}

export class PhoneChallengeDto implements PhoneChallengeContract {
  @ApiProperty({ type: String, format: "uuid" })
  challengeId!: string;

  @ApiProperty({ type: String, example: "+256 •••••• 123" })
  maskedPhone!: string;

  @ApiProperty({ type: String, format: "date-time" })
  expiresAt!: string;

  @ApiProperty({ type: String, format: "date-time" })
  resendAvailableAt!: string;

  @ApiProperty({ type: String, enum: PhoneCodeDeliveryStatus })
  deliveryStatus!: PhoneCodeDeliveryStatus;
}

export class VerifyPhoneCodeDto implements VerifyPhoneCodeRequestContract {
  @ApiProperty({ type: String, format: "uuid" })
  @IsUUID()
  challengeId!: string;

  @ApiProperty({ type: String, pattern: "^[0-9]{6}$", writeOnly: true })
  @IsString()
  @Matches(/^\d{6}$/)
  code!: string;
}

export class ResendPhoneCodeDto implements ResendPhoneCodeRequestContract {
  @ApiProperty({ type: String, format: "uuid" })
  @IsUUID()
  challengeId!: string;
}

export class RegistrationVerificationDto implements SessionCredentialsContract {
  @ApiProperty({ type: String }) accessToken!: string;
  @ApiProperty({ type: String }) refreshToken!: string;
  @ApiProperty({ type: String, format: "date-time" })
  accessTokenExpiresAt!: string;
  @ApiProperty({ type: String, format: "date-time" })
  refreshTokenExpiresAt!: string;
}

export class ProviderApprovalDto implements ProviderApprovalRequestContract {
  @ApiProperty({ type: String, enum: ProviderApprovalDecision })
  @IsEnum(ProviderApprovalDecision)
  decision!: ProviderApprovalDecision;

  @ApiPropertyOptional({ type: String, maxLength: 1000 })
  @ValidateIf(
    (value: ProviderApprovalDto) =>
      value.decision === ProviderApprovalDecision.rejected,
  )
  @IsString()
  @IsNotEmpty()
  @MaxLength(1000)
  reason?: string;
}

export class ProviderRegistrationStatusDto implements ProviderRegistrationStatusContract {
  @ApiProperty({ type: String, enum: ProviderStatus })
  status!: ProviderStatus;

  @ApiPropertyOptional({ type: String })
  providerNumber?: string;

  @ApiPropertyOptional({ type: String })
  rejectionReason?: string;
}

export class PendingProviderRegistrationDto implements PendingProviderRegistrationContract {
  @ApiProperty({ type: String, format: "uuid" }) providerUserId!: string;
  @ApiProperty({ type: String }) essLicenseNumber!: string;
  @ApiProperty({ type: String }) companyName!: string;
  @ApiProperty({ type: String }) phoneNumber!: string;
  @ApiProperty({ type: String, format: "email" }) email!: string;
  @ApiProperty({ type: String }) workAddress!: string;
  @ApiProperty({ type: String, enum: ServiceProviderType })
  providerType!: ServiceProviderType;
  @ApiProperty({ type: String }) contactPersonName!: string;
  @ApiProperty({ type: String }) contactPersonPhone!: string;
  @ApiProperty({ type: String, format: "date-time" }) submittedAt!: string;
}

export class ProviderStatusHistoryDto implements ProviderStatusHistoryContract {
  @ApiProperty({
    type: String,
    enum: ["KCCA_MANUAL", "SYSTEM_REGISTRATION_POLICY"],
  })
  provenance!: "KCCA_MANUAL" | "SYSTEM_REGISTRATION_POLICY";
  @ApiProperty({ type: String, enum: ProviderStatus })
  fromStatus!: ProviderStatus;
  @ApiProperty({ type: String, enum: ProviderStatus })
  toStatus!: ProviderStatus;
  @ApiPropertyOptional({ type: String }) reason?: string;
  @ApiProperty({ type: String, format: "date-time" }) createdAt!: string;
}

export class ProviderAdministrationDto
  extends PendingProviderRegistrationDto
  implements ProviderAdministrationContract
{
  @ApiProperty({ type: String, enum: ProviderStatus }) status!: ProviderStatus;
  @ApiProperty({ type: Boolean }) active!: boolean;
  @ApiPropertyOptional({ type: String }) providerNumber?: string;
  @ApiPropertyOptional({ type: String }) rejectionReason?: string;
  @ApiProperty({ type: ProviderStatusHistoryDto, isArray: true })
  statusHistory!: ProviderStatusHistoryContract[];
}

export class ProviderStatusChangeDto implements ProviderStatusChangeContract {
  @ApiProperty({
    type: String,
    enum: [
      ProviderStatus.approved,
      ProviderStatus.inactive,
      ProviderStatus.disabled,
    ],
  })
  @IsEnum(ProviderStatus)
  status!:
    ProviderStatus.inactive | ProviderStatus.approved | ProviderStatus.disabled;

  @ApiPropertyOptional({ type: String, maxLength: 1000 })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  reason?: string;
}
