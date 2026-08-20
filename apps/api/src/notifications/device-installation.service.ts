import { ForbiddenException, Injectable } from "@nestjs/common";
import { ApiErrorCode } from "@weyonje/contracts";
import { AuthenticatedActor } from "../auth/authenticated-actor";
import { PrismaService } from "../database/prisma.service";
import { DeviceTokenSecurityService } from "./device-token-security.service";

@Injectable()
export class DeviceInstallationService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tokens: DeviceTokenSecurityService,
  ) {}
  async register(
    actor: AuthenticatedActor,
    input: {
      installationId: string;
      token: string;
      platform: string;
      environment: string;
    },
  ) {
    if (!actor.user.isActive)
      throw new ForbiddenException({
        code: ApiErrorCode.accessDenied,
        message: "This account cannot register notifications.",
      });
    const lookup = this.tokens.lookup(input.token);
    await this.prisma.$transaction(async (tx) => {
      await tx.deviceInstallation.deleteMany({
        where: {
          tokenLookup: lookup,
          NOT: {
            userId: actor.user.id,
            installationId: input.installationId,
            environment: input.environment,
          },
        },
      });
      await tx.deviceInstallation.upsert({
        where: {
          userId_installationId_environment: {
            userId: actor.user.id,
            installationId: input.installationId,
            environment: input.environment,
          },
        },
        create: {
          userId: actor.user.id,
          installationId: input.installationId,
          environment: input.environment,
          platform: input.platform,
          tokenLookup: lookup,
          encryptedToken: this.tokens.encrypt(input.token),
        },
        update: {
          platform: input.platform,
          tokenLookup: lookup,
          encryptedToken: this.tokens.encrypt(input.token),
          active: true,
          invalidatedAt: null,
          lastSeenAt: new Date(),
        },
      });
    });
    return { registered: true as const };
  }
  async remove(actor: AuthenticatedActor, installationId: string) {
    await this.prisma.deviceInstallation.updateMany({
      where: { userId: actor.user.id, installationId },
      data: { active: false, invalidatedAt: new Date() },
    });
    return { removed: true as const };
  }
  async targets(userId: string) {
    const rows = await this.prisma.deviceInstallation.findMany({
      where: {
        userId,
        active: true,
        user: {
          isActive: true,
          loginEnabled: true,
          OR: [
            { actorType: { not: "SERVICE_PROVIDER" } },
            { providerStatus: "APPROVED" },
          ],
        },
      },
      select: { id: true, encryptedToken: true },
    });
    return rows.map((row) => ({
      id: row.id,
      token: this.tokens.decrypt(row.encryptedToken),
    }));
  }
  async invalidate(ids: string[]) {
    if (ids.length === 0) return;
    await this.prisma.deviceInstallation.updateMany({
      where: { id: { in: ids } },
      data: { active: false, invalidatedAt: new Date() },
    });
  }
}
