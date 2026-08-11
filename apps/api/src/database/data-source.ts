import "reflect-metadata";

import { config as loadDotEnv } from "dotenv";
import { DataSource } from "typeorm";

import { validateEnvironment } from "../config/environment";
import { ActorProfileEntity } from "../identity/actor-profile.entity";

loadDotEnv();
validateEnvironment(process.env);

export default new DataSource({
  type: "postgres",
  host: process.env.DATABASE_HOST!,
  port: Number(process.env.DATABASE_PORT),
  database: process.env.DATABASE_NAME!,
  username: process.env.DATABASE_USER!,
  password: process.env.DATABASE_PASSWORD!,
  ssl:
    process.env.DATABASE_SSL === "true" ? { rejectUnauthorized: true } : false,
  entities: [ActorProfileEntity],
  migrations: [`${__dirname}/migrations/*.{js,ts}`],
  migrationsTableName: "weyonje_migrations",
  synchronize: false,
});
