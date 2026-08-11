import { registerAs } from "@nestjs/config";
import { TypeOrmModuleOptions } from "@nestjs/typeorm";

import { ActorProfileEntity } from "../identity/actor-profile.entity";

export const databaseConfig = registerAs(
  "database",
  (): TypeOrmModuleOptions => ({
    type: "postgres",
    host: process.env.DATABASE_HOST!,
    port: Number(process.env.DATABASE_PORT),
    database: process.env.DATABASE_NAME!,
    username: process.env.DATABASE_USER!,
    password: process.env.DATABASE_PASSWORD!,
    ssl:
      process.env.DATABASE_SSL === "true"
        ? { rejectUnauthorized: true }
        : false,
    entities: [ActorProfileEntity],
    migrations: [`${__dirname}/migrations/*.{js,ts}`],
    migrationsRun: false,
    synchronize: false,
    logging: false,
  }),
);
