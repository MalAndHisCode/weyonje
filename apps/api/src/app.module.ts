import { Module } from "@nestjs/common";
import { ConfigModule, ConfigService } from "@nestjs/config";
import { TypeOrmModule } from "@nestjs/typeorm";

import { validateEnvironment } from "./config/environment";
import { identityConfig } from "./config/identity.config";
import { databaseConfig } from "./database/typeorm.config";
import { IdentityModule } from "./identity/identity.module";

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      cache: true,
      validate: validateEnvironment,
      load: [identityConfig, databaseConfig],
    }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => config.getOrThrow("database"),
    }),
    IdentityModule,
  ],
})
export class AppModule {}
