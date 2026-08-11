import { INestApplication, ValidationPipe } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import {
  FastifyAdapter,
  NestFastifyApplication,
} from "@nestjs/platform-fastify";
import request from "supertest";

import { AuthController } from "../src/auth/auth.controller";
import { AuthService } from "../src/auth/auth.service";
import { SessionService } from "../src/auth/session.service";
import { SignedAccessTokenGuard } from "../src/auth/signed-access-token.guard";

describe("native authentication HTTP contract", () => {
  let app: INestApplication;
  const credentials = {
    accessToken: "access-value",
    refreshToken: "refresh-value",
    accessTokenExpiresAt: "2026-08-11T12:10:00.000Z",
    refreshTokenExpiresAt: "2026-08-18T12:00:00.000Z",
  };
  const auth = {
    signIn: jest.fn().mockResolvedValue(credentials),
    refresh: jest.fn().mockResolvedValue(credentials),
  };
  const sessions = { signOut: jest.fn().mockResolvedValue(undefined) };

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [
        { provide: AuthService, useValue: auth },
        { provide: SessionService, useValue: sessions },
      ],
    })
      .overrideGuard(SignedAccessTokenGuard)
      .useValue({
        canActivate: (context: {
          switchToHttp(): { getRequest(): object };
        }) => {
          Object.assign(context.switchToHttp().getRequest(), {
            accessTokenClaims: { sessionId: "session-1", userId: "user-1" },
          });
          return true;
        },
      })
      .compile();
    app = module.createNestApplication<NestFastifyApplication>(
      new FastifyAdapter(),
    );
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true }),
    );
    await app.init();
    await app.getHttpAdapter().getInstance().ready();
  });

  afterAll(async () => app.close());

  it("signs in without returning actor or private profile data", async () => {
    const response = await request(app.getHttpServer())
      .post("/v1/auth/sign-in")
      .send({ email: "account@example.test", password: "not-a-real-password" })
      .expect(200);
    expect(response.body).toEqual(credentials);
    expect(response.text).not.toMatch(
      /actor|provider|email|password|sessionId/i,
    );
  });

  it.each([
    [{ email: "bad", password: "value" }],
    [{ email: "account@example.test" }],
    [{ email: "account@example.test", password: "value", unexpected: true }],
  ])("rejects malformed sign-in input", async (body) => {
    await request(app.getHttpServer())
      .post("/v1/auth/sign-in")
      .send(body)
      .expect(400);
  });

  it("rotates credentials through the refresh endpoint", async () => {
    await request(app.getHttpServer())
      .post("/v1/auth/refresh")
      .send({ refreshToken: "r".repeat(48) })
      .expect(200, credentials);
  });

  it("signs out idempotently through the authenticated session", async () => {
    await request(app.getHttpServer())
      .post("/v1/auth/sign-out")
      .set("Authorization", "Bearer opaque")
      .send({})
      .expect(200, { signedOut: true });
    expect(sessions.signOut).toHaveBeenCalledWith("user-1", "session-1");
  });
});
