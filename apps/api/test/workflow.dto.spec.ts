import { validate } from "class-validator";
import { CollectionOutcome } from "@weyonje/contracts";

import {
  AcceptRequestDto,
  SubmitFeedbackDto,
} from "../src/workflows/workflow.dto";

describe("workflow DTO validation", () => {
  it.each([1, 5])(
    "accepts the approved 1-5 rating boundary %i",
    async (rating) => {
      const value = Object.assign(new SubmitFeedbackDto(), {
        idempotencyKey: "a5eab3cc-3a0d-4fe2-9b89-a73a74c12aea",
        outcome: CollectionOutcome.completed,
        feedback: "Recorded outcome",
        rating,
      });
      expect(await validate(value)).toEqual([]);
    },
  );

  it.each([0, 6])(
    "rejects a rating outside the 1-5 scale: %i",
    async (rating) => {
      const value = Object.assign(new SubmitFeedbackDto(), {
        idempotencyKey: "a5eab3cc-3a0d-4fe2-9b89-a73a74c12aea",
        outcome: CollectionOutcome.completed,
        feedback: "Recorded outcome",
        rating,
      });
      expect(await validate(value)).not.toEqual([]);
    },
  );

  it("accepts a zero whole-number UGX agreement and rejects fractions", async () => {
    const zero = Object.assign(new AcceptRequestDto(), {
      idempotencyKey: "b6980f1a-d929-4231-8b9c-6336c45dacfb",
      agreedPriceUgx: 0,
    });
    const fraction = Object.assign(new AcceptRequestDto(), {
      idempotencyKey: "b6980f1a-d929-4231-8b9c-6336c45dacfb",
      agreedPriceUgx: 1000.5,
    });
    expect(await validate(zero)).toEqual([]);
    expect(await validate(fraction)).not.toEqual([]);
  });
});
