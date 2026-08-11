import { ExecutionContext } from "@nestjs/common";

import { SignedAccessTokenGuard } from "../src/auth/signed-access-token.guard";

describe("SignedAccessTokenGuard", () => {
  const tokens = { verifyAccessToken: jest.fn() };
  const guard = new SignedAccessTokenGuard(tokens as never);

  beforeEach(() => jest.clearAllMocks());

  it("attaches verified claims without consulting session state", async () => {
    const request = { headers: { authorization: "Bearer signed-token" } };
    tokens.verifyAccessToken.mockResolvedValue({
      userId: "user-1",
      sessionId: "session-1",
    });
    const context = {
      switchToHttp: () => ({ getRequest: () => request }),
    } as unknown as ExecutionContext;

    await expect(guard.canActivate(context)).resolves.toBe(true);
    expect(request).toMatchObject({
      accessTokenClaims: { userId: "user-1", sessionId: "session-1" },
    });
  });

  it("rejects a missing bearer token through the generic verifier error", async () => {
    tokens.verifyAccessToken.mockRejectedValue(new Error("unauthorized"));
    const context = {
      switchToHttp: () => ({
        getRequest: () => ({ headers: {} }),
      }),
    } as unknown as ExecutionContext;

    await expect(guard.canActivate(context)).rejects.toThrow("unauthorized");
  });
});
