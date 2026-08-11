import { registerAs } from "@nestjs/config";

export interface IdentityConfig {
  issuer: string;
  jwksUri: string;
  audience: string;
  algorithms: string[];
  roles: {
    client: string;
    provider: string;
    kccaMobile: string;
  };
}

export const identityConfig = registerAs("identity", (): IdentityConfig => ({
  issuer: process.env.KEYCLOAK_ISSUER!,
  jwksUri: process.env.KEYCLOAK_JWKS_URI!,
  audience: process.env.KEYCLOAK_AUDIENCE!,
  algorithms: process.env
    .KEYCLOAK_ALLOWED_ALGORITHMS!.split(",")
    .map((value) => value.trim()),
  roles: {
    client: process.env.KEYCLOAK_CLIENT_ROLE!,
    provider: process.env.KEYCLOAK_PROVIDER_ROLE!,
    kccaMobile: process.env.KEYCLOAK_KCCA_MOBILE_ROLE!,
  },
}));
