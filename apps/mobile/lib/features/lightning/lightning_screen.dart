import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/network/error_to_message.dart";
import "../../core/providers/api_provider.dart";
import "../../core/widgets/app_snackbar.dart";
import "../../core/widgets/app_widgets.dart";
import "providers/lightning_providers.dart";

class LightningScreen extends ConsumerWidget {
  const LightningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncItems = ref.watch(lightningMatchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("번개 매칭"),
        actions: [
          IconButton(
            tooltip: "번개 생성",
            onPressed: () async {
              try {
                final api = ref.read(apiClientProvider);
                await api.createLightningMatch(venueId: "v-1", level: "intermediate", capacity: 4);
                ref.invalidate(lightningMatchesProvider);
                if (!context.mounted) return;
                showAppSnackBar(context, message: "번개 매칭이 생성되었습니다.");
              } catch (e) {
                if (!context.mounted) return;
                showAppSnackBar(context, message: errorToMessage(e), isError: true);
              }
            },
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: asyncItems.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => AppError(
          message: err.toString(),
          onRetry: () => ref.invalidate(lightningMatchesProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.bolt_outlined,
              title: "열린 번개가 없습니다",
              hint: "우측 상단 + 로 샘플 번개를 만들어 보세요.",
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(lightningMatchesProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final level = item["level"]?.toString() ?? "-";
                final venueId = item["venueId"]?.toString() ?? "-";
                final capacity = item["capacity"]?.toString() ?? "-";
                final st = item["status"]?.toString() ?? "-";
                return AppListTileCard(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.tertiaryContainer,
                    foregroundColor: theme.colorScheme.onTertiaryContainer,
                    child: const Icon(Icons.bolt_rounded),
                  ),
                  title: "$venueId · $level",
                  subtitle: "정원 $capacity · 상태 $st",
                );
              },
            ),
          );
        },
      ),
    );
  }
}
