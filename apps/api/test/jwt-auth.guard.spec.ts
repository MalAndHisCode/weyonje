import { ExecutionContext, UnauthorizedException } from "@nestjs/common";
import { ApiErrorCode } from "@weyonje/contracts";

import { JwtAuthGuard } from "../src/identity/jwt-auth.guard";
import { TokenVerifier } from "../src/identity/token-verifier";

describe("JwtAuthGuard", () => {
  const verify = jest.fn();
  const guard = new JwtAuthGuard({ verify } as unknown as TokenVerifier);

  function context(authorization?: string) {
    const request: {
      headers: { authorization?: string };
      actorIdentity?: unknown;
    } = {
      headers: authorization == null ? {} : { authorization },
    };
    const executionContext = {
      switchToHttp: () => ({ getRequest: () => request }),
    } as ExecutionContext;
    return { executionContext, request };
  }

  beforeEach(() => verify.mockReset());

  it.each([undefined, "", "Basic value", "Bearer", "Bearer two tokens"])(
    "rejects a missing or malformed bearer value: %s",
    async (authorization) => {
      const { executionContext } = context(authorization);
      await expect(guard.canActivate(executionContext)).rejects.toMatchObject({
        response: {
          code: ApiErrorCode.authenticationRequired,
          message: "Authentication is required.",
        },
      });
      expect(verify).not.toHaveBeenCalled();
    },
  );

  it("passes only the opaque bearer token to verification", async () => {
    verify.mockResolvedValueOnce({
      subject: "subject-1",
      roles: new Set(["client"]),
    });
    const { executionContext, request } = context("Bearer opaque-token");

    await expect(guard.canActivate(executionContext)).resolves.toBe(true);
    expect(verify).toHaveBeenCalledWith("opaque-token");
    expect(request.actorIdentity).toEqual({
      subject: "subject-1",
      roles: new Set(["client"]),
    });
  });

  it("does not alter a verifier authentication failure", async () => {
    verify.mockRejectedValueOnce(
      new UnauthorizedException({
        code: ApiErrorCode.invalidToken,
        message: "The access token is invalid or expired.",
      }),
    );
    const { executionContext } = context("Bearer invalid-token");

    await expect(guard.canActivate(executionContext)).rejects.toMatchObject({
      response: { code: ApiErrorCode.invalidToken },
    });
  });
});
