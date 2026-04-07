import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/network/error_to_message.dart";
import "../../core/widgets/app_snackbar.dart";
import "../../core/widgets/app_widgets.dart";
import "providers/host_providers.dart";

class HostRequestsScreen extends ConsumerWidget {
  const HostRequestsScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final requestsAsync = ref.watch(hostJoinRequestsProvider(groupId));
    final decisionAsync = ref.watch(hostDecisionControllerProvider);

    Future<void> decide(String membershipId, bool approve) async {
      try {
        await ref.read(hostDecisionControllerProvider.notifier).decide(
              groupId: groupId,
              membershipId: membershipId,
              approve: approve,
            );
        ref.invalidate(hostJoinRequestsProvider(groupId));
        if (!context.mounted) return;
        showAppSnackBar(context, message: approve ? "승인 완료" : "거절 완료");
      } catch (e) {
        if (!context.mounted) return;
        showAppSnackBar(context, message: errorToMessage(e), isError: true);
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text("신청 관리 ($groupId)")),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => AppError(
          message: err.toString(),
          onRetry: () => ref.invalidate(hostJoinRequestsProvider(groupId)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.inbox_outlined,
              title: "처리할 신청이 없습니다",
              hint: "새 가입 신청이 오면 여기에 표시됩니다.",
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(hostJoinRequestsProvider(groupId).future),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final userId = item["userId"]?.toString() ?? "-";
                final status = item["status"]?.toString() ?? "-";
                final id = item["id"] as String;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: theme.colorScheme.primaryContainer,
                                foregroundColor: theme.colorScheme.onPrimaryContainer,
                                child: const Icon(Icons.person_rounded),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userId,
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    Text(
                                      "상태: $status",
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: decisionAsync.isLoading ? null : () => decide(id, false),
                                  icon: const Icon(Icons.close_rounded, size: 20),
                                  label: const Text("거절"),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: decisionAsync.isLoading ? null : () => decide(id, true),
                                  icon: const Icon(Icons.check_rounded, size: 20),
                                  label: const Text("승인"),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
