import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/network/error_to_message.dart";
import "../../core/providers/api_provider.dart";
import "../../core/widgets/app_snackbar.dart";
import "../../core/widgets/app_widgets.dart";
import "providers/favorite_providers.dart";

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncItems = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("즐겨찾기"),
        actions: [
          IconButton(
            tooltip: "샘플 구장 추가",
            onPressed: () async {
              try {
                final api = ref.read(apiClientProvider);
                await api.addFavorite(targetType: "venue", targetId: "v-1");
                ref.invalidate(favoritesProvider);
                if (!context.mounted) return;
                showAppSnackBar(context, message: "즐겨찾기에 추가되었습니다.");
              } catch (e) {
                if (!context.mounted) return;
                showAppSnackBar(context, message: errorToMessage(e), isError: true);
              }
            },
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: asyncItems.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => AppError(
          message: err.toString(),
          onRetry: () => ref.invalidate(favoritesProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.star_border_rounded,
              title: "즐겨찾기가 비어 있습니다",
              hint: "우측 상단 + 로 샘플을 추가해 보세요.",
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(favoritesProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final t = item["targetType"]?.toString() ?? "-";
                final id = item["targetId"]?.toString() ?? "-";
                final created = item["createdAt"]?.toString() ?? "";
                return AppListTileCard(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    foregroundColor: theme.colorScheme.onSecondaryContainer,
                    child: Icon(t == "venue" ? Icons.location_on_rounded : Icons.groups_rounded),
                  ),
                  title: "$t · $id",
                  subtitle: created,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
