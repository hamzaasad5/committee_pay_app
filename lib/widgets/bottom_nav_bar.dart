import 'package:committee_pay_app/providers/committees_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../views/home/home_screen.dart';
import '../views/my_committees/my_committees.dart';
import '../views/profile/profile_screen.dart';
import '../providers/auth_provider.dart';
import '../views/winner_announcement/winner_announcement_screen.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Get current user ID from AuthProvider
    final userId = context.watch<AuthProvider>().currentUserId ?? "";

    // Get committees list from CommitteesProvider
    final committees = context.watch<CommitteesProvider>().committees;

    // Choose a committeeId for winner announcement screen
    // For example, first committee in the list if available
    String? committeeId;
    if (committees.isNotEmpty) {
      committeeId = committees[0]["id"];
    }

    final List<Widget> _screens = [
      const HomeScreen(),
      MyCommitteesScreen(userId: userId),
      // Pass committeeId only if available, else show empty screen
      committeeId != null
          ? WinnerAnnouncementScreen(committeeId: committeeId)
          : const Center(
        child: Text("No committee available for announcements"),
      ),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: ThemeConstants.primaryColor,
        unselectedItemColor: ThemeConstants.textSecondaryLight,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Committees',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.announcement),
            label: 'Announcement',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
