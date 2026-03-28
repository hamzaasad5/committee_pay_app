import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/bottom_nav_bar.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool obscurePass = true;
  bool _isLoading = false;

  // Theme variation - keep consistent with login screen
  final String _themeVariation = 'modern';

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    phoneCtrl.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  Future<void> _handleSignUp(AuthProvider auth) async {
    _dismissKeyboard();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final error = await auth.signUpWithEmail(
        name: nameCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
      );

      if (error != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: AppColors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.r12),
              ),
            ),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BottomNavBar()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: ${e.toString()}'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getBackgroundColor() {
    switch (_themeVariation) {
      case 'modern':
        return AppColors.bg;
      case 'elegant':
        return AppColors.backgroundDark;
      case 'minimal':
        return AppColors.backgroundLight;
      case 'gradient':
        return AppColors.bg;
      default:
        return AppColors.bg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isLoading = auth.loading || _isLoading;

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Scaffold(
        backgroundColor: _getBackgroundColor(),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: AppColors.spacingLarge,
                vertical: AppColors.spacingMedium,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildLogo(),
                    SizedBox(height: AppColors.spacingLarge),
                    _buildWelcomeText(),
                    SizedBox(height: AppColors.spacingXLarge),
                    _buildNameField(),
                    SizedBox(height: AppColors.spacingMedium),
                    _buildEmailField(),
                    SizedBox(height: AppColors.spacingMedium),
                    _buildPhoneField(),
                    SizedBox(height: AppColors.spacingMedium),
                    _buildPasswordField(),
                    SizedBox(height: AppColors.spacingXLarge),
                    _buildSignUpButton(isLoading, auth),
                    SizedBox(height: AppColors.spacingMedium),
                    _buildSignInLink(),
                    SizedBox(height: AppColors.spacingXLarge),
                    _buildTermsAndPrivacy(),
                    SizedBox(height: AppColors.spacingMedium),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    switch (_themeVariation) {
      case 'modern':
        return Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.goldColor,
                AppColors.goldColor.withOpacity(0.8),
                AppColors.primaryColor,
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.goldColor.withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.person_add_alt_1,
            size: 45,
            color: Colors.white,
          ),
        );

      case 'elegant':
        return Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.goldSoft,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.goldColor,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.person_add_alt_1,
                size: 50,
                color: AppColors.goldColor,
              ),
            ),
            const SizedBox(height: AppColors.spacingSmall),
            Container(
              width: 60,
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.goldColor, AppColors.primaryColor],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        );

      case 'minimal':
        return Icon(
          Icons.person_add_alt_1,
          size: 80,
          color: AppColors.goldColor,
        );

      case 'gradient':
        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.goldColor,
                AppColors.primaryColor,
                AppColors.secondary,
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_add_alt_1,
            size: 50,
            color: Colors.white,
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWelcomeText() {
    final isDark = _themeVariation != 'minimal';

    return Column(
      children: [
        Text(
          "Create Account",
          style: AppColors.headlineLarge.copyWith(
            color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
            fontWeight: FontWeight.bold,
            fontSize: 32,
          ),
        ),
        SizedBox(height: AppColors.spacingSmall),
        Text(
          "Enter your details to continue",
          style: AppColors.bodyMedium.copyWith(
            color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: nameCtrl,
      style: TextStyle(
        color: _themeVariation == 'minimal' ? AppColors.textPrimaryLight : AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: "Full Name",
        labelStyle: TextStyle(
          color: _themeVariation == 'minimal' ? AppColors.textSecondaryLight : AppColors.textSecondary,
        ),
        prefixIcon: Icon(Icons.person_outline, color: AppColors.goldColor),
        hintText: "John Doe",
        hintStyle: TextStyle(
          color: (_themeVariation == 'minimal' ? AppColors.textSecondaryLight : AppColors.textSecondary).withOpacity(0.5),
        ),
        filled: true,
        fillColor: _themeVariation == 'minimal' ? AppColors.surfaceLight : AppColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.r12),
          borderSide: BorderSide(
            color: _themeVariation == 'minimal' ? AppColors.inputBorderLight : AppColors.border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.r12),
          borderSide: BorderSide(
            color: _themeVariation == 'minimal' ? AppColors.inputBorderLight : AppColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.r12),
          borderSide: const BorderSide(color: AppColors.goldColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.r12),
          borderSide: const BorderSide(color: AppColors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.r12),
          borderSide: const BorderSide(color: AppColors.red, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppColors.spacingMedium,
          vertical: AppColors.spacingMedium,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your full name';
        }
        if (value.length < 3) {
          return 'Name must be at least 3 characters';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: emailCtrl,
      keyboardType: TextInputType.emailAddress,
      style: TextStyle(
        color: _themeVariation == 'minimal' ? AppColors.textPrimaryLight : AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: "Email Address",
        labelStyle: TextStyle(
          color: _themeVariation == 'minimal' ? AppColors.textSecondaryLight : AppColors.textSecondary,
        ),
        prefixIcon: Icon(Icons.email_outlined, color: AppColors.goldColor),
        hintText: "you@example.com",
        hintStyle: TextStyle(
          color: (_themeVariation == 'minimal' ? AppColors.textSecondaryLight : AppColors.textSecondary).withOpacity(0.5),
        ),
        filled: true,
        fillColor: _themeVariation == 'minimal' ? AppColors.surfaceLight : AppColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.r12),
          borderSide: BorderSide(
            color: _themeVariation == 'minimal' ? AppColors.inputBorderLight : AppColors.border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.r12),
          borderSide: BorderSide(
            color: _themeVariation == 'minimal' ? AppColors.inputBorderLight : AppColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.r12),
          borderSide: const BorderSide(color: AppColors.goldColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.r12),
          borderSide: const BorderSide(color: AppColors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.r12),
          borderSide: const BorderSide(color: AppColors.red, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppColors.spacingMedium,
          vertical: AppColors.spacingMedium,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: phoneCtrl,
      keyboardType: TextInputType.phone,
      style: TextStyle(
        color: _themeVariation == 'minimal' ? AppColors.textPrimaryLight : AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: "Phone Number",
        labelStyle: TextStyle(
          color: _themeVariation == 'minimal' ? AppColors.textSecondaryLight : AppColors.textSecondary,
        ),
        prefixIcon: Icon(Icons.phone_outlined, color: AppColors.goldColor),
        hintText: "+92 300 1234567",
        hintStyle: TextStyle(
          color: (_themeVariation == 'minimal' ? AppColors.textSecondaryLight : AppColors.textSecondary).withOpacity(0.5),
        ),
        filled: true,
        fillColor: _themeVariation == 'minimal' ? AppColors.surfaceLight : AppColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.r12),
          borderSide: BorderSide(
            color: _themeVariation == 'minimal' ? AppColors.inputBorderLight : AppColors.border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.r12),
          borderSide: BorderSide(
            color: _themeVariation == 'minimal' ? AppColors.inputBorderLight : AppColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.r12),
          borderSide: const BorderSide(color: AppColors.goldColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.r12),
          borderSide: const BorderSide(color: AppColors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.r12),
          borderSide: const BorderSide(color: AppColors.red, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppColors.spacingMedium,
          vertical: AppColors.spacingMedium,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your phone number';
        }
        if (value.length < 10) {
          return 'Please enter a valid phone number';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: passCtrl,
      obscureText: obscurePass,
      style: TextStyle(
        color: _themeVariation == 'minimal' ? AppColors.textPrimaryLight : AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: "Password",
        labelStyle: TextStyle(
          color: _themeVariation == 'minimal' ? AppColors.textSecondaryLight : AppColors.textSecondary,
        ),
        prefixIcon: Icon(Icons.lock_outline, color: AppColors.goldColor),
        suffixIcon: IconButton(
          icon: Icon(
            obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: _themeVariation == 'minimal' ? AppColors.textSecondaryLight : AppColors.textSecondary,
          ),
          onPressed: () => setState(() => obscurePass = !obscurePass),
        ),
        hintText: "At least 6 characters",
        hintStyle: TextStyle(
          color: (_themeVariation == 'minimal' ? AppColors.textSecondaryLight : AppColors.textSecondary).withOpacity(0.5),
        ),
        filled: true,
        fillColor: _themeVariation == 'minimal' ? AppColors.surfaceLight : AppColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.r12),
          borderSide: BorderSide(
            color: _themeVariation == 'minimal' ? AppColors.inputBorderLight : AppColors.border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.r12),
          borderSide: BorderSide(
            color: _themeVariation == 'minimal' ? AppColors.inputBorderLight : AppColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.r12),
          borderSide: const BorderSide(color: AppColors.goldColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.r12),
          borderSide: const BorderSide(color: AppColors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.r12),
          borderSide: const BorderSide(color: AppColors.red, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppColors.spacingMedium,
          vertical: AppColors.spacingMedium,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _buildSignUpButton(bool isLoading, AuthProvider auth) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: isLoading ? null : () => _handleSignUp(auth),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.goldColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.goldColor.withOpacity(0.5),
          elevation: _themeVariation == 'minimal' ? 2 : 0,
          shadowColor: _themeVariation == 'minimal' ? AppColors.goldColor.withOpacity(0.3) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.r12),
            side: _themeVariation == 'elegant'
                ? BorderSide(color: AppColors.goldColor.withOpacity(0.5), width: 1)
                : BorderSide.none,
          ),
        ),
        child: isLoading
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : const Text(
          "Sign Up",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSignInLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Already have an account?",
          style: TextStyle(
            color: _themeVariation == 'minimal' ? AppColors.textSecondaryLight : AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        TextButton(
          onPressed: () {
            _dismissKeyboard();
            Navigator.pop(context);
          },
          style: TextButton.styleFrom(
            foregroundColor: AppColors.goldColor,
            padding: const EdgeInsets.symmetric(
              horizontal: AppColors.spacingSmall,
              vertical: AppColors.spacingSmall,
            ),
          ),
          child: Text(
            "Sign In",
            style: TextStyle(
              color: AppColors.goldColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsAndPrivacy() {
    final textColor = _themeVariation == 'minimal'
        ? AppColors.textSecondaryLight
        : AppColors.textSecondary;

    return Center(
      child: Column(
        children: [
          Text(
            "By signing up, you agree to our",
            style: TextStyle(
              fontSize: 11,
              color: textColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: AppColors.spacingXSmall),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onTap: () => _launchTermsOfService(),
                borderRadius: BorderRadius.circular(AppColors.r8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppColors.spacingSmall,
                    vertical: AppColors.spacingXSmall,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppColors.r8),
                    color: AppColors.goldSoft,
                  ),
                  child: Text(
                    "Terms of Service",
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      color: AppColors.goldColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppColors.spacingSmall),
              Text(
                "&",
                style: TextStyle(
                  fontSize: 11,
                  color: textColor,
                ),
              ),
              const SizedBox(width: AppColors.spacingSmall),
              InkWell(
                onTap: () => _launchPrivacyPolicy(),
                borderRadius: BorderRadius.circular(AppColors.r8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppColors.spacingSmall,
                    vertical: AppColors.spacingXSmall,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppColors.r8),
                    color: AppColors.goldSoft,
                  ),
                  child: Text(
                    "Privacy Policy",
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      color: AppColors.goldColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // URL Launch Methods
  Future<void> _launchPrivacyPolicy() async {
    final Uri url = Uri.parse("https://committee-pay-app.web.app/privacy-policy");
    await _launchUrlWithFallback(url);
  }

  Future<void> _launchTermsOfService() async {
    final Uri url = Uri.parse("https://committee-pay-app.web.app/terms-of-service");
    await _launchUrlWithFallback(url);
  }

  Future<void> _launchUrlWithFallback(Uri url) async {
    // Method 1: Try with canLaunchUrl first
    if (await canLaunchUrl(url)) {
      try {
        final bool launched = await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      } catch (e) {
        debugPrint('Error launching with externalApplication: $e');
      }
    }

    // Method 2: Try platform default
    try {
      final bool launched = await launchUrl(
        url,
        mode: LaunchMode.platformDefault,
      );
      if (launched) return;
    } catch (e) {
      debugPrint('Error launching with platformDefault: $e');
    }

    // Method 3: Try with web view
    try {
      final bool launched = await launchUrl(
        url,
        mode: LaunchMode.inAppWebView,
      );
      if (launched) return;
    } catch (e) {
      debugPrint('Error launching with inAppWebView: $e');
    }

    // Method 4: Fallback dialog
    if (mounted) {
      _showUrlFallbackDialog(url);
    }
  }

  void _showUrlFallbackDialog(Uri url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.r16),
        ),
        title: const Text(
          'Cannot Open Link',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unable to open the link automatically. You can:',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppColors.spacingMedium),
            Container(
              padding: const EdgeInsets.all(AppColors.spacingSmall),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(AppColors.r8),
              ),
              child: SelectableText(
                url.toString(),
                style: const TextStyle(
                  color: AppColors.goldColor,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Clipboard.setData(ClipboardData(text: url.toString()));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Link copied to clipboard! Open in your browser.'),
                    backgroundColor: AppColors.goldColor,
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.goldColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.r8),
              ),
            ),
            child: const Text('Copy Link'),
          ),
        ],
      ),
    );
  }
}