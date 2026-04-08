import "package:flutter/foundation.dart" show defaultTargetPlatform, kIsWeb, TargetPlatform;

enum AppFlavor { dev, stage, prod }

class AppEnv {
  static const String _flavorRaw = String.fromEnvironment("APP_FLAVOR", defaultValue: "dev");
  /// 비어 있으면 [apiBaseUrl] getter에서 플랫폼·flavor별 기본값을 씁니다.
  static const String _apiBaseUrlRaw = String.fromEnvironment("API_BASE_URL", defaultValue: "");

  static AppFlavor get flavor {
    switch (_flavorRaw) {
      case "stage":
        return AppFlavor.stage;
      case "prod":
        return AppFlavor.prod;
      default:
        return AppFlavor.dev;
    }
  }

  static String get apiBaseUrl {
    if (_apiBaseUrlRaw.isNotEmpty) return _apiBaseUrlRaw;
    // Android 에뮬레이터에서 호스트 PC의 로컬 API는 localhost가 아니라 10.0.2.2 (실기기는 LAN IP로 --dart-define=API_BASE_URL=...)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return "http://10.0.2.2:4000";
    }
    switch (flavor) {
      case AppFlavor.dev:
        return "http://localhost:4000";
      case AppFlavor.stage:
        return "https://stage-api.example.com";
      case AppFlavor.prod:
        return "https://api.example.com";
    }
  }

  /// Supabase Project URL.
  /// - 대시보드: Project Settings → API → Project URL
  /// - 넣는 위치(택1): `flutter run --dart-define=SUPABASE_URL=...`
  ///   또는 `apps/mobile/dart_defines.json` 의 `"SUPABASE_URL"` (권장, Git 제외)
  ///   또는 VS Code `.vscode/launch.json` → "Flutter: dart_defines.json"
  static const String supabaseUrl = String.fromEnvironment("SUPABASE_URL", defaultValue: "");

  /// Supabase anon public 키 (JWT). service_role·JWT Secret 은 넣지 말 것.
  /// - 대시보드: Project Settings → API → anon public
  /// - 넣는 위치: `dart_defines.json` 의 `"SUPABASE_ANON_KEY"` 또는 동일 이름 dart-define
  static const String supabaseAnonKey = String.fromEnvironment("SUPABASE_ANON_KEY", defaultValue: "");

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty && supabaseUrl.startsWith("http");

  /// Kakao·Google OAuth 앱에 **Redirect URI**로 넣는 Supabase Auth 콜백.
  /// 예: `https://eeukvvpakxrjtegfazvq.supabase.co/auth/v1/callback`
  static String get supabaseAuthCallbackUrl {
    if (!hasSupabaseConfig) return "";
    final base = supabaseUrl.replaceAll(RegExp(r"/$"), "");
    return "$base/auth/v1/callback";
  }

  static String get flavorName {
    switch (flavor) {
      case AppFlavor.dev:
        return "DEV";
      case AppFlavor.stage:
        return "STAGE";
      case AppFlavor.prod:
        return "PROD";
    }
  }
}
