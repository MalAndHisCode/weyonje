import { Injectable } from "@nestjs/common";

export interface PushNotificationMessage {
  recipientUserId: string;
  title: string;
  message: string;
  data: Readonly<Record<string, string>>;
}

export interface OperationalSmsMessage {
  recipientUserId: string;
  message: string;
  documentedPurpose: string;
}

export abstract class PushNotificationGateway {
  abstract send(message: PushNotificationMessage): Promise<void>;
}

export abstract class OperationalSmsGateway {
  abstract send(message: OperationalSmsMessage): Promise<void>;
}

@Injectable()
export class UnconfiguredPushNotificationGateway extends PushNotificationGateway {
  send(_message: PushNotificationMessage): Promise<void> {
    return Promise.reject(
      new Error("Push delivery is not configured for this development target."),
    );
  }
}

@Injectable()
export class UnconfiguredOperationalSmsGateway extends OperationalSmsGateway {
  send(_message: OperationalSmsMessage): Promise<void> {
    return Promise.reject(
      new Error(
        "Operational SMS is disabled unless its business purpose is documented and configured.",
      ),
    );
  }
}
