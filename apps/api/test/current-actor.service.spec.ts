import { ForbiddenException } from "@nestjs/common";
import { ActorAccess, ActorType, ProviderStatus } from "@weyonje/contracts";

import { AuthenticatedActor } from "../src/auth/authenticated-actor";
import { CurrentActorService } from "../src/identity/current-actor.service";

function actor(
  overrides: Partial<AuthenticatedActor["user"]> = {},
): AuthenticatedActor {
  return {
    sessionId: "session-1",
    user: {
      id: "user-1",
      actorType: ActorType.client,
      providerStatus: null,
      isActive: true,
      loginEnabled: true,
      emailVerifiedAt: new Date(),
      phoneVerifiedAt: null,
      mobileMonitoringPermitted: false,
      providerApprovalPermitted: false,
      callCentreOperationsPermitted: false,
      passwordVersion: 1,
      serviceProviderProfile: null,
      ...overrides,
    },
  } as AuthenticatedActor;
}

describe("CurrentActorService", () => {
  const service = new CurrentActorService();

  it("makes only an active Client eligible", () => {
    expect(service.resolve(actor())).toEqual({
      actorType: ActorType.client,
      access: ActorAccess.eligible,
      emailVerified: true,
    });
    expect(service.resolve(actor({ isActive: false }))).toMatchObject({
      access: ActorAccess.denied,
    });
  });

  it.each([
    [ProviderStatus.approved, true, ActorAccess.eligible],
    [ProviderStatus.approved, false, ActorAccess.restricted],
    [ProviderStatus.pending, true, ActorAccess.restricted],
    [ProviderStatus.rejected, true, ActorAccess.restricted],
    [ProviderStatus.inactive, true, ActorAccess.restricted],
    [ProviderStatus.disabled, true, ActorAccess.restricted],
  ])("resolves %s active=%s as %s", (providerStatus, isActive, access) => {
    expect(
      service.resolve(
        actor({
          actorType: ActorType.serviceProvider,
          providerStatus,
          isActive,
          serviceProviderProfile: {
            providerNumber: null,
            latestRejectionReason: null,
          },
        }),
      ),
    ).toEqual({
      actorType: ActorType.serviceProvider,
      access,
      emailVerified: true,
      providerStatus,
    });
  });

  it("returns provider approval details without exposing them to other actors", () => {
    expect(
      service.resolve(
        actor({
          actorType: ActorType.serviceProvider,
          providerStatus: ProviderStatus.rejected,
          serviceProviderProfile: {
            providerNumber: null,
            latestRejectionReason: "ESS licence could not be validated.",
          },
        }),
      ),
    ).toMatchObject({
      providerRejectionReason: "ESS licence could not be validated.",
    });
  });

  it.each([
    [true, true, ActorAccess.eligible],
    [true, false, ActorAccess.denied],
    [false, true, ActorAccess.denied],
  ])(
    "resolves KCCA active=%s permitted=%s as %s",
    (isActive, mobileMonitoringPermitted, access) => {
      expect(
        service.resolve(
          actor({
            actorType: ActorType.kccaStaff,
            isActive,
            mobileMonitoringPermitted,
          }),
        ),
      ).toEqual({
        actorType: ActorType.kccaStaff,
        access,
        emailVerified: true,
        mobileMonitoringPermitted,
        providerApprovalPermitted: false,
        callCentreOperationsPermitted: false,
      });
    },
  );

  it("allows KCCA administration without granting journey monitoring", () => {
    expect(
      service.resolve(
        actor({
          actorType: ActorType.kccaStaff,
          providerApprovalPermitted: true,
          mobileMonitoringPermitted: false,
        }),
      ),
    ).toMatchObject({
      access: ActorAccess.eligible,
      mobileMonitoringPermitted: false,
      providerApprovalPermitted: true,
    });
  });

  it.each([
    actor({ actorType: ActorType.serviceProvider, providerStatus: null }),
    actor({
      actorType: ActorType.client,
      providerStatus: ProviderStatus.pending,
    }),
    actor({ actorType: ActorType.client, mobileMonitoringPermitted: true }),
    actor({
      actorType: ActorType.client,
      serviceProviderProfile: {
        providerNumber: null,
        latestRejectionReason: null,
      },
    }),
    actor({ actorType: "UNKNOWN" as never }),
  ])("fails closed for inconsistent or unknown records", (value) => {
    expect(() => service.resolve(value)).toThrow(ForbiddenException);
  });
});
