import { plainToInstance, Transform } from "class-transformer";
import {
  IsIn,
  IsInt,
  IsNotEmpty,
  IsString,
  Max,
  Min,
  validateSync,
} from "class-validator";

const SECRET_FIELDS = [
  "ACCESS_TOKEN_SECRET",
  "EMAIL_ENCRYPTION_KEY",
  "EMAIL_LOOKUP_KEY",
  "REFRESH_TOKEN_HASH_KEY",
  "THROTTLE_HASH_KEY",
  "PII_ENCRYPTION_KEY",
  "PHONE_LOOKUP_KEY",
  "OTP_HASH_KEY",
] as const;

export class Environment {
  @IsIn(["development", "test", "production"])
  NODE_ENV = "development";

  @IsIn(["local", "development", "test", "production"])
  WEYONJE_ENVIRONMENT!: string;

  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(1)
  @Max(65535)
  PORT = 3000;

  @IsString()
  @IsNotEmpty()
  DATABASE_URL!: string;

  @IsString()
  @IsNotEmpty()
  DIRECT_URL!: string;

  @IsString()
  @IsNotEmpty()
  AUTH_ISSUER!: string;

  @IsString()
  @IsNotEmpty()
  AUTH_AUDIENCE!: string;

  @IsString()
  @IsNotEmpty()
  ACCESS_TOKEN_SECRET!: string;

  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(60)
  @Max(3600)
  ACCESS_TOKEN_TTL_SECONDS = 600;

  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(3600)
  @Max(2_592_000)
  REFRESH_TOKEN_TTL_SECONDS = 604_800;

  @IsString()
  @IsNotEmpty()
  EMAIL_ENCRYPTION_KEY!: string;

  @IsString()
  @IsNotEmpty()
  EMAIL_LOOKUP_KEY!: string;

  @IsString()
  @IsNotEmpty()
  REFRESH_TOKEN_HASH_KEY!: string;

  @IsString()
  @IsNotEmpty()
  THROTTLE_HASH_KEY!: string;

  @IsString()
  @IsNotEmpty()
  PII_ENCRYPTION_KEY!: string;

  @IsString()
  @IsNotEmpty()
  PHONE_LOOKUP_KEY!: string;

  @IsString()
  @IsNotEmpty()
  OTP_HASH_KEY!: string;

  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(3)
  @Max(20)
  AUTH_ACCOUNT_MAX_ATTEMPTS = 5;

  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(5)
  @Max(100)
  AUTH_IP_MAX_ATTEMPTS = 20;

  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(60)
  @Max(3600)
  AUTH_THROTTLE_WINDOW_SECONDS = 900;

  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(60)
  @Max(3600)
  AUTH_LOCK_SECONDS = 900;

  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(300)
  @Max(1800)
  OTP_TTL_SECONDS = 600;

  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(30)
  @Max(300)
  OTP_RESEND_SECONDS = 60;

  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(3)
  @Max(10)
  OTP_MAX_ATTEMPTS = 5;

  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(2)
  @Max(20)
  OTP_MAX_REQUESTS_PER_HOUR = 5;
}

export function validateEnvironment(
  values: Record<string, unknown>,
): Environment {
  const config = plainToInstance(Environment, values, {
    enableImplicitConversion: false,
  });
  const errors = validateSync(config, {
    skipMissingProperties: false,
    whitelist: true,
  });
  const invalid = new Set(errors.map((error) => error.property));

  for (const field of ["DATABASE_URL", "DIRECT_URL"] as const) {
    if (!isPostgresUrl(config[field])) invalid.add(field);
  }
  if (!isSecureIssuer(config.AUTH_ISSUER)) invalid.add("AUTH_ISSUER");
  if (looksLikePlaceholder(config.AUTH_AUDIENCE)) invalid.add("AUTH_AUDIENCE");

  const decodedSecrets = new Map<string, string>();
  for (const field of SECRET_FIELDS) {
    const decoded = decodeSecret(config[field], 32);
    if (!decoded || looksLikePlaceholder(config[field])) {
      invalid.add(field);
    } else if (
      (field === "EMAIL_ENCRYPTION_KEY" || field === "PII_ENCRYPTION_KEY") &&
      decoded.length !== 32
    ) {
      invalid.add(field);
    } else {
      const fingerprint = decoded.toString("hex");
      const previous = decodedSecrets.get(fingerprint);
      if (previous) {
        invalid.add(previous);
        invalid.add(field);
      }
      decodedSecrets.set(fingerprint, field);
    }
  }

  if (
    config.WEYONJE_ENVIRONMENT === "production" &&
    config.NODE_ENV !== "production"
  ) {
    invalid.add("NODE_ENV");
  }
  if (invalid.size > 0) {
    throw new Error(
      `Invalid or missing configuration: ${[...invalid].sort().join(", ")}`,
    );
  }
  return config;
}

export function decodeSecret(
  value: unknown,
  minimumBytes: number,
): Buffer | null {
  if (
    typeof value !== "string" ||
    !/^[A-Za-z0-9+/]+={0,2}$/.test(value) ||
    value.length % 4 !== 0
  ) {
    return null;
  }
  const decoded = Buffer.from(value, "base64");
  return decoded.length >= minimumBytes ? decoded : null;
}

function isPostgresUrl(value: string): boolean {
  try {
    const url = new URL(value);
    return (
      (url.protocol === "postgresql:" || url.protocol === "postgres:") &&
      Boolean(url.hostname) &&
      Boolean(url.username) &&
      !looksLikePlaceholder(value)
    );
  } catch {
    return false;
  }
}

function isSecureIssuer(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === "https:" && !looksLikePlaceholder(value);
  } catch {
    return false;
  }
}

function looksLikePlaceholder(value: string): boolean {
  return /(?:example\.invalid|placeholder|change[-_ ]?me|<[^>]+>|your[-_])/i.test(
    value,
  );
}
