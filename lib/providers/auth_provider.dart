import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../utils/app_local_storage.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool loading = false;
  bool logoutLoading = false;
  User? currentUser;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      currentUser = user;
      print('🔥 Auth state changed in provider: ${user?.uid ?? 'No user'}');
      notifyListeners();
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

  /// ========================
  /// SIGN UP
  /// ========================
  Future<String?> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    try {
      _setLoading(true);

      // Create user in Firebase Auth
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await cred.user?.updateDisplayName(name);

      currentUser = cred.user;

      // Add user document in Firestore
      await _db.collection("users").doc(currentUser!.uid).set({
        "name": name,
        "email": email,
        "phone": phone,
        "createdAt": FieldValue.serverTimestamp(),
        "committees": [],
        "totalBalance": 0,
      });

      // Save userId in local storage
      await LocalStorage.saveUserId(currentUser!.uid);

      // =====================
      // HIVE: Save user info offline
      var userBox = Hive.box('userBox');
      userBox.put('uid', currentUser!.uid);
      userBox.put('name', name);
      userBox.put('email', email);
      userBox.put('phone', phone);

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

  /// ========================
  /// LOGIN
  /// ========================
  Future<String?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);

      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      currentUser = cred.user;

      if (currentUser != null) {
        await LocalStorage.saveUserId(currentUser!.uid);

        // =====================
        // HIVE: Save user info offline
        var userBox = Hive.box('userBox');
        userBox.put('uid', currentUser!.uid);
        userBox.put('email', currentUser!.email ?? '');
        userBox.put('name', currentUser!.displayName ?? '');
      }

      _setLoading(false);
      return null;
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      return e.message;
    } catch (e) {
      _setLoading(false);
      return "Something went wrong";
    }
  }

  /// ========================
  /// LOGOUT
  /// ========================
  Future<void> logout() async {
    try {
      _setLogoutLoading(true);
      print('🔵 Starting logout process...');

      // 🔐 Firebase Sign Out
      await _auth.signOut();
      print('✓ Firebase sign out completed');

      // 👤 Clear user
      currentUser = null;
      print('✓ Current user cleared');

      // 💾 Clear Local Storage
      await LocalStorage.removeUserId();
      print('✓ User ID removed from local storage');

      // 📦 Clear Hive Storage
      try {
        var userBox = Hive.box('userBox');
        await userBox.clear();
        print('✓ Hive user box cleared');
      } catch (e) {
        print('⚠️ Hive clear error: $e');
      }

      print('✅ Logout completed successfully');
    } catch (e) {
      print('❌ Logout error: $e');
      rethrow; // important for UI handling
    }

    // ❗ DO NOT set loading false here
    // Loader will be removed by navigation
  }

  /// ========================
  /// OFFLINE SUPPORT: Get cached user info
  /// ========================
  Map<String, dynamic>? getCachedUser() {
    var userBox = Hive.box('userBox');
    if (userBox.isEmpty) return null;

    return {
      'uid': userBox.get('uid'),
      'name': userBox.get('name'),
      'email': userBox.get('email'),
      'phone': userBox.get('phone'),
    };
  }
}