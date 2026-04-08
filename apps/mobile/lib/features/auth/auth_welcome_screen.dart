import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/config/auth_config.dart";
import "providers/auth_providers.dart";

/// 소셜 로그인 · 회원가입 — 미니멀 카드 레이아웃.
class AuthWelcomeScreen extends ConsumerWidget {
  const AuthWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: MediaQuery.paddingOf(context).top > 20 ? 8 : 28),
              Text(
                "BDminton",
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  fontSize: 34,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "배드민턴 모임을 가볍게",
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 40),
              _AuthCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "시작하기",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "연동된 계정으로 가입과 로그인이 한 번에 됩니다.",
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.45,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _SocialButton(
                      label: "Google로 계속하기",
                      icon: Icons.g_mobiledata_rounded,
                      iconColor: const Color(0xFF4285F4),
                      onPressed: auth.isLoading
                          ? null
                          : () => ref.read(authControllerProvider.notifier).signInWithGoogle(),
                    ),
                    const SizedBox(height: 12),
                    _SocialButton(
                      label: "카카오로 계속하기",
                      icon: Icons.chat_bubble_outline_rounded,
                      iconColor: const Color(0xFF191600),
                      subtle: true,
                      onPressed: auth.isLoading
                          ? null
                          : () => ref.read(authControllerProvider.notifier).signInWithKakao(),
                    ),
                    const SizedBox(height: 12),
                    _SocialButton(
                      label: "네이버로 계속하기",
                      icon: Icons.nature_people_outlined,
                      iconColor: const Color(0xFF03C75A),
                      onPressed: auth.isLoading
                          ? null
                          : () => ref.read(authControllerProvider.notifier).signInWithNaver(),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      "Supabase 대시보드에서 Google·카카오·네이버 로그인 제공자와 리다이렉트 URL\n"
                      "${AuthConfig.oauthRedirectUrl}\n"
                      "을(를) 허용 목록에 추가하세요.",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (auth.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (auth.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    auth.error.toString(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: child,
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onPressed,
    this.subtle = false,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onPressed;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: subtle ? const Color(0xFFF5F5F4) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
