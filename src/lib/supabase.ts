import { createClient, type SupabaseClient } from "@supabase/supabase-js";

let adminSingleton: SupabaseClient | null = null;

function readEnv(name: string): string | undefined {
  const v = process.env[name];
  return typeof v === "string" && v.trim().length > 0 ? v.trim() : undefined;
}

/** 대시보드 Project Settings → API */
export function isSupabaseConfigured(): boolean {
  const url = readEnv("SUPABASE_URL");
  return Boolean(url && /^https?:\/\//i.test(url) && readEnv("SUPABASE_SERVICE_ROLE_KEY"));
}

/**
 * 서버 전용 클라이언트 — **service_role** 키 사용(Row Level Security 우회).
 * API 라우트·백그라운드 잡에서만 사용하고, 키는 클라이언트·Git에 노출하지 않습니다.
 */
export function getSupabaseAdmin(): SupabaseClient | null {
  if (!isSupabaseConfigured()) return null;
  if (adminSingleton) return adminSingleton;

  const url = readEnv("SUPABASE_URL")!;
  const serviceRoleKey = readEnv("SUPABASE_SERVICE_ROLE_KEY")!;

  adminSingleton = createClient(url, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false
    }
  });

  return adminSingleton;
}

/**
 * 공개(anon) 키 클라이언트 — RLS 정책이 적용됩니다.
 * 서버에서 “유저 컨텍스트”로 호출할 때만 필요하면 사용합니다.
 */
export function getSupabaseAnon(): SupabaseClient | null {
  const url = readEnv("SUPABASE_URL");
  const anon = readEnv("SUPABASE_ANON_KEY");
  if (!url || !anon || !/^https?:\/\//i.test(url)) return null;

  return createClient(url, anon, {
    auth: {
      persistSession: false,
      autoRefreshToken: false
    }
  });
}
