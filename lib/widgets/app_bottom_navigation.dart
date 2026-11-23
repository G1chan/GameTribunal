import 'package:flutter/material.dart';
import '../screens/home_page.dart';
import '../screens/ranking_page.dart';
import '../screens/profile_page.dart';
import '../screens/case_create_step1_page.dart';
import '../theme/app_colors.dart';
class AppBottomNavigation extends StatelessWidget { const AppBottomNavigation({super.key, required this.index}); final int index;
  void _go(BuildContext context, int next) { if (next == index) return; final page = switch (next) { 0 => const HomePage(), 1 => const HomePage(liveOnly: true), 2 => const CaseCreateStep1Page(), 3 => const RankingPage(), _ => const ProfilePage() }; Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => page), (r) => false); }
  @override Widget build(BuildContext context) => NavigationBar(height: 66, selectedIndex: index, onDestinationSelected: (value) => _go(context, value), indicatorColor: AppColors.redPale, destinations: const [NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: AppColors.red), label: '홈'), NavigationDestination(icon: Icon(Icons.bolt_outlined), selectedIcon: Icon(Icons.bolt, color: AppColors.red), label: '실시간'), NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle, color: AppColors.red), label: '사건 접수'), NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events, color: AppColors.red), label: '랭킹'), NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: AppColors.red), label: 'MY')]);
}
