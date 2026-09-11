import { ApiProperty } from "@nestjs/swagger";
import {
  ClientCodeRequestContract,
  ProviderCodeRequestContract,
  RegistrationRequiredContract,
  RefreshRequestContract,
  SessionCredentialsContract,
  SignInRequestContract,
  SignOutContract,
} from "@weyonje/contracts";
import {
  IsEmail,
  IsNotEmpty,
  IsString,
  MaxLength,
  MinLength,
} from "class-validator";

export class RegistrationRequiredDto implements RegistrationRequiredContract {
  @ApiProperty({ type: String, enum: ["REGISTRATION_REQUIRED"] })
  outcome!: "REGISTRATION_REQUIRED";
}

export class ClientCodeRequestDto implements ClientCodeRequestContract {
  @ApiProperty({ type: String, example: "+256 700 000000" })
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  phoneNumber!: string;
}

export class ProviderCodeRequestDto
  extends ClientCodeRequestDto
  implements ProviderCodeRequestContract {}

export class SignInDto implements SignInRequestContract {
  @ApiProperty({ type: String, example: "account@example.invalid" })
  @IsString()
  @IsEmail()
  @MaxLength(254)
  email!: string;

  @ApiProperty({ type: String, format: "password", writeOnly: true })
  @IsString()
  @MinLength(1)
  @MaxLength(1024)
  password!: string;
}

export class RefreshDto implements RefreshRequestContract {
  @ApiProperty({ type: String, writeOnly: true })
  @IsString()
  @MinLength(32)
  @MaxLength(512)
  refreshToken!: string;
}

export class SessionCredentialsDto implements SessionCredentialsContract {
  @ApiProperty({ type: String })
  accessToken!: string;

  @ApiProperty({ type: String })
  refreshToken!: string;

  @ApiProperty({ type: String, format: "date-time" })
  accessTokenExpiresAt!: string;

  @ApiProperty({ type: String, format: "date-time" })
  refreshTokenExpiresAt!: string;
}

export class SignOutDto implements SignOutContract {
  @ApiProperty({ type: Boolean, example: true })
  signedOut!: true;
}
