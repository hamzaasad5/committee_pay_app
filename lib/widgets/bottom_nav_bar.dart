import 'package:committee_pay_app/providers/committees_provider.dart';
import 'package:committee_pay_app/widgets/committee_popup.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../utils/app_local_storage.dart';
import '../views/chats/chats_list_screen.dart';
import '../views/home/home_screen.dart';
import '../views/my_committees/my_committees.dart';
import '../views/profile/profile_screen.dart';
import '../providers/auth_provider.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  String? _userId;
  bool _loadingUserId = true;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;

  final List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _fetchUserId();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabScaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );

    // Start animation loop for FAB
    _fabAnimationController.repeat(reverse: true);
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
      _initializeScreens();
    });
  }

  void _initializeScreens() {
    _screens.clear();
    _screens.addAll([
      const HomeScreen(),
      MyCommitteesScreen(userId: _userId ?? ""),
      ChatsListScreen(userId: _userId ?? ""),
      const ProfileScreen(),
    ]);
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _navigateToCreateCommittee() {
    if (_userId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateCommitteePopup(
            userId: _userId!,
          ),
        ),
      ).then((_) {
        // Refresh committees when coming back
        if (_currentIndex == 1) {
          final provider = context.read<CommitteesProvider>();
          provider.fetchUserCommittees(_userId!);
        }
      });
    }
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingUserId) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: const Center(
          child: CircularProgressIndicator(
            color: AppColors.goldColor,
          ),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: BottomAppBar(
            color: AppColors.surfaceDark,
            elevation: 0,
            height: 75,
            padding: EdgeInsets.zero,
            notchMargin: 8,
            shape: const CircularNotchedRectangle(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavBarItem(
                  index: 0,
                  icon: Icons.home_filled,
                  label: 'Home',
                  iconColor: AppColors.goldColor,
                ),
                _buildNavBarItem(
                  index: 1,
                  icon: Icons.group,
                  label: 'Committees',
                  iconColor: AppColors.goldColor,
                ),
                const SizedBox(width: 60),
                _buildNavBarItem(
                  index: 2,
                  icon: Icons.chat_bubble,
                  label: 'Chats',
                  iconColor: AppColors.goldColor,
                ),
                _buildNavBarItem(
                  index: 3,
                  icon: Icons.person,
                  label: 'Profile',
                  iconColor: AppColors.goldColor,
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: SizedBox(
        width: 68,
        height: 68,
        child: FloatingActionButton(
          onPressed: _navigateToCreateCommittee,
          elevation: 8,
          highlightElevation: 12,
          shape: const CircleBorder(),
          backgroundColor: AppColors.goldColor,
          foregroundColor: Colors.white,
          child: AnimatedBuilder(
            animation: _fabScaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _fabScaleAnimation.value,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.goldColor,
                        AppColors.goldColor.withOpacity(0.8),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.goldColor.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildNavBarItem({
    required int index,
    required IconData icon,
    required String label,
    required Color iconColor,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Container(
                key: ValueKey('$index-$isSelected'),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? iconColor.withOpacity(0.1) : Colors.transparent,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? iconColor : AppColors.textSecondary,
                  size: isSelected ? 26 : 24,
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: isSelected ? 12 : 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? iconColor : AppColors.textSecondary,
              ),
              child: Text(label),
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 4),
                height: 3,
                width: 20,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}