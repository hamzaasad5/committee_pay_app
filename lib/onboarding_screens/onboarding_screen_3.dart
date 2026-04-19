// lib/screens/onboarding/onboarding_screen_3.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../constants/app_colors.dart';

class OnboardingScreen3 extends StatefulWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  const OnboardingScreen3({
    super.key,
    required this.onGetStarted,
    required this.onBack,
    required this.onSkip,
  });

  @override
  State<OnboardingScreen3> createState() => _OnboardingScreen3State();
}

class _OnboardingScreen3State extends State<OnboardingScreen3>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _rotateController;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation for the button
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Rotation animation for the icon
    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _rotateAnimation = Tween<double>(begin: 0, end: 360).animate(
      CurvedAnimation(
        parent: _rotateController,
        curve: Curves.linear,
      ),
    );

    _pulseController.repeat(reverse: true);
    _rotateController.repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Padding(
              padding: const EdgeInsets.all(AppColors.spacingMedium),
              child: Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: widget.onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondaryLight,
                  ),
                  child: const Text('Skip', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(AppColors.spacingLarge),
                  child: Column(
                    children: [
                      // Animated rotating Lottie
                      SizedBox(
                        height: 250,
                        width: 250,
                        child: AnimatedBuilder(
                          animation: _rotateController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotateAnimation.value * 3.14159 / 180,
                              child: Lottie.asset(
                                'assets/animations/join_committee.json',
                                repeat: true,
                                animate: true,
                                fit: BoxFit.contain,
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: AppColors.spacingLarge),

                      // Title with shimmer effect
                      _buildShimmerText(),

                      const SizedBox(height: AppColors.spacingMedium),

                      // Description
                      Text(
                        'Discover and join committees that match your interests',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondaryLight,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: AppColors.spacingXLarge),

                      // Features grid
                      Container(
                        padding: const EdgeInsets.all(AppColors.spacingLarge),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.goldColor.withOpacity(0.05),
                              AppColors.secondaryColor.withOpacity(0.02),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppColors.borderRadiusLarge),
                          border: Border.all(
                            color: AppColors.goldColor.withOpacity(0.1),
                          ),
                        ),
                        child: GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: AppColors.spacingMedium,
                          crossAxisSpacing: AppColors.spacingMedium,
                          children: [
                            _buildGridItem(
                              Icons.explore_outlined,
                              'Browse Committees',
                              'Discover by category',
                            ),
                            _buildGridItem(
                              Icons.send_outlined,
                              'Request to Join',
                              'One-click requests',
                            ),
                            _buildGridItem(
                              Icons.bolt_outlined,
                              'Instant Access',
                              'Get approved quickly',
                            ),
                            _buildGridItem(
                              Icons.people_outline,
                              'Network',
                              'Connect with members',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppColors.spacingLarge),

                      // Testimonial card
                      Container(
                        padding: const EdgeInsets.all(AppColors.spacingMedium),
                        decoration: BoxDecoration(
                          color: AppColors.goldColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(AppColors.borderRadiusMedium),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: NetworkImage(
                                'https://randomuser.me/api/portraits/women/68.jpg',
                              ),
                            ),
                            const SizedBox(width: AppColors.spacingMedium),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Sarah Johnson',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '"Joined 3 committees and already contributing!"',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.format_quote,
                              color: AppColors.goldColor,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Get Started button with pulse animation
            Padding(
              padding: const EdgeInsets.all(AppColors.spacingLarge),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onBack,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.goldColor),
                        minimumSize: const Size(0, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.borderRadiusMedium),
                        ),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: AppColors.spacingMedium),
                  Expanded(
                    flex: 2,
                    child: ScaleTransition(
                      scale: _pulseAnimation,
                      child: ElevatedButton(
                        onPressed: widget.onGetStarted,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.goldColor,
                          minimumSize: const Size(0, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppColors.borderRadiusMedium),
                          ),
                        ),
                        child: const Text(
                          'Get Started',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerText() {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [
          AppColors.goldColor,
          AppColors.secondaryColor,
          AppColors.goldColor,
        ],
        stops: const [0.0, 0.5, 1.0],
        begin: Alignment(-1.0, 0),
        end: Alignment(1.0, 0),
      ).createShader(bounds),
      child: const Text(
        'Join Committee',
        style: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildGridItem(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(AppColors.spacingSmall),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppColors.borderRadiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 30, color: AppColors.goldColor),
          const SizedBox(height: AppColors.spacingSmall),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}