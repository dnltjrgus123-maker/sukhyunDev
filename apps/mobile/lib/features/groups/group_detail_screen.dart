import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/network/error_to_message.dart";
import "../../core/providers/api_provider.dart";
import "../../core/widgets/app_snackbar.dart";
import "../../core/widgets/app_widgets.dart";
import "providers/group_providers.dart";

enum _GroupProfileEditAction { save, removePhoto }

Future<void> _openGroupProfileEdit(
  BuildContext context,
  WidgetRef ref,
  String groupId,
  Map<String, dynamic> group,
) async {
  final nameCtrl = TextEditingController(text: group["name"]?.toString() ?? "");
  final descCtrl = TextEditingController(text: group["description"]?.toString() ?? "");
  final photoCtrl = TextEditingController(text: group["photoUrl"]?.toString() ?? "");

  final action = await showDialog<_GroupProfileEditAction>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("모임 프로필 수정"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "모임 이름"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: "소개"),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: photoCtrl,
              decoration: const InputDecoration(
                labelText: "대표 이미지 URL",
                hintText: "https://…",
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
        TextButton(
          onPressed: () => Navigator.pop(ctx, _GroupProfileEditAction.removePhoto),
          child: const Text("이미지만 제거"),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, _GroupProfileEditAction.save),
          child: const Text("저장"),
        ),
      ],
    ),
  );

  if (action == null || !context.mounted) return;

  try {
    final api = ref.read(apiClientProvider);
    if (action == _GroupProfileEditAction.removePhoto) {
      await api.patchGroupProfile(groupId, {"photoUrl": null});
    } else {
      final patch = <String, dynamic>{};
      final n = nameCtrl.text.trim();
      final origName = group["name"]?.toString() ?? "";
      if (n.isNotEmpty && n != origName) patch["name"] = n;
      final d = descCtrl.text;
      final origDesc = group["description"]?.toString() ?? "";
      if (d != origDesc) patch["description"] = d;
      final p = photoCtrl.text.trim();
      final origPhoto = group["photoUrl"]?.toString() ?? "";
      if (p != origPhoto) patch["photoUrl"] = p;
      if (patch.isEmpty) {
        if (context.mounted) {
          showAppSnackBar(context, message: "변경된 내용이 없습니다.");
        }
        return;
      }
      await api.patchGroupProfile(groupId, patch);
    }
    ref.invalidate(groupDetailProvider(groupId));
    if (context.mounted) {
      showAppSnackBar(context, message: "모임 프로필을 저장했습니다.");
    }
  } catch (e) {
    if (context.mounted) {
      showAppSnackBar(context, message: errorToMessage(e), isError: true);
    }
  }
}

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  String? _applyResult;

  Future<void> _apply() async {
    setState(() => _applyResult = null);
    try {
      final membership = await ref.read(groupApplyControllerProvider.notifier).apply(widget.groupId);
      setState(() => _applyResult = "신청 완료: ${membership.status}");
      if (!mounted) return;
      showAppSnackBar(context, message: "가입 신청이 완료되었습니다.");
    } catch (e) {
      final message = errorToMessage(e);
      setState(() => _applyResult = "신청 실패: $message");
      if (!mounted) return;
      showAppSnackBar(context, message: message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detailAsync = ref.watch(groupDetailProvider(widget.groupId));
    final applyAsync = ref.watch(groupApplyControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: detailAsync.when(
          data: (g) => Text(g["name"] as String? ?? "모임"),
          loading: () => const Text("모임"),
          error: (_, __) => const Text("모임"),
        ),
        actions: [
          detailAsync.maybeWhen(
            data: (g) {
              final hostId = g["hostUserId"]?.toString() ?? "";
              final me = ref.read(apiClientProvider).actorUserId;
              if (hostId != me) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: "모임 프로필 수정",
                onPressed: () => _openGroupProfileEdit(context, ref, widget.groupId, g),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => AppError(
          message: err.toString(),
          onRetry: () => ref.invalidate(groupDetailProvider(widget.groupId)),
        ),
        data: (group) {
          final name = group["name"] as String? ?? "-";
          final description = group["description"] as String? ?? "";
          final photoUrl = group["photoUrl"] as String?;
          final requiresApproval = group["requiresApproval"] as bool? ?? true;
          final status = group["status"] as String? ?? "recruiting";
          final memberCount = (group["memberCount"] as num?)?.toInt() ?? 0;
          final maxMembers = (group["maxMembers"] as num?)?.toInt() ?? 0;

          final statusLabel = switch (status) {
            "recruiting" => "모집 중",
            "closed" => "마감",
            _ => status,
          };

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GroupProfileBanner(photoUrl: photoUrl),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: Icon(Icons.flag_rounded, size: 18, color: theme.colorScheme.primary),
                      label: Text(statusLabel),
                      backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.65),
                    ),
                    Chip(
                      avatar: Icon(Icons.people_rounded, size: 18, color: theme.colorScheme.secondary),
                      label: Text("$memberCount / $maxMembers명"),
                    ),
                    Chip(
                      avatar: Icon(
                        requiresApproval ? Icons.verified_user_outlined : Icons.flash_on_rounded,
                        size: 18,
                      ),
                      label: Text(requiresApproval ? "운영자 승인" : "자동 가입"),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  name,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.45,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: applyAsync.isLoading ? null : _apply,
                  icon: applyAsync.isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(applyAsync.isLoading ? "신청 중…" : "가입 신청하기"),
                ),
                if (_applyResult != null) ...[
                  const SizedBox(height: 16),
                  Material(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_applyResult!, style: theme.textTheme.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
