import "package:flutter/material.dart";

import "../../core/widgets/app_snackbar.dart";
import "../../core/widgets/app_widgets.dart";

class HostEventsScreen extends StatelessWidget {
  const HostEventsScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text("정모 일정 ($groupId)")),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          const SectionHeader(
            title: "다가오는 정모",
            subtitle: "샘플 데이터입니다. 이후 일정 생성 API와 연결합니다.",
          ),
          _EventCard(
            title: "샘플 정모 #1",
            subtitle: "토요일 07:00 · 강남 배드민턴센터",
            accent: theme.colorScheme.primary,
          ),
          _EventCard(
            title: "샘플 정모 #2",
            subtitle: "수요일 20:00 · 수원 실내체육관",
            accent: theme.colorScheme.secondary,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        elevation: 2,
        onPressed: () {
          showAppSnackBar(context, message: "일정 생성 기능은 다음 단계에서 연결됩니다.");
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text("일정 추가"),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
