import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/providers/api_provider.dart";

class CreateReviewController extends AutoDisposeAsyncNotifier<Map<String, dynamic>?> {
  @override
  Future<Map<String, dynamic>?> build() async {
    return null;
  }

  Future<Map<String, dynamic>> submit({
    required String targetType,
    required String targetId,
    required int rating,
    String? comment,
  }) async {
    state = const AsyncLoading();
    final api = ref.read(apiClientProvider);
    final result = await AsyncValue.guard(
      () => api.createReview(
        targetType: targetType,
        targetId: targetId,
        rating: rating,
        comment: comment,
      ),
    );
    state = result;
    return result.requireValue;
  }
}

final createReviewControllerProvider =
    AutoDisposeAsyncNotifierProvider<CreateReviewController, Map<String, dynamic>?>(
  CreateReviewController.new,
);
