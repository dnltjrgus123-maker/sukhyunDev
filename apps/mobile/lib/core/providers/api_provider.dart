import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../config/app_env.dart";
import "../network/api_client.dart";
import "supabase_auth_provider.dart";

final apiClientProvider = Provider<ApiClient>((ref) {
  final auth = ref.watch(supabaseAuthProvider);
  final session = auth.valueOrNull?.session ??
      (AppEnv.hasSupabaseConfig ? Supabase.instance.client.auth.currentSession : null);
  final uid = session?.user.id;
  return ApiClient(
    baseUrl: AppEnv.apiBaseUrl,
    actorUserId: uid ?? "00000000-0000-4000-8000-000000000002",
    getAccessToken: () async {
      if (!AppEnv.hasSupabaseConfig) return null;
      return Supabase.instance.client.auth.currentSession?.accessToken;
    },
  );
});

final hostApiClientProvider = Provider<ApiClient>((ref) {
  ref.watch(supabaseAuthProvider);
  return ApiClient(
    baseUrl: AppEnv.apiBaseUrl,
    actorUserId: "00000000-0000-4000-8000-000000000001",
    getAccessToken: () async {
      if (!AppEnv.hasSupabaseConfig) return null;
      return Supabase.instance.client.auth.currentSession?.accessToken;
    },
  );
});
