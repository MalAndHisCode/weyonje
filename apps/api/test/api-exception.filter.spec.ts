import {
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from "@nestjs/common";
import { ApiErrorCode } from "@weyonje/contracts";

import { ApiExceptionFilter } from "../src/http/api-exception.filter";

describe("ApiExceptionFilter", () => {
  const send = jest.fn();
  const status = jest.fn(() => ({ send }));
  const host = {
    switchToHttp: () => ({
      getRequest: () => ({
        id: "request-id",
        method: "GET",
        url: "/v1/actors/me",
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
