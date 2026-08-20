import { Inject, Injectable } from "@nestjs/common";
import { ConfigType } from "@nestjs/config";
import { cert, getApps, initializeApp } from "firebase-admin/app";
import { getMessaging } from "firebase-admin/messaging";
import { pushConfig } from "../config/push.config";
import {
  DeliveryFailure,
  DeliveryReceipt,
  PushNotificationGateway,
  PushNotificationMessage,
} from "../workflows/notification-delivery.gateway";

@Injectable()
export class FirebasePushGateway extends PushNotificationGateway {
  constructor(
    @Inject(pushConfig.KEY)
    private readonly config: ConfigType<typeof pushConfig>,
  ) {
    super();
  }
  async send(message: PushNotificationMessage): Promise<DeliveryReceipt> {
    if (message.targets.length === 0)
      throw new DeliveryFailure("PUSH_TARGET_MISSING", false);
    try {
      const app =
        getApps()[0] ??
        initializeApp({
          credential: cert({
            projectId: this.config.projectId,
            clientEmail: this.config.clientEmail,
            privateKey: this.config.privateKey,
          }),
        });
      const response = await getMessaging(app).sendEachForMulticast({
        tokens: message.targets.map((target) => target.token),
        notification: { title: message.title, body: message.message },
        data: { ...message.data, deliveryKey: message.idempotencyKey },
        android: { priority: "high", notification: { visibility: "private" } },
      });
      const invalidTargetIds = response.responses.flatMap((result, index) => {
        const code = result.error?.code;
        return code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-registration-token"
          ? [message.targets[index]!.id]
          : [];
      });
      if (
        response.successCount === 0 &&
        invalidTargetIds.length !== response.responses.length
      )
        throw new DeliveryFailure("FCM_TRANSIENT_FAILURE", true);
      const providerMessageId = response.responses.find(
        (item) => item.messageId,
      )?.messageId;
      return {
        ...(providerMessageId ? { providerMessageId } : {}),
        invalidTargetIds,
      };
    } catch (error) {
      if (error instanceof DeliveryFailure) throw error;
      throw new DeliveryFailure("FCM_TRANSIENT_FAILURE", true);
    }
  }
}
