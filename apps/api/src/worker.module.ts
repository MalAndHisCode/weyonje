import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";

import { AuthModule } from "./auth/auth.module";
import { authConfig } from "./config/auth.config";
import { accountSecurityConfig } from "./config/account-security.config";
import { deliveryConfig } from "./config/delivery.config";
import { validateEnvironment } from "./config/environment";
import { smsConfig } from "./config/sms.config";
import { PrismaModule } from "./database/prisma.module";
import { DeliveryModule } from "./delivery/delivery.module";
import { AccountSecurityModule } from "./account-security/account-security.module";
import { reminderConfig } from "./config/reminder.config";
import { pushConfig } from "./config/push.config";
import { NotificationsModule } from "./notifications/notifications.module";

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      cache: true,
      validate: validateEnvironment,
      load: [
        authConfig,
        smsConfig,
        deliveryConfig,
        accountSecurityConfig,
        reminderConfig,
        pushConfig,
      ],
    }),
    PrismaModule,
    AuthModule,
    AccountSecurityModule,
    NotificationsModule,
    DeliveryModule,
  ],
})
export class WorkerModule {}
