import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from "@nestjs/common";
import { ApiErrorCode, ApiErrorContract } from "@weyonje/contracts";
import { FastifyReply, FastifyRequest } from "fastify";

import { safeFailureDiagnostics } from "./failure-diagnostics";

interface ErrorBody {
  code?: unknown;
  retryAt?: unknown;
  limitCategory?: unknown;
  message?: unknown;
}

@Catch()
export class ApiExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(ApiExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const context = host.switchToHttp();
    const request = context.getRequest<FastifyRequest>();
    const response = context.getResponse<FastifyReply>();
    const requestId = request.id;

    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const body = this.asErrorBody(exception.getResponse());
      const payload: ApiErrorContract = {
        code: this.stableCode(body.code, status),
        message: this.safeMessage(body.message, status),
        requestId,
      };
      if (
        typeof body.retryAt === "string" &&
        Number.isFinite(Date.parse(body.retryAt)) &&
        (body.limitCategory === "OTP_HOURLY" ||
          body.limitCategory === "OTP_COOLDOWN" ||
          body.limitCategory === "CLIENT_REQUEST")
      ) {
        payload.retryAt = new Date(body.retryAt).toISOString();
        payload.limitCategory = body.limitCategory;
      }
      void response.status(status).send(payload);
      return;
    }

    this.logger.error({
      event: "request_failed",
      requestId,
      method: request.method,
      route: request.routeOptions?.url ?? "unmatched",
      ...safeFailureDiagnostics(exception),
    });
    void response.status(HttpStatus.INTERNAL_SERVER_ERROR).send({
      code: ApiErrorCode.unexpected,
      message: "The request could not be completed. Try again later.",
      requestId,
    } satisfies ApiErrorContract);
  }

  private asErrorBody(value: string | object): ErrorBody {
    return typeof value === "object" && value !== null
      ? (value as ErrorBody)
      : { message: value };
  }

  private stableCode(value: unknown, status: number): ApiErrorCode {
    if (
      typeof value === "string" &&
      Object.values(ApiErrorCode).includes(value as ApiErrorCode)
    ) {
      return value as ApiErrorCode;
    }
    if (status === HttpStatus.UNAUTHORIZED)
      return ApiErrorCode.authenticationRequired;
    if (status === HttpStatus.BAD_REQUEST) return ApiErrorCode.invalidRequest;
    if (status === HttpStatus.TOO_MANY_REQUESTS)
      return ApiErrorCode.rateLimited;
    if (status === HttpStatus.FORBIDDEN) return ApiErrorCode.accessDenied;
    if (status === HttpStatus.REQUEST_TIMEOUT)
      return ApiErrorCode.requestTimeout;
    if (status === HttpStatus.SERVICE_UNAVAILABLE)
      return ApiErrorCode.dependencyUnavailable;
    return ApiErrorCode.unexpected;
  }

  private safeMessage(value: unknown, status: number): string {
    if (typeof value === "string") return value;
    if (status === HttpStatus.BAD_REQUEST && Array.isArray(value)) {
      // Emit owned copy only. Never echo validator values, targets, or unknown
      // property names (including names supplied by an unexpected payload).
      const fields: Record<string, string> = {
        toiletType: "Select the type of toilet to empty.",
        scheduleMode:
          "The service timing is unsupported. Update the app and try again.",
        idempotencyKey:
          "The request reference is invalid. Update the app before retrying.",
        locationKind:
          "Choose current location or select a location on the map.",
        location: "Select a valid service location.",
        additionalContactName:
          "Enter an additional contact name of at most 200 characters, or clear both contact fields.",
        additionalContactPhone:
          "Enter the additional contact telephone number, or clear both contact fields.",
      };
      const messages = Object.entries(fields)
        .filter(([field]) =>
          value.some(
            (item: unknown) =>
              typeof item === "string" && item.startsWith(`${field} `),
          ),
        )
        .map(([, message]) => message);
      return messages.length
        ? messages.join(" ")
        : "Check the request details. This app may need updating to submit the supported fields.";
    }
    if (status === HttpStatus.UNAUTHORIZED)
      return "Authentication is required.";
    if (status === HttpStatus.FORBIDDEN)
      return "This account cannot access Weyonje mobile services.";
    if (status === HttpStatus.BAD_REQUEST) return "The request is invalid.";
    if (status === HttpStatus.TOO_MANY_REQUESTS)
      return "Too many requests. Wait briefly and try again.";
    return "The request could not be completed. Try again later.";
  }
}
