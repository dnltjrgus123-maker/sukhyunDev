import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/config/app_env.dart";
import "../../core/providers/supabase_auth_provider.dart";
import "../shell/app_shell_screen.dart";
import "auth_welcome_screen.dart";

/// 로그인 여부에 따라 웰컴(소셜 로그인) 또는 메인 셸.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(supabaseAuthProvider);

    if (!AppEnv.hasSupabaseConfig) {
      return const AppShellScreen();
    }

    return auth.when(
      data: (state) {
        final session = state?.session;
        if (session != null) {
          return const AppShellScreen();
        }
        return const AuthWelcomeScreen();
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const AuthWelcomeScreen(),
    );
  }
}
