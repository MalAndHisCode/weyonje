import { Injectable, Logger } from "@nestjs/common";
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from "@nestjs/websockets";
import {
  ApiErrorCode,
  JourneyPhase,
  JourneySnapshotContract,
} from "@weyonje/contracts";
import { Server, Socket } from "socket.io";

import { AuthenticatedActor } from "../auth/authenticated-actor";
import { SessionService } from "../auth/session.service";
import { TokenService } from "../auth/token.service";

interface JourneySocketData {
  actor?: AuthenticatedActor;
}

@Injectable()
@WebSocketGateway({
  namespace: "/journeys",
  transports: ["websocket", "polling"],
})
export class JourneyGateway implements OnGatewayConnection {
  private readonly logger = new Logger(JourneyGateway.name);

  @WebSocketServer()
  private server!: Server;

  constructor(
    private readonly tokens: TokenService,
    private readonly sessions: SessionService,
  ) {}

  async handleConnection(socket: Socket): Promise<void> {
    try {
      const raw = socket.handshake.auth?.["token"];
      if (typeof raw !== "string" || raw.length === 0)
        throw new Error("missing token");
      const claims = await this.tokens.verifyAccessToken(raw);
      const actor = await this.sessions.authenticateAccess(
        claims.userId,
        claims.sessionId,
      );
      (socket.data as JourneySocketData).actor = actor;
      await socket.join(`user:${actor.user.id}`);
      if (
        actor.user.actorType === "KCCA_STAFF" &&
        actor.user.mobileMonitoringPermitted
      ) {
        await socket.join("role:kcca-monitoring");
      }
      socket.emit("session:ready", {
        reconciliation: "REST",
        authenticated: true,
      });
    } catch {
      socket.emit("session:error", {
        code: ApiErrorCode.authenticationRequired,
        message: "A valid access token is required.",
      });
      socket.disconnect(true);
    }
  }

  @SubscribeMessage("journey:reconcile")
  reconcile(
    @ConnectedSocket() socket: Socket,
    @MessageBody() body: { requestId?: unknown; phase?: unknown },
  ): { requestId: string; phase: JourneyPhase; reconciliation: "REST" } | void {
    if (!(socket.data as JourneySocketData).actor) return;
    if (
      typeof body.requestId !== "string" ||
      !Object.values(JourneyPhase).includes(body.phase as JourneyPhase)
    ) {
      return;
    }
    return {
      requestId: body.requestId,
      phase: body.phase as JourneyPhase,
      reconciliation: "REST",
    };
  }

  publishSnapshot(
    requestId: string,
    recipientUserIds: string[],
    snapshot: JourneySnapshotContract,
  ): void {
    const rooms = [...new Set(recipientUserIds)].map((id) => `user:${id}`);
    const event = { requestId, ...snapshot };
    for (const room of rooms)
      this.server.to(room).emit("journey:position", event);
    this.server.to("role:kcca-monitoring").emit("journey:position", event);
    this.logger.debug(
      `Published journey reconciliation hint for ${requestId}.`,
    );
  }
}
