import { Module } from "@nestjs/common";

import { AfricasTalkingSmsGateway, SmsGateway } from "./sms-gateway";
import { PhoneChallengeService } from "./phone-challenge.service";
import { PhoneSecurityService } from "./phone-security.service";

@Module({
  providers: [
    PhoneChallengeService,
    PhoneSecurityService,
    AfricasTalkingSmsGateway,
    { provide: SmsGateway, useExisting: AfricasTalkingSmsGateway },
  ],
  exports: [PhoneChallengeService, PhoneSecurityService],
})
export class PhoneModule {}
