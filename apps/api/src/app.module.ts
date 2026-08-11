import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";

import { AuthModule } from "./auth/auth.module";
import { authConfig } from "./config/auth.config";
import { validateEnvironment } from "./config/environment";
import { PrismaModule } from "./database/prisma.module";
import { IdentityModule } from "./identity/identity.module";

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      cache: true,
      validate: validateEnvironment,
      load: [authConfig],
    }),
    PrismaModule,
    AuthModule,
    IdentityModule,
  ],
})
export class AppModule {}
