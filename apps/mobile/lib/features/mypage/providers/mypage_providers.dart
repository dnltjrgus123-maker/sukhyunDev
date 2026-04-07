import "dart:convert";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:http/http.dart" as http;

import "../../../core/providers/api_provider.dart";

final currentUserProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getCurrentUser();
});

final notificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await http.get(
    Uri.parse("${api.baseUrl}/notifications"),
    headers: await api.getHeaders(),
  );
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  return (body["items"] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
});
