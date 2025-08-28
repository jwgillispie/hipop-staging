import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../shared/services/user_profile_service.dart';
import '../../premium/services/subscription_service.dart';

/// Service for managing organizer monthly event tracking and limits
/// This enforces the critical business rule:
/// - Free tier: 1 event per month
/// - Premium tier: Unlimited events
class OrganizerMonthlyTrackingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _trackingCollection = 'organizer_monthly_tracking';
  static const int freeTierMonthlyLimit = 1; // CRITICAL: Only 1 event for free tier
  
  /// Get or create monthly tracking document for organizer
  static Future<OrganizerMonthlyTracking> getOrCreateMonthlyTracking(
    String organizerId, {
    DateTime? date,
  }) async {
    final targetDate = date ?? DateTime.now();
    final trackingId = _generateTrackingId(organizerId, targetDate);
    
    try {
      final doc = await _firestore
          .collection(_trackingCollection)
          .doc(trackingId)
          .get();
      
      if (doc.exists) {
        return OrganizerMonthlyTracking.fromFirestore(doc);
      }
      
      // Create new tracking document
      final userProfileService = UserProfileService();
      final organizer = await userProfileService.getUserProfile(organizerId);
      
      final newTracking = OrganizerMonthlyTracking(
        id: trackingId,
        organizerId: organizerId,
        yearMonth: '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}',
        eventsCreated: 0,
        eventIds: const [],
        lastEventDate: targetDate,
        subscriptionTier: organizer?.subscriptionStatus ?? 'free',
      );
      
      await _firestore
          .collection(_trackingCollection)
          .doc(trackingId)
          .set(newTracking.toFirestore());
      
      debugPrint('✅ Created new monthly tracking for organizer: $trackingId');
      return newTracking;
    } catch (e) {
      debugPrint('❌ Error getting/creating organizer monthly tracking: $e');
      rethrow;
    }
  }
  
  /// Increment event count for organizer
  static Future<void> incrementEventCount(
    String organizerId, {
    DateTime? date,
    String? eventId,
  }) async {
    final targetDate = date ?? DateTime.now();
    final trackingId = _generateTrackingId(organizerId, targetDate);
    
    try {
      final updates = <String, dynamic>{
        'eventsCreated': FieldValue.increment(1),
        'lastEventDate': Timestamp.fromDate(targetDate),
      };
      
      if (eventId != null) {
        updates['eventIds'] = FieldValue.arrayUnion([eventId]);
      }
      
      await _firestore
          .collection(_trackingCollection)
          .doc(trackingId)
          .set(updates, SetOptions(merge: true));
      
      debugPrint('✅ Incremented event count for organizer: $organizerId');
    } catch (e) {
      debugPrint('❌ Error incrementing event count: $e');
      rethrow;
    }
  }
  
  /// Decrement event count for organizer (used when events are deleted)
  static Future<void> decrementEventCount(
    String organizerId, {
    DateTime? date,
    String? eventId,
  }) async {
    final targetDate = date ?? DateTime.now();
    final trackingId = _generateTrackingId(organizerId, targetDate);
    
    try {
      final updates = <String, dynamic>{
        'eventsCreated': FieldValue.increment(-1),
      };
      
      if (eventId != null) {
        updates['eventIds'] = FieldValue.arrayRemove([eventId]);
      }
      
      await _firestore
          .collection(_trackingCollection)
          .doc(trackingId)
          .update(updates);
      
      debugPrint('✅ Decremented event count for organizer: $organizerId');
    } catch (e) {
      debugPrint('❌ Error decrementing event count: $e');
      rethrow;
    }
  }
  
  /// Check if organizer can create more events this month
  static Future<bool> canCreateEvent(String organizerId) async {
    try {
      // Check if user has premium subscription
      final userProfileService = UserProfileService();
      final hasPremium = await userProfileService.hasPremiumAccess(organizerId);
      if (hasPremium) {
        debugPrint('✅ Organizer $organizerId has premium - unlimited events');
        return true;
      }
      
      final tracking = await getOrCreateMonthlyTracking(organizerId);
      final currentCount = tracking.eventsCreated;
      
      debugPrint('📊 Organizer $organizerId monthly event usage: $currentCount/$freeTierMonthlyLimit');
      return currentCount < freeTierMonthlyLimit;
    } catch (e) {
      debugPrint('❌ Error checking event limit: $e');
      // Default to denying if check fails - critical for revenue protection
      return false;
    }
  }
  
  /// Get remaining events for free tier organizer
  static Future<int> getRemainingEvents(String organizerId) async {
    try {
      final userProfileService = UserProfileService();
      final hasPremium = await userProfileService.hasPremiumAccess(organizerId);
      if (hasPremium) return -1; // Unlimited for premium
      
      final tracking = await getOrCreateMonthlyTracking(organizerId);
      final remaining = freeTierMonthlyLimit - tracking.eventsCreated;
      
      return remaining > 0 ? remaining : 0;
    } catch (e) {
      debugPrint('❌ Error getting remaining events: $e');
      return 0;
    }
  }
  
  /// Get event usage summary for an organizer
  static Future<Map<String, dynamic>> getEventUsageSummary(String organizerId) async {
    try {
      final subscription = await SubscriptionService.getUserSubscription(organizerId);
      final tracking = await getOrCreateMonthlyTracking(organizerId);
      final remaining = await getRemainingEvents(organizerId);
      
      final isPremium = subscription?.isPremium ?? false;
      
      return {
        'events_used': tracking.eventsCreated,
        'events_limit': isPremium ? 'unlimited' : freeTierMonthlyLimit,
        'remaining_events': isPremium ? 'unlimited' : remaining,
        'is_premium': isPremium,
        'can_create_more': isPremium || tracking.eventsCreated < freeTierMonthlyLimit,
        'subscription_tier': tracking.subscriptionTier,
        'month': tracking.yearMonth,
        'last_event_date': tracking.lastEventDate.toIso8601String(),
      };
    } catch (e) {
      debugPrint('❌ Error getting event usage summary: $e');
      return {
        'events_used': 0,
        'events_limit': freeTierMonthlyLimit,
        'remaining_events': freeTierMonthlyLimit,
        'is_premium': false,
        'can_create_more': true,
        'error': e.toString(),
      };
    }
  }
  
  /// Get organizer's monthly tracking history
  static Future<List<OrganizerMonthlyTracking>> getTrackingHistory(
    String organizerId, {
    int monthsBack = 6,
  }) async {
    try {
      final now = DateTime.now();
      final trackingDocs = <OrganizerMonthlyTracking>[];
      
      for (int i = 0; i < monthsBack; i++) {
        final targetDate = DateTime(now.year, now.month - i, 1);
        final trackingId = _generateTrackingId(organizerId, targetDate);
        
        final doc = await _firestore
            .collection(_trackingCollection)
            .doc(trackingId)
            .get();
        
        if (doc.exists) {
          trackingDocs.add(OrganizerMonthlyTracking.fromFirestore(doc));
        }
      }
      
      // Sort by year-month descending (most recent first)
      trackingDocs.sort((a, b) => b.yearMonth.compareTo(a.yearMonth));
      
      return trackingDocs;
    } catch (e) {
      debugPrint('❌ Error getting tracking history: $e');
      return [];
    }
  }
  
  /// Get tracking stats for multiple organizers (admin function)
  static Future<List<OrganizerMonthlyTracking>> getTrackingForMonth(
    DateTime month, {
    String? subscriptionTier,
  }) async {
    try {
      final yearMonth = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      
      Query query = _firestore
          .collection(_trackingCollection)
          .where('yearMonth', isEqualTo: yearMonth);
      
      if (subscriptionTier != null) {
        query = query.where('subscriptionTier', isEqualTo: subscriptionTier);
      }
      
      final snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => OrganizerMonthlyTracking.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting month tracking: $e');
      return [];
    }
  }
  
  /// Reset monthly tracking (admin function - use carefully)
  static Future<void> resetOrganizerTracking(String organizerId, DateTime month) async {
    try {
      final trackingId = _generateTrackingId(organizerId, month);
      
      await _firestore
          .collection(_trackingCollection)
          .doc(trackingId)
          .update({
            'eventsCreated': 0,
            'eventIds': [],
          });
      
      debugPrint('✅ Reset tracking for organizer $organizerId for month $trackingId');
    } catch (e) {
      debugPrint('❌ Error resetting organizer tracking: $e');
      rethrow;
    }
  }
  
  /// Update subscription tier for organizer tracking
  static Future<void> updateSubscriptionTier(
    String organizerId,
    String newTier, {
    DateTime? date,
  }) async {
    final targetDate = date ?? DateTime.now();
    final trackingId = _generateTrackingId(organizerId, targetDate);
    
    try {
      await _firestore
          .collection(_trackingCollection)
          .doc(trackingId)
          .update({'subscriptionTier': newTier});
      
      debugPrint('✅ Updated subscription tier for organizer $organizerId to $newTier');
    } catch (e) {
      debugPrint('❌ Error updating subscription tier: $e');
      rethrow;
    }
  }
  
  /// Migrate existing events to tracking system
  static Future<void> migrateExistingEvents(String organizerId) async {
    try {
      debugPrint('🔄 Migrating existing events for organizer: $organizerId');
      
      // Get all events for this organizer
      final eventsSnapshot = await _firestore
          .collection('events')
          .where('organizerId', isEqualTo: organizerId)
          .get();
      
      final eventsByMonth = <String, List<Map<String, dynamic>>>{};
      
      // Group events by month
      for (final eventDoc in eventsSnapshot.docs) {
        final eventData = eventDoc.data();
        final createdAt = (eventData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final monthKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}';
        
        eventsByMonth.putIfAbsent(monthKey, () => []);
        eventsByMonth[monthKey]!.add({
          'id': eventDoc.id,
          'createdAt': createdAt,
        });
      }
      
      // Create tracking documents for each month
      for (final entry in eventsByMonth.entries) {
        final monthKey = entry.key;
        final events = entry.value;
        
        final trackingId = '${organizerId}_$monthKey';
        
        final trackingData = {
          'organizerId': organizerId,
          'yearMonth': monthKey,
          'eventsCreated': events.length,
          'eventIds': events.map((e) => e['id']).toList(),
          'lastEventDate': Timestamp.fromDate(events.last['createdAt']),
          'subscriptionTier': 'free', // Default for migration
        };
        
        await _firestore
            .collection(_trackingCollection)
            .doc(trackingId)
            .set(trackingData, SetOptions(merge: true));
        
        debugPrint('✅ Created tracking for $monthKey: ${events.length} events');
      }
      
      debugPrint('🎉 Migration completed for organizer: $organizerId');
    } catch (e) {
      debugPrint('❌ Error migrating events: $e');
      rethrow;
    }
  }
  
  /// Generate tracking document ID
  static String _generateTrackingId(String organizerId, DateTime date) {
    return '${organizerId}_${date.year}_${date.month.toString().padLeft(2, '0')}';
  }
  
  /// Get usage statistics for analytics
  static Future<Map<String, dynamic>> getUsageStats({DateTime? month}) async {
    try {
      final targetMonth = month ?? DateTime.now();
      final yearMonth = '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}';
      
      final snapshot = await _firestore
          .collection(_trackingCollection)
          .where('yearMonth', isEqualTo: yearMonth)
          .get();
      
      int totalOrganizers = 0;
      int totalEvents = 0;
      int freeOrganizers = 0;
      int premiumOrganizers = 0;
      int atLimitOrganizers = 0;
      int potentialRevenueLoss = 0;
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        totalOrganizers++;
        
        final eventCount = data['eventsCreated'] as int? ?? 0;
        totalEvents += eventCount;
        
        final tier = data['subscriptionTier'] as String? ?? 'free';
        if (tier == 'free') {
          freeOrganizers++;
          if (eventCount >= freeTierMonthlyLimit) {
            atLimitOrganizers++;
            // Calculate potential revenue loss (events beyond limit)
            if (eventCount > freeTierMonthlyLimit) {
              potentialRevenueLoss += (eventCount - freeTierMonthlyLimit);
            }
          }
        } else {
          premiumOrganizers++;
        }
      }
      
      return {
        'month': yearMonth,
        'totalOrganizers': totalOrganizers,
        'totalEvents': totalEvents,
        'freeOrganizers': freeOrganizers,
        'premiumOrganizers': premiumOrganizers,
        'atLimitOrganizers': atLimitOrganizers,
        'potentialRevenueLoss': potentialRevenueLoss,
        'averageEventsPerOrganizer': totalOrganizers > 0 ? totalEvents / totalOrganizers : 0,
        'conversionOpportunities': atLimitOrganizers, // Organizers at limit who might upgrade
      };
    } catch (e) {
      debugPrint('❌ Error getting usage stats: $e');
      return {};
    }
  }
}

/// Model class for organizer monthly tracking
class OrganizerMonthlyTracking {
  final String id; // Format: organizerId_YYYY_MM
  final String organizerId;
  final String yearMonth;
  final int eventsCreated;
  final List<String> eventIds;
  final DateTime lastEventDate;
  final String subscriptionTier;
  
  const OrganizerMonthlyTracking({
    required this.id,
    required this.organizerId,
    required this.yearMonth,
    required this.eventsCreated,
    required this.eventIds,
    required this.lastEventDate,
    required this.subscriptionTier,
  });
  
  factory OrganizerMonthlyTracking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return OrganizerMonthlyTracking(
      id: doc.id,
      organizerId: data['organizerId'] ?? '',
      yearMonth: data['yearMonth'] ?? '',
      eventsCreated: data['eventsCreated'] ?? 0,
      eventIds: List<String>.from(data['eventIds'] ?? []),
      lastEventDate: (data['lastEventDate'] as Timestamp).toDate(),
      subscriptionTier: data['subscriptionTier'] ?? 'free',
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'organizerId': organizerId,
      'yearMonth': yearMonth,
      'eventsCreated': eventsCreated,
      'eventIds': eventIds,
      'lastEventDate': Timestamp.fromDate(lastEventDate),
      'subscriptionTier': subscriptionTier,
    };
  }
  
  /// Check if organizer has reached the free tier limit
  bool get isAtFreeLimit => subscriptionTier == 'free' && 
      eventsCreated >= OrganizerMonthlyTrackingService.freeTierMonthlyLimit;
  
  /// Get remaining events for free tier
  int get remainingFreeEvents {
    if (subscriptionTier != 'free') return -1; // Unlimited
    final remaining = OrganizerMonthlyTrackingService.freeTierMonthlyLimit - eventsCreated;
    return remaining > 0 ? remaining : 0;
  }
}

/// Exception class for tracking-related errors
class OrganizerTrackingException implements Exception {
  final String message;
  OrganizerTrackingException(this.message);
  @override
  String toString() => message;
}