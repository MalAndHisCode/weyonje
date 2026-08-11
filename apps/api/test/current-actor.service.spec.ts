import { ForbiddenException } from "@nestjs/common";
import { ActorAccess, ActorType, ProviderStatus } from "@weyonje/contracts";
import { Repository } from "typeorm";

import { IdentityConfig } from "../src/config/identity.config";
import { ActorProfileEntity } from "../src/identity/actor-profile.entity";
import { CurrentActorService } from "../src/identity/current-actor.service";

const config: IdentityConfig = {
  issuer: "https://identity.example.test/realms/weyonje",
  jwksUri: "https://identity.example.test/certs",
  audience: "weyonje-api-test",
  algorithms: ["RS256"],
  roles: { client: "client", provider: "provider", kccaMobile: "kcca-mobile" },
};

function profile(overrides: Partial<ActorProfileEntity>): ActorProfileEntity {
  return Object.assign(new ActorProfileEntity(), {
    id: "f59d0ecf-12f2-4727-8096-a25df3127688",
    keycloakSubject: "subject-1",
    actorType: ActorType.client,
    providerStatus: null,
    isActive: true,
    mobileMonitoringPermitted: false,
    createdAt: new Date(0),
    updatedAt: new Date(0),
    ...overrides,
  });
}

function serviceFor(value: ActorProfileEntity | null): CurrentActorService {
  const repository = {
    findOne: jest.fn().mockResolvedValue(value),
  } as unknown as Repository<ActorProfileEntity>;
  return new CurrentActorService(repository, config);
}

describe("CurrentActorService", () => {
  it("allows an active client with the matching identity role", async () => {
    await expect(
      serviceFor(profile({})).resolve({
        subject: "subject-1",
        roles: new Set(["client"]),
      }),
    ).resolves.toEqual({
      actorType: ActorType.client,
      access: ActorAccess.eligible,
    });
  });

  it.each([
    ProviderStatus.pending,
    ProviderStatus.rejected,
    ProviderStatus.inactive,
    ProviderStatus.disabled,
  ])("restricts a %s provider from provider work", async (providerStatus) => {
    const result = await serviceFor(
      profile({ actorType: ActorType.serviceProvider, providerStatus }),
    ).resolve({ subject: "subject-1", roles: new Set(["provider"]) });
    expect(result).toEqual({
      actorType: ActorType.serviceProvider,
      access: ActorAccess.restricted,
      providerStatus,
    });
  });

  it("allows only an approved and active provider", async () => {
    await expect(
      serviceFor(
        profile({
          actorType: ActorType.serviceProvider,
          providerStatus: ProviderStatus.approved,
        }),
      ).resolve({ subject: "subject-1", roles: new Set(["provider"]) }),
    ).resolves.toEqual({
      actorType: ActorType.serviceProvider,
      access: ActorAccess.eligible,
      providerStatus: ProviderStatus.approved,
    });

    await expect(
      serviceFor(
        profile({
          actorType: ActorType.serviceProvider,
          providerStatus: ProviderStatus.approved,
          isActive: false,
        }),
      ).resolve({ subject: "subject-1", roles: new Set(["provider"]) }),
    ).resolves.toMatchObject({ access: ActorAccess.restricted });
  });

  it("allows only explicitly permitted active KCCA mobile staff", async () => {
    const eligible = serviceFor(
      profile({
        actorType: ActorType.kccaStaff,
        mobileMonitoringPermitted: true,
      }),
    );
    await expect(
      eligible.resolve({
        subject: "subject-1",
        roles: new Set(["kcca-mobile"]),
      }),
    ).resolves.toEqual({
      actorType: ActorType.kccaStaff,
      access: ActorAccess.eligible,
    });

    const unpermitted = serviceFor(profile({ actorType: ActorType.kccaStaff }));
    await expect(
      unpermitted.resolve({
        subject: "subject-1",
        roles: new Set(["kcca-mobile"]),
      }),
    ).resolves.toEqual({
      actorType: ActorType.kccaStaff,
      access: ActorAccess.denied,
    });
  });

  it.each([
    ["unknown subject", null, new Set(["client"])],
    ["missing role", profile({}), new Set<string>()],
    [
      "unrecognized provider state",
      profile({ actorType: ActorType.serviceProvider, providerStatus: null }),
      new Set(["provider"]),
    ],
  ])(
    "denies %s without leaking profile data",
    async (_name, actorProfile, roles) => {
      try {
        await serviceFor(actorProfile).resolve({ subject: "unknown", roles });
        throw new Error("Expected access to be denied");
      } catch (error) {
        expect(error).toBeInstanceOf(ForbiddenException);
        expect(
          JSON.stringify((error as ForbiddenException).getResponse()),
        ).not.toContain("subject-1");
        expect(
          JSON.stringify((error as ForbiddenException).getResponse()),
        ).not.toContain("f59d0ecf");
      }
    },
  );
});
