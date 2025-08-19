import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/approval_request.dart';
import '../../shared/services/real_time_analytics_service.dart';

/// Service for managing vendor approval requests - keeping it simple like existing services
class MarketApprovalService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _queueCollection = 'market_approval_queue';
  static const String _postsCollection = 'vendor_posts';
  static const String _trackingCollection = 'vendor_monthly_tracking';

  /// Get pending approvals for market organizer
  /// NOTE: Market posts are now auto-approved, so this returns empty
  static Stream<List<ApprovalRequest>> getPendingApprovals(String organizerId) {
    // Market posts are auto-approved - no pending requests exist
    return Stream.value(<ApprovalRequest>[]);
  }

  /// Approve a single vendor post
  static Future<void> approveVendorPost({
    required String queueId,
    required String postId,
    required String approverId,
    String? organizerNotes,
  }) async {
    final approvalStartTime = DateTime.now();
    
    try {
      // Get post data for analytics before approval
      final postDoc = await _firestore.collection(_postsCollection).doc(postId).get();
      final postData = postDoc.data();
      final vendorId = postData?['vendorId'];
      final marketId = postData?['marketId'];
      final requestedAt = (postData?['approvalRequestedAt'] as Timestamp?)?.toDate();
      
      await _firestore.runTransaction((transaction) async {
        final now = FieldValue.serverTimestamp();
        
        // Update vendor post
        final updateData = {
          'approvalStatus': 'approved',
          'approvalDecidedAt': now,
          'approvedBy': approverId,
          'status': 'active',
          'updatedAt': now,
        };
        
        if (organizerNotes != null && organizerNotes.isNotEmpty) {
          updateData['organizerNotes'] = organizerNotes;
        }
        
        transaction.update(_firestore.collection(_postsCollection).doc(postId), updateData);
        
        // Update queue
        transaction.update(_firestore.collection(_queueCollection).doc(queueId), {
          'status': 'approved',
          'decidedAt': now,
        });
      });
      
      // Track approval analytics
      await _trackApprovalDecision(
        approverId: approverId,
        vendorId: vendorId,
        marketId: marketId,
        postId: postId,
        decision: 'approved',
        requestedAt: requestedAt,
        decidedAt: approvalStartTime,
        hasNotes: organizerNotes?.isNotEmpty ?? false,
      );
      
      debugPrint('✅ Approved vendor post: $postId');
    } catch (e) {
      debugPrint('❌ Error approving vendor post: $e');
      rethrow;
    }
  }

  /// Deny a single vendor post
  static Future<void> denyVendorPost({
    required String queueId,
    required String postId,
    required String approverId,
    required String organizerNotes,
  }) async {
    final approvalStartTime = DateTime.now();
    
    try {
      // Get post data for analytics before denial
      final postDoc = await _firestore.collection(_postsCollection).doc(postId).get();
      final postData = postDoc.data();
      final vendorId = postData?['vendorId'];
      final marketId = postData?['marketId'];
      final requestedAt = (postData?['approvalRequestedAt'] as Timestamp?)?.toDate();
      
      await _firestore.runTransaction((transaction) async {
        final now = FieldValue.serverTimestamp();
        
        // Update vendor post
        transaction.update(_firestore.collection(_postsCollection).doc(postId), {
          'approvalStatus': 'denied',
          'approvalDecidedAt': now,
          'approvedBy': approverId,
          'organizerNotes': organizerNotes,
          'status': 'denied',
          'updatedAt': now,
        });
        
        // Update queue
        transaction.update(_firestore.collection(_queueCollection).doc(queueId), {
          'status': 'denied',
          'decidedAt': now,
          'denialReason': organizerNotes,
        });
        
        if (vendorId != null) {
          final now = DateTime.now();
          final trackingId = '${vendorId}_${now.year}_${now.month}';
          
          // Refund monthly count since denied
          transaction.update(_firestore.collection(_trackingCollection).doc(trackingId), {
            'posts.total': FieldValue.increment(-1),
            'posts.denied': FieldValue.increment(1),
          });
        }
      });
      
      // Track denial analytics
      await _trackApprovalDecision(
        approverId: approverId,
        vendorId: vendorId,
        marketId: marketId,
        postId: postId,
        decision: 'denied',
        requestedAt: requestedAt,
        decidedAt: approvalStartTime,
        hasNotes: true,
        denialReason: organizerNotes,
      );
      
      debugPrint('✅ Denied vendor post: $postId');
    } catch (e) {
      debugPrint('❌ Error denying vendor post: $e');
      rethrow;
    }
  }

  /// BULK OPERATIONS - approve multiple posts at once
  static Future<List<String>> bulkApproveVendorPosts({
    required List<String> queueIds,
    required List<String> postIds,
    required String approverId,
    String? organizerNotes,
  }) async {
    final List<String> successfullyApproved = [];
    
    try {
      // Process in batches of 500 (Firestore limit)
      for (int i = 0; i < queueIds.length; i += 500) {
        final batch = _firestore.batch();
        final batchQueueIds = queueIds.skip(i).take(500).toList();
        final batchPostIds = postIds.skip(i).take(500).toList();
        
        for (int j = 0; j < batchQueueIds.length; j++) {
          final queueId = batchQueueIds[j];
          final postId = batchPostIds[j];
          final now = FieldValue.serverTimestamp();
          
          // Update vendor post
          final updateData = {
            'approvalStatus': 'approved',
            'approvalDecidedAt': now,
            'approvedBy': approverId,
            'status': 'active',
            'updatedAt': now,
          };
          
          if (organizerNotes != null && organizerNotes.isNotEmpty) {
            updateData['organizerNotes'] = organizerNotes;
          }
          
          batch.update(_firestore.collection(_postsCollection).doc(postId), updateData);
          
          // Update queue
          batch.update(_firestore.collection(_queueCollection).doc(queueId), {
            'status': 'approved',
            'decidedAt': now,
          });
          
          successfullyApproved.add(postId);
        }
        
        await batch.commit();
        debugPrint('✅ Bulk approved batch ${i ~/ 500 + 1}: ${batchPostIds.length} posts');
      }
      
      // Track bulk approval analytics
      await _trackBulkApprovalDecision(
        approverId: approverId,
        decision: 'approved',
        postCount: successfullyApproved.length,
        hasNotes: organizerNotes?.isNotEmpty ?? false,
      );
      
      debugPrint('✅ Bulk approved total: ${successfullyApproved.length} posts');
      return successfullyApproved;
    } catch (e) {
      debugPrint('❌ Error in bulk approval: $e');
      rethrow;
    }
  }

  /// BULK OPERATIONS - deny multiple posts at once
  static Future<List<String>> bulkDenyVendorPosts({
    required List<String> queueIds,
    required List<String> postIds,
    required String approverId,
    required String organizerNotes,
  }) async {
    final List<String> successfullyDenied = [];
    
    try {
      // Process in batches of 500 (Firestore limit)
      for (int i = 0; i < queueIds.length; i += 500) {
        final batch = _firestore.batch();
        final batchQueueIds = queueIds.skip(i).take(500).toList();
        final batchPostIds = postIds.skip(i).take(500).toList();
        
        for (int j = 0; j < batchQueueIds.length; j++) {
          final queueId = batchQueueIds[j];
          final postId = batchPostIds[j];
          final now = FieldValue.serverTimestamp();
          
          // Update vendor post
          batch.update(_firestore.collection(_postsCollection).doc(postId), {
            'approvalStatus': 'denied',
            'approvalDecidedAt': now,
            'approvedBy': approverId,
            'organizerNotes': organizerNotes,
            'status': 'denied',
            'updatedAt': now,
          });
          
          // Update queue
          batch.update(_firestore.collection(_queueCollection).doc(queueId), {
            'status': 'denied',
            'decidedAt': now,
            'denialReason': organizerNotes,
          });
          
          successfullyDenied.add(postId);
        }
        
        await batch.commit();
        debugPrint('✅ Bulk denied batch ${i ~/ 500 + 1}: ${batchPostIds.length} posts');
      }
      
      // Update monthly tracking for denied posts (separate operation)
      await _updateTrackingForDeniedPosts(successfullyDenied);
      
      // Track bulk denial analytics
      await _trackBulkApprovalDecision(
        approverId: approverId,
        decision: 'denied',
        postCount: successfullyDenied.length,
        hasNotes: true,
      );
      
      debugPrint('✅ Bulk denied total: ${successfullyDenied.length} posts');
      return successfullyDenied;
    } catch (e) {
      debugPrint('❌ Error in bulk denial: $e');
      rethrow;
    }
  }

  /// Get approved vendors for a market on a specific date
  static Stream<List<Map<String, dynamic>>> getApprovedVendorsForMarket(
    String marketId, 
    DateTime date,
  ) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    return _firestore
        .collection(_postsCollection)
        .where('associatedMarketId', isEqualTo: marketId)
        .where('isActive', isEqualTo: true) // Changed: All active posts are auto-approved
        .where('popUpStartDateTime', isGreaterThanOrEqualTo: startOfDay)
        .where('popUpStartDateTime', isLessThan: endOfDay)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
              'id': doc.id,
              ...doc.data(),
            })
            .toList());
  }

  /// Helper method to update tracking for denied posts
  static Future<void> _updateTrackingForDeniedPosts(List<String> postIds) async {
    try {
      final now = DateTime.now();
      final trackingUpdates = <String, Map<String, dynamic>>{};
      
      // Get vendor IDs for all denied posts
      for (final postId in postIds) {
        final postDoc = await _firestore.collection(_postsCollection).doc(postId).get();
        final vendorId = postDoc.data()?['vendorId'];
        
        if (vendorId != null) {
          final trackingId = '${vendorId}_${now.year}_${now.month}';
          trackingUpdates[trackingId] = {
            'posts.total': FieldValue.increment(-1),
            'posts.denied': FieldValue.increment(1),
          };
        }
      }
      
      // Apply tracking updates in batches
      final trackingIds = trackingUpdates.keys.toList();
      for (int i = 0; i < trackingIds.length; i += 500) {
        final batch = _firestore.batch();
        final batchIds = trackingIds.skip(i).take(500);
        
        for (final trackingId in batchIds) {
          batch.update(
            _firestore.collection(_trackingCollection).doc(trackingId), 
            trackingUpdates[trackingId]!,
          );
        }
        
        await batch.commit();
      }
      
      debugPrint('✅ Updated tracking for ${postIds.length} denied posts');
    } catch (e) {
      debugPrint('❌ Error updating tracking for denied posts: $e');
      // Don't rethrow - this is a secondary operation
    }
  }

  // Analytics tracking methods
  
  static Future<void> _trackApprovalDecision({
    required String approverId,
    String? vendorId,
    String? marketId,
    required String postId,
    required String decision,
    DateTime? requestedAt,
    required DateTime decidedAt,
    required bool hasNotes,
    String? denialReason,
  }) async {
    try {
      // Calculate time to decision if we have the request timestamp
      Duration? timeToDecision;
      if (requestedAt != null) {
        timeToDecision = decidedAt.difference(requestedAt);
      }
      
      await RealTimeAnalyticsService.trackEvent('market_post_approval_decision', {
        'approverId': approverId,
        'vendorId': vendorId,
        'marketId': marketId,
        'postId': postId,
        'decision': decision,
        'requestedAt': requestedAt?.toIso8601String(),
        'decidedAt': decidedAt.toIso8601String(),
        'timeToDecisionMinutes': timeToDecision?.inMinutes,
        'timeToDecisionHours': timeToDecision?.inHours,
        'hasOrganizerNotes': hasNotes,
        'denialReason': decision == 'denied' ? denialReason : null,
        'isWeekend': decidedAt.weekday >= 6,
        'hourOfDay': decidedAt.hour,
      });
    } catch (e) {
      debugPrint('❌ Error tracking approval decision: $e');
      // Don't rethrow - analytics shouldn't break the main flow
    }
  }
  
  static Future<void> _trackBulkApprovalDecision({
    required String approverId,
    required String decision,
    required int postCount,
    required bool hasNotes,
  }) async {
    try {
      await RealTimeAnalyticsService.trackEvent('market_bulk_approval_decision', {
        'approverId': approverId,
        'decision': decision,
        'postCount': postCount,
        'hasOrganizerNotes': hasNotes,
        'decidedAt': DateTime.now().toIso8601String(),
        'isWeekend': DateTime.now().weekday >= 6,
        'hourOfDay': DateTime.now().hour,
      });
    } catch (e) {
      debugPrint('❌ Error tracking bulk approval: $e');
      // Don't rethrow - analytics shouldn't break the main flow
    }
  }
}