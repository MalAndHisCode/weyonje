import "reflect-metadata";

import { ConsoleLogger } from "@nestjs/common";
import { NestFactory } from "@nestjs/core";

import { DeliveryProcessor } from "./delivery/delivery.processor";
import { WorkerModule } from "./worker.module";

async function bootstrap(): Promise<void> {
  const app = await NestFactory.createApplicationContext(WorkerModule, {
    logger: new ConsoleLogger({ json: true }),
  });
  app.enableShutdownHooks();
  const processor = app.get(DeliveryProcessor);
  const stop = () => processor.stop();
  process.once("SIGINT", stop);
  process.once("SIGTERM", stop);
  try {
    await processor.run();
  } finally {
    await app.close();
  }
}

void bootstrap();
