import { Injectable } from "@nestjs/common";
import { randomUUID } from "node:crypto";

export interface PushNotificationMessage {
  idempotencyKey: string;
  recipientUserId: string;
  title: string;
  message: string;
  data: Readonly<Record<string, string>>;
  targets: ReadonlyArray<{ id: string; token: string }>;
}

export interface OperationalSmsMessage {
  idempotencyKey: string;
  recipientPhone: string;
  message: string;
  documentedPurpose: string;
}

export interface EmailNotificationMessage {
  idempotencyKey: string;
  recipientEmail: string;
  subject: string;
  message: string;
}

export abstract class PushNotificationGateway {
  abstract send(message: PushNotificationMessage): Promise<DeliveryReceipt>;
}

export abstract class OperationalSmsGateway {
  abstract send(message: OperationalSmsMessage): Promise<DeliveryReceipt>;
}

export abstract class EmailNotificationGateway {
  abstract send(message: EmailNotificationMessage): Promise<DeliveryReceipt>;
}

export interface DeliveryReceipt {
  providerMessageId?: string;
  invalidTargetIds?: string[];
}

@Injectable()
export class DevelopmentFakePushNotificationGateway extends PushNotificationGateway {
  send(_message: PushNotificationMessage): Promise<DeliveryReceipt> {
    return Promise.resolve({ providerMessageId: `fake-push-${randomUUID()}` });
  }
}

export class DeliveryFailure extends Error {
  constructor(
    readonly code: string,
    readonly transient: boolean,
  ) {
    super(code);
    this.name = "DeliveryFailure";
  }
}

@Injectable()
export class UnconfiguredPushNotificationGateway extends PushNotificationGateway {
  send(_message: PushNotificationMessage): Promise<DeliveryReceipt> {
    return Promise.reject(new DeliveryFailure("PUSH_NOT_CONFIGURED", false));
  }
}

@Injectable()
export class UnconfiguredOperationalSmsGateway extends OperationalSmsGateway {
  send(_message: OperationalSmsMessage): Promise<DeliveryReceipt> {
    return Promise.reject(
      new DeliveryFailure("OPERATIONAL_SMS_NOT_CONFIGURED", false),
    );
  }
}

@Injectable()
export class DevelopmentFakeOperationalSmsGateway extends OperationalSmsGateway {
  send(_message: OperationalSmsMessage): Promise<DeliveryReceipt> {
    return Promise.resolve({ providerMessageId: `fake-sms-${randomUUID()}` });
  }
}

@Injectable()
export class DevelopmentFakeEmailGateway extends EmailNotificationGateway {
  send(_message: EmailNotificationMessage): Promise<DeliveryReceipt> {
    return Promise.resolve({ providerMessageId: `fake-email-${randomUUID()}` });
  }
}

@Injectable()
export class UnconfiguredEmailGateway extends EmailNotificationGateway {
  send(_message: EmailNotificationMessage): Promise<DeliveryReceipt> {
    return Promise.reject(new DeliveryFailure("EMAIL_NOT_CONFIGURED", false));
  }
}
