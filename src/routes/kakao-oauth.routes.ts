import { Router } from "express";

import {
  createKakaoSessionTicket,
  createOAuthState,
  consumeOAuthState,
  getKakaoOAuthScope,
  kakaoOAuthEnvOk,
  takeKakaoSessionTicket
} from "../lib/kakao-oauth.js";

/**
 * Supabase 문서: account_email은 선택(Biz 앱), Kakao provider의 Allow users without an email 로
 * 이메일 없이 진행 가능하다고 안내한다.
 * 호스팅 Auth 구현(supabase/auth NewKakaoProvider)은 authorize 스코프 기본 배열에
 * account_email을 포함하는 코드가 남아 있어, 비즈 앱이 아닌 앱에서 KOE205가 날 수 있다.
 * 이 라우트는 카카오에 직접 인가(OIDC, 프로필만) 후 grant_type=id_token 으로 세션을 맞춘다.
 */
export const kakaoOAuthRouter = Router();

kakaoOAuthRouter.get("/auth/kakao/authorize-url", (_req, res) => {
  if (!kakaoOAuthEnvOk()) {
    return res.status(503).json({
      message:
        "Kakao OAuth proxy 미설정: KAKAO_REST_API_KEY, KAKAO_CLIENT_SECRET, KAKAO_REDIRECT_URI, SUPABASE_URL, SUPABASE_ANON_KEY"
    });
  }
  const clientId = process.env.KAKAO_REST_API_KEY!.trim();
  const redirectUri = process.env.KAKAO_REDIRECT_URI!.trim();
  const state = createOAuthState();
  const params = new URLSearchParams({
    client_id: clientId,
    redirect_uri: redirectUri,
    response_type: "code",
    scope: getKakaoOAuthScope(),
    state
  });
  const url = `https://kauth.kakao.com/oauth/authorize?${params.toString()}`;
  res.json({ url });
});

kakaoOAuthRouter.get("/auth/kakao/callback", async (req, res) => {
  const code = typeof req.query.code === "string" ? req.query.code : "";
  const state = typeof req.query.state === "string" ? req.query.state : "";
  const err = typeof req.query.error === "string" ? req.query.error : "";

  if (err) {
    return res.status(400).send(`Kakao 오류: ${err}`);
  }
  if (!code || !consumeOAuthState(state)) {
    return res.status(400).send("잘못된 요청(code/state).");
  }
  if (!kakaoOAuthEnvOk()) {
    return res.status(503).send("서버 Kakao/Supabase 환경 변수가 없습니다.");
  }

  const clientId = process.env.KAKAO_REST_API_KEY!.trim();
  const clientSecret = process.env.KAKAO_CLIENT_SECRET!.trim();
  const redirectUri = process.env.KAKAO_REDIRECT_URI!.trim();
  const supabaseUrl = process.env.SUPABASE_URL!.replace(/\/$/, "");
  const anonKey = process.env.SUPABASE_ANON_KEY!.trim();

  const form = new URLSearchParams({
    grant_type: "authorization_code",
    client_id: clientId,
    redirect_uri: redirectUri,
    code,
    client_secret: clientSecret
  });

  const tokRes = await fetch("https://kauth.kakao.com/oauth/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded;charset=utf-8"
    },
    body: form.toString()
  });

  const tokJson = (await tokRes.json()) as Record<string, unknown>;
  if (!tokRes.ok) {
    return res
      .status(502)
      .send(
        `카카오 토큰 교환 실패: ${JSON.stringify(tokJson)}. OIDC·동의항목(openid, 프로필)을 확인하세요.`
      );
  }

  const idToken = typeof tokJson.id_token === "string" ? tokJson.id_token : "";
  if (!idToken) {
    return res
      .status(502)
      .send(
        "id_token이 없습니다. Kakao 개발자 콘솔에서 OpenID Connect 활성화 후 동의 항목에 openid·프로필을 넣으세요."
      );
  }

  const sbRes = await fetch(`${supabaseUrl}/auth/v1/token?grant_type=id_token`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: anonKey,
      Authorization: `Bearer ${anonKey}`
    },
    body: JSON.stringify({
      provider: "kakao",
      id_token: idToken
    })
  });

  const sbJson = (await sbRes.json()) as Record<string, unknown> & {
    session?: { refresh_token?: string };
  };
  if (!sbRes.ok) {
    return res.status(502).send(`Supabase id_token 교환 실패: ${JSON.stringify(sbJson)}`);
  }

  const refresh =
    typeof sbJson.refresh_token === "string"
      ? sbJson.refresh_token
      : typeof sbJson.session?.refresh_token === "string"
        ? sbJson.session.refresh_token
        : "";

  if (!refresh) {
    return res.status(502).send(`Supabase 응답에 refresh_token이 없습니다: ${JSON.stringify(sbJson)}`);
  }

  const ticket = createKakaoSessionTicket(refresh);
  const deepLink = `com.bdminton.meet.app://kakao?ticket=${encodeURIComponent(ticket)}`;
  res.redirect(302, deepLink);
});

kakaoOAuthRouter.post("/auth/kakao/claim", (req, res) => {
  const ticket = typeof req.body?.ticket === "string" ? req.body.ticket.trim() : "";
  if (!ticket) {
    return res.status(400).json({ message: "ticket is required" });
  }
  const refresh = takeKakaoSessionTicket(ticket);
  if (!refresh) {
    return res.status(400).json({ message: "Invalid or expired ticket" });
  }
  res.json({ supabaseRefreshToken: refresh });
});
