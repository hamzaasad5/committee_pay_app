import 'package:shared_preferences/shared_preferences.dart';

/// A helper class to manage local storage using SharedPreferences.
/// This can be used to save, retrieve, and remove small persistent data like userId.
class LocalStorage {
  LocalStorage._(); // Private constructor to prevent instantiation

  /// Key for storing the user ID
  static const String _keyUserId = 'userId';

  /// Saves the [userId] to local storage.
  ///
  /// Usage:
  /// ```dart
  /// await LocalStorage.saveUserId("12345");
  /// ```
  static Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId);
  }

  /// Retrieves the saved userId from local storage.
  /// Returns `null` if no userId is stored.
  ///
  /// Usage:
  /// ```dart
  /// String? userId = await LocalStorage.getUserId();
  /// ```
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  /// Removes the saved userId from local storage.
  /// Use this on logout.
  ///
  /// Usage:
  /// ```dart
  /// await LocalStorage.removeUserId();
  /// ```
  static Future<void> removeUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
  }

  /// Clears all stored data in SharedPreferences.
  /// ⚠️ Use carefully, this removes everything stored.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
