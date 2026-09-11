import {
  ActorType,
  ClientType,
  ProviderApprovalDecision,
  ServiceProviderType,
} from "@weyonje/contracts";

import { EmailSecurityService } from "../src/auth/email-security.service";
import { AuthenticatedActor } from "../src/auth/authenticated-actor";
import { testAuthConfig } from "./support/auth-config";
import { SessionService } from "../src/auth/session.service";
import { PrismaService } from "../src/database/prisma.service";
import { PhoneChallengePurpose } from "../src/generated/prisma/enums";
import { PhoneChallengeService } from "../src/registration/phone-challenge.service";
import { PhoneSecurityService } from "../src/registration/phone-security.service";
import { RegistrationService } from "../src/registration/registration.service";

describe("RegistrationService submissions", () => {
  function harness() {
    const user = {
      findFirst: jest.fn().mockResolvedValue(null),
      create: jest.fn().mockResolvedValue({ id: "user-1" }),
    };
    const prisma = { user } as unknown as PrismaService;
    const emails = {
      normalize: jest.fn((value: string) => value.trim().toLowerCase()),
      lookup: jest.fn((value: string) => `email-lookup:${value}`),
      encrypt: jest.fn((value: string) => `encrypted-email:${value}`),
    } as unknown as EmailSecurityService;
    const phones = {
      normalize: jest.fn((value: string) =>
        value.startsWith("+") ? value : "+256700000123",
      ),
      lookup: jest.fn((value: string) => `phone-lookup:${value}`),
      encrypt: jest.fn((value: string) => `encrypted-phone:${value}`),
    } as unknown as PhoneSecurityService;
    const challenge = {
      create: jest.fn().mockResolvedValue({ challengeId: "challenge-1" }),
    } as unknown as PhoneChallengeService;
    const service = new RegistrationService(
      prisma,
      emails,
      phones,
      challenge,
      {} as SessionService,
      testAuthConfig(),
    );
    return { service, user, emails, phones, challenge };
  }

  it("persists a Client without email or password and starts phone verification", async () => {
    const value = harness();
    await value.service.registerClient({
      clientType: ClientType.individual,
      firstName: " Amina ",
      lastName: " N. ",
      phoneNumber: "0700000123",
    });

    expect(value.emails.normalize).not.toHaveBeenCalled();
    expect(value.user.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          encryptedEmail: null,
          emailLookup: null,
          passwordHash: null,
          actorType: "CLIENT",
          clientProfile: {
            create: expect.objectContaining({
              clientType: "INDIVIDUAL",
              firstName: "Amina",
              lastName: "N.",
            }),
          },
        }),
      }),
    );
    expect(value.challenge.create).toHaveBeenCalledWith(
      "+256700000123",
      PhoneChallengePurpose.REGISTRATION,
      "user-1",
    );
  });

  it("persists a password-free Provider with mandatory email", async () => {
    const value = harness();
    await value.service.registerServiceProvider({
      essLicenseNumber: "ESS-42",
      companyName: "Clean Kampala Ltd",
      phoneNumber: "+256700000123",
      email: " Ops@Example.test ",
      workAddress: "Nakawa",
      providerType: ServiceProviderType.gulper,
      contactPersonName: "Amina",
      contactPersonPhone: "+256701000123",
    });

    expect(value.user.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          encryptedEmail: "encrypted-email:ops@example.test",
          emailLookup: "email-lookup:ops@example.test",
          passwordHash: null,
          actorType: "SERVICE_PROVIDER",
          providerStatus: "PENDING",
          serviceProviderProfile: {
            create: expect.objectContaining({
              essLicenseNumber: "ESS-42",
              providerType: "GULPER",
            }),
          },
        }),
      }),
    );
  });

  it("resumes a pending Client without overwriting the profile or creating a duplicate", async () => {
    const value = harness();
    value.user.findFirst.mockResolvedValueOnce({ id: "pending-client" });
    await value.service.registerClient({
      clientType: ClientType.individual,
      firstName: "New",
      lastName: "Submission",
      phoneNumber: "0700000123",
    });
    expect(value.user.create).not.toHaveBeenCalled();
    expect(value.challenge.create).toHaveBeenCalledWith(
      "+256700000123",
      PhoneChallengePurpose.REGISTRATION,
      "pending-client",
    );
  });

  it("resumes an unverified pending Provider without replacing any profile data", async () => {
    const h = harness();
    h.user.findFirst.mockResolvedValueOnce({ id: "pending-provider" });
    await h.service.registerServiceProvider({
      essLicenseNumber: "new-value",
      companyName: "Replacement attempt",
      email: "different@example.test",
      phoneNumber: "0700000123",
      workAddress: "Different",
      providerType: ServiceProviderType.gulper,
      contactPersonName: "Different",
      contactPersonPhone: "+256701000123",
    });
    expect(h.user.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          phoneLookup: "phone-lookup:+256700000123",
          actorType: "SERVICE_PROVIDER",
          phoneVerifiedAt: null,
          loginEnabled: false,
          isActive: false,
          providerStatus: "PENDING",
        },
      }),
    );
    expect(h.user.create).not.toHaveBeenCalled();
    expect(h.challenge.create).toHaveBeenCalledWith(
      "+256700000123",
      "REGISTRATION",
      "pending-provider",
    );
  });

  it("requires a reason before a KCCA rejection can reach persistence", async () => {
    const value = harness();
    const reviewer = {
      user: {
        id: "kcca-1",
        actorType: ActorType.kccaStaff,
        isActive: true,
        providerApprovalPermitted: true,
      },
    } as AuthenticatedActor;
    await expect(
      value.service.decideProvider(reviewer, "provider-1", {
        decision: ProviderApprovalDecision.rejected,
      }),
    ).rejects.toMatchObject({
      response: { message: "A rejection reason is required." },
    });
  });
});
