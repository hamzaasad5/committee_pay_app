import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool loading = false;
  User? currentUser;

  AuthProvider() {
    _auth.authStateChanges().listen((user) {
      currentUser = user;
      notifyListeners();
    });
  }

  void _setLoading(bool value) {
    loading = value;
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
        "committees": [], // empty initially
        "totalBalance": 0,
      });

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
    try {
      _setLoading(true);

      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      currentUser = cred.user;
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

  // LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
    currentUser = null;
    notifyListeners();
  }
}
