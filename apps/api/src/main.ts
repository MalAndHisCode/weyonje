import "reflect-metadata";

import { ConsoleLogger, ValidationPipe } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { NestFactory } from "@nestjs/core";
import {
  FastifyAdapter,
  NestFastifyApplication,
} from "@nestjs/platform-fastify";
import { DocumentBuilder, SwaggerModule } from "@nestjs/swagger";
import helmet from "@fastify/helmet";

import { AppModule } from "./app.module";
import { ApiExceptionFilter } from "./http/api-exception.filter";

async function bootstrap(): Promise<void> {
  const adapter = new FastifyAdapter({
    bodyLimit: 1024 * 1024,
    connectionTimeout: 10_000,
    requestTimeout: 10_000,
    trustProxy: true,
    genReqId: () => crypto.randomUUID(),
  });
  const app = await NestFactory.create<NestFastifyApplication>(
    AppModule,
    adapter,
    {
      logger: new ConsoleLogger({ json: true }),
    },
  );
  const config = app.get(ConfigService);

  await app.register(helmet, { global: true });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: false,
    }),
  );
  app.useGlobalFilters(new ApiExceptionFilter());
  app.enableShutdownHooks();

  if (config.get("NODE_ENV") !== "production") {
    const swaggerConfig = new DocumentBuilder()
      .setTitle("Weyonje API")
      .setVersion("0.1.0")
      .addBearerAuth()
      .build();
    SwaggerModule.setup(
      "internal/docs",
      app,
      SwaggerModule.createDocument(app, swaggerConfig),
    );
  }

  await app.listen({
    port: config.getOrThrow<number>("PORT"),
    host: "0.0.0.0",
  });
}

void bootstrap();
