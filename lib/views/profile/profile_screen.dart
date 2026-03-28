import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../constants/app_colors.dart';
import '../../providers/profile_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/loading_overlay.dart';
import '../../services/error_handler.dart';
import 'package:intl/intl.dart';

import '../my_committees/my_committees.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isEditing = false;
  bool _isSaving = false;
  File? _profileImage;
  Map<String, dynamic>? _userData;
  String? _error;
  bool _isLoading = true;
  bool _isInitialized = false;
  String _appVersion = '1.0.0';
  String _appName = 'Committee Pay';
  final String _themeVariation = 'modern';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProfile();
      _getAppInfo();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshProfile();
    }
  }

  Future<void> _getAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
          _appName = packageInfo.appName;
        });
      }
    } catch (e) {
      debugPrint('Error getting app info: $e');
    }
  }

  Future<void> _initializeProfile() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = context.read<ProfileProvider>();
      await provider.fetchUserProfile();

      if (mounted) {
        setState(() {
          _userData = provider.userData;
          _error = provider.error;
          _isLoading = false;
          _isInitialized = true;

          if (_userData != null) {
            _nameController.text = _userData!["name"] ?? "";
            _phoneController.text = _userData!["phone"] ?? "";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _isInitialized = true;
        });
      }
    }
  }

  Future<void> _refreshProfile() async {
    if (!mounted) return;

    final provider = context.read<ProfileProvider>();
    await provider.fetchUserProfile();

    if (mounted) {
      setState(() {
        _userData = provider.userData;
        _error = provider.error;
        if (_userData != null) {
          _nameController.text = _userData!["name"] ?? "";
          _phoneController.text = _userData!["phone"] ?? "";
        }
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );

      if (pickedFile != null && mounted) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, 'Failed to pick image');
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final provider = context.read<ProfileProvider>();

      final success = await provider.updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        imageFile: _profileImage,
      );

      if (success && mounted) {
        setState(() {
          _isEditing = false;
          _profileImage = null;
        });

        ErrorHandler.showSuccess(context, 'Profile updated successfully');
        await _refreshProfile();
      } else if (mounted) {
        ErrorHandler.showError(context, provider.error ?? 'Failed to update profile');
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, 'An unexpected error occurred');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _shareAppLink() async {
    try {
      final String appLink = Platform.isAndroid
          ? 'https://play.google.com/store/apps/details?id=com.committeepay.app'
          : 'https://apps.apple.com/app/id123456789';

      final String shareText = '''
🎉 Join me on Committee Pay - The Ultimate Committee Management App!

Committee Pay helps you:
✅ Manage committees easily
✅ Track payments securely
✅ Get notifications for draws
✅ Connect with community

Download now: $appLink

Invite code: ${_userData?['referralCode'] ?? _userData?['uid']?.substring(0, 8) ?? 'COMMITTEE'}

#CommitteePay #Savings #Community
''';

      await Share.share(
        shareText,
        subject: 'Join Committee Pay - Manage Your Committees Smartly!',
      );

      await FirebaseFirestore.instance.collection('analytics').add({
        'userId': _userData?['uid'],
        'action': 'share_app',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, 'Failed to share app link');
      }
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.r20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.goldColor, AppColors.goldColor.withOpacity(0.7)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _appName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Version $_appVersion',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),
              _buildAboutItem(
                icon: Icons.info_outline,
                text: 'Committee Pay is the ultimate platform for managing committees and savings groups.',
              ),
              const SizedBox(height: 12),
              _buildAboutItem(
                icon: Icons.verified,
                text: 'Secure & Transparent Transactions',
              ),
              const SizedBox(height: 12),
              _buildAboutItem(
                icon: Icons.people,
                text: 'Join 10,000+ Active Users',
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _shareAppLink();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.goldColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.r12),
                        ),
                      ),
                      child: const Text('Share App'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutItem({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.goldColor),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _rateApp() async {
    final String appStoreUrl = 'https://play.google.com/store/apps/details?id=com.committeepay.app';
    await _launchUrlWithFallback(Uri.parse(appStoreUrl));
  }

  Future<void> _openPrivacyPolicy() async {
    final Uri url = Uri.parse('https://committee-pay-app.web.app/privacy-policy');
    await _launchUrlWithFallback(url);
  }

  Future<void> _openTermsOfService() async {
    final Uri url = Uri.parse('https://committee-pay-app.web.app/terms-of-service');
    await _launchUrlWithFallback(url);
  }

  Future<void> _launchUrlWithFallback(Uri url) async {
    if (await canLaunchUrl(url)) {
      try {
        final bool launched = await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      } catch (e) {
        debugPrint('Error launching: $e');
      }
    }

    try {
      final bool launched = await launchUrl(
        url,
        mode: LaunchMode.platformDefault,
      );
      if (launched) return;
    } catch (e) {
      debugPrint('Error launching with platformDefault: $e');
    }

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
                    content: Text('Link copied to clipboard!'),
                    backgroundColor: AppColors.goldColor,
                    behavior: SnackBarBehavior.floating,
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

  Future<void> _contactSupport() async {
    final String email = 'support@committeepay.com';
    final String subject = 'Committee Pay Support Request';
    final String body = '''
User ID: ${_userData?['uid'] ?? 'N/A'}
Name: ${_userData?['name'] ?? 'N/A'}
Email: ${_userData?['email'] ?? 'N/A'}
App Version: $_appVersion

---
Please describe your issue here:
''';

    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        _showWhatsAppFallbackDialog();
      }
    } catch (e) {
      _showWhatsAppFallbackDialog();
    }
  }

  void _showWhatsAppFallbackDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.r16),
        ),
        title: const Text(
          'Email App Not Available',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Would you like to contact support via WhatsApp instead?',
          style: TextStyle(color: AppColors.textSecondary),
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
            onPressed: () {
              Navigator.pop(context);
              _openWhatsApp();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.goldColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.r8),
              ),
            ),
            child: const Text('Open WhatsApp'),
          ),
        ],
      ),
    );
  }

  Future<void> _openWhatsApp() async {
    final String phoneNumber = '923189547155';
    final String message = '''
Hello! I need support regarding Committee Pay App.

User ID: ${_userData?['uid'] ?? 'N/A'}
Name: ${_userData?['name'] ?? 'N/A'}
Email: ${_userData?['email'] ?? 'N/A'}
Phone: ${_userData?['phone'] ?? 'N/A'}
App Version: $_appVersion

---
Please help me with:
''';

    String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (!cleanPhone.startsWith('+')) {
      cleanPhone = '+$cleanPhone';
    }

    final whatsappApiUrl = Uri.parse('whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(message)}');
    final whatsappWebUrl = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');

    try {
      if (await canLaunchUrl(whatsappApiUrl)) {
        await launchUrl(whatsappApiUrl);
      } else if (await canLaunchUrl(whatsappWebUrl)) {
        await launchUrl(whatsappWebUrl, mode: LaunchMode.externalApplication);
      } else {
        _showWhatsAppInstallDialog();
      }
    } catch (e) {
      _showWhatsAppInstallDialog();
    }
  }

  void _showWhatsAppInstallDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.r16),
        ),
        title: const Text(
          'WhatsApp Not Available',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Please install WhatsApp to chat with support.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final Uri playStoreUrl = Uri.parse('https://play.google.com/store/apps/details?id=com.whatsapp');
              await _launchUrlWithFallback(playStoreUrl);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.goldColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.r8),
              ),
            ),
            child: const Text('Install WhatsApp'),
          ),
        ],
      ),
    );
  }

  void _showFAQs() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppColors.r20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: AppColors.goldColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Frequently Asked Questions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildFAQItem(
                    question: 'How do I create a committee?',
                    answer: 'Tap the + button on the bottom navigation bar and choose either Daily or Monthly committee.',
                  ),
                  _buildFAQItem(
                    question: 'How are winners selected?',
                    answer: 'Winners are selected randomly through our automated draw system.',
                  ),
                  _buildFAQItem(
                    question: 'Is my money safe?',
                    answer: 'Yes! All transactions are recorded securely.',
                  ),
                  _buildFAQItem(
                    question: 'How do I invite members?',
                    answer: 'Share your committee code or use the "Share App" feature.',
                  ),
                  _buildFAQItem(
                    question: 'Can I join multiple committees?',
                    answer: 'Yes, you can join and create multiple committees.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem({required String question, required String answer}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppColors.r12),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, size: 16, color: AppColors.goldColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            answer,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    try {
      final shouldLogout = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.r16),
          ),
          title: const Text(
            'Logout',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.r8),
                ),
              ),
              child: const Text('Logout'),
            ),
          ],
        ),
      );

      if (shouldLogout != true || !mounted) return;

      setState(() => _isSaving = true);
      final authProvider = context.read<AuthProvider>();

      try {
        await authProvider.logout();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } catch (e) {
        setState(() => _isSaving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to logout: ${e.toString()}'),
              backgroundColor: AppColors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: ${e.toString()}'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _toggleEdit() {
    if (_isEditing) {
      setState(() {
        _isEditing = false;
        _profileImage = null;
        if (_userData != null) {
          _nameController.text = _userData!["name"] ?? "";
          _phoneController.text = _userData!["phone"] ?? "";
        }
      });
    } else {
      setState(() => _isEditing = true);
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Color _getColorFromName(String name) {
    if (name.isEmpty) return AppColors.goldColor;
    final hash = name.hashCode.abs();
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.7, 0.5).toColor();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<ProfileProvider>();

    return WillPopScope(
      onWillPop: () async {
        if (_isEditing) {
          final shouldDiscard = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppColors.surfaceDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.r16),
              ),
              title: const Text(
                'Discard Changes?',
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                'You have unsaved changes. Are you sure you want to go back?',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('Stay'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.r8),
                    ),
                  ),
                  child: const Text('Discard'),
                ),
              ],
            ),
          );
          return shouldDiscard ?? false;
        }
        return true;
      },
      child: LoadingOverlay(
        isLoading: _isSaving,
        child: Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: AppColors.surfaceDark,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: const Text(
              "Profile",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            centerTitle: true,
            actions: [
              if (!_isLoading && _userData != null && !_isEditing)
                IconButton(
                  icon: Icon(Icons.edit, color: AppColors.goldColor),
                  onPressed: _toggleEdit,
                  tooltip: 'Edit Profile',
                ),
              if (_isEditing)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _toggleEdit,
                  tooltip: 'Cancel',
                ),
            ],
          ),
          body: _buildBody(provider),
        ),
      ),
    );
  }

  Widget _buildBody(ProfileProvider provider) {
    if (_isLoading && !_isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.goldColor),
            SizedBox(height: 16),
            Text(
              'Loading profile...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_error != null && _userData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.red,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load profile',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _initializeProfile,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.r12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_userData == null) {
      return const Center(
        child: Text(
          'No user data available',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final user = _userData!;
    final profileColor = _getColorFromName(user["name"] ?? "");
    final initials = _getInitials(user["name"] ?? "");

    return RefreshIndicator(
      onRefresh: _refreshProfile,
      color: AppColors.goldColor,
      backgroundColor: AppColors.surfaceDark,
      child: ListView(
        padding: const EdgeInsets.all(AppColors.spacingMedium),
        children: [
          _buildCompactProfileHeader(user, profileColor, initials),
          if (_isEditing) const SizedBox(height: 20),
          if (_isEditing) _buildEditForm(),
          const SizedBox(height: 20),
          _buildStatsSection(user),
          const SizedBox(height: 20),
          _buildMainMenu(),
          const SizedBox(height: 20),
          _buildSupportSection(),
          const SizedBox(height: 20),
          _buildAboutSection(),
          const SizedBox(height: 20),
          _buildLogoutButton(),
          const SizedBox(height: 20),
          _buildAppVersion(),
        ],
      ),
    );
  }

  Widget _buildCompactProfileHeader(Map<String, dynamic> user, Color profileColor, String initials) {
    return Container(
      padding: const EdgeInsets.all(AppColors.spacingMedium),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppColors.r16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isEditing ? AppColors.goldColor : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 35,
                  backgroundColor: profileColor.withOpacity(0.2),
                  backgroundImage: _profileImage != null
                      ? FileImage(_profileImage!)
                      : (user["profileImage"] != null
                      ? NetworkImage(user["profileImage"])
                      : null) as ImageProvider?,
                  child: _profileImage == null && user["profileImage"] == null
                      ? Text(
                    initials,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: profileColor,
                    ),
                  )
                      : null,
                ),
              ),
              if (_isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.goldColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user["name"] ?? "No Name",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  user["email"] ?? "No Email",
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      user["phone"] ?? "No Phone",
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.goldSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.goldColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.goldColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Active",
                            style: TextStyle(
                              color: AppColors.goldColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Container(
      padding: const EdgeInsets.all(AppColors.spacingMedium),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppColors.r16),
        border: Border.all(color: AppColors.goldColor.withOpacity(0.3)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Edit Profile",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _nameController,
              label: "Full Name",
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter your name';
                if (value.length < 3) return 'Name must be at least 3 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _phoneController,
              label: "Phone Number",
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter your phone number';
                if (value.length < 10) return 'Please enter a valid phone number';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _toggleEdit,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppColors.r10),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _updateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.goldColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppColors.r10),
                      ),
                    ),
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(Map<String, dynamic> user) {
    return Container(
      padding: const EdgeInsets.all(AppColors.spacingMedium),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppColors.r16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Statistics",
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  label: "Committees",
                  value: "${user["committeesCount"] ?? 0}",
                  icon: Icons.group,
                  color: AppColors.goldColor,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  label: "Payments",
                  value: "${user["paymentsCount"] ?? 0}",
                  icon: Icons.payment,
                  color: AppColors.goldColor,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  label: "Member Since",
                  value: _formatJoinDate(user["createdAt"]),
                  icon: Icons.calendar_today,
                  color: AppColors.goldColor,
                  isSmall: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool isSmall = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmall ? 11 : 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMainMenu() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppColors.r16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.group_outlined,
            title: "My Committees",
            subtitle: "View and manage your committees",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MyCommitteesScreen(
                    userId: _userData?["uid"] ?? "",
                  ),
                ),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.notifications_outlined,
            title: "Notifications",
            subtitle: "Manage your alerts",
            onTap: () {
              Fluttertoast.showToast(msg: "Coming soon!");
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.settings_outlined,
            title: "Settings",
            subtitle: "App preferences",
            onTap: () {
              Fluttertoast.showToast(msg: 'Coming soon!');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppColors.r16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.help_outline,
            title: "FAQs",
            subtitle: "Frequently asked questions",
            onTap: _showFAQs,
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.support_agent,
            title: "Contact Support",
            subtitle: "Get help from our team",
            onTap: _contactSupport,
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppColors.r16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.share,
            title: "Share App",
            subtitle: "Invite friends and family",
            onTap: _shareAppLink,
            showArrow: true,
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.star,
            title: "Rate Us",
            subtitle: "Love the app? Leave a review",
            onTap: _rateApp,
            showArrow: true,
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.info_outline,
            title: "About",
            subtitle: "Version $_appVersion",
            onTap: _showAboutDialog,
            showArrow: true,
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.privacy_tip_outlined,
            title: "Privacy Policy",
            subtitle: "Read our privacy policy",
            onTap: _openPrivacyPolicy,
            showArrow: true,
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.description_outlined,
            title: "Terms of Service",
            subtitle: "Terms and conditions",
            onTap: _openTermsOfService,
            showArrow: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showArrow = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.r16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.goldSoft,
                  borderRadius: BorderRadius.circular(AppColors.r10),
                ),
                child: Icon(icon, color: AppColors.goldColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (showArrow)
                Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.textSecondary,
                  size: 14,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppColors.r16),
        border: Border.all(color: AppColors.red.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _logout,
          borderRadius: BorderRadius.circular(AppColors.r16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.logout,
                  color: AppColors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  "Logout",
                  style: TextStyle(
                    color: AppColors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppVersion() {
    return Center(
      child: Text(
        'Version $_appVersion',
        style: TextStyle(
          color: AppColors.textSecondary.withOpacity(0.5),
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Divider(
        color: AppColors.border,
        height: 1,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.goldColor, size: 20),
        filled: true,
        fillColor: AppColors.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.r12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.r12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.r12),
          borderSide: const BorderSide(color: AppColors.goldColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.r12),
          borderSide: const BorderSide(color: AppColors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  String _formatJoinDate(dynamic timestamp) {
    if (timestamp == null) return 'New';
    try {
      if (timestamp is Timestamp) {
        return DateFormat('MMM yyyy').format(timestamp.toDate());
      }
      return 'New';
    } catch (e) {
      return 'New';
    }
  }
}