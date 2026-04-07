import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/providers/api_provider.dart";

final favoritesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getFavorites();
});
