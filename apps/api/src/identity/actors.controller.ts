import { Controller, Get, Req, UseGuards } from "@nestjs/common";
import {
  ApiBearerAuth,
  ApiForbiddenResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
  ApiUnauthorizedResponse,
} from "@nestjs/swagger";

import { ApiErrorDto, CurrentActorDto } from "./current-actor.dto";
import { CurrentActorService } from "./current-actor.service";
import { AuthenticatedRequest, JwtAuthGuard } from "./jwt-auth.guard";

@ApiTags("actors")
@ApiBearerAuth()
@Controller("v1/actors")
export class ActorsController {
  constructor(private readonly currentActor: CurrentActorService) {}

  @Get("me")
  @UseGuards(JwtAuthGuard)
  @ApiOperation({
    summary: "Resolve the authenticated Weyonje actor and mobile eligibility",
  })
  @ApiOkResponse({ type: CurrentActorDto })
  @ApiUnauthorizedResponse({ type: ApiErrorDto })
  @ApiForbiddenResponse({ type: ApiErrorDto })
  async me(@Req() request: AuthenticatedRequest): Promise<CurrentActorDto> {
    return this.currentActor.resolve(request.actorIdentity!);
  }
}
