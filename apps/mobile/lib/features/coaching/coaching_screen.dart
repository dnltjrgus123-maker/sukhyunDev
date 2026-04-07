import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/providers/api_provider.dart";
import "../../core/widgets/app_snackbar.dart";
import "../../core/widgets/app_widgets.dart";

class CoachingScreen extends ConsumerStatefulWidget {
  const CoachingScreen({super.key});

  @override
  ConsumerState<CoachingScreen> createState() => _CoachingScreenState();
}

class _CoachingScreenState extends ConsumerState<CoachingScreen> {
  late Future<List<Map<String, dynamic>>> _coachesFuture;
  late Future<Map<String, dynamic>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _reloadAll();
  }

  void _reloadAll() {
    final api = ref.read(apiClientProvider);
    _coachesFuture = api.getCoaches();
    _bookingsFuture = api.getMyLessonBookings();
    setState(() {});
  }

  Future<void> _bookCoach(Map<String, dynamic> coach) async {
    final api = ref.read(apiClientProvider);
    final user = coach["user"] as Map<String, dynamic>?;
    final coachUserId = coach["userId"]?.toString() ?? "";
    final nickname = user?["nickname"]?.toString() ?? "코치";

    final startsCtrl = TextEditingController(
      text: DateTime.now().add(const Duration(days: 1, hours: 10)).toIso8601String(),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("$nickname 예약"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("시작 시각(ISO8601)"),
            const SizedBox(height: 8),
            TextField(controller: startsCtrl, maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("취소")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("요청")),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await api.createLessonBooking(
        coachUserId: coachUserId,
        startsAtIso: startsCtrl.text.trim(),
      );
      if (!mounted) return;
      showAppSnackBar(context, message: "예약 요청을 보냈습니다. 코치 승인을 기다려 주세요.");
      _reloadAll();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, message: e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("코칭"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "코치 찾기"),
              Tab(text: "내 예약"),
            ],
          ),
          actions: [
            IconButton(onPressed: _reloadAll, icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        body: TabBarView(
          children: [
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _coachesFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return AppError(message: snap.error.toString(), onRetry: _reloadAll);
                }
                final coaches = snap.data ?? [];
                if (coaches.isEmpty) {
                  return const EmptyState(
                    icon: Icons.sports,
                    title: "등록된 코치가 없습니다",
                    hint: "백엔드 시드 또는 코치 등록 API를 사용해 보세요.",
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: coaches.length,
                  itemBuilder: (context, i) {
                    final c = coaches[i];
                    final user = c["user"] as Map<String, dynamic>?;
                    final nickname = user?["nickname"]?.toString() ?? "코치";
                    final bio = c["bio"]?.toString() ?? "";
                    final rate = c["hourlyRateWon"];
                    final rateLabel = rate is num ? "${rate.round()}원/시간" : "";

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
                                  UserPhotoCircle(
                                    photoUrl: user?["photoUrl"]?.toString(),
                                    radius: 24,
                                    backgroundColor: theme.colorScheme.primaryContainer,
                                    fallback:
                                        Icon(Icons.person, color: theme.colorScheme.onPrimaryContainer),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      nickname,
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  if (rateLabel.isNotEmpty)
                                    Text(
                                      rateLabel,
                                      style: theme.textTheme.labelLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.tertiary,
                                      ),
                                    ),
                                ],
                              ),
                              if (bio.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(bio, style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
                              ],
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.tonal(
                                  onPressed: () => _bookCoach(c),
                                  child: const Text("예약 요청"),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            FutureBuilder<Map<String, dynamic>>(
              future: _bookingsFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return AppError(message: snap.error.toString(), onRetry: _reloadAll);
                }
                final asCoach = (snap.data?["asCoach"] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
                final asStudent =
                    (snap.data?["asStudent"] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
                final all = [...asStudent.map((e) => MapEntry("수강", e)), ...asCoach.map((e) => MapEntry("코치", e))];

                if (all.isEmpty) {
                  return const EmptyState(
                    icon: Icons.event_note_outlined,
                    title: "예약 내역이 없습니다",
                    hint: "코치 찾기 탭에서 레슨을 요청해 보세요.",
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: all.length,
                  itemBuilder: (context, i) {
                    final role = all[i].key;
                    final b = all[i].value;
                    final status = b["status"]?.toString() ?? "";
                    final starts = b["startsAt"]?.toString() ?? "";

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        tileColor: theme.colorScheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        title: Text("$role · $status"),
                        subtitle: Text(starts),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
