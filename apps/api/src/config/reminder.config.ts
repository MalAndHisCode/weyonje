import { registerAs } from "@nestjs/config";
import { validateEnvironment } from "./environment";

export const reminderConfig = registerAs("reminder", () => {
  const env = validateEnvironment(process.env);
  const offsetsMinutes = [
    ...new Set(
      env.REMINDER_OFFSETS_MINUTES.split(",").map((value) =>
        Number(value.trim()),
      ),
    ),
  ].sort((a, b) => b - a);
  if (
    offsetsMinutes.length === 0 ||
    offsetsMinutes.some(
      (value) => !Number.isInteger(value) || value < 1 || value > 10080,
    )
  )
    throw new Error("Invalid REMINDER_OFFSETS_MINUTES configuration.");
  return { offsetsMinutes };
});
