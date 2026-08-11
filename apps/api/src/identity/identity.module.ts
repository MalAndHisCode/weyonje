import { Module } from "@nestjs/common";

import { AuthModule } from "../auth/auth.module";
import { ActorsController } from "./actors.controller";
import { CurrentActorService } from "./current-actor.service";

@Module({
  imports: [AuthModule],
  controllers: [ActorsController],
  providers: [CurrentActorService],
})
export class IdentityModule {}
