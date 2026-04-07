import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/models/app_models.dart";
import "../../../core/providers/api_provider.dart";

final groupDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, groupId) async {
  final api = ref.watch(apiClientProvider);
  return api.getGroupDetail(groupId);
});

class GroupApplyController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Membership> apply(String groupId) async {
    state = const AsyncLoading();
    final api = ref.read(apiClientProvider);
    final result = await AsyncValue.guard(() => api.applyMembership(groupId));
    state = result.whenData((_) => null);
    return result.requireValue;
  }
}

final groupApplyControllerProvider =
    AutoDisposeAsyncNotifierProvider<GroupApplyController, void>(GroupApplyController.new);
