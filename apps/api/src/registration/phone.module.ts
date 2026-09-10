import { Module } from "@nestjs/common";
import { ConfigType } from "@nestjs/config";

import { smsConfig } from "../config/sms.config";
import {
  AfricasTalkingSmsGateway,
  DevelopmentFakeSmsGateway,
  SmsGateway,
} from "./sms-gateway";
import { PhoneChallengeService } from "./phone-challenge.service";
import { PhoneSecurityService } from "./phone-security.service";

@Module({
  providers: [
    PhoneChallengeService,
    PhoneSecurityService,
    AfricasTalkingSmsGateway,
    DevelopmentFakeSmsGateway,
    {
      provide: SmsGateway,
      inject: [
        smsConfig.KEY,
        AfricasTalkingSmsGateway,
        DevelopmentFakeSmsGateway,
      ],
      useFactory: (
        config: ConfigType<typeof smsConfig>,
        africasTalking: AfricasTalkingSmsGateway,
        fake: DevelopmentFakeSmsGateway,
      ) => {
        switch (config.provider) {
          case "AFRICAS_TALKING":
            return africasTalking;
          case "FAKE":
            return fake;
          default:
            throw new Error("Unsupported SMS_PROVIDER");
        }
      },
    },
  ],
  exports: [PhoneChallengeService, PhoneSecurityService],
})
export class PhoneModule {}
