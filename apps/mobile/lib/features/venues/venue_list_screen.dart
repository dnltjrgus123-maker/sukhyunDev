import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/app_router.dart";
import "../../core/widgets/app_widgets.dart";
import "providers/venue_providers.dart";

class VenueListScreen extends ConsumerStatefulWidget {
  const VenueListScreen({super.key});

  @override
  ConsumerState<VenueListScreen> createState() => _VenueListScreenState();
}

class _VenueListScreenState extends ConsumerState<VenueListScreen> {
  final _areaCtrl = TextEditingController();

  @override
  void dispose() {
    _areaCtrl.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final value = _areaCtrl.text.trim();
    ref.read(venueAreaFilterProvider.notifier).state = value.isEmpty ? null : value;
    ref.invalidate(venuesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venuesAsync = ref.watch(venuesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("배드민턴장"),
        actions: [
          IconButton(
            tooltip: "새로고침",
            onPressed: () => ref.invalidate(venuesProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _areaCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _applyFilter(),
                    decoration: const InputDecoration(
                      labelText: "지역 검색",
                      hintText: "예: 서울, 경기",
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: FilledButton.tonal(
                    onPressed: _applyFilter,
                    child: const Text("적용"),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "코트 수와 평점을 확인하고 모임까지 이어 보세요.",
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: venuesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => AppError(
                message: err.toString(),
                onRetry: () => ref.invalidate(venuesProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.location_off_outlined,
                    title: "조건에 맞는 구장이 없습니다",
                    hint: "검색어를 바꿔 다시 적용해 보세요.",
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(venuesProvider.future),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return AppListTileCard(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          foregroundColor: theme.colorScheme.onPrimaryContainer,
                          child: const Icon(Icons.sports_tennis),
                        ),
                        title: item.name,
                        subtitle:
                            "${item.address}\n코트 ${item.courtCount}면 · 평균 ★ ${item.ratingAvg.toStringAsFixed(1)}",
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.venueDetail,
                          arguments: {"venueId": item.id},
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
