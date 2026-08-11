import { plainToInstance, Transform } from "class-transformer";
import {
  IsBoolean,
  IsIn,
  IsInt,
  IsNotEmpty,
  IsString,
  IsUrl,
  Max,
  Min,
  validateSync,
} from "class-validator";

export class Environment {
  @IsIn(["development", "test", "production"])
  NODE_ENV = "development";

  @IsString()
  @IsNotEmpty()
  WEYONJE_ENVIRONMENT!: string;

  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(1)
  @Max(65535)
  PORT = 3000;

  @IsUrl({ require_tld: false, protocols: ["https"] })
  KEYCLOAK_ISSUER!: string;

  @IsUrl({ require_tld: false, protocols: ["https"] })
  KEYCLOAK_JWKS_URI!: string;

  @IsString()
  @IsNotEmpty()
  KEYCLOAK_AUDIENCE!: string;

  @IsString()
  @IsNotEmpty()
  KEYCLOAK_ALLOWED_ALGORITHMS = "RS256";

  @IsString()
  @IsNotEmpty()
  KEYCLOAK_CLIENT_ROLE!: string;

  @IsString()
  @IsNotEmpty()
  KEYCLOAK_PROVIDER_ROLE!: string;

  @IsString()
  @IsNotEmpty()
  KEYCLOAK_KCCA_MOBILE_ROLE!: string;

  @IsString()
  @IsNotEmpty()
  DATABASE_HOST!: string;

  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(1)
  @Max(65535)
  DATABASE_PORT = 5432;

  @IsString()
  @IsNotEmpty()
  DATABASE_NAME!: string;

  @IsString()
  @IsNotEmpty()
  DATABASE_USER!: string;

  @IsString()
  @IsNotEmpty()
  DATABASE_PASSWORD!: string;

  @Transform(({ value }) => String(value).toLowerCase() === "true")
  @IsBoolean()
  DATABASE_SSL = true;
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
  if (errors.length > 0) {
    const fields = errors.map((error) => error.property).join(", ");
    throw new Error(`Invalid or missing configuration: ${fields}`);
  }
  return config;
}
