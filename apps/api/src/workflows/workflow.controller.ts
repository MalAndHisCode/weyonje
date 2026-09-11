import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  ParseEnumPipe,
  ParseUUIDPipe,
  Post,
  Put,
  Query,
  Req,
  UseGuards,
} from "@nestjs/common";
import {
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from "@nestjs/swagger";
import { JourneyPhase } from "@weyonje/contracts";

import {
  AccessTokenGuard,
  AuthenticatedRequest,
} from "../auth/access-token.guard";
import {
  AcceptRequestDto,
  AssignDisposalSiteDto,
  CallCentreAssignmentDto,
  CallCentreCreateRequestDto,
  CreateClientServiceRequestDto,
  ClientRequestProfileDto,
  DisposalSiteDto,
  IdempotentCommandDto,
  JourneySnapshotDto,
  LocationPolicyDto,
  OperationalNotificationDto,
  ProviderPendingRequestDto,
  RejectAssignedRequestDto,
  ServiceRequestDetailDto,
  ServiceRequestSummaryDto,
  SubmitFeedbackDto,
  SubmitLocationBatchDto,
} from "./workflow.dto";
import { WorkflowService } from "./workflow.service";

function actor(request: AuthenticatedRequest) {
  return request.authenticatedActor!;
}

@ApiTags("configuration")
@Controller("v1/config")
export class WorkflowConfigController {
  constructor(private readonly workflows: WorkflowService) {}

  @Get("location-policy")
  @ApiOperation({
    summary: "Read the provisional, configurable location policy",
  })
  @ApiOkResponse({ type: LocationPolicyDto })
  locationPolicy() {
    return this.workflows.locationPolicy();
  }
}

@ApiTags("client workflows")
@ApiBearerAuth()
@UseGuards(AccessTokenGuard)
@Controller("v1/client")
export class ClientWorkflowController {
  constructor(private readonly workflows: WorkflowService) {}

  @Get("dashboard")
  dashboard(@Req() request: AuthenticatedRequest) {
    return this.workflows.clientDashboard(actor(request));
  }

  @Get("profile")
  @ApiOkResponse({ type: ClientRequestProfileDto })
  profile(@Req() request: AuthenticatedRequest) {
    return this.workflows.clientProfile(actor(request));
  }

  @Post("requests")
  @ApiCreatedResponse({ type: ServiceRequestDetailDto })
  create(
    @Req() request: AuthenticatedRequest,
    @Body() body: CreateClientServiceRequestDto,
  ) {
    return this.workflows.createClientRequest(actor(request), body);
  }

  @Get("requests")
  @ApiOkResponse({ type: ServiceRequestSummaryDto, isArray: true })
  list(@Req() request: AuthenticatedRequest) {
    return this.workflows.clientRequests(actor(request));
  }

  @Get("requests/:requestId")
  @ApiOkResponse({ type: ServiceRequestDetailDto })
  detail(
    @Req() request: AuthenticatedRequest,
    @Param("requestId", ParseUUIDPipe) requestId: string,
  ) {
    return this.workflows.clientRequest(actor(request), requestId);
  }

  @Post("requests/:requestId/feedback")
  @HttpCode(200)
  @ApiOkResponse({ type: ServiceRequestDetailDto })
  feedback(
    @Req() request: AuthenticatedRequest,
    @Param("requestId", ParseUUIDPipe) requestId: string,
    @Body() body: SubmitFeedbackDto,
  ) {
    return this.workflows.submitClientFeedback(actor(request), requestId, body);
  }
}

@ApiTags("provider workflows")
@ApiBearerAuth()
@UseGuards(AccessTokenGuard)
@Controller("v1/provider")
export class ProviderWorkflowController {
  constructor(private readonly workflows: WorkflowService) {}

  @Get("dashboard")
  dashboard(@Req() request: AuthenticatedRequest) {
    return this.workflows.providerDashboard(actor(request));
  }

  @Get("requests/pending")
  @ApiOkResponse({ type: ProviderPendingRequestDto, isArray: true })
  pending(@Req() request: AuthenticatedRequest) {
    return this.workflows.pendingProviderRequests(actor(request));
  }

  @Get("requests/:requestId")
  @ApiOkResponse({ type: ServiceRequestDetailDto })
  requestDetail(
    @Req() request: AuthenticatedRequest,
    @Param("requestId", ParseUUIDPipe) requestId: string,
  ) {
    return this.workflows.providerRequest(actor(request), requestId);
  }

  @Post("requests/:requestId/accept")
  @HttpCode(200)
  accept(
    @Req() request: AuthenticatedRequest,
    @Param("requestId", ParseUUIDPipe) requestId: string,
    @Body() body: AcceptRequestDto,
  ) {
    return this.workflows.acceptRequest(actor(request), requestId, body);
  }

  @Post("requests/:requestId/reject")
  @HttpCode(200)
  reject(
    @Req() request: AuthenticatedRequest,
    @Param("requestId", ParseUUIDPipe) requestId: string,
    @Body() body: RejectAssignedRequestDto,
  ) {
    return this.workflows.rejectAssignedRequest(
      actor(request),
      requestId,
      body.idempotencyKey,
    );
  }

  @Get("jobs")
  @ApiOkResponse({ type: ServiceRequestSummaryDto, isArray: true })
  jobs(@Req() request: AuthenticatedRequest) {
    return this.workflows.providerJobs(actor(request));
  }

  @Get("jobs/:requestId")
  @ApiOkResponse({ type: ServiceRequestDetailDto })
  job(
    @Req() request: AuthenticatedRequest,
    @Param("requestId", ParseUUIDPipe) requestId: string,
  ) {
    return this.workflows.providerJob(actor(request), requestId);
  }

  @Post("jobs/:requestId/journeys/:phase/start")
  @HttpCode(200)
  startJourney(
    @Req() request: AuthenticatedRequest,
    @Param("requestId", ParseUUIDPipe) requestId: string,
    @Param("phase", new ParseEnumPipe(JourneyPhase)) phase: JourneyPhase,
    @Body() body: IdempotentCommandDto,
  ) {
    return this.workflows.startJourney(
      actor(request),
      requestId,
      phase,
      body.idempotencyKey,
    );
  }

  @Post("jobs/:requestId/positions")
  @HttpCode(200)
  @ApiOkResponse({ type: JourneySnapshotDto })
  positions(
    @Req() request: AuthenticatedRequest,
    @Param("requestId", ParseUUIDPipe) requestId: string,
    @Body() body: SubmitLocationBatchDto,
  ) {
    return this.workflows.submitPositions(actor(request), requestId, body);
  }

  @Post("jobs/:requestId/collection-completed")
  @HttpCode(200)
  collection(
    @Req() request: AuthenticatedRequest,
    @Param("requestId", ParseUUIDPipe) requestId: string,
    @Body() body: IdempotentCommandDto,
  ) {
    return this.workflows.reportCollection(
      actor(request),
      requestId,
      body.idempotencyKey,
    );
  }

  @Post("jobs/:requestId/disposal-completed")
  @HttpCode(200)
  disposal(
    @Req() request: AuthenticatedRequest,
    @Param("requestId", ParseUUIDPipe) requestId: string,
    @Body() body: IdempotentCommandDto,
  ) {
    return this.workflows.completeDisposal(
      actor(request),
      requestId,
      body.idempotencyKey,
    );
  }
}

@ApiTags("call centre workflows")
@ApiBearerAuth()
@UseGuards(AccessTokenGuard)
@Controller("v1/call-centre")
export class CallCentreWorkflowController {
  constructor(private readonly workflows: WorkflowService) {}

  @Post("requests")
  @ApiCreatedResponse({ type: ServiceRequestDetailDto })
  create(
    @Req() request: AuthenticatedRequest,
    @Body() body: CallCentreCreateRequestDto,
  ) {
    return this.workflows.createCallCentreRequest(actor(request), body);
  }

  @Get("requests")
  list(@Req() request: AuthenticatedRequest) {
    return this.workflows.callCentreRequests(actor(request));
  }

  @Get("clients")
  clients(@Req() request: AuthenticatedRequest, @Query("query") query = "") {
    return this.workflows.callCentreClients(actor(request), query);
  }

  @Get("providers")
  providers(@Req() request: AuthenticatedRequest) {
    return this.workflows.callCentreProviders(actor(request));
  }

  @Get("requests/:requestId")
  detail(
    @Req() request: AuthenticatedRequest,
    @Param("requestId", ParseUUIDPipe) requestId: string,
  ) {
    return this.workflows.authorizedRequestDetail(actor(request), requestId);
  }

  @Post("requests/:requestId/assignment")
  @HttpCode(200)
  assign(
    @Req() request: AuthenticatedRequest,
    @Param("requestId", ParseUUIDPipe) requestId: string,
    @Body() body: CallCentreAssignmentDto,
  ) {
    return this.workflows.assignCallCentreRequest(
      actor(request),
      requestId,
      body,
    );
  }

  @Post("requests/:requestId/feedback")
  @HttpCode(200)
  feedback(
    @Req() request: AuthenticatedRequest,
    @Param("requestId", ParseUUIDPipe) requestId: string,
    @Body() body: SubmitFeedbackDto,
  ) {
    return this.workflows.submitCallCentreFeedback(
      actor(request),
      requestId,
      body,
    );
  }
}

@ApiTags("KCCA operations")
@ApiBearerAuth()
@UseGuards(AccessTokenGuard)
@Controller("v1/kcca")
export class KccaWorkflowController {
  constructor(private readonly workflows: WorkflowService) {}

  @Get("monitoring")
  monitoring(@Req() request: AuthenticatedRequest) {
    return this.workflows.kccaMonitoring(actor(request));
  }

  @Get("disposal-sites")
  sites(@Req() request: AuthenticatedRequest) {
    return this.workflows.disposalSites(actor(request));
  }

  @Put("disposal-sites")
  site(@Req() request: AuthenticatedRequest, @Body() body: DisposalSiteDto) {
    return this.workflows.upsertDisposalSite(actor(request), body);
  }

  @Post("requests/:requestId/disposal-site")
  @HttpCode(200)
  assignSite(
    @Req() request: AuthenticatedRequest,
    @Param("requestId", ParseUUIDPipe) requestId: string,
    @Body() body: AssignDisposalSiteDto,
  ) {
    return this.workflows.assignDisposalSite(
      actor(request),
      requestId,
      body.disposalSiteId,
      body.idempotencyKey,
    );
  }

  @Get("requests/:requestId/disposal-site-history")
  assignmentHistory(
    @Req() request: AuthenticatedRequest,
    @Param("requestId", ParseUUIDPipe) requestId: string,
  ) {
    return this.workflows.disposalAssignmentHistory(actor(request), requestId);
  }
}

@ApiTags("journey tracking")
@ApiBearerAuth()
@UseGuards(AccessTokenGuard)
@Controller("v1/journeys")
export class JourneyController {
  constructor(private readonly workflows: WorkflowService) {}

  @Get(":requestId")
  @ApiOkResponse({ type: JourneySnapshotDto })
  tracking(
    @Req() request: AuthenticatedRequest,
    @Param("requestId", ParseUUIDPipe) requestId: string,
    @Query("phase", new ParseEnumPipe(JourneyPhase)) phase: JourneyPhase,
  ) {
    return this.workflows.tracking(actor(request), requestId, phase);
  }
}

@ApiTags("notifications")
@ApiBearerAuth()
@UseGuards(AccessTokenGuard)
@Controller("v1/notifications")
export class NotificationController {
  constructor(private readonly workflows: WorkflowService) {}

  @Get()
  @ApiOkResponse({ type: OperationalNotificationDto, isArray: true })
  list(@Req() request: AuthenticatedRequest) {
    return this.workflows.notifications(actor(request));
  }

  @Post(":notificationId/read")
  @HttpCode(200)
  read(
    @Req() request: AuthenticatedRequest,
    @Param("notificationId", ParseUUIDPipe) notificationId: string,
  ) {
    return this.workflows.markNotificationRead(actor(request), notificationId);
  }
}
