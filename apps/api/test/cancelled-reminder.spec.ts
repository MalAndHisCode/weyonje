import { DeliveryProcessor } from "../src/delivery/delivery.processor";

describe("Cancelled request reminder delivery (persistence fake)", () => {
  it.each(["IN_APP", "PUSH"])(
    "retains attempt evidence without dispatching %s",
    async (channel) => {
      const requestedServiceAt = new Date(Date.now() + 86_400_000);
      const notification = jest.fn();
      const push = jest.fn();
      const updateAttempt = jest.fn();
      const updateOutbox = jest.fn(async () => ({ count: 1 }));
      const tx = {
        $queryRaw: jest.fn(async () => [
          {
            id: "outbox",
            requestId: "request",
            recipientUserId: "client",
            channel,
            eventType: "REMINDER",
            payload: { requestedServiceAt: requestedServiceAt.toISOString() },
            deduplicationKey: "reminder",
            attempts: 1,
            createdAt: new Date(),
          },
        ]),
        deliveryAttempt: { createMany: jest.fn(), update: updateAttempt },
        outboxEvent: { updateMany: updateOutbox },
        operationalNotification: { createMany: notification },
      };
      const prisma = {
        $transaction: async (work: (value: typeof tx) => Promise<unknown>) =>
          work(tx),
        serviceRequest: {
          findUnique: jest.fn(async () => ({
            status: "CANCELLED",
            requestedServiceAt,
          })),
        },
      };
      const processor = new DeliveryProcessor(
        prisma as never,
        {} as never,
        {} as never,
        { send: push } as never,
        {} as never,
        {} as never,
        {} as never,
        {} as never,
        {
          batchSize: 10,
          claimLeaseSeconds: 30,
          maxAttempts: 3,
          backoffMaximumSeconds: 10,
          backoffBaseSeconds: 1,
        } as never,
      );
      expect(await processor.processBatch()).toBe(1);
      expect(notification).not.toHaveBeenCalled();
      expect(push).not.toHaveBeenCalled();
      expect(updateOutbox).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            status: "DEAD_LETTER",
            lastErrorCode: "REMINDER_INELIGIBLE",
          }),
        }),
      );
      expect(updateAttempt).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            result: "PERMANENT_FAILURE",
            errorCode: "REMINDER_INELIGIBLE",
          }),
        }),
      );
    },
  );
});
