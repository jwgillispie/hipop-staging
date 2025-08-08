import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;

/// Comprehensive service for GDPR-compliant user data deletion
/// 
/// This service handles the complete removal of user data across all
/// Firestore collections while maintaining data integrity and providing
/// proper error handling and progress reporting.
class UserDataDeletionService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  UserDataDeletionService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Delete all user data across all collections
  /// 
  /// This method performs a comprehensive deletion of user data for GDPR compliance.
  /// It handles:
  /// - User profile and preferences
  /// - Favorites and bookmarks
  /// - Vendor-specific data (posts, applications, relationships)
  /// - Analytics and usage data
  /// - User-created content
  /// 
  /// [userId] - The UID of the user whose data should be deleted
  /// [userType] - Optional user type for type-specific cleanup
  /// [onProgress] - Optional callback to report deletion progress
  /// 
  /// Returns a [UserDataDeletionResult] with details about the deletion operation
  Future<UserDataDeletionResult> deleteAllUserData(
    String userId, {
    String? userType,
    Function(String operation, int completed, int total)? onProgress,
  }) async {
    debugPrint('🗑️  Starting comprehensive user data deletion for user: $userId');
    developer.log('Starting user data deletion', name: 'UserDataDeletionService');
    
    final result = UserDataDeletionResult(userId: userId, startTime: DateTime.now());
    final batch = _firestore.batch();
    int operationCount = 0;
    int totalOperations = 0;

    try {
      // First, collect all operations to get total count for progress reporting
      final collectionsToClean = await _getCollectionsToClean(userId, userType);
      totalOperations = collectionsToClean.fold<int>(0, (total, collection) => total + collection.documentCount);
      
      debugPrint('📊 Found $totalOperations documents to delete across ${collectionsToClean.length} collections');

      bool hasBatchOperations = false;

      // Process each collection
      for (final collectionInfo in collectionsToClean) {
        debugPrint('🧹 Cleaning collection: ${collectionInfo.name} (${collectionInfo.documentCount} documents)');
        onProgress?.call('Deleting ${collectionInfo.name}', operationCount, totalOperations);
        
        try {
          final deletedCount = await _cleanCollection(
            collectionInfo.name,
            collectionInfo.query,
            batch,
          );
          
          result.collectionsProcessed[collectionInfo.name] = deletedCount;
          operationCount += deletedCount;
          
          if (deletedCount > 0) {
            hasBatchOperations = true;
          }
          
          debugPrint('✅ Deleted $deletedCount documents from ${collectionInfo.name}');
        } catch (e) {
          debugPrint('❌ Error cleaning collection ${collectionInfo.name}: $e');
          result.errors.add('Failed to clean ${collectionInfo.name}: $e');
        }
      }

      // Commit the batch deletion
      debugPrint('💾 Committing batch deletion...');
      onProgress?.call('Finalizing deletion', operationCount, totalOperations);
      
      if (hasBatchOperations) {
        await batch.commit();
      }

      result.endTime = DateTime.now();
      result.success = result.errors.isEmpty;
      result.totalDocumentsDeleted = operationCount;

      debugPrint('🎉 User data deletion completed successfully');
      debugPrint('📊 Total documents deleted: ${result.totalDocumentsDeleted}');
      debugPrint('⏱️  Total time: ${result.duration?.inMilliseconds}ms');

      return result;

    } catch (e) {
      result.endTime = DateTime.now();
      result.success = false;
      result.errors.add('Critical error during deletion: $e');
      
      debugPrint('💥 Critical error during user data deletion: $e');
      developer.log('Critical deletion error: $e', name: 'UserDataDeletionService', error: e);
      
      return result;
    }
  }

  /// Get list of collections and queries that need to be cleaned for this user
  Future<List<CollectionCleanupInfo>> _getCollectionsToClean(String userId, String? userType) async {
    final collections = <CollectionCleanupInfo>[];

    // Core user data collections
    collections.add(await _getCollectionInfo('user_profiles', 
        _firestore.collection('user_profiles').where(FieldPath.documentId, isEqualTo: userId)));
    
    collections.add(await _getCollectionInfo('user_favorites', 
        _firestore.collection('user_favorites').where('userId', isEqualTo: userId)));
    
    collections.add(await _getCollectionInfo('user_market_favorites', 
        _firestore.collection('user_market_favorites').where('userId', isEqualTo: userId)));

    // Vendor-specific collections (if user is a vendor)
    if (userType == 'vendor' || userType == null) {
      collections.add(await _getCollectionInfo('vendor_posts', 
          _firestore.collection('vendor_posts').where('vendorId', isEqualTo: userId)));
      
      collections.add(await _getCollectionInfo('vendor_applications', 
          _firestore.collection('vendor_applications').where('vendorId', isEqualTo: userId)));
      
      collections.add(await _getCollectionInfo('managed_vendors', 
          _firestore.collection('managed_vendors').where('vendorId', isEqualTo: userId)));
      
      collections.add(await _getCollectionInfo('vendor_markets', 
          _firestore.collection('vendor_markets').where('vendorId', isEqualTo: userId)));
      
      collections.add(await _getCollectionInfo('vendor_market_relationships', 
          _firestore.collection('vendor_market_relationships').where('vendorId', isEqualTo: userId)));
    }

    // Market organizer collections (if user is a market organizer)
    if (userType == 'market_organizer' || userType == null) {
      collections.add(await _getCollectionInfo('managed_vendors', 
          _firestore.collection('managed_vendors').where('organizerId', isEqualTo: userId)));
    }

    // User-created content
    
    collections.add(await _getCollectionInfo('events', 
        _firestore.collection('events').where('organizerId', isEqualTo: userId)));

    // Analytics and tracking data
    collections.add(await _getCollectionInfo('analytics', 
        _firestore.collection('analytics').where('userId', isEqualTo: userId)));
    
    collections.add(await _getCollectionInfo('usage_tracking', 
        _firestore.collection('usage_tracking').where('userId', isEqualTo: userId)));

    // User search history and preferences
    collections.add(await _getCollectionInfo('search_history', 
        _firestore.collection('search_history').where('userId', isEqualTo: userId)));

    // User subscriptions and premium data
    collections.add(await _getCollectionInfo('user_subscriptions', 
        _firestore.collection('user_subscriptions').where('userId', isEqualTo: userId)));

    // Filter out collections with no documents
    return collections.where((c) => c.documentCount > 0).toList();
  }

  /// Get information about a collection including document count
  Future<CollectionCleanupInfo> _getCollectionInfo(String collectionName, Query query) async {
    try {
      final snapshot = await query.get();
      return CollectionCleanupInfo(
        name: collectionName,
        query: query,
        documentCount: snapshot.docs.length,
      );
    } catch (e) {
      debugPrint('⚠️  Error getting info for collection $collectionName: $e');
      return CollectionCleanupInfo(
        name: collectionName,
        query: query,
        documentCount: 0,
      );
    }
  }

  /// Clean a specific collection using the provided query
  Future<int> _cleanCollection(String collectionName, Query query, WriteBatch batch) async {
    try {
      final snapshot = await query.get();
      
      if (snapshot.docs.isEmpty) {
        debugPrint('ℹ️  No documents found in $collectionName');
        return 0;
      }

      // Add all deletions to the batch
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('❌ Error cleaning collection $collectionName: $e');
      rethrow;
    }
  }


  /// Verify user authentication and permissions for deletion
  Future<bool> verifyDeletionPermissions(String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ No authenticated user for deletion request');
        return false;
      }

      if (currentUser.uid != userId) {
        debugPrint('❌ User attempting to delete data for different user');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error verifying deletion permissions: $e');
      return false;
    }
  }

  /// Get deletion preview - shows what would be deleted without actually deleting
  Future<UserDataDeletionPreview> getDeletePreview(String userId, {String? userType}) async {
    debugPrint('🔍 Generating deletion preview for user: $userId');
    
    try {
      final collections = await _getCollectionsToClean(userId, userType);
      final totalDocuments = collections.fold<int>(0, (total, c) => total + c.documentCount);
      
      return UserDataDeletionPreview(
        userId: userId,
        collectionsToProcess: collections.map((c) => '${c.name} (${c.documentCount} docs)').toList(),
        totalDocumentsToDelete: totalDocuments,
        estimatedTimeMinutes: (totalDocuments / 100).ceil(), // Rough estimate
      );
    } catch (e) {
      debugPrint('❌ Error generating deletion preview: $e');
      throw Exception('Failed to generate deletion preview: $e');
    }
  }
}

/// Information about a collection that needs cleanup
class CollectionCleanupInfo {
  final String name;
  final Query query;
  final int documentCount;

  CollectionCleanupInfo({
    required this.name,
    required this.query,
    required this.documentCount,
  });
}

/// Result of a user data deletion operation
class UserDataDeletionResult {
  final String userId;
  final DateTime startTime;
  DateTime? endTime;
  bool success = false;
  int totalDocumentsDeleted = 0;
  final Map<String, int> collectionsProcessed = {};
  final List<String> errors = [];

  UserDataDeletionResult({
    required this.userId,
    required this.startTime,
  });

  Duration? get duration => endTime?.difference(startTime);

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'success': success,
      'totalDocumentsDeleted': totalDocumentsDeleted,
      'collectionsProcessed': collectionsProcessed,
      'errors': errors,
      'durationMs': duration?.inMilliseconds,
    };
  }
}

/// Preview of what will be deleted
class UserDataDeletionPreview {
  final String userId;
  final List<String> collectionsToProcess;
  final int totalDocumentsToDelete;
  final int estimatedTimeMinutes;

  UserDataDeletionPreview({
    required this.userId,
    required this.collectionsToProcess,
    required this.totalDocumentsToDelete,
    required this.estimatedTimeMinutes,
  });
}

/// Exception thrown during user data deletion operations
class UserDataDeletionException implements Exception {
  final String message;
  final String? userId;
  final String? operation;

  UserDataDeletionException(
    this.message, {
    this.userId,
    this.operation,
  });

  @override
  String toString() => 'UserDataDeletionException: $message';
}

