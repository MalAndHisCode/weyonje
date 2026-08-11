import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";

import { ActorProfileEntity } from "./actor-profile.entity";
import { ActorsController } from "./actors.controller";
import { CurrentActorService } from "./current-actor.service";
import { JwtAuthGuard } from "./jwt-auth.guard";
import { TokenVerifier } from "./token-verifier";

@Module({
  imports: [TypeOrmModule.forFeature([ActorProfileEntity])],
  controllers: [ActorsController],
  providers: [CurrentActorService, JwtAuthGuard, TokenVerifier],
})
export class IdentityModule {}
