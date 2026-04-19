// lib/screens/onboarding/onboarding_screen_2.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../constants/app_colors.dart';

class OnboardingScreen2 extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  const OnboardingScreen2({
    super.key,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  @override
  State<OnboardingScreen2> createState() => _OnboardingScreen2State();
}

class _OnboardingScreen2State extends State<OnboardingScreen2>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Bounce animation for the main icon
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _bounceController,
        curve: Curves.elasticOut,
      ),
    );

    // Scale animation for features
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    );

    _bounceController.repeat(reverse: true);
    _scaleController.forward();
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _scaleController.dispose();
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
              padding: EdgeInsets.all(AppColors.spacingMedium),
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
                      // Animated bouncing Lottie
                      ScaleTransition(
                        scale: _bounceAnimation,
                        child: SizedBox(
                          height: 250,
                          width: 250,
                          child: Lottie.asset(
                            'assets/animations/create_committee.json',
                            repeat: true,
                            animate: true,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      const SizedBox(height: AppColors.spacingLarge),

                      // Title with animation
                      AnimatedBuilder(
                        animation: _bounceController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _bounceController.value,
                            child: ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  AppColors.secondaryColor,
                                  AppColors.goldColor,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                              child: const Text(
                                'Create Committee',
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: AppColors.spacingMedium),

                      // Description
                      Text(
                        'Start your own committee in seconds',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondaryLight,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: AppColors.spacingXLarge),

                      // Animated steps
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(AppColors.spacingLarge),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.secondaryColor.withOpacity(0.05),
                                AppColors.goldColor.withOpacity(0.02),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(AppColors.borderRadiusLarge),
                            border: Border.all(
                              color: AppColors.secondaryColor.withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildStepItem(
                                '1',
                                'Set Committee Goals',
                                'Define purpose and objectives',
                                Icons.flag_outlined,
                              ),
                              const SizedBox(height: AppColors.spacingMedium),
                              _buildStepItem(
                                '2',
                                'Invite Members',
                                'Add members by email or share link',
                                Icons.person_add_outlined,
                              ),
                              const SizedBox(height: AppColors.spacingMedium),
                              _buildStepItem(
                                '3',
                                'Assign Roles',
                                'Set roles like Chair, Secretary, Treasurer',
                                Icons.assignment_outlined,
                              ),
                              const SizedBox(height: AppColors.spacingMedium),
                              _buildStepItem(
                                '4',
                                'Track Progress',
                                'Monitor activities and achievements',
                                Icons.trending_up_outlined,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Navigation buttons
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
                    child: ElevatedButton(
                      onPressed: widget.onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.goldColor,
                        minimumSize: const Size(0, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.borderRadiusMedium),
                        ),
                      ),
                      child: const Text(
                        'Next',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

  Widget _buildStepItem(String stepNumber, String title, String subtitle, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.secondaryColor, AppColors.goldColor],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              stepNumber,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppColors.spacingMedium),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
        Icon(icon, size: 20, color: AppColors.secondaryColor),
      ],
    );
  }
}