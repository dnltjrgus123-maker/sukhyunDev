import "app_env.dart";

/// - [oauthRedirectUrl]: `signInWithOAuth(redirectTo: …)` — 인증 후 앱으로 복귀 (딥링크).
/// - Kakao/구글 **개발자 콘솔** Redirect URI에는 [AppEnv.supabaseAuthCallbackUrl] 을 등록.
/// - Supabase Dashboard **Redirect URLs**에는 콜백 URL + 딥링크 둘 다 허용.
abstract final class AuthConfig {
  static const String oauthRedirectUrl = "com.bdminton.meet.app://callback";
}
