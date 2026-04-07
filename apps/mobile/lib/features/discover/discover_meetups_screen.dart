import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/app_router.dart";
import "../../core/providers/api_provider.dart";
import "../../core/widgets/app_widgets.dart";

class DiscoverMeetupsScreen extends ConsumerStatefulWidget {
  const DiscoverMeetupsScreen({super.key});

  @override
  ConsumerState<DiscoverMeetupsScreen> createState() => _DiscoverMeetupsScreenState();
}

class _DiscoverMeetupsScreenState extends ConsumerState<DiscoverMeetupsScreen> {
  static const double _defaultLat = 37.5665;
  static const double _defaultLng = 126.978;
  String _sort = "distance";
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final api = ref.read(apiClientProvider);
    _future = api.discoverMeetups(lat: _defaultLat, lng: _defaultLng, sort: _sort);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text("근처 모임")),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: "distance", label: Text("거리순")),
                ButtonSegment(value: "time", label: Text("시간순", maxLines: 1)),
              ],
              selected: {_sort},
              onSelectionChanged: (s) {
                setState(() => _sort = s.first);
                _reload();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return AppError(
                    message: snap.error.toString(),
                    onRetry: _reload,
                  );
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.map_outlined,
                    title: "표시할 모임이 없습니다",
                    hint: "샘플 데이터에 연결된 모임만 보입니다.",
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    _reload();
                    await _future;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final row = items[i];
                      final group = row["group"] as Map<String, dynamic>? ?? {};
                      final venue = row["venue"] as Map<String, dynamic>?;
                      final dist = row["distanceKm"];
                      final next = row["nextPlaySession"] as Map<String, dynamic>?;
                      final groupId = group["id"]?.toString() ?? "";
                      final name = group["name"]?.toString() ?? "모임";
                      final gPhoto = group["photoUrl"]?.toString();
                      final venueName = venue?["name"]?.toString() ?? "";
                      final distLabel = dist is num ? "${dist.toStringAsFixed(1)} km" : "—";
                      final nextLabel = next != null ? next["startsAt"]?.toString() ?? "" : "예정 없음";

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(18),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: groupId.isEmpty
                                ? null
                                : () => Navigator.pushNamed(
                                      context,
                                      AppRoutes.groupDetail,
                                      arguments: {"groupId": groupId},
                                    ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: SizedBox(
                                          width: 64,
                                          height: 52,
                                          child: gPhoto != null && gPhoto.isNotEmpty
                                              ? Image.network(
                                                  gPhoto,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      ColoredBox(
                                                    color: theme.colorScheme.primaryContainer,
                                                    child: Icon(
                                                      Icons.groups_2_rounded,
                                                      color: theme.colorScheme.onPrimaryContainer,
                                                    ),
                                                  ),
                                                )
                                              : ColoredBox(
                                                  color: theme.colorScheme.primaryContainer,
                                                  child: Icon(
                                                    Icons.groups_2_rounded,
                                                    color: theme.colorScheme.onPrimaryContainer,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.place_outlined,
                                                  color: theme.colorScheme.primary,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    name,
                                                    style: theme.textTheme.titleSmall
                                                        ?.copyWith(fontWeight: FontWeight.w800),
                                                  ),
                                                ),
                                                Text(
                                                  distLabel,
                                                  style: theme.textTheme.labelLarge?.copyWith(
                                                    color: theme.colorScheme.tertiary,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (venueName.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      venueName,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    "다음 세션 · $nextLabel",
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            "기준 위치: 서울 시청 근처(${_defaultLat.toStringAsFixed(2)}, ${_defaultLng.toStringAsFixed(2)}) — 실제 앱에서는 GPS로 대체할 수 있습니다.",
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
