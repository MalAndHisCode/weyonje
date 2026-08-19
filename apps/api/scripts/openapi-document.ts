import { Module } from "@nestjs/common";
import { NestFactory } from "@nestjs/core";
import {
  FastifyAdapter,
  NestFastifyApplication,
} from "@nestjs/platform-fastify";
import { DocumentBuilder, OpenAPIObject, SwaggerModule } from "@nestjs/swagger";

import { AccessTokenGuard } from "../src/auth/access-token.guard";
import { AuthController } from "../src/auth/auth.controller";
import { AuthService } from "../src/auth/auth.service";
import { SessionService } from "../src/auth/session.service";
import { ActorsController } from "../src/identity/actors.controller";
import { CurrentActorService } from "../src/identity/current-actor.service";
import {
  ProviderRegistrationController,
  RegistrationController,
} from "../src/registration/registration.controller";
import { RegistrationService } from "../src/registration/registration.service";
import {
  CallCentreWorkflowController,
  ClientWorkflowController,
  JourneyController,
  KccaWorkflowController,
  NotificationController,
  ProviderWorkflowController,
  WorkflowConfigController,
} from "../src/workflows/workflow.controller";
import { WorkflowService } from "../src/workflows/workflow.service";

@Module({
  controllers: [
    AuthController,
    ActorsController,
    RegistrationController,
    ProviderRegistrationController,
    WorkflowConfigController,
    ClientWorkflowController,
    ProviderWorkflowController,
    CallCentreWorkflowController,
    KccaWorkflowController,
    JourneyController,
    NotificationController,
  ],
  providers: [
    { provide: AuthService, useValue: {} },
    { provide: SessionService, useValue: {} },
    { provide: CurrentActorService, useValue: { resolve: () => undefined } },
    { provide: RegistrationService, useValue: {} },
    { provide: WorkflowService, useValue: {} },
    { provide: AccessTokenGuard, useValue: { canActivate: () => true } },
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
      "Native authentication, server-managed sessions, and authoritative eligibility for Weyonje clients.",
    )
    .setVersion("0.1.0")
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  await app.close();
  return document;
}
