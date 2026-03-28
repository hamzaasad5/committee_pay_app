// lib/services/image_upload_service.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class ImageUploadService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<String> uploadImage(File image, String folderPath) async {
    try {
      final fileName = path.basename(image.path);
      final reference = _storage.ref().child('$folderPath/$fileName');

      await reference.putFile(image);
      final downloadUrl = await reference.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  static Future<void> deleteImage(String imageUrl) async {
    try {
      final reference = _storage.refFromURL(imageUrl);
      await reference.delete();
    } catch (e) {
      throw Exception('Failed to delete image: $e');
    }
  }
}