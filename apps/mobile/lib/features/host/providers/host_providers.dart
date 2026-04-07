import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/providers/api_provider.dart";

final hostJoinRequestsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) async {
  final api = ref.watch(hostApiClientProvider);
  return api.getJoinRequests(groupId);
});

class HostDecisionController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> decide({
    required String groupId,
    required String membershipId,
    required bool approve,
  }) async {
    state = const AsyncLoading();
    final api = ref.read(hostApiClientProvider);
    final result = await AsyncValue.guard(
      () => api.decideJoinRequest(groupId: groupId, membershipId: membershipId, approve: approve),
    );
    state = result.whenData((_) => null);
  }
}

final hostDecisionControllerProvider =
    AutoDisposeAsyncNotifierProvider<HostDecisionController, void>(HostDecisionController.new);
