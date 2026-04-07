/**
 * Supabase 연동 스모크: .env 로드 후 설정 플래그 + Auth Admin listUsers 1건.
 * 실행: node scripts/supabase-smoke.mjs (프로젝트 루트에서)
 */
import "dotenv/config";
import { createClient } from "@supabase/supabase-js";

const url = process.env.SUPABASE_URL?.trim();
const service = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
const anon = process.env.SUPABASE_ANON_KEY?.trim();
const jwtSecret = process.env.SUPABASE_JWT_SECRET?.trim();

const out = {
  databaseUrl: Boolean(process.env.DATABASE_URL?.trim()),
  supabaseUrl: Boolean(url && /^https?:\/\//i.test(url)),
  serviceRole: Boolean(service),
  anon: Boolean(anon),
  jwtSecret: Boolean(jwtSecret)
};
console.log("[env]", JSON.stringify(out, null, 2));

if (!url || !service) {
  console.log("[skip] SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY 필요");
  process.exit(0);
}

const admin = createClient(url, service, {
  auth: { persistSession: false, autoRefreshToken: false }
});

const { data, error } = await admin.auth.admin.listUsers({ page: 1, perPage: 1 });
if (error) {
  console.error("[auth.admin.listUsers] FAIL:", error.message);
  process.exit(1);
}
console.log("[auth.admin.listUsers] OK sampleCount=", data?.users?.length ?? 0);

if (anon) {
  const client = createClient(url, anon, {
    auth: { persistSession: false, autoRefreshToken: false }
  });
  const anonHealth = await client.auth.getSession();
  console.log("[anon client] getSession (no session expected):", anonHealth.error?.message ?? "ok");
}

console.log("[done] Supabase API 응답 정상");
