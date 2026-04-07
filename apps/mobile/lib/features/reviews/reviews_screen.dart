import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/network/error_to_message.dart";
import "../../core/widgets/app_snackbar.dart";
import "../../core/widgets/app_widgets.dart";
import "providers/review_providers.dart";

class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({super.key});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  int _rating = 5;
  String? _message;

  Future<void> _submit() async {
    setState(() => _message = null);
    try {
      final result = await ref.read(createReviewControllerProvider.notifier).submit(
            targetType: "venue",
            targetId: "v-1",
            rating: _rating,
            comment: "샘플 후기",
          );
      setState(() => _message = "후기 등록 완료: ${result["id"]}");
      if (!mounted) return;
      showAppSnackBar(context, message: "후기 등록이 완료되었습니다.");
    } catch (e) {
      final message = errorToMessage(e);
      setState(() => _message = "후기 등록 실패: $message");
      if (!mounted) return;
      showAppSnackBar(context, message: message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reviewState = ref.watch(createReviewControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("후기 · 평점")),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          const SectionHeader(
            title: "샘플 후기 등록",
            subtitle: "별점을 고르고 등록해 API를 확인합니다.",
          ),
          Text("별점", style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment<int>(value: 1, label: Text("1")),
                ButtonSegment<int>(value: 2, label: Text("2")),
                ButtonSegment<int>(value: 3, label: Text("3")),
                ButtonSegment<int>(value: 4, label: Text("4")),
                ButtonSegment<int>(value: 5, label: Text("5")),
              ],
              selected: {_rating},
              onSelectionChanged: (s) => setState(() => _rating = s.first),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: reviewState.isLoading ? null : _submit,
            icon: reviewState.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(reviewState.isLoading ? "등록 중…" : "후기 등록"),
          ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 28),
          const ChatUpgradePreviewCard(),
        ],
      ),
    );
  }
}

class ChatUpgradePreviewCard extends StatelessWidget {
  const ChatUpgradePreviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const ChatUpgradeScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.chat_bubble_outline_rounded, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "채팅 고도화 (Phase 2)",
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "공지 고정 · 투표 · 읽음 · 모더레이션",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
    );
  }
}

class ChatUpgradeScreen extends StatelessWidget {
  const ChatUpgradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text("채팅 고도화")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text("구현 예정 기능", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          ...[
            "공지 고정",
            "출석 / 안건 투표",
            "읽음 상태",
            "금칙어 · 신고 기반 모더레이션",
          ].map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline, size: 22, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Text(t, style: theme.textTheme.bodyLarge)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
