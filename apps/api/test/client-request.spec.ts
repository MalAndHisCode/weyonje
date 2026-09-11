import { plainToInstance } from "class-transformer";
import { validate } from "class-validator";
import { RequestLocationKind, ScheduleMode } from "@weyonje/contracts";
import {
  CallCentreCreateRequestDto,
  CreateClientServiceRequestDto,
} from "../src/workflows/workflow.dto";
import { WorkflowService } from "../src/workflows/workflow.service";

const client = {
  user: { id: "client", actorType: "CLIENT", isActive: true },
} as never;
const base = {
  idempotencyKey: "d5784cb8-6bf8-493a-9036-151ca0d75c5c",
  locationKind: RequestLocationKind.mapPin,
  location: { latitude: 0.3, longitude: 32.5 },
  scheduleMode: ScheduleMode.asSoonAsPossible,
};

describe("Client request profile and ingress", () => {
  const findUnique = jest.fn();
  const service = new WorkflowService(
    { user: { findUnique } } as never,
    {
      decrypt: (value: string) => `phone:${value}`,
      normalize: (value: string) => value,
      encrypt: (value: string) => value,
    } as never,
    { decrypt: (value: string) => `email:${value}` } as never,
    {} as never,
    {} as never,
    {} as never,
  );
  beforeEach(() => findUnique.mockReset());

  it.each([
    [
      { clientType: "INDIVIDUAL", firstName: "Amina", lastName: "Test" },
      "Amina Test",
    ],
    [
      { clientType: "ORGANIZATION", organizationName: "Test Company" },
      "Test Company",
    ],
  ])("reads only the authenticated Client profile", async (profile, name) => {
    findUnique.mockResolvedValue({
      encryptedPhone: "protected",
      clientProfile: profile,
    });
    await expect(service.clientProfile(client)).resolves.toEqual({
      clientName: name,
      phoneNumber: "phone:protected",
    });
    expect(findUnique.mock.calls[0][0].where).toEqual({ id: "client" });
  });

  it("includes email only when present and rejects other actors", async () => {
    findUnique.mockResolvedValue({
      encryptedPhone: "protected",
      encryptedEmail: "protected",
      clientProfile: {
        clientType: "INDIVIDUAL",
        firstName: "Amina",
        lastName: "Test",
      },
    });
    expect(await service.clientProfile(client)).toHaveProperty(
      "emailAddress",
      "email:protected",
    );
    await expect(
      service.clientProfile({
        user: { actorType: "KCCA_STAFF", isActive: true },
      } as never),
    ).rejects.toThrow("Only an active Client");
    await expect(
      service.clientProfile({
        user: { actorType: "CLIENT", isActive: false },
      } as never),
    ).rejects.toThrow("Only an active Client");
  });

  it("requires toilet type before any Client database write", async () => {
    await expect(service.createClientRequest(client, base)).rejects.toThrow(
      "Select the type of toilet",
    );
    expect(findUnique).not.toHaveBeenCalled();
    const errors = await validate(
      plainToInstance(CreateClientServiceRequestDto, base),
    );
    expect(errors.map((error) => error.property)).toContain("toiletType");
    expect(
      await validate(
        plainToInstance(CreateClientServiceRequestDto, {
          ...base,
          toiletType: "PIT_LATRINE",
        }),
      ),
    ).toEqual([]);
  });

  it("keeps Call Centre toilet type optional", async () => {
    const errors = await validate(
      plainToInstance(CallCentreCreateRequestDto, {
        ...base,
        clientName: "Amina",
        clientPhone: "0700000123",
      }),
    );
    expect(errors.map((error) => error.property)).not.toContain("toiletType");
  });
});
