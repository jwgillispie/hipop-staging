import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for migrating the existing vendor-market system to the new unified post-approval model
class VendorMarketMigrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _postsCollection = 'vendor_posts';
  static const String _queueCollection = 'market_approval_queue';
  static const String _trackingCollection = 'vendor_monthly_tracking';

  /// Execute the complete migration process
  static Future<MigrationResult> executeMigration({
    bool dryRun = false,
    int batchSize = 500,
  }) async {
    debugPrint('🚀 Starting vendor-market system migration...');
    debugPrint('📊 Mode: ${dryRun ? 'DRY RUN' : 'LIVE MIGRATION'}');
    debugPrint('📦 Batch size: $batchSize');
    
    final result = MigrationResult();
    
    try {
      // Step 1: Analyze existing data
      debugPrint('\n📊 Step 1: Analyzing existing data...');
      final analysis = await _analyzeExistingData();
      result.analysis = analysis;
      
      // Step 2: Migrate vendor posts
      debugPrint('\n🔄 Step 2: Migrating vendor posts...');
      final postMigration = await _migrateVendorPosts(dryRun: dryRun, batchSize: batchSize);
      result.postsProcessed = postMigration.processed;
      result.postsUpdated = postMigration.updated;
      result.postsErrors = postMigration.errors;
      
      // Step 3: Create monthly tracking documents
      debugPrint('\n📈 Step 3: Creating monthly tracking...');
      final trackingMigration = await _createMonthlyTracking(dryRun: dryRun);
      result.trackingCreated = trackingMigration.created;
      result.trackingErrors = trackingMigration.errors;
      
      // Step 4: Clean up old data structures (only if not dry run)
      if (!dryRun) {
        debugPrint('\n🧹 Step 4: Cleaning up deprecated data...');
        final cleanup = await _cleanupDeprecatedData();
        result.cleanupItems = cleanup.cleanedUp;
      }
      
      result.success = true;
      result.completedAt = DateTime.now();
      
      debugPrint('\n✅ Migration completed successfully!');
      debugPrint('📊 Results:');
      debugPrint('   - Posts processed: ${result.postsProcessed}');
      debugPrint('   - Posts updated: ${result.postsUpdated}');
      debugPrint('   - Tracking docs created: ${result.trackingCreated}');
      debugPrint('   - Errors: ${result.postsErrors.length + result.trackingErrors.length}');
      
    } catch (e) {
      result.success = false;
      result.error = e.toString();
      debugPrint('❌ Migration failed: $e');
    }
    
    return result;
  }
  
  /// Analyze existing data to understand migration scope
  static Future<DataAnalysis> _analyzeExistingData() async {
    final analysis = DataAnalysis();
    
    try {
      // Count vendor posts
      final postsSnapshot = await _firestore.collection(_postsCollection).get();
      analysis.totalPosts = postsSnapshot.docs.length;
      
      // Analyze post types
      int marketPosts = 0;
      int independentPosts = 0;
      int postsNeedingUpdate = 0;
      final Set<String> vendorIds = {};
      final Map<String, int> monthlyPostCounts = {};
      
      for (final doc in postsSnapshot.docs) {
        final data = doc.data();
        final vendorId = data['vendorId'] as String?;
        final marketId = data['marketId'] as String?;
        final hasNewFields = data.containsKey('postType') && data.containsKey('version');
        
        if (vendorId != null) {
          vendorIds.add(vendorId);
        }
        
        if (marketId != null) {
          marketPosts++;
        } else {
          independentPosts++;
        }
        
        if (!hasNewFields) {
          postsNeedingUpdate++;
        }
        
        // Count posts by month for tracking
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final monthKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}';
        monthlyPostCounts[monthKey] = (monthlyPostCounts[monthKey] ?? 0) + 1;
      }
      
      analysis.marketPosts = marketPosts;
      analysis.independentPosts = independentPosts;
      analysis.postsNeedingUpdate = postsNeedingUpdate;
      analysis.uniqueVendors = vendorIds.length;
      analysis.monthsWithPosts = monthlyPostCounts.keys.length;
      
      // Check existing tracking documents
      final trackingSnapshot = await _firestore.collection(_trackingCollection).get();
      analysis.existingTrackingDocs = trackingSnapshot.docs.length;
      
      debugPrint('📊 Data Analysis:');
      debugPrint('   - Total posts: ${analysis.totalPosts}');
      debugPrint('   - Market posts: ${analysis.marketPosts}');
      debugPrint('   - Independent posts: ${analysis.independentPosts}');
      debugPrint('   - Posts needing update: ${analysis.postsNeedingUpdate}');
      debugPrint('   - Unique vendors: ${analysis.uniqueVendors}');
      debugPrint('   - Months with posts: ${analysis.monthsWithPosts}');
      debugPrint('   - Existing tracking docs: ${analysis.existingTrackingDocs}');
      
    } catch (e) {
      debugPrint('❌ Error analyzing data: $e');
      rethrow;
    }
    
    return analysis;
  }
  
  /// Migrate vendor posts to new schema
  static Future<PostMigrationResult> _migrateVendorPosts({
    required bool dryRun,
    required int batchSize,
  }) async {
    final result = PostMigrationResult();
    
    try {
      // Get all posts that need migration
      final postsSnapshot = await _firestore.collection(_postsCollection).get();
      final allPosts = postsSnapshot.docs;
      
      debugPrint('📝 Found ${allPosts.length} posts to process');
      
      // Process in batches
      for (int i = 0; i < allPosts.length; i += batchSize) {
        final batch = allPosts.skip(i).take(batchSize).toList();
        
        debugPrint('🔄 Processing batch ${(i ~/ batchSize) + 1}/${(allPosts.length / batchSize).ceil()}');
        
        if (dryRun) {
          // Dry run - just analyze what would be changed
          for (final doc in batch) {
            result.processed++;
            final data = doc.data();
            
            if (!data.containsKey('postType') || !data.containsKey('version')) {
              result.updated++;
            }
          }
        } else {
          // Live migration - update documents
          final firestoreBatch = _firestore.batch();
          
          for (final doc in batch) {
            try {
              result.processed++;
              final data = doc.data();
              
              // Check if migration is needed
              if (!data.containsKey('postType') || !data.containsKey('version')) {
                final updates = _generatePostUpdates(data);
                firestoreBatch.update(doc.reference, updates);
                result.updated++;
              }
            } catch (e) {
              result.errors.add('Error processing post ${doc.id}: $e');
            }
          }
          
          // Commit batch
          if (result.updated % batchSize == 0 && result.updated > 0) {
            await firestoreBatch.commit();
            debugPrint('✅ Committed batch of ${batch.length} updates');
          }
        }
      }
      
    } catch (e) {
      result.errors.add('Migration error: $e');
    }
    
    return result;
  }
  
  /// Generate updates for a vendor post
  static Map<String, dynamic> _generatePostUpdates(Map<String, dynamic> data) {
    final updates = <String, dynamic>{};
    
    // Determine post type based on marketId
    final marketId = data['marketId'];
    if (!data.containsKey('postType')) {
      updates['postType'] = marketId != null ? 'market' : 'independent';
    }
    
    // Set associated market fields
    if (marketId != null && !data.containsKey('associatedMarketId')) {
      updates['associatedMarketId'] = marketId;
      // TODO: Could fetch market details to populate name and logo
    }
    
    // Set approval status for existing market posts
    if (marketId != null && !data.containsKey('approvalStatus')) {
      updates['approvalStatus'] = 'approved'; // Assume existing market posts are approved
      updates['approvalDecidedAt'] = FieldValue.serverTimestamp();
    }
    
    // Set tracking fields
    if (!data.containsKey('monthlyPostNumber')) {
      updates['monthlyPostNumber'] = 0; // Will be recalculated during tracking creation
    }
    
    if (!data.containsKey('countsTowardLimit')) {
      updates['countsTowardLimit'] = true;
    }
    
    // Set schema version
    if (!data.containsKey('version')) {
      updates['version'] = 2;
    }
    
    // Update timestamp
    updates['updatedAt'] = FieldValue.serverTimestamp();
    
    return updates;
  }
  
  /// Create monthly tracking documents
  static Future<TrackingMigrationResult> _createMonthlyTracking({
    required bool dryRun,
  }) async {
    final result = TrackingMigrationResult();
    
    try {
      // Get all vendor posts grouped by vendor and month
      final postsSnapshot = await _firestore.collection(_postsCollection).get();
      final vendorMonthlyData = <String, Map<String, List<String>>>{};
      
      // Group posts by vendor and month
      for (final doc in postsSnapshot.docs) {
        final data = doc.data();
        final vendorId = data['vendorId'] as String?;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        
        if (vendorId != null) {
          final monthKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}';
          
          vendorMonthlyData.putIfAbsent(vendorId, () => {});
          vendorMonthlyData[vendorId]!.putIfAbsent(monthKey, () => []);
          vendorMonthlyData[vendorId]![monthKey]!.add(doc.id);
        }
      }
      
      debugPrint('📊 Found data for ${vendorMonthlyData.length} vendors');
      
      // Create tracking documents
      for (final vendorEntry in vendorMonthlyData.entries) {
        final vendorId = vendorEntry.key;
        final monthlyData = vendorEntry.value;
        
        for (final monthEntry in monthlyData.entries) {
          final monthKey = monthEntry.key;
          final postIds = monthEntry.value;
          
          try {
            if (dryRun) {
              result.created++;
            } else {
              await _createTrackingDocument(vendorId, monthKey, postIds);
              result.created++;
            }
          } catch (e) {
            result.errors.add('Error creating tracking for $vendorId/$monthKey: $e');
          }
        }
      }
      
    } catch (e) {
      result.errors.add('Tracking migration error: $e');
    }
    
    return result;
  }
  
  /// Create a single tracking document
  static Future<void> _createTrackingDocument(
    String vendorId,
    String monthKey,
    List<String> postIds,
  ) async {
    final trackingId = '${vendorId}_$monthKey';
    
    // Check if already exists
    final existing = await _firestore.collection(_trackingCollection).doc(trackingId).get();
    if (existing.exists) {
      return; // Skip if already exists
    }
    
    // Get post details to calculate counts
    int independentCount = 0;
    int marketCount = 0;
    DateTime? lastPostDate;
    
    for (final postId in postIds) {
      try {
        final postDoc = await _firestore.collection(_postsCollection).doc(postId).get();
        if (postDoc.exists) {
          final data = postDoc.data()!;
          final postType = data['postType'] as String? ?? 'independent';
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          
          if (postType == 'market') {
            marketCount++;
          } else {
            independentCount++;
          }
          
          if (lastPostDate == null || (createdAt != null && createdAt.isAfter(lastPostDate))) {
            lastPostDate = createdAt;
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error processing post $postId: $e');
      }
    }
    
    final trackingData = {
      'vendorId': vendorId,
      'yearMonth': monthKey,
      'posts': {
        'total': postIds.length,
        'independent': independentCount,
        'market': marketCount,
        'denied': 0,
      },
      'postIds': postIds,
      'lastPostDate': lastPostDate != null ? Timestamp.fromDate(lastPostDate) : Timestamp.now(),
      'subscriptionTier': 'free', // Default for migration
    };
    
    await _firestore.collection(_trackingCollection).doc(trackingId).set(trackingData);
    debugPrint('✅ Created tracking: $trackingId (${postIds.length} posts)');
  }
  
  /// Clean up deprecated data structures
  static Future<CleanupResult> _cleanupDeprecatedData() async {
    final result = CleanupResult();
    
    try {
      debugPrint('🧹 Starting cleanup of deprecated collections...');
      
      // Clean up old vendor permissions/applications if they exist
      final collections = ['vendor_permissions', 'vendor_applications', 'market_vendor_relationships'];
      
      for (final collectionName in collections) {
        try {
          final snapshot = await _firestore.collection(collectionName).limit(10).get();
          if (snapshot.docs.isNotEmpty) {
            debugPrint('📋 Found ${snapshot.docs.length} documents in $collectionName (showing first 10)');
            debugPrint('⚠️  Consider manually cleaning up $collectionName collection');
            result.cleanedUp++;
          }
        } catch (e) {
          // Collection might not exist - that's okay
          debugPrint('ℹ️  Collection $collectionName does not exist or is empty');
        }
      }
      
    } catch (e) {
      debugPrint('❌ Error during cleanup: $e');
    }
    
    return result;
  }
  
  /// Validate migration results
  static Future<ValidationResult> validateMigration() async {
    final result = ValidationResult();
    
    try {
      debugPrint('🔍 Validating migration results...');
      
      // Check all posts have required fields
      final postsSnapshot = await _firestore.collection(_postsCollection).get();
      int validPosts = 0;
      int invalidPosts = 0;
      
      for (final doc in postsSnapshot.docs) {
        final data = doc.data();
        
        if (data.containsKey('postType') && 
            data.containsKey('version') && 
            data['version'] == 2) {
          validPosts++;
        } else {
          invalidPosts++;
          result.issues.add('Post ${doc.id} missing required migration fields');
        }
      }
      
      result.validPosts = validPosts;
      result.invalidPosts = invalidPosts;
      
      // Check tracking documents
      final trackingSnapshot = await _firestore.collection(_trackingCollection).get();
      result.trackingDocs = trackingSnapshot.docs.length;
      
      // Validate tracking consistency
      final vendorPostCounts = <String, int>{};
      for (final doc in postsSnapshot.docs) {
        final data = doc.data();
        final vendorId = data['vendorId'] as String?;
        if (vendorId != null) {
          vendorPostCounts[vendorId] = (vendorPostCounts[vendorId] ?? 0) + 1;
        }
      }
      
      debugPrint('✅ Validation complete:');
      debugPrint('   - Valid posts: $validPosts');
      debugPrint('   - Invalid posts: $invalidPosts');
      debugPrint('   - Tracking docs: ${result.trackingDocs}');
      debugPrint('   - Issues found: ${result.issues.length}');
      
      result.success = invalidPosts == 0 && result.issues.isEmpty;
      
    } catch (e) {
      result.success = false;
      result.issues.add('Validation error: $e');
    }
    
    return result;
  }
  
  /// Rollback migration (emergency use only)
  static Future<void> rollbackMigration() async {
    debugPrint('🚨 EMERGENCY ROLLBACK: Reverting vendor-market migration...');
    
    try {
      // Remove new fields from vendor posts
      final postsSnapshot = await _firestore.collection(_postsCollection).get();
      
      const fieldsToRemove = [
        'postType', 'associatedMarketId', 'associatedMarketName', 'associatedMarketLogo',
        'approvalStatus', 'approvalRequestedAt', 'approvalDecidedAt', 'approvedBy',
        'approvalNote', 'approvalExpiresAt', 'monthlyPostNumber', 'countsTowardLimit',
        'version'
      ];
      
      int batchCount = 0;
      var batch = _firestore.batch();
      
      for (final doc in postsSnapshot.docs) {
        final updates = <String, dynamic>{};
        for (final field in fieldsToRemove) {
          updates[field] = FieldValue.delete();
        }
        
        if (updates.isNotEmpty) {
          batch.update(doc.reference, updates);
          batchCount++;
          
          if (batchCount >= 500) {
            await batch.commit();
            batch = _firestore.batch();
            batchCount = 0;
          }
        }
      }
      
      if (batchCount > 0) {
        await batch.commit();
      }
      
      // Delete approval queue
      final queueSnapshot = await _firestore.collection(_queueCollection).get();
      batch = _firestore.batch();
      batchCount = 0;
      
      for (final doc in queueSnapshot.docs) {
        batch.delete(doc.reference);
        batchCount++;
        
        if (batchCount >= 500) {
          await batch.commit();
          batch = _firestore.batch();
          batchCount = 0;
        }
      }
      
      if (batchCount > 0) {
        await batch.commit();
      }
      
      // Delete tracking documents
      final trackingSnapshot = await _firestore.collection(_trackingCollection).get();
      batch = _firestore.batch();
      batchCount = 0;
      
      for (final doc in trackingSnapshot.docs) {
        batch.delete(doc.reference);
        batchCount++;
        
        if (batchCount >= 500) {
          await batch.commit();
          batch = _firestore.batch();
          batchCount = 0;
        }
      }
      
      if (batchCount > 0) {
        await batch.commit();
      }
      
      debugPrint('✅ Rollback completed');
      
    } catch (e) {
      debugPrint('❌ Rollback failed: $e');
      rethrow;
    }
  }
}

/// Migration result classes
class MigrationResult {
  bool success = false;
  String? error;
  DateTime? completedAt;
  DataAnalysis? analysis;
  int postsProcessed = 0;
  int postsUpdated = 0;
  int trackingCreated = 0;
  int cleanupItems = 0;
  List<String> postsErrors = [];
  List<String> trackingErrors = [];
}

class DataAnalysis {
  int totalPosts = 0;
  int marketPosts = 0;
  int independentPosts = 0;
  int postsNeedingUpdate = 0;
  int uniqueVendors = 0;
  int monthsWithPosts = 0;
  int existingTrackingDocs = 0;
}

class PostMigrationResult {
  int processed = 0;
  int updated = 0;
  List<String> errors = [];
}

class TrackingMigrationResult {
  int created = 0;
  List<String> errors = [];
}

class CleanupResult {
  int cleanedUp = 0;
}

class ValidationResult {
  bool success = false;
  int validPosts = 0;
  int invalidPosts = 0;
  int trackingDocs = 0;
  List<String> issues = [];
}