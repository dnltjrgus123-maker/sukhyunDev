import "package:flutter/material.dart";

import "../favorites/favorites_screen.dart";
import "../home/home_screen.dart";
import "../lightning/lightning_screen.dart";
import "../mypage/my_page_screen.dart";
import "../reviews/reviews_screen.dart";
import "../venues/venue_list_screen.dart";

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  int _index = 0;

  late final List<Widget> _tabs = const [
    HomeScreen(),
    VenueListScreen(),
    LightningScreen(),
    FavoritesScreen(),
    ReviewsScreen(),
    MyPageScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        animationDuration: const Duration(milliseconds: 280),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        elevation: 8,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: "홈",
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            selectedIcon: Icon(Icons.location_on_rounded),
            label: "구장",
          ),
          NavigationDestination(
            icon: Icon(Icons.flash_on_outlined),
            selectedIcon: Icon(Icons.flash_on_rounded),
            label: "번개",
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline_rounded),
            selectedIcon: Icon(Icons.star_rounded),
            label: "즐겨찾기",
          ),
          NavigationDestination(
            icon: Icon(Icons.rate_review_outlined),
            selectedIcon: Icon(Icons.rate_review_rounded),
            label: "후기",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: "마이",
          ),
        ],
      ),
    );
  }
}
