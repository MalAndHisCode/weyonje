import { Module } from "@nestjs/common";
import { NestFactory } from "@nestjs/core";
import {
  FastifyAdapter,
  NestFastifyApplication,
} from "@nestjs/platform-fastify";
import { DocumentBuilder, OpenAPIObject, SwaggerModule } from "@nestjs/swagger";

import { ActorsController } from "../src/identity/actors.controller";
import { CurrentActorService } from "../src/identity/current-actor.service";
import { JwtAuthGuard } from "../src/identity/jwt-auth.guard";

@Module({
  controllers: [ActorsController],
  providers: [
    { provide: CurrentActorService, useValue: { resolve: () => undefined } },
    { provide: JwtAuthGuard, useValue: { canActivate: () => true } },
  ],
})
class OpenApiModule {}

export async function generateOpenApiDocument(): Promise<OpenAPIObject> {
  const app = await NestFactory.create<NestFastifyApplication>(
    OpenApiModule,
    new FastifyAdapter(),
    {
      logger: false,
    },
  );
  const config = new DocumentBuilder()
    .setTitle("Weyonje API")
    .setDescription(
      "Authoritative identity and eligibility capabilities for Weyonje clients.",
    )
    .setVersion("0.1.0")
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  await app.close();
  return document;
}
