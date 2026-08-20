import {
  CreateServiceRequestContract,
  RequestLocationKind,
  ScheduleMode,
} from "@weyonje/contracts";

import {
  hasConsecutiveArrivalEvidence,
  WorkflowService,
} from "../src/workflows/workflow.service";

describe("WorkflowService request policy", () => {
  const policy = {
    provisional: true as const,
    sampleIntervalSeconds: 15,
    sampleDistanceMetres: 25,
    arrivalRadiusMetres: 75,
    arrivalMaximumAccuracyMetres: 50,
    staleAfterSeconds: 60,
    retentionDays: 90,
    backgroundTrackingEnabled: true,
    approvalNotice: "Requires KCCA approval.",
  };

  const service = new WorkflowService(
    {} as never,
    {
      normalize: (value: string) => value,
      encrypt: (value: string) => value,
    } as never,
    {} as never,
    {} as never,
    policy,
    { offsetsMinutes: [120] } as never,
  );

  const validate = (input: CreateServiceRequestContract) =>
    (
      service as unknown as {
        validateRequestInput(value: CreateServiceRequestContract): {
          latitude: number | null;
          longitude: number | null;
          requestedServiceAt: Date | null;
        };
      }
    ).validateRequestInput(input);

  it("exposes the initial location values as provisional configuration", () => {
    expect(service.locationPolicy()).toEqual(policy);
  });

  it("accepts ASAP without a requested instant and normalizes text location", () => {
    expect(
      validate({
        idempotencyKey: "d5784cb8-6bf8-493a-9036-151ca0d75c5c",
        locationKind: RequestLocationKind.text,
        locationText: "  Nakawa  ",
        scheduleMode: ScheduleMode.asSoonAsPossible,
      }),
    ).toMatchObject({
      locationText: "Nakawa",
      latitude: null,
      longitude: null,
      requestedServiceAt: null,
    });
  });

  it("requires a future requested date and time in scheduled mode", () => {
    expect(() =>
      validate({
        idempotencyKey: "d5784cb8-6bf8-493a-9036-151ca0d75c5c",
        locationKind: RequestLocationKind.text,
        locationText: "Nakawa",
        scheduleMode: ScheduleMode.scheduled,
      }),
    ).toThrow("Choose a future service date and time within 90 days.");
  });

  it("rejects coordinates on a text-only request", () => {
    expect(() =>
      validate({
        idempotencyKey: "d5784cb8-6bf8-493a-9036-151ca0d75c5c",
        locationKind: RequestLocationKind.text,
        locationText: "Nakawa",
        location: { latitude: 0.3476, longitude: 32.5825 },
        scheduleMode: ScheduleMode.asSoonAsPossible,
      }),
    ).toThrow("Enter a text location without coordinates");
  });
});

describe("journey arrival evidence", () => {
  it("recognises two qualifying samples across consecutive mobile batches", () => {
    expect(hasConsecutiveArrivalEvidence(true, [true])).toBe(true);
  });

  it("does not arrive from one sample or interrupted evidence", () => {
    expect(hasConsecutiveArrivalEvidence(undefined, [true])).toBe(false);
    expect(hasConsecutiveArrivalEvidence(true, [false])).toBe(false);
    expect(hasConsecutiveArrivalEvidence(false, [true])).toBe(false);
  });
});
