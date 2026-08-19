import { Module } from "@nestjs/common";

import { AuthModule } from "../auth/auth.module";
import { PhoneModule } from "../registration/phone.module";
import {
  CallCentreWorkflowController,
  ClientWorkflowController,
  JourneyController,
  KccaWorkflowController,
  NotificationController,
  ProviderWorkflowController,
  WorkflowConfigController,
} from "./workflow.controller";
import { WorkflowService } from "./workflow.service";
import { JourneyGateway } from "./journey.gateway";
import {
  OperationalSmsGateway,
  PushNotificationGateway,
  UnconfiguredOperationalSmsGateway,
  UnconfiguredPushNotificationGateway,
} from "./notification-delivery.gateway";

@Module({
  imports: [AuthModule, PhoneModule],
  controllers: [
    WorkflowConfigController,
    ClientWorkflowController,
    ProviderWorkflowController,
    CallCentreWorkflowController,
    KccaWorkflowController,
    JourneyController,
    NotificationController,
  ],
  providers: [
    WorkflowService,
    JourneyGateway,
    UnconfiguredPushNotificationGateway,
    UnconfiguredOperationalSmsGateway,
    {
      provide: PushNotificationGateway,
      useExisting: UnconfiguredPushNotificationGateway,
    },
    {
      provide: OperationalSmsGateway,
      useExisting: UnconfiguredOperationalSmsGateway,
    },
  ],
  exports: [WorkflowService],
})
export class WorkflowModule {}
