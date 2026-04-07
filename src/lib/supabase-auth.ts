import * as jose from "jose";

function readEnv(name: string): string | undefined {
  const v = process.env[name];
  return typeof v === "string" && v.trim().length > 0 ? v.trim() : undefined;
}

/**
 * 환경 변수 `SUPABASE_JWT_SECRET` — 루트 `.env` / `.env.example` 주석 참고.
 * Supabase 대시보드 → Project Settings → API → JWT 설정의 **JWT Secret**(HS256, anon/service 키와 다름).
 * "JWT Signing Keys" 비대칭 키가 아닌 이 Secret 문자열을 넣습니다.
 */
export function isSupabaseJwtSecretConfigured(): boolean {
  return Boolean(readEnv("SUPABASE_JWT_SECRET"));
}

export async function verifySupabaseAccessToken(token: string): Promise<{ sub: string }> {
  const secret = readEnv("SUPABASE_JWT_SECRET");
  if (!secret) {
    throw new Error("SUPABASE_JWT_SECRET is not configured");
  }
  const key = new TextEncoder().encode(secret);
  const { payload } = await jose.jwtVerify(token, key, { algorithms: ["HS256"] });
  const sub = payload.sub;
  if (typeof sub !== "string" || sub.length === 0) {
    throw new Error("Invalid token: missing sub");
  }
  return { sub };
}
