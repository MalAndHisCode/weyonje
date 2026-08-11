import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

import { generateOpenApiDocument } from "./openapi-document";

async function main(): Promise<void> {
  const target = resolve(process.cwd(), "openapi", "openapi.json");
  const expected = `${JSON.stringify(await generateOpenApiDocument(), null, 2)}\n`;
  const actual = await readFile(target, "utf8");
  if (actual !== expected) {
    throw new Error(
      "OpenAPI contract is out of date. Run pnpm openapi:generate.",
    );
  }
}

void main();
