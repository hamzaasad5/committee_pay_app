import 'package:committee_pay_app/providers/committees_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../utils/app_local_storage.dart';
import '../views/home/home_screen.dart';
import '../views/member_assigment/widgets/member_assignment_home.dart';
import '../views/my_committees/my_committees.dart';
import '../views/profile/profile_screen.dart';
import '../providers/auth_provider.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _currentIndex = 0;
  String? _userId;
  bool _loadingUserId = true;

  @override
  void initState() {
    super.initState();
    _fetchUserId();
  }

  Future<void> _fetchUserId() async {
    final authProvider = context.read<AuthProvider>();
    String? userId = authProvider.currentUser?.uid;

    if (userId == null) {
      userId = await LocalStorage.getUserId();
    }

    setState(() {
      _userId = userId;
      _loadingUserId = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingUserId) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List<Widget> screens = [
      const HomeScreen(),
      MyCommitteesScreen(userId: _userId ?? ""),
      const MemberAssignmentHome(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: AppColors.primaryColor,
        unselectedItemColor: AppColors.textSecondaryLight,
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
