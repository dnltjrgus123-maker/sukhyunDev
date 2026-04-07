import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "core/app_router.dart";
import "core/config/app_env.dart";
import "core/theme/app_theme.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppEnv.hasSupabaseConfig) {
    await Supabase.initialize(
      url: AppEnv.supabaseUrl,
      anonKey: AppEnv.supabaseAnonKey,
    );
  } else if (kDebugMode) {
    debugPrint(
      "Supabase 클라이언트 미초기화: dart-define에 SUPABASE_URL, SUPABASE_ANON_KEY를 넣으면 "
      "모의 소셜 로그인 후 세션이 연결됩니다.",
    );
  }
  runApp(const ProviderScope(child: BadmintonMeetApp()));
}

class BadmintonMeetApp extends StatelessWidget {
  const BadmintonMeetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "배드민턴 모임 (${AppEnv.flavorName})",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
