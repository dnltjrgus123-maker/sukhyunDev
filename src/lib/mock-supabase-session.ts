import { randomUUID } from "node:crypto";
import type { SupabaseClient } from "@supabase/supabase-js";

export type SupabaseSessionTokens = {
  accessToken: string;
  refreshToken: string
};

const MOCK_EMAIL_DOMAIN = "mock.bdminton.internal";

export function syntheticEmailForUserId(userId: string): string {
  return `${userId}@${MOCK_EMAIL_DOMAIN}`;
}

/**
 * 개발용 모의 소셜: service_role로 비밀번호를 덮어쓴 뒤 anon 클라이언트로 세션을 받습니다.
 * `public.users.id`와 `auth.users.id`가 같아야 합니다.
 */
export async function issueSessionByUserId(
  admin: SupabaseClient,
  anon: SupabaseClient,
  authUserId: string,
  email: string
): Promise<SupabaseSessionTokens | null> {
  const password = randomUUID();
  const { error: updErr } = await admin.auth.admin.updateUserById(authUserId, { password });
  if (updErr) return null;
  const { data, error } = await anon.auth.signInWithPassword({ email, password });
  if (error || !data.session) return null;
  return {
    accessToken: data.session.access_token,
    refreshToken: data.session.refresh_token
  };
}

export async function tryAttachSupabaseSessionToSocialResponse(params: {
  admin: SupabaseClient;
  anon: SupabaseClient;
  prismaUserId: string;
  prismaEmail: string | null;
  response: Record<string, unknown>;
}): Promise<void> {
  const { admin, anon, prismaUserId, prismaEmail, response } = params;
  let get = await admin.auth.admin.getUserById(prismaUserId);
  if (get.error || !get.data?.user) {
    const emailForAuth =
      prismaEmail && prismaEmail.trim().length > 0
        ? prismaEmail.trim().toLowerCase()
        : syntheticEmailForUserId(prismaUserId);
    const password = randomUUID();
    const { data: created, error: createErr } = await admin.auth.admin.createUser({
      id: prismaUserId,
      email: emailForAuth,
      password,
      email_confirm: true
    });
    if (createErr || !created?.user) {
      return;
    }
    get = { data: { user: created.user }, error: null };
  }
  const wrap = get.data!;
  let email = wrap.user.email ?? prismaEmail ?? syntheticEmailForUserId(prismaUserId);
  if (!wrap.user.email && prismaEmail) {
    await admin.auth.admin.updateUserById(prismaUserId, { email: prismaEmail });
    email = prismaEmail;
  }
  const session = await issueSessionByUserId(admin, anon, prismaUserId, email);
  if (session) {
    response.supabaseAccessToken = session.accessToken;
    response.supabaseRefreshToken = session.refreshToken;
  }
}
