import { writeFile } from "node:fs/promises";
import { resolve } from "node:path";

import { generateOpenApiDocument } from "./openapi-document";

async function main(): Promise<void> {
  const target = resolve(process.cwd(), "openapi", "openapi.json");
  const document = await generateOpenApiDocument();
  await writeFile(target, `${JSON.stringify(document, null, 2)}\n`, "utf8");
}

void main();
