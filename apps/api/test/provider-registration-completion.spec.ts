import { plainToInstance } from "class-transformer";
import { validateSync } from "class-validator";
import { RegistrationService } from "../src/registration/registration.service";
import { ServiceProviderRegistrationDto } from "../src/registration/registration.dto";
import { PrismaService } from "../src/database/prisma.service";
import { PhoneChallengeService } from "../src/registration/phone-challenge.service";
import { PhoneSecurityService } from "../src/registration/phone-security.service";
import { EmailSecurityService } from "../src/auth/email-security.service";
import { SessionService } from "../src/auth/session.service";
import { testAuthConfig } from "./support/auth-config";

// Transactional persistence fake: tests the use-case boundary, not PostgreSQL locks.
function harness(enabled: boolean, overrides: Record<string, unknown> = {}) {
  let user: Record<string, unknown> = {
    id: "provider",
    actorType: "SERVICE_PROVIDER",
    phoneVerifiedAt: null,
    passwordVersion: 1,
    providerStatus: "PENDING",
    isActive: false,
    loginEnabled: false,
    serviceProviderProfile: { providerNumber: null },
    ...overrides,
  };
  let consumed = false;
  let rows: Array<{ table: string; data: Record<string, unknown> }> = [];
  const insert = (table: string) => ({
    create: jest.fn(async ({ data }: { data: Record<string, unknown> }) => {
      rows.push({ table, data });
      return data;
    }),
  });
  const tx = {
    $queryRaw: jest.fn().mockResolvedValue([]),
    user: {
      findUnique: jest.fn(async () => user),
      update: jest.fn(async ({ data }: { data: Record<string, unknown> }) => {
        user = { ...user, ...data };
        return user;
      }),
    },
    serviceProviderProfile: {
      update: jest.fn(async ({ data }: { data: Record<string, unknown> }) => {
        rows.push({ table: "profile", data });
      }),
    },
    clientProfile: { update: jest.fn() },
    providerApprovalDecisionRecord: insert("decision"),
    providerStatusHistory: insert("history"),
    auditEvent: insert("audit"),
    registrationNotification: insert("registrationNotification"),
    operationalNotification: insert("notification"),
    outboxEvent: insert("outbox"),
  };
  const sessions = {
    create: jest.fn(async () => {
      rows.push({ table: "session", data: {} });
      return { accessToken: "test" };
    }),
  };
  const challenges = {
    verifyAndComplete: jest.fn(
      async (
        _id: string,
        _code: string,
        purpose: string,
        complete: (id: string, tx: object) => Promise<unknown>,
      ) => {
        expect(purpose).toBe("REGISTRATION");
        if (consumed) throw new Error("consumed");
        const snapshot = structuredClone({ user, rows });
        consumed = true;
        try {
          return await complete("provider", tx);
        } catch (error) {
          user = snapshot.user;
          rows = snapshot.rows;
          consumed = false;
          throw error;
        }
      },
    ),
  };
  const config = testAuthConfig({
    serviceProviderAutoApprovalEnabled: enabled,
  });
  const service = new RegistrationService(
    {} as PrismaService,
    new EmailSecurityService(config),
    new PhoneSecurityService(config),
    challenges as unknown as PhoneChallengeService,
    sessions as unknown as SessionService,
    config,
  );
  return {
    service,
    tx,
    sessions,
    user: () => user,
    rows: () => rows,
    consumed: () => consumed,
  };
}

describe("Provider registration policy completion", () => {
  it.each([false, true])(
    "completes verification atomically with policy=%s",
    async (enabled) => {
      const h = harness(enabled);
      await h.service.verifyPhone("challenge", "001234");
      expect(h.user()).toMatchObject({
        loginEnabled: true,
        isActive: enabled,
        providerStatus: enabled ? "APPROVED" : "PENDING",
        phoneVerifiedAt: expect.any(Date),
      });
      expect(h.tx.$queryRaw).toHaveBeenCalledTimes(1);
      expect(h.sessions.create).toHaveBeenCalledWith(
        expect.objectContaining({ id: "provider" }),
        h.tx,
      );
      const rows = h.rows();
      if (enabled) {
        expect(
          rows.find((r) => r.table === "profile")?.data.providerNumber,
        ).toMatch(/^WSP-[A-F0-9]{12}$/);
        expect(rows.find((r) => r.table === "decision")?.data).toMatchObject({
          decidedByUserId: null,
          provenance: "SYSTEM_REGISTRATION_POLICY",
          decision: "APPROVED",
        });
        expect(rows.find((r) => r.table === "history")?.data).toMatchObject({
          changedByUserId: null,
          provenance: "SYSTEM_REGISTRATION_POLICY",
          fromStatus: "PENDING",
          toStatus: "APPROVED",
        });
        expect(
          rows.find((r) => r.table === "audit")?.data.actorUserId,
        ).toBeNull();
        expect(
          rows.find((r) => r.table === "notification")?.data.message,
        ).toContain("automatically approved");
        expect(
          rows.some((r) => r.data.type === "PROVIDER_REVIEW_REQUIRED"),
        ).toBe(false);
      } else {
        expect(rows.map((r) => r.table)).toEqual([
          "registrationNotification",
          "session",
        ]);
        expect(rows[0]?.data.type).toBe("PROVIDER_REVIEW_REQUIRED");
      }
      await expect(
        h.service.verifyPhone("challenge", "001234"),
      ).rejects.toThrow("consumed");
      expect(h.rows()).toHaveLength(rows.length);
    },
  );
  it.each([
    "profile",
    "decision",
    "history",
    "audit",
    "registrationNotification",
    "notification",
    "outbox",
    "session",
  ])("rolls back when %s fails and permits retry", async (stage) => {
    const h = harness(true);
    const operation = {
      profile: h.tx.serviceProviderProfile.update,
      decision: h.tx.providerApprovalDecisionRecord.create,
      history: h.tx.providerStatusHistory.create,
      audit: h.tx.auditEvent.create,
      registrationNotification: h.tx.registrationNotification.create,
      notification: h.tx.operationalNotification.create,
      outbox: h.tx.outboxEvent.create,
      session: h.sessions.create,
    }[stage];
    operation!.mockRejectedValueOnce(new Error("write failed"));
    await expect(h.service.verifyPhone("challenge", "001234")).rejects.toThrow(
      "write failed",
    );
    expect(h.user()).toMatchObject({
      phoneVerifiedAt: null,
      loginEnabled: false,
      providerStatus: "PENDING",
    });
    expect(h.rows()).toEqual([]);
    expect(h.consumed()).toBe(false);
    await h.service.verifyPhone("challenge", "001234");
    expect(h.rows().filter((r) => r.table === "decision")).toHaveLength(1);
  });
  it.each([
    { phoneVerifiedAt: new Date() },
    { providerStatus: "REJECTED" },
    { providerStatus: "INACTIVE" },
    { providerStatus: "DISABLED" },
    { loginEnabled: true },
    { isActive: true },
    { serviceProviderProfile: { providerNumber: "WSP-EXISTING" } },
  ])("does not resurrect or renumber %j", async (state) => {
    const h = harness(true, state);
    await expect(
      h.service.verifyPhone("challenge", "001234"),
    ).rejects.toThrow();
    expect(h.rows()).toEqual([]);
    expect(h.consumed()).toBe(false);
  });
  it("accepts password-free business fields and still requires contact email", () => {
    const data = {
      essLicenseNumber: "ESS-42",
      companyName: "Example",
      phoneNumber: "0700000123",
      email: "contact@example.test",
      workAddress: "Nakawa",
      providerType: "GULPER",
      contactPersonName: "Contact",
      contactPersonPhone: "0701000123",
    };
    expect(
      validateSync(plainToInstance(ServiceProviderRegistrationDto, data)),
    ).toEqual([]);
    expect(
      validateSync(
        plainToInstance(ServiceProviderRegistrationDto, {
          ...data,
          email: undefined,
        }),
      ).some((e) => e.property === "email"),
    ).toBe(true);
    expect(
      validateSync(
        plainToInstance(ServiceProviderRegistrationDto, {
          ...data,
          password: "legacy",
        }),
        { whitelist: true, forbidNonWhitelisted: true },
      ).some((e) => e.property === "password"),
    ).toBe(true);
  });
});
