import {
  Body,
  Controller,
  Delete,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  Req,
  UseGuards,
} from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { IsIn, IsString, IsUUID, MaxLength, MinLength } from "class-validator";
import {
  AccessTokenGuard,
  AuthenticatedRequest,
} from "../auth/access-token.guard";
import { DeviceInstallationService } from "./device-installation.service";

class RegisterDeviceDto {
  @IsUUID() installationId!: string;
  @IsString() @MinLength(20) @MaxLength(4096) token!: string;
  @IsIn(["ANDROID"]) platform!: string;
  @IsIn(["local", "development", "test", "production"]) environment!: string;
}

@ApiTags("notification devices")
@ApiBearerAuth()
@UseGuards(AccessTokenGuard)
@Controller("v1/notification-devices")
export class NotificationDevicesController {
  constructor(private readonly devices: DeviceInstallationService) {}
  @Post()
  @HttpCode(200)
  register(
    @Req() request: AuthenticatedRequest,
    @Body() body: RegisterDeviceDto,
  ) {
    return this.devices.register(request.authenticatedActor!, body);
  }
  @Delete(":installationId")
  @HttpCode(200)
  remove(
    @Req() request: AuthenticatedRequest,
    @Param("installationId", ParseUUIDPipe) installationId: string,
  ) {
    return this.devices.remove(request.authenticatedActor!, installationId);
  }
}
