import 'package:committee_pay_app/providers/committees_provider.dart';
import 'package:committee_pay_app/providers/profile_provider.dart';
import 'package:committee_pay_app/views/auth/login.dart';
import 'package:committee_pay_app/views/splash_screen.dart';
import 'package:committee_pay_app/widgets/bottom_nav_bar.dart';
import 'package:committee_pay_app/providers/auth_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants/app_colors.dart';
import 'firebase_options.dart';
import 'onboarding_screens/onboarding_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Firebase Init
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🔥 Hive Init
  await Hive.initFlutter();

  // ✅ Open boxes
  await Hive.openBox('userBox');
  await Hive.openBox('committeesBox');
  await Hive.openBox('paymentsBox');

  // ✅ Initialize SharedPreferences for onboarding
  await SharedPreferences.getInstance();

  runApp(const CommitteeApp());
}

class CommitteeApp extends StatelessWidget {
  const CommitteeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CommitteesProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ],
      child: MaterialApp(
        title: "KametiPro",
        debugShowCheckedModeBanner: false,
        theme: AppColors.lightTheme,
        darkTheme: AppColors.darkTheme,
        home: const AppInitializer(), // ✅ Changed from AuthGate to AppInitializer
        routes: {
          "/signup": (context) => const SignInScreen(),
          "/bottom_nav_bar": (context) => const BottomNavBar(),
          "/onboarding": (context) => const OnboardingWrapper(), // ✅ Added onboarding route
          "/home": (context) => const BottomNavBar(), // ✅ Home route
        },
      ),
    );
  }
}

/// ✅ NEW: AppInitializer handles both onboarding AND authentication
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true;
  bool _showOnboarding = false;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Check onboarding status
    final prefs = await SharedPreferences.getInstance();
    final hasCompletedOnboarding = prefs.getBool('onboardingCompleted') ?? false;

    // Check authentication status
    final user = FirebaseAuth.instance.currentUser;

    setState(() {
      _showOnboarding = !hasCompletedOnboarding;
      _isLoggedIn = user != null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SplashScreen();
    }

    // Priority 1: Show onboarding for first-time users
    if (_showOnboarding) {
      return const OnboardingWrapper();
    }

    // Priority 2: Show auth gate for non-logged in users
    if (!_isLoggedIn) {
      return const SignInScreen();
    }

    // Priority 3: Show main app for logged in users
    return const BottomNavBar();
  }
}

/// ✅ Keep AuthGate for backward compatibility (optional)
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    print("🔄 AuthGate build triggered... waiting for FirebaseAuth stream");

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        print("📡 Auth state changed → Connection: ${snapshot.connectionState}");
        print("📡 Snapshot hasData: ${snapshot.hasData}");

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          print("🔓 User is logged in → UID: ${snapshot.data!.uid}");
          return const BottomNavBar();
        }

        return const SignInScreen();
      },
    );
  }
}