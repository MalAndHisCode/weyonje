import { Module } from "@nestjs/common";

import { AuthModule } from "../auth/auth.module";
import { PhoneModule } from "./phone.module";
import {
  ProviderRegistrationController,
  RegistrationController,
} from "./registration.controller";
import { RegistrationService } from "./registration.service";

@Module({
  imports: [AuthModule, PhoneModule],
  controllers: [RegistrationController, ProviderRegistrationController],
  providers: [RegistrationService],
})
export class RegistrationModule {}
