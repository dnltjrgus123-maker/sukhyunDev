import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/app_router.dart";
import "../auth/providers/auth_providers.dart";

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final nick = authState.valueOrNull?.user.userMetadata?["full_name"]?.toString() ??
        authState.valueOrNull?.user.email?.split("@").first;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                MediaQuery.paddingOf(context).top + 20,
                24,
                12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nick != null && nick.isNotEmpty ? "안녕하세요, $nick 님" : "안녕하세요",
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      letterSpacing: -0.6,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "오늘은 어떤 코트로 갈까요?",
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      fontSize: 18,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),
                _HeroCreateCard(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.groupCreate),
                ),
                const SizedBox(height: 18),
                _NavTileCard(
                  icon: Icons.location_on_outlined,
                  title: "구장 찾기",
                  subtitle: "지역별 배드민턴장과 이 구장의 모임",
                  accent: theme.colorScheme.secondary,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.venues),
                ),
                _NavTileCard(
                  icon: Icons.explore_outlined,
                  title: "근처 모임",
                  subtitle: "거리·시간 순 디스커버",
                  accent: theme.colorScheme.tertiary,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.discoverMeetups),
                ),
                _NavTileCard(
                  icon: Icons.sports_rounded,
                  title: "코칭 · 레슨",
                  subtitle: "코치 찾기와 예약",
                  accent: theme.colorScheme.primary,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.coaching),
                ),
                _NavTileCard(
                  icon: Icons.person_outline_rounded,
                  title: "마이페이지",
                  subtitle: "알림 · 프로필",
                  accent: theme.colorScheme.outline,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.myPage),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 8),
                  Text(
                    "개발 전용",
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: authState.isLoading
                        ? null
                        : () => ref
                            .read(authControllerProvider.notifier)
                            .signInWithMockSocialFromServer(),
                    icon: authState.isLoading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : const Icon(Icons.bug_report_outlined),
                    label: const Text("모의 소셜(서버)"),
                  ),
                ],
                const SizedBox(height: 110),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCreateCard extends StatelessWidget {
  const _HeroCreateCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 0.82),
                const Color(0xFF0D9488),
              ],
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "새 모임 개설",
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "따뜻한 라운드부터 번개까지,\n몇 분이면 준비 끝.",
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        height: 1.45,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTileCard extends StatelessWidget {
  const _NavTileCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accent, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
