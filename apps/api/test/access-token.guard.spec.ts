import { ExecutionContext, UnauthorizedException } from "@nestjs/common";

import { AccessTokenGuard } from "../src/auth/access-token.guard";
import { SessionService } from "../src/auth/session.service";
import { TokenService } from "../src/auth/token.service";

describe("AccessTokenGuard", () => {
  const tokens = { verifyAccessToken: jest.fn() };
  const sessions = { authenticateAccess: jest.fn() };
  const guard = new AccessTokenGuard(
    tokens as unknown as TokenService,
    sessions as unknown as SessionService,
  );

  function context(authorization?: string) {
    const request: {
      headers: { authorization?: string };
      authenticatedActor?: object;
    } = {
      headers: authorization ? { authorization } : {},
    };
    return {
      request,
      execution: {
        switchToHttp: () => ({ getRequest: () => request }),
      } as ExecutionContext,
    };
  }

  beforeEach(() => jest.clearAllMocks());

  it.each([undefined, "", "Basic value", "Bearer", "Bearer two values"])(
    "rejects missing or malformed authentication: %s",
    async (authorization) => {
      await expect(
        guard.canActivate(context(authorization).execution),
      ).rejects.toBeInstanceOf(UnauthorizedException);
      expect(tokens.verifyAccessToken).not.toHaveBeenCalled();
    },
  );

  it("validates both token claims and current server session", async () => {
    tokens.verifyAccessToken.mockResolvedValue({
      userId: "user-1",
      sessionId: "session-1",
    });
    sessions.authenticateAccess.mockResolvedValue({
      sessionId: "session-1",
      user: { id: "user-1" },
    });
    const { execution, request } = context("Bearer opaque");
    await expect(guard.canActivate(execution)).resolves.toBe(true);
    expect(sessions.authenticateAccess).toHaveBeenCalledWith(
      "user-1",
      "session-1",
    );
    expect(request.authenticatedActor).toMatchObject({
      sessionId: "session-1",
    });
  });
});
