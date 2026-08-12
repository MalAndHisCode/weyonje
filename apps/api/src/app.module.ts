import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";

import { AuthModule } from "./auth/auth.module";
import { authConfig } from "./config/auth.config";
import { validateEnvironment } from "./config/environment";
import { smsConfig } from "./config/sms.config";
import { PrismaModule } from "./database/prisma.module";
import { IdentityModule } from "./identity/identity.module";
import { RegistrationModule } from "./registration/registration.module";

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      cache: true,
      validate: validateEnvironment,
      load: [authConfig, smsConfig],
    }),
    PrismaModule,
    AuthModule,
    IdentityModule,
    RegistrationModule,
  ],
})
export class AppModule {}
