import * as jose from "jose";

function readEnv(name: string): string | undefined {
  const v = process.env[name];
  return typeof v === "string" && v.trim().length > 0 ? v.trim() : undefined;
}

const jwtClockTolerance = "60s";

/**
 * 환경 변수 `SUPABASE_JWT_SECRET` — 루트 `.env` / `.env.example` 주석 참고.
 * 레거시 HS256 대칭 시크릿. "JWT Signing Keys"만 쓰는 프로젝트는 비어 있어도 JWKS 폴백 가능.
 */
export function isSupabaseJwtSecretConfigured(): boolean {
  return Boolean(readEnv("SUPABASE_JWT_SECRET"));
}

/** Bearer access_token 검증을 시도할지(미들웨어). JWT Secret 또는 JWKS(SUPABASE_URL) 중 하나면 true. */
export function isSupabaseAccessTokenVerificationConfigured(): boolean {
  return isSupabaseJwtSecretConfigured() || Boolean(readEnv("SUPABASE_URL"));
}

function normalizeSupabaseOrigin(url: string): string {
  return url.replace(/\/$/, "");
}

/**
 * 1) `SUPABASE_JWT_SECRET` 이 있으면 HS256으로 먼저 검증.
 * 2) 실패하거나 비대칭(ES256 등) 토큰이면 `SUPABASE_URL`의 JWKS로 검증.
 * @see https://supabase.com/docs/guides/auth/jwts
 */
export async function verifySupabaseAccessToken(token: string): Promise<{ sub: string }> {
  const secret = readEnv("SUPABASE_JWT_SECRET");
  if (secret) {
    try {
      const key = new TextEncoder().encode(secret);
      const { payload } = await jose.jwtVerify(token, key, {
        algorithms: ["HS256"],
        clockTolerance: jwtClockTolerance
      });
      const sub = payload.sub;
      if (typeof sub === "string" && sub.length > 0) {
        return { sub };
      }
      throw new Error("Invalid token: missing sub");
    } catch {
      /* 대칭 시크릿과 알고리즘이 맞지 않으면 JWKS 시도 */
    }
  }

  const baseUrl = readEnv("SUPABASE_URL");
  if (!baseUrl) {
    throw new Error(
      "SUPABASE_URL is not set (JWKS). Set SUPABASE_JWT_SECRET for HS256-only or SUPABASE_URL for JWKS."
    );
  }

  const origin = normalizeSupabaseOrigin(baseUrl);
  const jwksUri = new URL("/auth/v1/.well-known/jwks.json", `${origin}/`);
  const JWKS = jose.createRemoteJWKSet(jwksUri);
  const issuer = `${origin}/auth/v1`;

  const { payload } = await jose.jwtVerify(token, JWKS, {
    issuer,
    clockTolerance: jwtClockTolerance
  });
  const sub = payload.sub;
  if (typeof sub !== "string" || sub.length === 0) {
    throw new Error("Invalid token: missing sub");
  }
  return { sub };
}
