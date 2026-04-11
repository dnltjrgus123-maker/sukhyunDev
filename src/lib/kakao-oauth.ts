import { randomUUID } from "node:crypto";

/** 일회용 Supabase refresh 토큰 전달 (딥링크) */
const tickets = new Map<string, { refreshToken: string; exp: number }>();
/** CSRF용 authorize state */
const oauthStates = new Map<string, number>();

const TTL_MS = 5 * 60_000;
const STATE_TTL_MS = 10 * 60_000;

function cleanupMaps() {
  const now = Date.now();
  for (const [k, v] of tickets) {
    if (now > v.exp) tickets.delete(k);
  }
  for (const [k, exp] of oauthStates) {
    if (now > exp) oauthStates.delete(k);
  }
}

export function createOAuthState(): string {
  cleanupMaps();
  const s = randomUUID();
  oauthStates.set(s, Date.now() + STATE_TTL_MS);
  return s;
}

export function consumeOAuthState(state: string | undefined): boolean {
  if (!state) return false;
  cleanupMaps();
  const exp = oauthStates.get(state);
  oauthStates.delete(state);
  return exp != null && Date.now() <= exp;
}

export function createKakaoSessionTicket(refreshToken: string): string {
  cleanupMaps();
  const id = randomUUID();
  tickets.set(id, { refreshToken, exp: Date.now() + TTL_MS });
  return id;
}

export function takeKakaoSessionTicket(id: string): string | null {
  cleanupMaps();
  const row = tickets.get(id);
  tickets.delete(id);
  if (!row || Date.now() > row.exp) return null;
  return row.refreshToken;
}

export function kakaoOAuthEnvOk(): boolean {
  const id = process.env.KAKAO_REST_API_KEY?.trim();
  const secret = process.env.KAKAO_CLIENT_SECRET?.trim();
  const redir = process.env.KAKAO_REDIRECT_URI?.trim();
  const url = process.env.SUPABASE_URL?.trim();
  const anon = process.env.SUPABASE_ANON_KEY?.trim();
  return Boolean(id && secret && redir && url && anon);
}

/**
 * 인가 코드 요청의 scope — 카카오 문서는 **쉼표(,)** 로 여러 동의항목을 구분한다.
 * 공백 구분(openid+profile_…)은 invalid_scope(KOE205)로 이어질 수 있음.
 * 콘솔 [동의항목]에 켜 둔 것만 넣을 것. profile_image 미설정이면 기본에서 제외.
 */
export function getKakaoOAuthScope(): string {
  const fromEnv = process.env.KAKAO_OAUTH_SCOPE?.trim();
  if (fromEnv) return fromEnv;
  return "openid,profile_nickname";
}
