import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { DeviceInstallationService } from "./device-installation.service";
import { DeviceTokenSecurityService } from "./device-token-security.service";
import { FirebasePushGateway } from "./firebase-push.gateway";
import { NotificationDevicesController } from "./notifications.controller";

@Module({
  imports: [AuthModule],
  controllers: [NotificationDevicesController],
  providers: [
    DeviceInstallationService,
    DeviceTokenSecurityService,
    FirebasePushGateway,
  ],
  exports: [DeviceInstallationService, FirebasePushGateway],
})
export class NotificationsModule {}
