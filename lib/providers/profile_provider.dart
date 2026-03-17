import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileProvider extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _userData;

  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get userData => _userData;

  /// Fetch current user profile with additional stats
  Future<void> fetchUserProfile() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw "User not logged in";

      final snapshot = await _db.collection("users").doc(userId).get();

      if (!snapshot.exists) throw "User data not found";

      _userData = snapshot.data();
      _userData!['uid'] = userId;

      // Fetch additional stats
      await _fetchUserStats(userId);

    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching user profile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch user statistics (committees count, payments count)
  Future<void> _fetchUserStats(String userId) async {
    try {
      // Get committees count
      final committeesSnapshot = await _db
          .collection('committees')
          .where('membersMap.$userId', isEqualTo: true)
          .get();

      _userData!['committeesCount'] = committeesSnapshot.docs.length;

      // Get payments count
      int paymentsCount = 0;
      for (var committee in committeesSnapshot.docs) {
        final payments = committee.data()['membersPayments'] as Map?;
        if (payments != null && payments[userId] != null) {
          final memberPayments = payments[userId] as Map;
          paymentsCount += memberPayments.length;
        }
      }
      _userData!['paymentsCount'] = paymentsCount;

      // Get creation date
      final userDoc = await _db.collection('users').doc(userId).get();
      final createdAt = userDoc.data()?['createdAt'];
      if (createdAt != null) {
        _userData!['createdAt'] = createdAt;
      }

    } catch (e) {
      debugPrint('Error fetching user stats: $e');
    }
  }

  /// Update profile with image
  Future<bool> updateProfile({
    required String name,
    required String phone,
    File? imageFile,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      final userRef = _db.collection('users').doc(userId);

      Map<String, dynamic> updateData = {
        'name': name,
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Upload image if provided
      if (imageFile != null) {
        try {
          // Delete old image if exists
          if (_userData != null && _userData!['profileImage'] != null) {
            try {
              final oldImageUrl = _userData!['profileImage'] as String;
              final oldRef = _storage.refFromURL(oldImageUrl);
              await oldRef.delete();
            } catch (e) {
              debugPrint('Error deleting old image: $e');
            }
          }

          // Upload new image
          final fileName = 'profile_$userId.jpg';
          final ref = _storage.ref().child('profile_images').child(fileName);

          // Set metadata
          final metadata = SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {'userId': userId},
          );

          final uploadTask = ref.putFile(imageFile, metadata);
          final snapshot = await uploadTask.whenComplete(() => {});
          final downloadUrl = await snapshot.ref.getDownloadURL();

          updateData['profileImage'] = downloadUrl;
        } catch (e) {
          debugPrint('Error uploading image: $e');
          throw Exception('Failed to upload profile image');
        }
      }

      // Update Firestore
      await userRef.update(updateData);

      // Update local user data
      if (_userData != null) {
        _userData!.addAll(updateData);
      }

      // Update Firebase Auth display name
      try {
        await _auth.currentUser?.updateDisplayName(name);
      } catch (e) {
        debugPrint('Error updating auth display name: $e');
      }

      _isLoading = false;
      notifyListeners();
      return true;

    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('Error updating profile: $e');
      return false;
    }
  }

  /// Simple profile update without image (for backward compatibility)
  Future<void> updateProfileSimple({
    required String name,
    required String phone,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      await _db.collection('users').doc(userId).update({
        'name': name,
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update local user data
      if (_userData != null) {
        _userData!['name'] = name;
        _userData!['phone'] = phone;
      }

      // Update Firebase Auth display name
      try {
        await _auth.currentUser?.updateDisplayName(name);
      } catch (e) {
        debugPrint('Error updating auth display name: $e');
      }

      _isLoading = false;
      notifyListeners();

    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('Error updating profile: $e');
    }
  }

  /// Upload profile image only
  Future<String?> uploadProfileImage(File imageFile) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      // Delete old image if exists
      if (_userData != null && _userData!['profileImage'] != null) {
        try {
          final oldImageUrl = _userData!['profileImage'] as String;
          final oldRef = _storage.refFromURL(oldImageUrl);
          await oldRef.delete();
        } catch (e) {
          debugPrint('Error deleting old image: $e');
        }
      }

      final fileName = 'profile_$userId.jpg';
      final ref = _storage.ref().child('profile_images').child(fileName);

      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask.whenComplete(() => {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update Firestore with new image URL
      await _db.collection('users').doc(userId).update({
        'profileImage': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update local user data
      if (_userData != null) {
        _userData!['profileImage'] = downloadUrl;
      }
      notifyListeners();

      return downloadUrl;

    } catch (e) {
      _error = e.toString();
      debugPrint('Error uploading profile image: $e');
      return null;
    }
  }

  /// Clear any errors
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Reset provider state
  void reset() {
    _isLoading = false;
    _error = null;
    _userData = null;
    notifyListeners();
  }

  /// Logout user
  Future<void> logout() async {
    try {
      await _auth.signOut();
      reset();
    } catch (e) {
      debugPrint('Error during logout: $e');
    }
  }
}