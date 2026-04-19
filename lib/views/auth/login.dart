import 'package:committee_pay_app/providers/auth_provider.dart';
import 'package:committee_pay_app/views/auth/signup.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../utils/app_local_storage.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'forgot_password_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool obscurePass = true;
  bool _isLoading = false;

  // Theme variation - change this to test different designs
  // Options: 'modern', 'elegant', 'minimal', 'gradient'
  final String _themeVariation = 'modern';

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  Future<void> _handleLogin(AuthProvider auth) async {
    _dismissKeyboard();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = emailCtrl.text.trim();
      final password = passCtrl.text.trim();

      final error = await auth.loginWithEmail(
        email: email,
        password: password,
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

      final userId = await LocalStorage.getUserId();
      if (userId == null || userId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Error fetching userId. Please try again."),
              backgroundColor: AppColors.red,
              behavior: SnackBarBehavior.floating,
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
                    _buildEmailField(),
                    SizedBox(height: AppColors.spacingMedium),
                    _buildPasswordField(),
                    SizedBox(height: AppColors.spacingSmall),
                    _buildForgotPassword(),
                    SizedBox(height: AppColors.spacingXLarge),
                    _buildSignInButton(isLoading, auth),
                    SizedBox(height: AppColors.spacingMedium),
                    _buildSignUpLink(),
                    SizedBox(height: AppColors.spacingXLarge),
                    _buildPrivacyPolicy(),
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
                AppColors.goldColor,
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
            Icons.account_balance_wallet,
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
                Icons.account_balance_wallet,
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
          Icons.account_balance_wallet,
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
            Icons.account_balance_wallet,
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
          "Welcome Back",
          style: AppColors.headlineLarge.copyWith(
            color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
            fontWeight: FontWeight.bold,
            fontSize: 32,
          ),
        ),
        SizedBox(height: AppColors.spacingSmall),
        Text(
          "Sign in to continue to Committee Pay",
          style: AppColors.bodyMedium.copyWith(
            color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
            fontSize: 14,
          ),
        ),
      ],
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

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          _dismissKeyboard();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
          );
        },
        style: TextButton.styleFrom(
          foregroundColor: AppColors.goldColor,
          padding: const EdgeInsets.symmetric(
            horizontal: AppColors.spacingSmall,
            vertical: AppColors.spacingSmall,
          ),
        ),
        child: Text(
          "Forgot Password?",
          style: TextStyle(
            color: AppColors.goldColor,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSignInButton(bool isLoading, AuthProvider auth) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: isLoading ? null : () => _handleLogin(auth),
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
          "Sign In",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account?",
          style: TextStyle(
            color: _themeVariation == 'minimal' ? AppColors.textSecondaryLight : AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        TextButton(
          onPressed: () {
            _dismissKeyboard();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SignupScreen()),
            );
          },
          style: TextButton.styleFrom(
            foregroundColor: AppColors.goldColor,
            padding: const EdgeInsets.symmetric(
              horizontal: AppColors.spacingSmall,
              vertical: AppColors.spacingSmall,
            ),
          ),
          child: Text(
            "Sign Up",
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

  Widget _buildPrivacyPolicy() {
    final textColor = _themeVariation == 'minimal'
        ? AppColors.textSecondaryLight
        : AppColors.textSecondary;

    return Center(
      child: Column(
        children: [
          Text(
            "By signing in, you agree to our",
            style: TextStyle(
              fontSize: 11,
              color: textColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: AppColors.spacingXSmall),
          InkWell(
            onTap: () => _launchPrivacyPolicy(),
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
    );
  }
}

Future<void> _launchPrivacyPolicy() async {
  final Uri url = Uri.parse("https://committee-pay-app.web.app/privacy-policy");
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

}
