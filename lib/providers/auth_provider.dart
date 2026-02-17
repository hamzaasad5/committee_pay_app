import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/app_local_storage.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool loading = false;
  User? currentUser;
  bool logoutLoading = false;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      print('🔥 Auth state changed in provider: ${user?.uid ?? 'No user'}');
      notifyListeners(); // This will rebuild widgets listening to provider
    });
  }

  void _setLoading(bool value) {
    loading = value;
    notifyListeners();
  }

  void _setLogoutLoading(bool value) {
    logoutLoading = value;
    notifyListeners();
  }
  String? get currentUserId => currentUser?.uid;

  // SIGN UP WITH EMAIL + FIRESTORE
  Future<String?> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    try {
      _setLoading(true);

      // 1️⃣ Create user in Firebase Auth
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2️⃣ Update display name
      await cred.user?.updateDisplayName(name);

      currentUser = cred.user;

      // 3️⃣ Add user document in Firestore
      await _db.collection("users").doc(currentUser!.uid).set({
        "name": name,
        "email": email,
        "phone": phone,
        "createdAt": FieldValue.serverTimestamp(),
        "committees": [],
        "totalBalance": 0,
      });
      await LocalStorage.saveUserId(currentUser!.uid);

      _setLoading(false);
      return null;
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      return e.message;
    } catch (e) {
      _setLoading(false);
      return "Something went wrong: $e";
    }
  }

  // LOGIN WITH EMAIL
  Future<String?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    print("🔵 loginWithEmail() called");
    print("📩 Email: $email");

    try {
      _setLoading(true);
      print("🟢 Signing in Firebase user...");

      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print("✅ Login successful → UID: ${cred.user?.uid}");

      currentUser = cred.user;
      if (currentUser != null) {
        await LocalStorage.saveUserId(currentUser!.uid);
      }
      _setLoading(false);
      return null;
    } on FirebaseAuthException catch (e) {
      print("❌ FirebaseAuthException during login: ${e.code} → ${e.message}");
      _setLoading(false);
      return e.message;
    } catch (e) {
      print("❌ Unknown login error: $e");
      _setLoading(false);
      return "Something went wrong";
    }
  }

  // LOGOUT
  Future<void> logout() async {
    _setLogoutLoading(true);

    await Future.delayed(const Duration(milliseconds: 800)); // 👌 Smooth UI
    await _auth.signOut();
    currentUser = null;

    await LocalStorage.removeUserId();

    _setLogoutLoading(false);
  }
}