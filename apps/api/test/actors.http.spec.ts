import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import {
  FastifyAdapter,
  NestFastifyApplication,
} from "@nestjs/platform-fastify";
import { ActorAccess, ActorType } from "@weyonje/contracts";
import request from "supertest";

import { AccessTokenGuard } from "../src/auth/access-token.guard";
import { ActorsController } from "../src/identity/actors.controller";
import { CurrentActorService } from "../src/identity/current-actor.service";

describe("GET /v1/actors/me", () => {
  let app: INestApplication;
  const resolve = jest.fn();

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [ActorsController],
      providers: [{ provide: CurrentActorService, useValue: { resolve } }],
    })
      .overrideGuard(AccessTokenGuard)
      .useValue({
        canActivate: (context: {
          switchToHttp(): { getRequest(): object };
        }) => {
          Object.assign(context.switchToHttp().getRequest(), {
            authenticatedActor: { sessionId: "hidden", user: { id: "hidden" } },
          });
          return true;
        },
      })
      .compile();
    app = module.createNestApplication<NestFastifyApplication>(
      new FastifyAdapter(),
    );
    await app.init();
    await app.getHttpAdapter().getInstance().ready();
  });

  afterAll(async () => app?.close());

  it("returns only routing eligibility fields", async () => {
    resolve.mockReturnValueOnce({
      actorType: ActorType.client,
      access: ActorAccess.eligible,
    });
    const response = await request(app.getHttpServer())
      .get("/v1/actors/me")
      .expect(200);
    expect(response.body).toEqual({ actorType: "CLIENT", access: "ELIGIBLE" });
    expect(response.text).not.toMatch(
      /phone|email|password|token|session|route/i,
    );
  });
});
