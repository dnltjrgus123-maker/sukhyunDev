import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../../core/config/app_env.dart";
import "../../../core/providers/api_provider.dart";

class AuthController extends StateNotifier<AsyncValue<Session?>> {
  AuthController(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  /// 모의 소셜 로그인 → 서버가 Supabase 세션을 내려주면 클라이언트에 저장합니다.
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
          "응답에 supabaseRefreshToken이 없습니다. "
          "서버 .env의 SUPABASE_SERVICE_ROLE_KEY·SUPABASE_ANON_KEY와 "
          "클라이언트 dart-define(SUPABASE_URL·SUPABASE_ANON_KEY)을 확인하세요. "
          "시드만 있는 사용자는 모의 로그인 시 서버가 같은 UUID로 auth.users를 만듭니다.",
        );
      }
      final auth = Supabase.instance.client.auth;
      final res = await auth.setSession(result.supabaseRefreshToken);
      return res.session;
    });
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<Session?>>((ref) {
  return AuthController(ref);
});
