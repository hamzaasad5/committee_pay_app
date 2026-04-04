import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool showTagline;

  const AppLogo({
    super.key,
    this.size = 120,
    this.showText = true,
    this.showTagline = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo Circle
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF21A472), // Primary Teal
                Color(0xFF1A8A60), // Darker Teal
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryColor.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer ring
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: size * 0.04,
                  ),
                ),
              ),

              // "K" letter monogram
              Text(
                'K',
                style: TextStyle(
                  fontSize: size * 0.45,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Montserrat',
                ),
              ),

              // Pro badge
              Positioned(
                bottom: size * 0.20,
                right: size * 0.20,
                child: Container(
                  padding: EdgeInsets.all(size * 0.06),
                  decoration: BoxDecoration(
                    color: AppColors.goldColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.star_rounded,
                    size: size * 0.12,
                    color: Colors.white,
                  ),
                ),
              ),

              // Checkmark ring (progress indicator)
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: 0.75,
                  strokeWidth: size * 0.035,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.goldColor,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (showText) ...[
          const SizedBox(height: 16),

          // App Name
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFF21A472),
                Color(0xFF1A8A60),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              'KametiPro',
              style: TextStyle(
                fontSize: size * 0.22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
                fontFamily: 'Montserrat',
              ),
            ),
          ),

          if (showTagline) ...[
            const SizedBox(height: 4),
            Text(
              'Professional Committee Tracker',
              style: TextStyle(
                fontSize: size * 0.08,
                color: AppColors.textSecondaryLight,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ],
    );
  }
}