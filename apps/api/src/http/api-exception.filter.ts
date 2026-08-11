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

interface ErrorBody {
  code?: unknown;
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
      void response.status(status).send(payload);
      return;
    }

    this.logger.error({
      event: "request_failed",
      requestId,
      method: request.method,
      route: request.url,
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
    if (status === HttpStatus.FORBIDDEN) return ApiErrorCode.accessDenied;
    if (status === HttpStatus.REQUEST_TIMEOUT)
      return ApiErrorCode.requestTimeout;
    if (status === HttpStatus.SERVICE_UNAVAILABLE)
      return ApiErrorCode.dependencyUnavailable;
    return ApiErrorCode.unexpected;
  }

  private safeMessage(value: unknown, status: number): string {
    if (typeof value === "string") return value;
    if (status === HttpStatus.UNAUTHORIZED)
      return "Authentication is required.";
    if (status === HttpStatus.FORBIDDEN)
      return "This account cannot access Weyonje mobile services.";
    return "The request could not be completed. Try again later.";
  }
}
