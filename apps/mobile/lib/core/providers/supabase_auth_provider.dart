import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../config/app_env.dart";

/// Supabase Auth 상태 스트림. 미설정 시 단일 `null`(세션 없음).
final supabaseAuthProvider = StreamProvider<AuthState?>((ref) {
  if (!AppEnv.hasSupabaseConfig) {
    return Stream<AuthState?>.value(null);
  }
  return Supabase.instance.client.auth.onAuthStateChange.map<AuthState?>((a) => a);
});
