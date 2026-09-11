import { Prisma } from "../generated/prisma/client";

export type ClientRequestStage =
  | "normalization"
  | "profile_lookup"
  | "transaction"
  | "idempotency_lookup"
  | "request_create"
  | "request_update"
  | "history_write"
  | "audit_write"
  | "notification_write"
  | "outbox_write"
  | "reminder_write"
  | "idempotency_write"
  | "transaction_completion"
  | "idempotency_recovery"
  | "detail_read"
  | "detail_mapping";

const stages = new WeakMap<object, ClientRequestStage>();

// Attach owned stage labels without mutating or wrapping Prisma/HTTP errors:
// existing transaction conflict handling and client contracts remain intact.
export async function atClientRequestStage<T>(
  stage: ClientRequestStage,
  work: () => Promise<T>,
): Promise<T> {
  try {
    return await work();
  } catch (error) {
    if (typeof error === "object" && error !== null && !stages.has(error)) {
      stages.set(error, stage);
    }
    throw error;
  }
}

export type RequestStageRunner = typeof atClientRequestStage;
export const withoutDiagnostics: RequestStageRunner = (_stage, work) => work();

export function safeFailureDiagnostics(error: unknown) {
  const stage =
    typeof error === "object" && error !== null ? stages.get(error) : undefined;
  let category = "unknown";
  let prismaCode: string | undefined;
  if (error instanceof Prisma.PrismaClientKnownRequestError) {
    category = "prisma_known_request";
    // Do not include messages, metadata, SQL, stack or arbitrary code values.
    if (
      new Set([
        "P1000",
        "P1001",
        "P1002",
        "P1003",
        "P1008",
        "P1010",
        "P1011",
        "P1017",
        "P2000",
        "P2002",
        "P2003",
        "P2004",
        "P2010",
        "P2011",
        "P2021",
        "P2022",
        "P2024",
        "P2025",
        "P2028",
        "P2034",
      ]).has(error.code)
    )
      prismaCode = error.code;
  } else if (error instanceof Prisma.PrismaClientInitializationError) {
    category = "prisma_initialization";
  } else if (error instanceof Prisma.PrismaClientValidationError) {
    category = "prisma_validation";
  } else if (error instanceof Prisma.PrismaClientUnknownRequestError) {
    category = "prisma_unknown_request";
  } else if (error instanceof TypeError) category = "type_error";
  else if (error instanceof RangeError) category = "range_error";
  else if (error instanceof Error) category = "error";
  return {
    category,
    ...(stage ? { stage } : {}),
    ...(prismaCode ? { prismaCode } : {}),
  };
}
