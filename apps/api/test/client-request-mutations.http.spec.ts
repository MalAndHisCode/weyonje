import { ExecutionContext, ValidationPipe } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import {
  FastifyAdapter,
  NestFastifyApplication,
} from "@nestjs/platform-fastify";
import { randomUUID } from "node:crypto";
import { AccessTokenGuard } from "../src/auth/access-token.guard";
import { ApiExceptionFilter } from "../src/http/api-exception.filter";
import { ClientWorkflowController } from "../src/workflows/workflow.controller";
import { WorkflowService } from "../src/workflows/workflow.service";
import { PhoneSecurityService } from "../src/registration/phone-security.service";

// Transactional persistence fake: tests HTTP/service rules and rollback, NOT
// PostgreSQL isolation. Real races live in the opt-in PostgreSQL suite.
describe("Client mutation HTTP boundary (persistence fake)", () => {
  let app: NestFastifyApplication;
  let service: WorkflowService;
  let row: any;
  let records: Map<string, any>;
  let history: any[];
  let audits: any[];
  let actor: any;
  let failAudit = false;
  let failResponse = false;
  const id = randomUUID();
  const owner = randomUUID();
  const phones = new PhoneSecurityService({
    piiEncryptionKey: Buffer.alloc(32, 7),
  } as never);
  const matches = (where: any) =>
    Object.entries(where).every(([key, value]) => {
      if (key === "assignments" || key === "journeys")
        return row[key].length === 0;
      if (value instanceof Date) return row[key].getTime() === value.getTime();
      return row[key] === value;
    });
  const recordKey = (where: any) =>
    JSON.stringify(where.actorUserId_operation_key);
  const tx = {
    serviceRequest: {
      findFirst: jest.fn(async ({ where }: any) =>
        matches(where) ? row : null,
      ),
      updateMany: jest.fn(async ({ where, data }: any) => {
        if (!matches(where)) return { count: 0 };
        row = { ...row, ...data };
        return { count: 1 };
      }),
    },
    requestStatusHistory: {
      create: jest.fn(async ({ data }: any) => {
        history.push(data);
      }),
    },
    auditEvent: {
      create: jest.fn(async ({ data }: any) => {
        if (failAudit) throw new Error("synthetic audit failure");
        audits.push(data);
      }),
    },
    idempotencyRecord: {
      findUnique: jest.fn(async ({ where }: any) =>
        records.get(recordKey(where)),
      ),
      create: jest.fn(async ({ data }: any) =>
        records.set(
          recordKey({
            actorUserId_operation_key: {
              actorUserId: data.actorUserId,
              operation: data.operation,
              key: data.key,
            },
          }),
          data,
        ),
      ),
    },
  };
  const prisma = {
    serviceRequest: {
      findFirst: async ({ where }: any) => {
        if (failResponse) {
          failResponse = false;
          throw new Error("synthetic post-commit response failure");
        }
        return matches(where) ? row : null;
      },
      findMany: async ({ where }: any) =>
        where.status === "PENDING" && row.status !== "PENDING" ? [] : [row],
    },
    $transaction: async (work: (value: typeof tx) => Promise<unknown>) => {
      const before = {
        row: { ...row },
        records: new Map(records),
        history: [...history],
        audits: [...audits],
      };
      try {
        return await work(tx);
      } catch (error) {
        ({ row, records, history, audits } = before);
        throw error;
      }
    },
  };
  beforeAll(async () => {
    service = new WorkflowService(
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
          context.switchToHttp().getRequest().authenticatedActor = actor;
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
  afterAll(async () => app.close());
  beforeEach(() => {
    actor = { user: { id: owner, actorType: "CLIENT", isActive: true } };
    row = {
      id,
      reference: "WRQ-LEGACY123456",
      clientUserId: owner,
      origin: "MOBILE_APP",
      status: "PENDING",
      acceptedProviderUserId: null,
      acceptedAt: null,
      updatedAt: new Date("2026-01-01T00:00:00.000Z"),
      createdAt: new Date("2026-01-01T00:00:00.000Z"),
      clientName: "Test Client",
      encryptedClientPhone: phones.encrypt("+256700000123"),
      locationKind: "CURRENT",
      locationText: null,
      latitude: 0.3,
      longitude: 32.5,
      toiletType: null,
      scheduleMode: "SCHEDULED",
      requestedServiceAt: new Date("2026-02-01T12:00:00Z"),
      agreedPriceUgx: null,
      assignments: [],
      journeys: [],
      collectionReport: null,
      feedback: null,
    };
    records = new Map();
    history = [];
    audits = [];
    failAudit = false;
    failResponse = false;
    jest.clearAllMocks();
  });
  const payload = () => ({
    idempotencyKey: randomUUID(),
    expectedUpdatedAt: row.updatedAt.toISOString(),
    locationKind: "MAP_PIN",
    location: { latitude: 0.4, longitude: 32.6 },
    toiletType: "SEPTIC_TANK",
    additionalContactName: null,
    additionalContactPhone: null,
  });
  const update = (body = payload()) =>
    app.inject({
      method: "PUT",
      url: `/v1/client/requests/${id}`,
      payload: body,
    });
  const withdraw = (
    body = {
      idempotencyKey: randomUUID(),
      expectedUpdatedAt: row.updatedAt.toISOString(),
    },
  ) =>
    app.inject({
      method: "POST",
      url: `/v1/client/requests/${id}/withdraw`,
      payload: body,
    });

  it.each([
    "SERVICE_PROVIDER",
    "KCCA_STAFF",
    "INACTIVE",
    "OTHER_CLIENT",
    "CALL_CENTRE",
  ])("denies %s on both mutations", async (role) => {
    if (role === "CALL_CENTRE") row.origin = role;
    else if (role === "OTHER_CLIENT") actor.user.id = randomUUID();
    else if (role === "INACTIVE") actor.user.isActive = false;
    else actor.user.actorType = role;
    expect([403, 404]).toContain((await update()).statusCode);
    expect([403, 404]).toContain((await withdraw()).statusCode);
    expect(tx.serviceRequest.updateMany).not.toHaveBeenCalled();
    expect(audits).toHaveLength(0);
  });
  it.each([
    "ACCEPTED",
    "ACTIVE",
    "COLLECTION_REPORTED",
    "COLLECTION_COMPLETED",
    "FOLLOW_UP_REQUIRED",
    "COMPLETED",
    "CANCELLED",
  ])("rejects %s without changes", async (status) => {
    row.status = status;
    expect((await update()).statusCode).toBe(409);
    expect((await withdraw()).statusCode).toBe(409);
    expect(row.status).toBe(status);
    expect(audits).toHaveLength(0);
  });
  it.each([
    "acceptedProviderUserId",
    "acceptedAt",
    "assignments",
    "journeys",
    "feedback",
    "collectionReport",
  ])("enforces invariant %s in conditional mutation", async (field) => {
    row[field] = ["assignments", "journeys"].includes(field) ? [{}] : "present";
    expect((await update()).statusCode).toBe(409);
    expect((await withdraw()).statusCode).toBe(409);
  });
  it.each([
    ["CURRENT", "PIT_LATRINE"],
    ["MAP_PIN", "SEPTIC_TANK"],
  ])(
    "replaces %s/%s preserving ID, legacy reference and past scheduling",
    async (locationKind, toiletType) => {
      const body = {
        ...payload(),
        locationKind,
        toiletType,
        additionalContactName: "Contact",
        additionalContactPhone: "0700000123",
      };
      const response = await update(body as any);
      expect(response.statusCode).toBe(200);
      expect(response.json()).toMatchObject({
        id,
        reference: "WRQ-LEGACY123456",
        locationKind,
        toiletType,
        additionalContactPhone: "+256700000123",
        scheduleMode: "SCHEDULED",
        requestedServiceAt: "2026-02-01T12:00:00.000Z",
      });
      expect((await update()).statusCode).toBe(200);
      expect(row.additionalContactName).toBeNull();
      expect(row.encryptedAdditionalPhone).toBeNull();
      expect(history).toHaveLength(0);
      expect(audits).toHaveLength(2);
    },
  );
  it("rejects stale edits, same-key payload mismatch and preserves current state on old replay", async () => {
    const first = payload();
    expect((await update(first)).statusCode).toBe(200);
    expect((await update(first)).statusCode).toBe(200);
    expect(audits).toHaveLength(1);
    expect(
      (await update({ ...first, toiletType: "PIT_LATRINE" })).statusCode,
    ).toBe(409);
    expect(
      (await update({ ...first, idempotencyKey: randomUUID() })).statusCode,
    ).toBe(409);
    expect((await withdraw()).statusCode).toBe(200);
    expect((await update(first)).json().status).toBe("CANCELLED");
    expect(audits).toHaveLength(2);
  });
  it("withdraws once, retains evidence, and excludes terminal work from dashboard and Provider lists", async () => {
    const body = {
      idempotencyKey: randomUUID(),
      expectedUpdatedAt: row.updatedAt.toISOString(),
    };
    expect((await withdraw(body)).statusCode).toBe(200);
    expect((await withdraw(body)).statusCode).toBe(200);
    expect(history).toEqual([
      expect.objectContaining({
        fromStatus: "PENDING",
        toStatus: "CANCELLED",
        actorUserId: owner,
      }),
    ]);
    expect(audits).toEqual([
      expect.objectContaining({ action: "request.withdrawn" }),
    ]);
    expect(await service.clientDashboard(actor)).toMatchObject({
      pendingCount: 0,
      activeCount: 0,
      actionRequiredCount: 0,
    });
    expect(
      await service.pendingProviderRequests({
        user: {
          id: randomUUID(),
          actorType: "SERVICE_PROVIDER",
          isActive: true,
          providerStatus: "APPROVED",
          loginEnabled: true,
        },
      } as never),
    ).toEqual([]);
    expect(row.id).toBe(id);
    expect(row.reference).toBe("WRQ-LEGACY123456");
  });
  it.each(["update", "withdraw"])(
    "recovers %s post-commit response failure and rolls back audit failure",
    async (operation) => {
      const body =
        operation === "update"
          ? payload()
          : {
              idempotencyKey: randomUUID(),
              expectedUpdatedAt: row.updatedAt.toISOString(),
            };
      const send = () =>
        operation === "update" ? update(body as any) : withdraw(body);
      failAudit = true;
      expect((await send()).statusCode).toBe(500);
      expect(row.updatedAt.toISOString()).toBe(body.expectedUpdatedAt);
      expect(records.size).toBe(0);
      expect(history).toHaveLength(0);
      failAudit = false;
      failResponse = true;
      expect((await send()).statusCode).toBe(500);
      expect(records.size).toBe(1);
      expect(audits).toHaveLength(1);
      expect((await send()).statusCode).toBe(200);
      expect(audits).toHaveLength(1);
    },
  );
  it.each([
    { status: "CANCELLED" },
    { scheduleMode: "AS_SOON_AS_POSSIBLE" },
    { clientUserId: "someone" },
    { reference: "KCCA-X" },
    { location: { latitude: 91, longitude: 32 } },
    { toiletType: null },
    { additionalContactName: undefined },
    { additionalContactName: "Name" },
  ])("rejects invalid or server-managed fields %j", async (extra) => {
    expect((await update({ ...payload(), ...extra } as any)).statusCode).toBe(
      400,
    );
    expect(audits).toHaveLength(0);
  });
});
