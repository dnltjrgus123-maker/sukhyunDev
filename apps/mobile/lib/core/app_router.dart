import "package:flutter/material.dart";

import "../features/coaching/coaching_screen.dart";
import "../features/discover/discover_meetups_screen.dart";
import "../features/groups/group_create_screen.dart";
import "../features/groups/group_detail_screen.dart";
import "../features/host/host_events_screen.dart";
import "../features/host/host_requests_screen.dart";
import "../features/mypage/my_page_screen.dart";
import "../features/shell/app_shell_screen.dart";
import "../features/venues/venue_detail_screen.dart";
import "../features/venues/venue_list_screen.dart";

class AppRoutes {
  static const home = "/";
  static const venues = "/venues";
  static const venueDetail = "/venues/detail";
  static const groupDetail = "/groups/detail";
  static const groupCreate = "/groups/create";
  static const myPage = "/my";
  static const hostRequests = "/host/requests";
  static const hostEvents = "/host/events";
  static const discoverMeetups = "/discover/meetups";
  static const coaching = "/coaching";
}

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return _material(const AppShellScreen());
      case AppRoutes.venues:
        return _material(const VenueListScreen());
      case AppRoutes.venueDetail:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return _material(VenueDetailScreen(venueId: args["venueId"] as String? ?? "v-1"));
      case AppRoutes.groupDetail:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return _material(GroupDetailScreen(groupId: args["groupId"] as String? ?? "g-1"));
      case AppRoutes.groupCreate:
        return _material(const GroupCreateScreen());
      case AppRoutes.myPage:
        return _material(const MyPageScreen());
      case AppRoutes.hostRequests:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return _material(HostRequestsScreen(groupId: args["groupId"] as String? ?? "g-1"));
      case AppRoutes.hostEvents:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return _material(HostEventsScreen(groupId: args["groupId"] as String? ?? "g-1"));
      case AppRoutes.discoverMeetups:
        return _material(const DiscoverMeetupsScreen());
      case AppRoutes.coaching:
        return _material(const CoachingScreen());
      default:
        return _material(
          const Scaffold(body: Center(child: Text("Unknown route"))),
        );
    }
  }

  static MaterialPageRoute<dynamic> _material(Widget child) {
    return MaterialPageRoute<dynamic>(builder: (_) => child);
  }
}
