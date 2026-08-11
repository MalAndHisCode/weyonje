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

  @ApiPropertyOptional({
    type: String,
    enum: ProviderStatus,
    enumName: "ProviderStatus",
  })
  providerStatus?: ProviderStatus;
}

export class ApiErrorDto {
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
