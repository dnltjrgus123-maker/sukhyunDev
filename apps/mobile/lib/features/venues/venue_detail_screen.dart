import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/app_router.dart";
import "../../core/widgets/app_widgets.dart";
import "providers/venue_providers.dart";

class VenueDetailScreen extends ConsumerWidget {
  const VenueDetailScreen({super.key, required this.venueId});

  final String venueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueAsync = ref.watch(venueDetailProvider(venueId));
    final groupsAsync = ref.watch(venueGroupsProvider(venueId));

    return Scaffold(
      appBar: AppBar(
        title: venueAsync.when(
          data: (v) => Text(v["name"] as String? ?? "구장"),
          loading: () => const Text("구장"),
          error: (_, __) => const Text("구장"),
        ),
      ),
      body: venueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => AppError(
          message: err.toString(),
          onRetry: () => ref.invalidate(venueDetailProvider(venueId)),
        ),
        data: (venue) {
          final name = venue["name"] as String? ?? venueId;
          final address = venue["address"] as String? ?? "";
          final courtCount = (venue["courtCount"] as num?)?.toInt() ?? 0;
          final rating = (venue["ratingAvg"] as num?)?.toDouble() ?? 0.0;
          final theme = Theme.of(context);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(venueDetailProvider(venueId));
              ref.invalidate(venueGroupsProvider(venueId));
              await ref.read(venueGroupsProvider(venueId).future);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primaryContainer,
                            theme.colorScheme.secondaryContainer.withValues(alpha: 0.65),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.apartment_rounded, color: theme.colorScheme.primary, size: 28),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  name,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (address.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              address,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                                height: 1.4,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              _InfoChip(icon: Icons.grid_on_rounded, label: "코트 $courtCount면"),
                              _InfoChip(
                                icon: Icons.star_rounded,
                                label: "평균 ${rating.toStringAsFixed(1)}",
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: SectionHeader(
                      title: "이 구장의 모임",
                      subtitle: "모임 카드를 눌러 상세 · 가입 신청까지 진행할 수 있습니다.",
                    ),
                  ),
                ),
                groupsAsync.when(
                  loading: () => const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => SliverFillRemaining(
                    child: AppError(message: err.toString()),
                  ),
                  data: (groups) {
                    if (groups.isEmpty) {
                      return SliverFillRemaining(
                        child: EmptyState(
                          icon: Icons.group_off_outlined,
                          title: "등록된 모임이 없습니다",
                          hint: "다른 구장을 둘러보세요.",
                        ),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final group = groups[index];
                            final statusLabel = switch (group.status) {
                              "recruiting" => "모집 중",
                              "closed" => "마감",
                              _ => group.status,
                            };
                            return AppListTileCard(
                              leading: UserPhotoCircle(
                                photoUrl: group.photoUrl,
                                radius: 22,
                                backgroundColor: theme.colorScheme.tertiaryContainer,
                                fallback: Icon(
                                  Icons.groups_2_rounded,
                                  size: 22,
                                  color: theme.colorScheme.onTertiaryContainer,
                                ),
                              ),
                              title: group.name,
                              subtitle: "$statusLabel · ${group.memberCount}/${group.maxMembers}명",
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => Navigator.pushNamed(
                                context,
                                AppRoutes.groupDetail,
                                arguments: {"groupId": group.id},
                              ),
                            );
                          },
                          childCount: groups.length,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
