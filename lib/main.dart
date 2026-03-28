import 'package:committee_pay_app/providers/committees_provider.dart';
import 'package:committee_pay_app/providers/profile_provider.dart';
import 'package:committee_pay_app/views/auth/login.dart';
import 'package:committee_pay_app/widgets/bottom_nav_bar.dart';
import 'package:committee_pay_app/providers/auth_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart'; // ✅ ADD THIS

import 'constants/app_colors.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Firebase Init
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🔥 Hive Init
  await Hive.initFlutter();

  // ✅ Open boxes (VERY IMPORTANT)
  await Hive.openBox('userBox');
  await Hive.openBox('committeesBox');
  await Hive.openBox('paymentsBox');

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
        title: "Committee App",
        debugShowCheckedModeBanner: false,
        theme: AppColors.lightTheme,
        darkTheme: AppColors.darkTheme,
        home: const AuthGate(),
        routes: {
          "/signup": (context) => const SignInScreen(),
          "/bottom_nav_bar": (context) => const BottomNavBar(),
        },
      ),
    );
  }
}

/// AuthGate decides which screen to show depending on Firebase Auth state
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