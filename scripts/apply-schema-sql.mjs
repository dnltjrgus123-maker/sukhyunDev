import { readFile } from "node:fs/promises";
import { Client } from "pg";

async function main() {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    throw new Error("DATABASE_URL is required.");
  }

  const base = await readFile(new URL("../db/schema.sql", import.meta.url), "utf-8");
  const ext = await readFile(new URL("../db/schema_extensions.sql", import.meta.url), "utf-8").catch(() => "");
  const sql = ext ? `${base}\n\n${ext}` : base;
  const client = new Client({ connectionString });
  await client.connect();
  try {
    await client.query("BEGIN");
    await client.query(sql);
    await client.query("COMMIT");
    console.log("Schema applied successfully.");
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
