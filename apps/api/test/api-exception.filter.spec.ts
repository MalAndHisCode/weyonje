import {
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from "@nestjs/common";
import { ApiErrorCode } from "@weyonje/contracts";

import { ApiExceptionFilter } from "../src/http/api-exception.filter";

import { Prisma } from "../src/generated/prisma/client";
import { atClientRequestStage } from "../src/http/failure-diagnostics";

describe("ApiExceptionFilter", () => {
  const send = jest.fn();
  const status = jest.fn(() => ({ send }));
  const host = {
    switchToHttp: () => ({
      getRequest: () => ({
        id: "request-id",
        method: "GET",
        url: "/v1/actors/private-id?phone=secret",
        routeOptions: { url: "/v1/actors/:id" },
      }),
      getResponse: () => ({ status }),
    }),
  } as unknown as ArgumentsHost;
  const filter = new ApiExceptionFilter();

  beforeEach(() => {
    send.mockReset();
    status.mockClear();
    jest.spyOn(Logger.prototype, "error").mockImplementation(() => undefined);
  });

  afterEach(() => jest.restoreAllMocks());

  it("preserves only a recognized stable error contract", () => {
    filter.catch(
      new HttpException(
        {
          code: ApiErrorCode.accessDenied,
          message: "This account cannot access Weyonje mobile services.",
        },
        HttpStatus.FORBIDDEN,
      ),
      host,
    );

    expect(status).toHaveBeenCalledWith(HttpStatus.FORBIDDEN);
    expect(send).toHaveBeenCalledWith({
      code: ApiErrorCode.accessDenied,
      message: "This account cannot access Weyonje mobile services.",
      requestId: "request-id",
    });
  });

  it("preserves safe retry evidence and discards unrecognized metadata", () => {
    filter.catch(
      new HttpException(
        {
          code: ApiErrorCode.rateLimited,
          message: "Wait.",
          retryAt: "2026-09-10T12:00:00Z",
          limitCategory: "OTP_HOURLY",
          phone: "private",
          codeValue: "private",
        },
        429,
      ),
      host,
    );
    expect(send).toHaveBeenCalledWith({
      code: ApiErrorCode.rateLimited,
      message: "Wait.",
      retryAt: "2026-09-10T12:00:00.000Z",
      limitCategory: "OTP_HOURLY",
      requestId: "request-id",
    });
    send.mockClear();
    filter.catch(
      new HttpException(
        { message: "Wait.", retryAt: "invalid", limitCategory: "OTHER" },
        429,
      ),
      host,
    );
    expect(send.mock.calls[0]?.[0]).not.toHaveProperty("retryAt");
  });

  it("logs only owned stages, categories, recognized Prisma codes and route templates", async () => {
    const error = new Prisma.PrismaClientKnownRequestError(
      "SQL phone email coordinates secret",
      {
        code: "P2003",
        clientVersion: "secret",
        meta: { target: "secret", cause: "secret" },
      },
    );
    try {
      await atClientRequestStage("transaction", () =>
        atClientRequestStage("outbox_write", async () => {
          throw error;
        }),
      );
    } catch (failure) {
      filter.catch(failure, host);
    }
    expect(Logger.prototype.error).toHaveBeenCalledWith({
      event: "request_failed",
      requestId: "request-id",
      method: "GET",
      route: "/v1/actors/:id",
      category: "prisma_known_request",
      stage: "outbox_write",
      prismaCode: "P2003",
    });
    expect(
      JSON.stringify((Logger.prototype.error as jest.Mock).mock.calls),
    ).not.toContain("secret");
    expect(JSON.stringify(send.mock.calls)).not.toContain("secret");
  });

  it.each([
    new Error("secret"),
    { name: "secret", code: "P2003", meta: "secret" },
    new Prisma.PrismaClientKnownRequestError("secret", {
      code: "secret",
      clientVersion: "secret",
    }),
    "secret",
  ])(
    "does not trust arbitrary names, codes, metadata or thrown values",
    (error) => {
      filter.catch(error, host);
      expect(
        JSON.stringify((Logger.prototype.error as jest.Mock).mock.calls),
      ).not.toContain("secret");
      expect(
        (Logger.prototype.error as jest.Mock).mock.calls[0][0],
      ).not.toHaveProperty("prismaCode");
    },
  );

  it("does not leak unexpected exception details", () => {
    filter.catch(new Error("database-password-and-subject"), host);

    expect(status).toHaveBeenCalledWith(HttpStatus.INTERNAL_SERVER_ERROR);
    const payload = send.mock.calls[0]?.[0];
    expect(payload).toEqual({
      code: ApiErrorCode.unexpected,
      message: "The request could not be completed. Try again later.",
      requestId: "request-id",
    });
    expect(JSON.stringify(payload)).not.toContain("database-password");
  });
});
