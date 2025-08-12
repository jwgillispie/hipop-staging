import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class PhotoService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload multiple photos for a vendor post
  static Future<List<String>> uploadPostPhotos(
    String postId,
    List<File> photos,
  ) async {
    final uploadedUrls = <String>[];
    
    for (int i = 0; i < photos.length; i++) {
      try {
        final file = photos[i];
        final filename = 'post_${postId}_photo_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = _storage.ref().child('vendor_posts').child(postId).child(filename);
        
        final uploadTask = ref.putFile(file);
        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();
        
        uploadedUrls.add(downloadUrl);
        debugPrint('✅ Photo uploaded: $filename');
      } catch (e) {
        debugPrint('❌ Error uploading photo $i: $e');
        // Continue with other photos even if one fails
      }
    }
    
    return uploadedUrls;
  }

  /// Delete photos for a vendor post
  static Future<void> deletePostPhotos(String postId, List<String> photoUrls) async {
    for (final url in photoUrls) {
      try {
        final ref = _storage.refFromURL(url);
        await ref.delete();
        debugPrint('✅ Photo deleted: ${ref.name}');
      } catch (e) {
        debugPrint('❌ Error deleting photo: $e');
        // Continue with other photos even if one fails
      }
    }
  }

  /// Update photos for a vendor post (handles additions and deletions)
  static Future<List<String>> updatePostPhotos(
    String postId,
    List<String> existingUrls,
    List<File> newPhotos,
  ) async {
    // Upload new photos
    final newUrls = await uploadPostPhotos(postId, newPhotos);
    
    // Combine existing URLs with new URLs
    final allUrls = [...existingUrls, ...newUrls];
    
    return allUrls;
  }

  /// Get storage path for a vendor post
  static String getPostStoragePath(String postId) {
    return 'vendor_posts/$postId';
  }

  /// Upload a single photo to a specific folder
  static Future<String> uploadPhoto(
    File photo,
    String folder,
    String userId, {
    String? customFileName,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = customFileName ?? '${folder}_${userId}_${timestamp}.jpg';
      final ref = _storage.ref().child(folder).child(userId).child(filename);
      
      final uploadTask = ref.putFile(photo);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      debugPrint('✅ Photo uploaded: $filename to $folder');
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error uploading photo to $folder: $e');
      rethrow;
    }
  }

  /// Delete a photo by URL
  static Future<void> deletePhoto(String photoUrl) async {
    try {
      final ref = _storage.refFromURL(photoUrl);
      await ref.delete();
      debugPrint('✅ Photo deleted: ${ref.name}');
    } catch (e) {
      debugPrint('❌ Error deleting photo: $e');
      rethrow;
    }
  }
}