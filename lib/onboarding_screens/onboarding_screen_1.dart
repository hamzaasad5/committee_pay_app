// lib/screens/onboarding/onboarding_screen_1.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../constants/app_colors.dart';

class OnboardingScreen1 extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const OnboardingScreen1({
    super.key,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<OnboardingScreen1> createState() => _OnboardingScreen1State();
}

class _OnboardingScreen1State extends State<OnboardingScreen1>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Fade animation for content
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Slide animation for features
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
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
                      // Animated Lottie
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SizedBox(
                          height: 250,
                          width: 250,
                          child: Lottie.asset(
                            'assets/animations/group_chat.json',
                            repeat: true,
                            animate: true,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      const SizedBox(height: AppColors.spacingLarge),

                      // Title with animated gradient
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              AppColors.goldColor,
                              AppColors.secondaryColor,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Text(
                            'Group Chats',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: AppColors.spacingMedium),

                      // Description
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Text(
                          'Stay connected with real-time group discussions',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondaryLight,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: AppColors.spacingXLarge),

                      // Animated features list
                      SlideTransition(
                        position: _slideAnimation,
                        child: Container(
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
                          child: Column(
                            children: [
                              _buildFeatureItem(
                                Icons.chat_bubble_outline,
                                'Real-time Messaging',
                                'Instant communication with all members',
                              ),
                              const SizedBox(height: AppColors.spacingMedium),
                              _buildFeatureItem(
                                Icons.attach_file,
                                'File Sharing',
                                'Share documents, images, and files',
                              ),
                              const SizedBox(height: AppColors.spacingMedium),
                              _buildFeatureItem(
                                Icons.poll_outlined,
                                'Create Polls',
                                'Get quick feedback from committee',
                              ),
                              const SizedBox(height: AppColors.spacingMedium),
                              // _buildFeatureItem(
                              //   Icons,
                              //   'Mention Members',
                              //   '@mention to get someone\'s attention',
                              // ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Next button
            Padding(
              padding: const EdgeInsets.all(AppColors.spacingLarge),
              child: ElevatedButton(
                onPressed: widget.onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldColor,
                  minimumSize: const Size(double.infinity, 50),
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
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.goldColor, AppColors.secondaryColor],
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: Colors.white),
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
      ],
    );
  }
}