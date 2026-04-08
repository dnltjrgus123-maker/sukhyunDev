import "package:flutter/material.dart";

/// 배드민턴 코트를 연상하는 딥 그린 + 청록 액센트.
abstract final class AppTheme {
  static const Color seed = Color(0xFF14532D);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      primary: const Color(0xFF166534),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFD1FAE5),
      onPrimaryContainer: const Color(0xFF052E16),
      secondary: const Color(0xFF0F766E),
      onSecondary: Colors.white,
      tertiary: const Color(0xFFC2410C),
      surface: const Color(0xFFF5F6F4),
      surfaceContainerHighest: const Color(0xFFE8EAE8),
      error: const Color(0xFFB91C1C),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      textTheme: Typography.blackMountainView.apply(
        bodyColor: const Color(0xFF1C1C1E),
        displayColor: const Color(0xFF1C1C1E),
      ).copyWith(
        headlineLarge: const TextStyle(fontWeight: FontWeight.w800, fontSize: 32, height: 1.15),
        headlineMedium: const TextStyle(fontWeight: FontWeight.w800, fontSize: 28, height: 1.2),
        headlineSmall: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24, height: 1.25),
        titleLarge: const TextStyle(fontWeight: FontWeight.w700, fontSize: 22, height: 1.3),
        titleMedium: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, height: 1.35),
        bodyLarge: const TextStyle(fontSize: 17, height: 1.45, fontWeight: FontWeight.w500),
        bodyMedium: const TextStyle(fontSize: 16, height: 1.42),
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 3,
        height: 72,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
            size: 24,
          );
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        shadowColor: Colors.black.withValues(alpha: 0.08),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5)),
    );
  }
}
