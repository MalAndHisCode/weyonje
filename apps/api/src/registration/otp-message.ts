/** Provider-neutral, ASCII-only SMS. The reference scopes Android autofill. */
export function composeOtpMessage(
  code: string,
  challengeId: string,
  ttlSeconds: number,
  appHash?: string,
): string {
  if (
    !/^\d{6}$/.test(code) ||
    !/^[0-9a-f-]{36}$/.test(challengeId) ||
    !Number.isInteger(ttlSeconds) ||
    ttlSeconds <= 0
  ) {
    throw new Error("Invalid OTP message parameters");
  }
  if (appHash && !/^[A-Za-z0-9+/]{11}$/.test(appHash))
    throw new Error("Invalid Android SMS app hash");
  const message = `<#> Weyonje code: ${code}\nExpires in ${ttlSeconds}s. Do not share.\nRef: ${challengeId}${appHash ? `\n${appHash}` : ""}`;
  if (Buffer.byteLength(message, "utf8") > 140)
    throw new Error("OTP message exceeds 140 bytes");
  return message;
}
