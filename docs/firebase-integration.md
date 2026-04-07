# 인증: Supabase Auth

이전 Firebase 연동은 제거되었습니다. 서버·클라이언트 모두 **Supabase Auth** 기준입니다.

## 서버 (Express)

- `Authorization: Bearer <access_token>`: `SUPABASE_JWT_SECRET`으로 JWT를 검증하고 `sub`를 액터 UUID로 사용합니다.
- `/health` 응답의 `supabaseJwt`가 JWT Secret 설정 여부를 나타냅니다.
- 모의 소셜 `POST /auth/social/:provider`는 서비스 롤·anon 키가 있으면 `supabaseAccessToken` / `supabaseRefreshToken`을 함께 반환합니다. `public.users.id`와 `auth.users.id`가 같아야 세션 연동이 됩니다.

## Flutter

- `--dart-define=SUPABASE_URL=...` 및 `SUPABASE_ANON_KEY=...`로 `Supabase.initialize` 합니다.
- gotrue `setSession`은 **refresh token** 인자를 받습니다. 모의 로그인 후 `supabaseRefreshToken`으로 세션을 복구합니다.

## 환경 변수

- **서버:** 프로젝트 루트 `.env` (`.env.example`을 복사 후 채움 — 각 키마다 대시보드 경로 주석 있음)
- **Flutter:** `apps/mobile/dart_defines.json.example` → `dart_defines.json`으로 복사 후 `SUPABASE_URL`·`SUPABASE_ANON_KEY`만 입력 (`dart_defines.json`은 Git 제외)
