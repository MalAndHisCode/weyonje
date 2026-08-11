import { PrismaPg } from "@prisma/adapter-pg";
import { execFileSync } from "node:child_process";
import { randomUUID } from "node:crypto";
import { resolve } from "node:path";

import { PrismaClient } from "../src/generated/prisma/client";
import { ActorType } from "../src/generated/prisma/enums";

const runtimeUrl = process.env.TEST_DATABASE_URL;
const directUrl = process.env.TEST_DIRECT_URL;
const describePostgres = runtimeUrl && directUrl ? describe : describe.skip;

describePostgres("opt-in isolated PostgreSQL migration and constraints", () => {
  jest.setTimeout(60_000);
  let prisma: PrismaClient;

  beforeAll(async () => {
    execFileSync(
      process.platform === "win32" ? "pnpm.cmd" : "pnpm",
      ["prisma", "migrate", "deploy"],
      {
        cwd: resolve(__dirname, ".."),
        env: { ...process.env, DIRECT_URL: directUrl! },
        stdio: "pipe",
      },
    );
    prisma = new PrismaClient({
      adapter: new PrismaPg({ connectionString: runtimeUrl! }),
    });
    await prisma.$connect();
  });

  afterAll(async () => prisma?.$disconnect());

  it("enforces protected-email uniqueness and Provider consistency", async () => {
    const lookup = Buffer.from(randomUUID()).toString("base64url");
    const base = {
      encryptedEmail: "v1.synthetic.encrypted.payload",
      emailLookup: lookup,
      passwordHash: "$argon2id$synthetic-not-usable",
      actorType: ActorType.CLIENT,
      emailVerifiedAt: new Date(),
    };
    const user = await prisma.user.create({ data: base, select: { id: true } });
    try {
      await expect(prisma.user.create({ data: base })).rejects.toBeDefined();
      await expect(
        prisma.user.create({
          data: {
            ...base,
            emailLookup: Buffer.from(randomUUID()).toString("base64url"),
            actorType: ActorType.SERVICE_PROVIDER,
          },
        }),
      ).rejects.toBeDefined();
    } finally {
      await prisma.user.delete({ where: { id: user.id } });
    }
  });

  it("cascades sessions and hashed refresh tokens with user cleanup", async () => {
    const user = await prisma.user.create({
      data: {
        encryptedEmail: "v1.synthetic.encrypted.payload",
        emailLookup: Buffer.from(randomUUID()).toString("base64url"),
        passwordHash: "$argon2id$synthetic-not-usable",
        actorType: ActorType.CLIENT,
        emailVerifiedAt: new Date(),
      },
      select: { id: true },
    });
    const session = await prisma.authenticationSession.create({
      data: {
        userId: user.id,
        familyId: randomUUID(),
        passwordVersion: 1,
        absoluteExpiresAt: new Date(Date.now() + 60_000),
        refreshTokens: {
          create: {
            tokenHash: Buffer.from(randomUUID()).toString("base64url"),
            expiresAt: new Date(Date.now() + 60_000),
          },
        },
      },
      select: { id: true },
    });
    await prisma.user.delete({ where: { id: user.id } });
    await expect(
      prisma.authenticationSession.count({ where: { id: session.id } }),
    ).resolves.toBe(0);
    await expect(
      prisma.refreshToken.count({ where: { sessionId: session.id } }),
    ).resolves.toBe(0);
  });
});
