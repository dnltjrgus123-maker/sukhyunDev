import "dart:async";

import "package:app_links/app_links.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../core/config/app_env.dart";
import "../../../core/config/auth_config.dart";
import "../../../core/network/api_client.dart";
import "../../../core/providers/api_provider.dart";

Future<void> syncServerProfileForSession(Session session) async {
  final api = ApiClient(
    baseUrl: AppEnv.apiBaseUrl,
    actorUserId: session.user.id,
    getAccessToken: () async => session.accessToken,
  );
  await api.syncProfile();
}

bool _isKakaoTicketDeepLink(Uri u) =>
    u.scheme == "com.bdminton.meet.app" &&
    u.host == "kakao" &&
    (u.queryParameters["ticket"] ?? "").isNotEmpty;

Future<Uri> _waitKakaoTicketUri() async {
  final appLinks = AppLinks();
  final initial = await appLinks.getInitialLink();
  if (initial != null && _isKakaoTicketDeepLink(initial)) {
    return initial;
  }
  return appLinks.uriLinkStream
      .firstWhere(_isKakaoTicketDeepLink)
      .timeout(const Duration(minutes: 3));
}

class AuthController extends StateNotifier<AsyncValue<Session?>> {
  AuthController(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<void> signOut() async {
    if (AppEnv.hasSupabaseConfig) {
      await Supabase.instance.client.auth.signOut();
    }
    state = const AsyncValue.data(null);
  }

  /// 개발용: 서버 모의 소셜(서비스 롤) — OAuth 미설정 시에도 동작.
  Future<void> signInWithMockSocialFromServer() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      if (!AppEnv.hasSupabaseConfig) {
        throw Exception("dart-define에 SUPABASE_URL, SUPABASE_ANON_KEY가 없습니다.");
      }
      final api = ref.read(apiClientProvider);
      final result = await api.socialLogin(
        provider: "google",
        providerUserId: "flutter-dev-user",
        email: "flutter-dev@example.com",
        nickname: "flutter-user",
      );
      if (result.supabaseRefreshToken.isEmpty) {
        throw Exception(
          "응답에 supabaseRefreshToken이 없습니다. 서버 .env의 키와 클라이언트 dart-define을 확인하세요.",
        );
      }
      final auth = Supabase.instance.client.auth;
      final res = await auth.setSession(result.supabaseRefreshToken);
      final session = res.session;
      if (session != null) {
        await syncServerProfileForSession(session);
      }
      return session;
    });
  }

  Future<void> signInWithGoogle() => _oauthSignIn(OAuthProvider.google);

  /// 카카오: API 프록시(이메일 스코프 미요청) → OIDC id_token → Supabase 세션.
  /// 문서상 signInWithOAuth(kakao)+Allow users without an email 로도 가능하지만,
  /// 호스팅 Auth가 authorize에 account_email을 넣는 경우 KOE205 — 그때 KAKAO_* 필수.
  Future<void> signInWithKakao() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      if (!AppEnv.hasSupabaseConfig) {
        throw Exception("Supabase 설정이 필요합니다.");
      }
      final api = ref.read(apiClientProvider);
      final url = await api.getKakaoAuthorizeUrl();
      final uriFuture = _waitKakaoTicketUri();
      final launched =
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!launched) {
        throw Exception("브라우저를 열 수 없습니다.");
      }
      final deepLink = await uriFuture;
      final ticket = deepLink.queryParameters["ticket"] ?? "";
      if (ticket.isEmpty) {
        throw Exception("ticket이 없습니다.");
      }
      final result = await api.claimKakaoTicket(ticket);
      if (result.supabaseRefreshToken.isEmpty) {
        throw Exception("세션을 받지 못했습니다.");
      }
      final auth = Supabase.instance.client.auth;
      final res = await auth.setSession(result.supabaseRefreshToken);
      final session = res.session;
      if (session != null) {
        await syncServerProfileForSession(session);
      }
      return session;
    });
  }

  /// 네이버: 대시보드에 provider slug `naver` 등록 필요. PKCE 파라미터 유지를 위해 URL만 교체.
  Future<void> signInWithNaver() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      if (!AppEnv.hasSupabaseConfig) {
        throw Exception("Supabase 설정이 필요합니다.");
      }
      final client = Supabase.instance.client.auth;
      final res = await client.getOAuthSignInUrl(
        provider: OAuthProvider.google,
        redirectTo: AuthConfig.oauthRedirectUrl,
      );
      final uri = Uri.parse(res.url);
      final q = Map<String, String>.from(uri.queryParameters);
      q["provider"] = "naver";
      final fixed = uri.replace(queryParameters: q);
      final future = client.onAuthStateChange
          .where((a) => a.event == AuthChangeEvent.signedIn && a.session != null)
          .map((a) => a.session!)
          .first
          .timeout(const Duration(minutes: 3));
      final launched = await launchUrl(fixed, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw Exception("브라우저를 열 수 없습니다.");
      }
      final session = await future;
      await syncServerProfileForSession(session);
      return session;
    });
  }

  Future<void> _oauthSignIn(OAuthProvider provider) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      if (!AppEnv.hasSupabaseConfig) {
        throw Exception("Supabase 설정이 필요합니다.");
      }
      final client = Supabase.instance.client.auth;
      final existing = client.currentSession;
      if (existing != null) {
        await syncServerProfileForSession(existing);
        return existing;
      }
      final future = client.onAuthStateChange
          .where((a) => a.event == AuthChangeEvent.signedIn && a.session != null)
          .map((a) => a.session!)
          .first
          .timeout(const Duration(minutes: 3));
      await client.signInWithOAuth(
        provider,
        redirectTo: AuthConfig.oauthRedirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      final session = await future;
      await syncServerProfileForSession(session);
      return session;
    });
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<Session?>>((ref) {
  return AuthController(ref);
});
