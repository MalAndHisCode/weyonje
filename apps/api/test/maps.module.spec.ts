import { Global, Module } from "@nestjs/common";
import {
  FastifyAdapter,
  NestFastifyApplication,
} from "@nestjs/platform-fastify";
import { Test } from "@nestjs/testing";

import { SessionService } from "../src/auth/session.service";
import { TokenService } from "../src/auth/token.service";
import { authConfig } from "../src/config/auth.config";
import { smsConfig } from "../src/config/sms.config";
import { PrismaService } from "../src/database/prisma.service";
import { MapsModule } from "../src/maps/maps.module";
import { MapsService } from "../src/maps/maps.service";
import { testAuthConfig } from "./support/auth-config";

@Global()
@Module({
  providers: [
    { provide: authConfig.KEY, useValue: testAuthConfig() },
    { provide: smsConfig.KEY, useValue: { provider: "FAKE" } },
    { provide: PrismaService, useValue: {} },
  ],
  exports: [authConfig.KEY, smsConfig.KEY, PrismaService],
})
class TestInfrastructureModule {}

describe("MapsModule authentication wiring", () => {
  let app: NestFastifyApplication;
  const maps = { search: jest.fn().mockResolvedValue([]) };
  const sessions = {
    authenticateAccess: jest.fn().mockResolvedValue({ userId: "user-1" }),
  };

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      imports: [TestInfrastructureModule, MapsModule],
    })
      .overrideProvider(MapsService)
      .useValue(maps)
      .overrideProvider(SessionService)
      .useValue(sessions)
      .compile();
    app = module.createNestApplication<NestFastifyApplication>(
      new FastifyAdapter(),
    );
    await app.init();
    await app.getHttpAdapter().getInstance().ready();
  });

  afterAll(async () => app?.close());

  it("initializes the real module and rejects unauthenticated requests", async () => {
    const response = await app.inject({
      method: "POST",
      url: "/v1/maps/search",
      payload: { text: "Kampala" },
    });
    expect(response.statusCode).toBe(401);
    expect(maps.search).not.toHaveBeenCalled();
  });

  it("uses the imported token and session services for authenticated requests", async () => {
    const { token } = await app
      .get(TokenService)
      .issueAccessToken("user-1", "session-1");
    const response = await app.inject({
      method: "POST",
      url: "/v1/maps/search",
      headers: { authorization: `Bearer ${token}` },
      payload: { text: "Kampala" },
    });
    expect(response.statusCode).toBe(201);
    expect(sessions.authenticateAccess).toHaveBeenCalledWith(
      "user-1",
      "session-1",
    );
    expect(maps.search).toHaveBeenCalledWith("Kampala");
  });
});
