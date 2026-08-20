import { Controller, Get, Req, UseGuards } from "@nestjs/common";
import { ApiBearerAuth, ApiOkResponse, ApiTags } from "@nestjs/swagger";

import {
  AccessTokenGuard,
  AuthenticatedRequest,
} from "../auth/access-token.guard";
import { DeliveryProcessor } from "./delivery.processor";

@ApiTags("delivery operations")
@ApiBearerAuth()
@UseGuards(AccessTokenGuard)
@Controller("v1/kcca/delivery")
export class DeliveryController {
  constructor(private readonly delivery: DeliveryProcessor) {}

  @Get("health")
  @ApiOkResponse({ description: "Safe delivery backlog and worker health" })
  health(@Req() request: AuthenticatedRequest) {
    return this.delivery.health(request.authenticatedActor!);
  }
}
