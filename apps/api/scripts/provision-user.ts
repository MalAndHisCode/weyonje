import "reflect-metadata";

import { BadRequestException } from "@nestjs/common";
import { PrismaPg } from "@prisma/adapter-pg";
import { config } from "dotenv";
import { resolve } from "node:path";
import { createInterface } from "node:readline/promises";
import { stdin, stdout } from "node:process";

import { EmailSecurityService } from "../src/auth/email-security.service";
import { PasswordService } from "../src/auth/password.service";
import { buildAuthConfig } from "../src/config/auth.config";
import { validateEnvironment } from "../src/config/environment";
import { PrismaClient } from "../src/generated/prisma/client";
import { ActorType, ProviderStatus } from "../src/generated/prisma/enums";

config({ path: resolve(__dirname, "../../../.env") });

interface ProvisioningOptions {
  actorType: ActorType;
  providerStatus: ProviderStatus | null;
  mobileMonitoringPermitted: boolean;
  callCentreOperationsPermitted: boolean;
  emailVerified: boolean;
  active: boolean;
  loginEnabled: boolean;
}

async function main(): Promise<void> {
  const environment = validateEnvironment(process.env);
  if (environment.WEYONJE_ENVIRONMENT === "production") {
    throw new Error("Development user provisioning is disabled in production.");
  }
  const options = parseOptions(process.argv.slice(2));
  const authentication = buildAuthConfig(environment);
  const emails = new EmailSecurityService(authentication);
  const passwords = new PasswordService(authentication);
  const prisma = new PrismaClient({
    adapter: new PrismaPg({ connectionString: environment.DIRECT_URL }),
  });
  await prisma.$connect();
  try {
    const email = await promptLine("Email: ");
    const password = await promptSecret("Password: ");
    const confirmation = await promptSecret("Confirm password: ");
    if (password !== confirmation) throw new Error("Passwords do not match.");

    const normalizedEmail = emails.normalize(email);
    passwords.validateForProvisioning(password);
    try {
      await prisma.user.create({
        data: {
          encryptedEmail: emails.encrypt(normalizedEmail),
          emailLookup: emails.lookup(normalizedEmail),
          passwordHash: await passwords.hash(password),
          actorType: options.actorType,
          providerStatus: options.providerStatus,
          isActive: options.active,
          loginEnabled: options.loginEnabled,
          emailVerifiedAt: options.emailVerified ? new Date() : null,
          mobileMonitoringPermitted: options.mobileMonitoringPermitted,
          callCentreOperationsPermitted: options.callCentreOperationsPermitted,
        },
        select: { id: true },
      });
      stdout.write("Development account created.\n");
    } catch (error) {
      if (isUniqueConstraint(error)) {
        throw new Error("An account with that email already exists.");
      }
      throw error;
    }
  } finally {
    await prisma.$disconnect();
  }
}

function parseOptions(args: string[]): ProvisioningOptions {
  const value = (name: string) => {
    const index = args.indexOf(name);
    return index < 0 ? undefined : args[index + 1];
  };
  const actorValue = value("--actor-type");
  if (!Object.values(ActorType).includes(actorValue as ActorType)) {
    throw new Error(
      "--actor-type must be CLIENT, SERVICE_PROVIDER, or KCCA_STAFF.",
    );
  }
  const actorType = actorValue as ActorType;
  const providerValue = value("--provider-status");
  const providerStatus = providerValue as ProviderStatus | undefined;
  if (actorType === ActorType.SERVICE_PROVIDER) {
    if (!Object.values(ProviderStatus).includes(providerStatus!)) {
      throw new Error("Service Providers require a valid --provider-status.");
    }
  } else if (providerValue !== undefined) {
    throw new Error("Only Service Providers may have --provider-status.");
  }
  const mobileMonitoringPermitted = args.includes("--kcca-mobile-monitoring");
  const callCentreOperationsPermitted = args.includes(
    "--call-centre-operations",
  );
  if (mobileMonitoringPermitted && actorType !== ActorType.KCCA_STAFF) {
    throw new Error(
      "Mobile monitoring permission is only valid for KCCA Staff.",
    );
  }
  if (callCentreOperationsPermitted && actorType !== ActorType.KCCA_STAFF) {
    throw new Error(
      "Call Centre operations permission is only valid for KCCA Staff.",
    );
  }
  return {
    actorType,
    providerStatus:
      actorType === ActorType.SERVICE_PROVIDER ? providerStatus! : null,
    mobileMonitoringPermitted,
    callCentreOperationsPermitted,
    emailVerified: args.includes("--email-verified"),
    active: !args.includes("--inactive"),
    loginEnabled: !args.includes("--login-disabled"),
  };
}

async function promptLine(label: string): Promise<string> {
  if (!stdin.isTTY || !stdout.isTTY) {
    throw new Error("Provisioning requires an interactive terminal.");
  }
  const readline = createInterface({ input: stdin, output: stdout });
  try {
    return await readline.question(label);
  } finally {
    readline.close();
  }
}

async function promptSecret(label: string): Promise<string> {
  if (!stdin.isTTY || !stdout.isTTY || !stdin.setRawMode) {
    throw new Error("A terminal capable of masked input is required.");
  }
  stdout.write(label);
  stdin.setRawMode(true);
  stdin.setEncoding("utf8");
  return new Promise<string>((resolve, reject) => {
    let value = "";
    const cleanup = () => {
      stdin.off("data", onData);
      stdin.off("end", onEnd);
      stdin.off("error", onError);
      stdin.setRawMode(false);
      stdin.pause();
    };
    const succeed = () => {
      cleanup();
      stdout.write("\n");
      resolve(value);
    };
    const fail = (error: Error) => {
      cleanup();
      reject(error);
    };
    const onData = (chunk: string | Buffer) => {
      const text = typeof chunk === "string" ? chunk : chunk.toString("utf8");
      for (const character of text) {
        if (character === "\r" || character === "\n") {
          succeed();
          return;
        }
        if (character === "\u0003") {
          fail(new Error("Provisioning cancelled."));
          return;
        }
        if (character === "\b" || character === "\u007f") {
          value = value.slice(0, -1);
        } else if (character >= " ") {
          value += character;
        }
      }
    };
    const onEnd = () => fail(new Error("Password input ended unexpectedly."));
    const onError = (error: Error) => fail(error);

    stdin.on("data", onData);
    stdin.once("end", onEnd);
    stdin.once("error", onError);
    stdin.resume();
  });
}

function isUniqueConstraint(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    error.code === "P2002"
  );
}

void main().catch((error: unknown) => {
  const message =
    error instanceof BadRequestException
      ? "The account details are invalid."
      : error instanceof Error
        ? error.message
        : "Provisioning failed.";
  process.stderr.write(`${message}\n`);
  process.exitCode = 1;
});
