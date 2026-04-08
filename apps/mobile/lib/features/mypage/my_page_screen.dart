import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/config/app_env.dart";
import "../../core/providers/api_provider.dart";
import "../../core/widgets/app_snackbar.dart";
import "../../core/widgets/app_widgets.dart";
import "../auth/providers/auth_providers.dart";
import "providers/mypage_providers.dart";

String _notificationTitleKo(String type) {
  switch (type) {
    case "membership_approved":
      return "모임 가입이 승인되었습니다";
    case "membership_rejected":
      return "가입 신청이 거절되었습니다";
    case "membership_expired":
      return "멤버십이 만료되었습니다";
    case "event_updated":
      return "모임 일정이 변경되었습니다";
    case "play_session_start":
      return "모임 운동 시작 알림";
    case "play_session_spot_open":
      return "참가 자리가 났습니다";
    case "play_session_promoted_from_waitlist":
      return "대기열에서 참가로 전환되었습니다";
    case "lesson_booking_confirmed":
      return "레슨 예약이 확정되었습니다";
    case "lesson_booking_request":
      return "새 레슨 예약 요청이 있습니다";
    default:
      return type;
  }
}

Future<void> _openEditProfile(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> user,
) async {
  final nicknameCtrl = TextEditingController(text: user["nickname"]?.toString() ?? "");
  final photoCtrl = TextEditingController(text: user["photoUrl"]?.toString() ?? "");

  final action = await showDialog<_ProfileEditAction>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("프로필 수정"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nicknameCtrl,
              decoration: const InputDecoration(labelText: "닉네임"),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: photoCtrl,
              decoration: const InputDecoration(
                labelText: "프로필 사진 URL",
                hintText: "https://… (비우고 저장 시 사진 제거)",
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
        TextButton(
          onPressed: () => Navigator.pop(ctx, _ProfileEditAction.removePhoto),
          child: const Text("사진만 제거"),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, _ProfileEditAction.save),
          child: const Text("저장"),
        ),
      ],
    ),
  );

  if (action == null || !context.mounted) return;

  try {
    final api = ref.read(apiClientProvider);
    if (action == _ProfileEditAction.removePhoto) {
      await api.patchCurrentUserProfile({"photoUrl": null});
    } else {
      final patch = <String, dynamic>{};
      final nick = nicknameCtrl.text.trim();
      final origNick = user["nickname"]?.toString() ?? "";
      if (nick.isNotEmpty && nick != origNick) patch["nickname"] = nick;
      final photoVal = photoCtrl.text.trim();
      final origPhoto = user["photoUrl"]?.toString() ?? "";
      if (photoVal != origPhoto) patch["photoUrl"] = photoVal;
      if (patch.isEmpty) {
        if (context.mounted) {
          showAppSnackBar(context, message: "변경된 내용이 없습니다.");
        }
        return;
      }
      await api.patchCurrentUserProfile(patch);
    }
    ref.invalidate(currentUserProvider);
    if (context.mounted) {
      showAppSnackBar(context, message: "프로필을 저장했습니다.");
    }
  } catch (e) {
    if (context.mounted) {
      showAppSnackBar(context, message: e.toString(), isError: true);
    }
  }
}

enum _ProfileEditAction { save, removePhoto }

class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notificationsAsync = ref.watch(notificationsProvider);
    final profileAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("마이페이지"),
        actions: [
          if (AppEnv.hasSupabaseConfig)
            TextButton(
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).signOut();
                if (context.mounted) {
                  showAppSnackBar(context, message: "로그아웃했습니다.");
                }
              },
              child: Text(
                "로그아웃",
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          profileAsync.maybeWhen(
            data: (user) => IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _openEditProfile(context, ref, user),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          profileAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: AppError(
                message: err.toString(),
                onRetry: () => ref.invalidate(currentUserProvider),
              ),
            ),
            data: (user) {
              final nickname = user["nickname"]?.toString() ?? "플레이어";
              final skill = user["skillLevel"]?.toString() ?? "";
              final photoUrl = user["photoUrl"]?.toString();

              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.secondaryContainer,
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    UserPhotoCircle(
                      photoUrl: photoUrl,
                      radius: 32,
                      backgroundColor: theme.colorScheme.primary,
                      fallback: Icon(Icons.person_rounded, size: 36, color: theme.colorScheme.onPrimary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nickname,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          if (skill.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              "실력 · $skill",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            "알림과 프로필 사진은 이 화면에서 관리할 수 있습니다.",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SectionHeader(
              title: "알림 센터",
              subtitle: "아래로 당겨 새로고침할 수 있습니다.",
              action: IconButton(
                onPressed: () => ref.invalidate(notificationsProvider),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          ),
          Expanded(
            child: notificationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => AppError(
                message: err.toString(),
                onRetry: () => ref.invalidate(notificationsProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: "새 알림이 없습니다",
                    hint: "가입 신청이나 모임 소식이 오면 여기에 표시됩니다.",
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(notificationsProvider.future),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final typeRaw = item["type"]?.toString() ?? "";
                      final type = _notificationTitleKo(typeRaw);
                      final created = item["createdAt"]?.toString() ?? "";
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.primaryContainer,
                              foregroundColor: theme.colorScheme.onPrimaryContainer,
                              child: const Icon(Icons.notifications_active_outlined),
                            ),
                            title: Text(type, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(created, style: theme.textTheme.bodySmall),
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
    );
  }
}
