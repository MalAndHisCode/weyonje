import { Module } from "@nestjs/common";
import { ConfigType } from "@nestjs/config";

import { smsConfig } from "../config/sms.config";
import { AuthModule } from "../auth/auth.module";
import { AccountSecurityModule } from "../account-security/account-security.module";
import { accountSecurityConfig } from "../config/account-security.config";
import { PhoneModule } from "../registration/phone.module";
import { NotificationsModule } from "../notifications/notifications.module";
import { FirebasePushGateway } from "../notifications/firebase-push.gateway";
import { pushConfig } from "../config/push.config";
import {
  DevelopmentFakeEmailGateway,
  DevelopmentFakePushNotificationGateway,
  DevelopmentFakeOperationalSmsGateway,
  EmailNotificationGateway,
  OperationalSmsGateway,
  PushNotificationGateway,
  UnconfiguredOperationalSmsGateway,
  UnconfiguredPushNotificationGateway,
  UnconfiguredEmailGateway,
} from "../workflows/notification-delivery.gateway";
import { DeliveryController } from "./delivery.controller";
import { DeliveryProcessor } from "./delivery.processor";

@Module({
  imports: [
    AccountSecurityModule,
    AuthModule,
    PhoneModule,
    NotificationsModule,
  ],
  controllers: [DeliveryController],
  providers: [
    DeliveryProcessor,
    UnconfiguredPushNotificationGateway,
    DevelopmentFakePushNotificationGateway,
    UnconfiguredOperationalSmsGateway,
    DevelopmentFakeOperationalSmsGateway,
    DevelopmentFakeEmailGateway,
    UnconfiguredEmailGateway,
    {
      provide: PushNotificationGateway,
      inject: [
        pushConfig.KEY,
        DevelopmentFakePushNotificationGateway,
        FirebasePushGateway,
        UnconfiguredPushNotificationGateway,
      ],
      useFactory: (
        config: ConfigType<typeof pushConfig>,
        fake: DevelopmentFakePushNotificationGateway,
        firebase: FirebasePushGateway,
        unconfigured: UnconfiguredPushNotificationGateway,
      ) =>
        config.provider === "FAKE"
          ? fake
          : config.provider === "FIREBASE"
            ? firebase
            : unconfigured,
    },
    {
      provide: OperationalSmsGateway,
      inject: [
        smsConfig.KEY,
        DevelopmentFakeOperationalSmsGateway,
        UnconfiguredOperationalSmsGateway,
      ],
      useFactory: (
        config: ConfigType<typeof smsConfig>,
        fake: DevelopmentFakeOperationalSmsGateway,
        unconfigured: UnconfiguredOperationalSmsGateway,
      ) => (config.provider === "FAKE" ? fake : unconfigured),
    },
    {
      provide: EmailNotificationGateway,
      inject: [
        accountSecurityConfig.KEY,
        DevelopmentFakeEmailGateway,
        UnconfiguredEmailGateway,
      ],
      useFactory: (
        config: ConfigType<typeof accountSecurityConfig>,
        fake: DevelopmentFakeEmailGateway,
        unconfigured: UnconfiguredEmailGateway,
      ) => (config.emailProvider === "FAKE" ? fake : unconfigured),
    },
  ],
  exports: [DeliveryProcessor],
})
export class DeliveryModule {}
