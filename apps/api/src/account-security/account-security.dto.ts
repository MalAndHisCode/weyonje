import { ApiProperty, ApiPropertyOptional } from "@nestjs/swagger";
import {
  AccountChallengeContract,
  AccountChallengeMethod,
  CompletePasswordRecoveryContract,
  PasswordRecoveryRequestContract,
  RequestEmailVerificationContract,
  VerifyEmailContract,
} from "@weyonje/contracts";
import {
  IsEmail,
  IsEnum,
  IsString,
  IsUUID,
  Matches,
  MaxLength,
  MinLength,
} from "class-validator";

export class AccountChallengeDto implements AccountChallengeContract {
  @ApiProperty({ type: String, format: "uuid" })
  challengeId!: string;

  @ApiProperty({ type: String, format: "date-time" })
  expiresAt!: string;

  @ApiProperty({ type: String, format: "date-time" })
  resendAvailableAt!: string;

  @ApiProperty({ type: String, enum: ["QUEUED"] })
  deliveryStatus!: "QUEUED";

  @ApiPropertyOptional({ type: String, writeOnly: true })
  developmentVerificationCode?: string;
}

export class PasswordRecoveryRequestDto implements PasswordRecoveryRequestContract {
  @ApiProperty({ type: String, example: "account@example.invalid" })
  @IsEmail()
  @MaxLength(254)
  email!: string;

  @ApiProperty({ type: String, enum: AccountChallengeMethod })
  @IsEnum(AccountChallengeMethod)
  method!: AccountChallengeMethod;
}

export class ChallengeReferenceDto {
  @ApiProperty({ type: String, format: "uuid" })
  @IsUUID()
  challengeId!: string;
}

export class CompletePasswordRecoveryDto implements CompletePasswordRecoveryContract {
  @ApiProperty({ type: String, format: "uuid" })
  @IsUUID()
  challengeId!: string;

  @ApiProperty({ type: String, pattern: "^[0-9]{6}$" })
  @Matches(/^\d{6}$/)
  code!: string;

  @ApiProperty({ type: String, format: "password", writeOnly: true })
  @IsString()
  @MinLength(12)
  @MaxLength(1024)
  newPassword!: string;
}

export class RequestEmailVerificationDto implements RequestEmailVerificationContract {
  @ApiProperty({ type: String, enum: AccountChallengeMethod })
  @IsEnum(AccountChallengeMethod)
  method!: AccountChallengeMethod;
}

export class VerifyEmailDto implements VerifyEmailContract {
  @ApiProperty({ type: String, format: "uuid" })
  @IsUUID()
  challengeId!: string;

  @ApiProperty({ type: String, pattern: "^[0-9]{6}$" })
  @Matches(/^\d{6}$/)
  code!: string;
}

export class AccountSecurityResultDto {
  @ApiProperty({ type: Boolean, example: true })
  completed!: true;
}
