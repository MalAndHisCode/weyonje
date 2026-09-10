import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";
import { resolve } from "node:path";

import { AuthModule } from "./auth/auth.module";
import { authConfig } from "./config/auth.config";
import { accountSecurityConfig } from "./config/account-security.config";
import { deliveryConfig } from "./config/delivery.config";
import { validateEnvironment } from "./config/environment";
import { smsConfig } from "./config/sms.config";
import { locationConfig } from "./config/location.config";
import { PrismaModule } from "./database/prisma.module";
import { IdentityModule } from "./identity/identity.module";
import { RegistrationModule } from "./registration/registration.module";
import { WorkflowModule } from "./workflows/workflow.module";
import { DeliveryModule } from "./delivery/delivery.module";
import { AccountSecurityModule } from "./account-security/account-security.module";
import { mapsConfig } from "./config/maps.config";
import { MapsModule } from "./maps/maps.module";
import { reminderConfig } from "./config/reminder.config";
import { pushConfig } from "./config/push.config";
import { NotificationsModule } from "./notifications/notifications.module";

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      cache: true,
      // Resolve the documented root .env from source and compiled API layouts.
      // Deployment environment variables retain Nest's normal precedence.
      envFilePath: resolve(__dirname, "../../..", ".env"),
      validate: validateEnvironment,
      load: [
        authConfig,
        smsConfig,
        locationConfig,
        deliveryConfig,
        accountSecurityConfig,
        mapsConfig,
        reminderConfig,
        pushConfig,
      ],
    }),
    PrismaModule,
    AuthModule,
    IdentityModule,
    RegistrationModule,
    WorkflowModule,
    AccountSecurityModule,
    DeliveryModule,
    MapsModule,
    NotificationsModule,
  ],
})
export class AppModule {}
