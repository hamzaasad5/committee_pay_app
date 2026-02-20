import 'package:committee_pay_app/providers/committees_provider.dart';
import 'package:committee_pay_app/providers/profile_provider.dart';
import 'package:committee_pay_app/views/auth/login.dart';
import 'package:committee_pay_app/widgets/bottom_nav_bar.dart';
import 'package:committee_pay_app/providers/auth_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'constants/app_colors.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
        theme: ThemeConstants.lightTheme,
        darkTheme: ThemeConstants.darkTheme,
        home: const AuthGate(),
        routes: {
          "/signup": (context) => const SignInScreen(), // fallback if needed
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

        // 🔁 Waiting for Firebase
        if (snapshot.connectionState == ConnectionState.waiting) {
          print("⏳ Firebase still connecting...");
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 🔐 User logged in
        if (snapshot.hasData && snapshot.data != null) {
          print("🔓 User is logged in → UID: ${snapshot.data!.uid}");
          return const BottomNavBar();
        }

        // 🚪 Not logged in
        print("🚪 No user found → Showing Sign In screen");
        return const SignInScreen();
      },
    );
  }
}

