import { ExecutionContext, ValidationPipe } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import {
  FastifyAdapter,
  NestFastifyApplication,
} from "@nestjs/platform-fastify";
import { AccessTokenGuard } from "../src/auth/access-token.guard";
import { ApiExceptionFilter } from "../src/http/api-exception.filter";
import { ClientWorkflowController } from "../src/workflows/workflow.controller";
import { WorkflowService } from "../src/workflows/workflow.service";
import { PhoneSecurityService } from "../src/registration/phone-security.service";

const mobilePayload = {
  idempotencyKey: "d5784cb8-6bf8-493a-9036-151ca0d75c5c",
  locationKind: "CURRENT",
  location: { latitude: 0.312345678, longitude: 32.512345678 },
  toiletType: "PIT_LATRINE",
  scheduleMode: "AS_SOON_AS_POSSIBLE",
};

describe("Client creation HTTP boundary with real service and isolated persistence fake", () => {
  let app: NestFastifyApplication;
  let stored: Record<string, unknown> | undefined;
  let replay: Record<string, unknown> | undefined;
  let actorType = "CLIENT";
  const phones = new PhoneSecurityService({
    piiEncryptionKey: Buffer.alloc(32, 7),
  } as never);
  const create = jest.fn(
    async ({ data }: { data: Record<string, unknown> }) => {
      stored = {
        ...data,
        id: "d5784cb8-6bf8-493a-9036-151ca0d75c5d",
        status: "PENDING",
        createdAt: new Date(),
        updatedAt: new Date(),
        agreedPriceUgx: null,
      };
      return { id: stored.id };
    },
  );
  const history = jest.fn();
  const audit = jest.fn();
  const outbox = jest.fn();
  const tx = {
    serviceRequest: { create },
    requestStatusHistory: { create: history },
    auditEvent: { create: audit },
    operationalNotification: {
      create: jest.fn(async () => ({ id: "notification" })),
    },
    outboxEvent: { create: outbox },
    idempotencyRecord: {
      findUnique: jest.fn(async () => replay),
      create: jest.fn(async ({ data }: { data: Record<string, unknown> }) => {
        replay = data;
      }),
    },
  };
  const prisma = {
    user: {
      findUnique: jest.fn(async () => ({
        encryptedPhone: phones.encrypt("+256700000123"),
        clientProfile: {
          clientType: "INDIVIDUAL",
          firstName: "Amina",
          lastName: "Test",
        },
      })),
    },
    serviceRequest: { findFirst: jest.fn(async () => stored) },
    $transaction: jest.fn(
      async (work: (value: typeof tx) => Promise<unknown>) => work(tx),
    ),
  };
  beforeAll(async () => {
    const service = new WorkflowService(
      prisma as never,
      phones,
      {} as never,
      {} as never,
      {} as never,
      { offsetsMinutes: [120] } as never,
    );
    const module = await Test.createTestingModule({
      controllers: [ClientWorkflowController],
      providers: [{ provide: WorkflowService, useValue: service }],
    })
      .overrideGuard(AccessTokenGuard)
      .useValue({
        canActivate: (context: ExecutionContext) => {
          context.switchToHttp().getRequest().authenticatedActor = {
            user: { id: "client", actorType, isActive: true },
          };
          return true;
        },
      })
      .compile();
    app = module.createNestApplication<NestFastifyApplication>(
      new FastifyAdapter(),
    );
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: false,
      }),
    );
    app.useGlobalFilters(new ApiExceptionFilter());
    await app.init();
    await app.getHttpAdapter().getInstance().ready();
  });
  beforeEach(() => {
    stored = undefined;
    replay = undefined;
    actorType = "CLIENT";
    jest.clearAllMocks();
  });
  afterAll(async () => app.close());
  const post = (payload: Record<string, unknown>) =>
    app.inject({ method: "POST", url: "/v1/client/requests", payload });
  it.each([
    ["CURRENT", "PIT_LATRINE"],
    ["CURRENT", "SEPTIC_TANK"],
    ["MAP_PIN", "PIT_LATRINE"],
    ["MAP_PIN", "SEPTIC_TANK"],
  ])(
    "creates %s / %s and returns persisted details with unchanged retry",
    async (locationKind, toiletType) => {
      const payload = { ...mobilePayload, locationKind, toiletType };
      const response = await post(payload);
      expect(response.statusCode).toBe(201);
      expect(response.json()).toMatchObject({
        clientName: "Amina Test",
        status: "PENDING",
        locationKind,
        toiletType,
        location: mobilePayload.location,
        scheduleMode: mobilePayload.scheduleMode,
      });
      expect(stored).toMatchObject({
        clientUserId: "client",
        latitude: mobilePayload.location.latitude,
        locationText: null,
        requestedServiceAt: null,
      });
      expect(history).toHaveBeenCalledTimes(1);
      expect(audit).toHaveBeenCalledTimes(1);
      expect(outbox).toHaveBeenCalledTimes(1);
      const retry = await post(payload);
      expect(retry.json()).toEqual(response.json());
      expect(create).toHaveBeenCalledTimes(1);
      const detail = await app.inject({
        method: "GET",
        url: "/v1/client/requests/" + response.json().id,
      });
      expect(detail.statusCode).toBe(200);
      expect(detail.json()).toEqual(response.json());
    },
  );
  it("normalizes valid additional contacts and encrypts persistence", async () => {
    const response = await post({
      ...mobilePayload,
      additionalContactName: " Contact ",
      additionalContactPhone: "0700000123",
    });
    expect(response.statusCode).toBe(201);
    expect(response.json()).toMatchObject({
      additionalContactName: "Contact",
      additionalContactPhone: "+256700000123",
    });
    expect(stored?.encryptedAdditionalPhone).not.toBe("0700000123");
  });
  it("reproduces the old mobile schedule rejection safely before persistence", async () => {
    const response = await post({ ...mobilePayload, scheduleMode: "ASAP" });
    expect(response.statusCode).toBe(400);
    expect(response.json()).toMatchObject({
      code: "INVALID_REQUEST",
      message:
        "The service timing is unsupported. Update the app and try again.",
    });
    expect(create).not.toHaveBeenCalled();
  });
  it.each([
    { toiletType: undefined },
    { toiletType: "OTHER" },
    { idempotencyKey: "bad" },
    { locationKind: "MAP" },
    { location: { latitude: "0.3", longitude: 32 } },
    { location: { latitude: 91, longitude: 32 } },
    { location: { latitude: 0, longitude: -181 } },
    { locationText: "private coordinates" },
    { requestedServiceAt: "2026-10-01T00:00:00Z" },
    { clientName: "untrusted" },
    { additionalContactName: "" },
    { additionalContactName: "Contact" },
    { additionalContactPhone: "0700000123" },
    {
      additionalContactName: "Contact",
      additionalContactPhone: "invalid-private-phone",
    },
  ])("safely rejects malformed input %#", async (change) => {
    const response = await post({ ...mobilePayload, ...change });
    expect(response.statusCode).toBe(400);
    expect(response.json()).toMatchObject({
      code: "INVALID_REQUEST",
      requestId: expect.any(String),
    });
    expect(response.json().message).not.toBe("The request is invalid.");
    expect(response.body).not.toMatch(
      /invalid-private-phone|private coordinates|untrusted|target|stack/,
    );
    expect(create).not.toHaveBeenCalled();
  });
  it("retains Client-only service authorization", async () => {
    actorType = "SERVICE_PROVIDER";
    expect((await post(mobilePayload)).statusCode).toBe(403);
    expect(create).not.toHaveBeenCalled();
  });
});
