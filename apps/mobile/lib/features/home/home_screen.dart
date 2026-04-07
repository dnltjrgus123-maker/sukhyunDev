import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/app_router.dart";
import "../../core/widgets/app_widgets.dart";
import "../auth/providers/auth_providers.dart";

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final supabaseUserId = authState.valueOrNull?.user.id;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.85),
                    theme.colorScheme.secondary.withValues(alpha: 0.9),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 12,
                20,
                28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "배드민턴 모임",
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "구장 찾기 · 모임 · 번개까지 한곳에서",
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onPrimary.withValues(alpha: 0.92),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HeroChip(icon: Icons.sports_tennis, label: "실내 코트"),
                      _HeroChip(icon: Icons.groups_2_outlined, label: "모임 매칭"),
                      _HeroChip(icon: Icons.bolt_outlined, label: "번개"),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.onPrimary,
                      foregroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onPressed: authState.isLoading
                        ? null
                        : () async {
                            await ref
                                .read(authControllerProvider.notifier)
                                .signInWithMockSocialFromServer();
                            final result = ref.read(authControllerProvider);
                            if (!context.mounted) return;
                            result.whenOrNull(
                              error: (err, _) => ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("로그인 실패: $err")),
                              ),
                              data: (session) {
                                final id = session?.user.id;
                                if (id != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("로그인 완료 · $id")),
                                  );
                                }
                              },
                            );
                          },
                    icon: authState.isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : const Icon(Icons.login_rounded),
                    label: Text(authState.isLoading ? "로그인 중…" : "Supabase로 로그인(모의)"),
                  ),
                  if (supabaseUserId != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.verified_user_outlined, color: theme.colorScheme.onPrimary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Supabase 사용자 · ${supabaseUserId.length > 28 ? "${supabaseUserId.substring(0, 28)}…" : supabaseUserId}",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SectionHeader(
                  title: "바로 가기",
                  subtitle: "MVP 플로우와 운영자 화면으로 이동합니다.",
                ),
                _HomeNavCard(
                  icon: Icons.location_city_rounded,
                  iconColor: theme.colorScheme.primary,
                  title: "구장 목록",
                  subtitle: "지역 필터 → 상세 → 이 구장의 모임",
                  onTap: () => Navigator.pushNamed(context, AppRoutes.venues),
                ),
                _HomeNavCard(
                  icon: Icons.near_me_rounded,
                  iconColor: theme.colorScheme.tertiary,
                  title: "근처 모임",
                  subtitle: "거리순·시간순 탐색 (구장 좌표 기준)",
                  onTap: () => Navigator.pushNamed(context, AppRoutes.discoverMeetups),
                ),
                _HomeNavCard(
                  icon: Icons.sports_martial_arts_rounded,
                  iconColor: theme.colorScheme.secondary,
                  title: "코칭 · 레슨",
                  subtitle: "코치 목록 · 레슨 예약 요청",
                  onTap: () => Navigator.pushNamed(context, AppRoutes.coaching),
                ),
                _HomeNavCard(
                  icon: Icons.person_rounded,
                  iconColor: theme.colorScheme.secondary,
                  title: "마이페이지",
                  subtitle: "알림 · 신청 현황",
                  onTap: () => Navigator.pushNamed(context, AppRoutes.myPage),
                ),
                _HomeNavCard(
                  icon: Icons.how_to_reg_rounded,
                  iconColor: theme.colorScheme.tertiary,
                  title: "운영자 · 가입 신청 관리",
                  subtitle: "승인 / 거절 (샘플 모임 g-1)",
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.hostRequests,
                    arguments: {"groupId": "g-1"},
                  ),
                ),
                _HomeNavCard(
                  icon: Icons.event_note_rounded,
                  iconColor: theme.colorScheme.primary,
                  title: "운영자 · 정모 일정",
                  subtitle: "정모 캘린더 (샘플)",
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.hostEvents,
                    arguments: {"groupId": "g-1"},
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.onPrimary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeNavCard extends StatelessWidget {
  const _HomeNavCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
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
