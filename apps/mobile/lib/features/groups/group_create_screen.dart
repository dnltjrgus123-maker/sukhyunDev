import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/app_router.dart";
import "../../core/providers/api_provider.dart";
import "../../core/widgets/app_snackbar.dart";
import "../venues/providers/venue_providers.dart";

const _levels = ["beginner", "intermediate", "advanced"];

String _levelLabel(String v) {
  switch (v) {
    case "beginner":
      return "입문";
    case "intermediate":
      return "중급";
    case "advanced":
      return "상급";
    default:
      return v;
  }
}

class GroupCreateScreen extends ConsumerStatefulWidget {
  const GroupCreateScreen({super.key});

  @override
  ConsumerState<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends ConsumerState<GroupCreateScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _levelMin = "beginner";
  String _levelMax = "advanced";
  String? _venueId;
  double _maxMembers = 16;
  bool _requiresApproval = true;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showAppSnackBar(context, message: "모임 이름을 입력해 주세요.", isError: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      final venues = await ref.read(venuesProvider.future);
      final homeId = _venueId ?? (venues.isNotEmpty ? venues.first.id : null);
      final created = await api.createGroup(
        name: name,
        homeVenueId: homeId,
        description: _descCtrl.text.trim(),
        levelMin: _levelMin,
        levelMax: _levelMax,
        maxMembers: _maxMembers.round(),
        requiresApproval: _requiresApproval,
      );
      final id = created["id"]?.toString();
      if (!mounted) return;
      if (id != null && id.isNotEmpty) {
        showAppSnackBar(context, message: "모임을 만들었습니다.");
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.groupDetail,
          arguments: {"groupId": id},
        );
      } else {
        showAppSnackBar(context, message: "응답 형식이 올바르지 않습니다.", isError: true);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, message: e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venuesAsync = ref.watch(venuesProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text("모임 만들기"),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Text(
            "새 모임을 개설합니다",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "활동 구장과 실력대를 정하면 멤버가 모임을 찾기 쉬워요.",
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
                  decoration: const InputDecoration(
                    labelText: "모임 이름",
                    hintText: "예: 주말 오전 라이트 모임",
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _descCtrl,
                  minLines: 2,
                  maxLines: 4,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
                  decoration: const InputDecoration(
                    labelText: "소개 (선택)",
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "홈 구장",
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                venuesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(e.toString(), style: TextStyle(color: theme.colorScheme.error)),
                  data: (venues) {
                    if (venues.isEmpty) {
                      return Text(
                        "등록된 구장이 없습니다. 서버 시드를 확인하세요.",
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      value: _venueId ?? venues.first.id,
                      decoration: const InputDecoration(
                        labelText: "구장 선택",
                      ),
                      items: venues
                          .map(
                            (v) => DropdownMenuItem(
                              value: v.id,
                              child: Text(v.name, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _venueId = v),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _levelMin,
                        decoration: const InputDecoration(labelText: "최소 실력"),
                        items: _levels
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(_levelLabel(e)),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _levelMin = v ?? _levelMin),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _levelMax,
                        decoration: const InputDecoration(labelText: "최대 실력"),
                        items: _levels
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(_levelLabel(e)),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _levelMax = v ?? _levelMax),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  "최대 인원 ${_maxMembers.round()}명",
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Slider(
                  value: _maxMembers,
                  min: 4,
                  max: 40,
                  divisions: 18,
                  label: "${_maxMembers.round()}명",
                  onChanged: (v) => setState(() => _maxMembers = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    "가입 시 호스트 승인",
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  value: _requiresApproval,
                  onChanged: (v) => setState(() => _requiresApproval = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    "모임 개설하기",
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
