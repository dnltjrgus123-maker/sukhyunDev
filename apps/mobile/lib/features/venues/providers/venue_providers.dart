import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/models/app_models.dart";
import "../../../core/providers/api_provider.dart";

final venueAreaFilterProvider = StateProvider<String?>((ref) => null);

final venuesProvider = FutureProvider<List<VenueSummary>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final area = ref.watch(venueAreaFilterProvider);
  return api.getVenues(area: area);
});

final venueGroupsProvider = FutureProvider.family<List<GroupSummary>, String>((ref, venueId) async {
  final api = ref.watch(apiClientProvider);
  return api.getVenueGroups(venueId);
});

final venueDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, venueId) async {
  final api = ref.watch(apiClientProvider);
  return api.getVenue(venueId);
});
