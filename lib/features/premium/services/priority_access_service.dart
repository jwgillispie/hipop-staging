import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'subscription_service.dart';
import '../../shopper/services/shopper_notification_service.dart';

/// Priority access types
enum AccessType {
  earlyAnnouncement,
  reservedSpot,
  vipAccess,
  exclusiveEvent,
  limitedQuantity,
}

/// Reservation status
enum ReservationStatus {
  pending,
  confirmed,
  cancelled,
  expired,
  attended,
}

/// Priority access service for premium shoppers
/// Provides early access to popular pop-up announcements and event reservations
class PriorityAccessService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _priorityAccessCollection = 
      _firestore.collection('priority_access');
  static final CollectionReference _eventReservationsCollection = 
      _firestore.collection('event_reservations');

  /// Create priority access for a vendor post/event (called when vendor creates post)
  static Future<void> createPriorityAccess({
    required String postId,
    required String vendorId,
    required String vendorName,
    required String title,
    required String description,
    required DateTime eventDateTime,
    required String location,
    AccessType accessType = AccessType.earlyAnnouncement,
    int? maxReservations,
    Duration? earlyAccessDuration,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final priorityAccessDoc = {
        'postId': postId,
        'vendorId': vendorId,
        'vendorName': vendorName,
        'title': title,
        'description': description,
        'eventDateTime': Timestamp.fromDate(eventDateTime),
        'location': location,
        'accessType': accessType.name,
        'maxReservations': maxReservations,
        'currentReservations': 0,
        'isActive': true,
        'metadata': metadata ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'earlyAccessUntil': earlyAccessDuration != null
            ? Timestamp.fromDate(DateTime.now().add(earlyAccessDuration))
            : null,
      };

      final docRef = await _priorityAccessCollection.add(priorityAccessDoc);

      // Notify premium shoppers who follow this vendor
      await _notifyPremiumFollowers(
        vendorId: vendorId,
        vendorName: vendorName,
        accessType: accessType,
        title: title,
        eventDateTime: eventDateTime,
        location: location,
        accessId: docRef.id,
      );

      debugPrint('✅ Priority access created for post: $postId');
    } catch (e) {
      debugPrint('❌ Error creating priority access: $e');
    }
  }

  /// Get available priority access opportunities for a shopper
  static Future<List<Map<String, dynamic>>> getAvailableAccess({
    required String shopperId,
    String? location,
    int limit = 20,
  }) async {
    try {
      final hasFeature = await SubscriptionService.hasFeature(
        shopperId,
        'vendor_following_system',
      );

      if (!hasFeature) {
        throw Exception('Priority access is a premium feature');
      }

      // Get followed vendors for personalized access
      final followsSnapshot = await _firestore
          .collection('vendor_follows')
          .where('shopperId', isEqualTo: shopperId)
          .where('isActive', isEqualTo: true)
          .get();

      final followedVendorIds = followsSnapshot.docs
          .map((doc) => doc.data()['vendorId'] as String)
          .toList();

      if (followedVendorIds.isEmpty) {
        return _getGeneralPriorityAccess(location: location, limit: limit);
      }

      // Get priority access for followed vendors
      Query query = _priorityAccessCollection
          .where('isActive', isEqualTo: true)
          .where('vendorId', whereIn: followedVendorIds.take(10).toList()) // Firestore limit
          .orderBy('createdAt', descending: true);

      final snapshot = await query.limit(limit).get();
      final results = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Check if user already has reservation
        final hasReservation = await _hasExistingReservation(shopperId, doc.id);
        
        results.add({
          'accessId': doc.id,
          ...data,
          'hasReservation': hasReservation,
          'canReserve': _canMakeReservation(data, hasReservation),
        });
      }

      return results;
    } catch (e) {
      debugPrint('❌ Error getting available access: $e');
      rethrow;
    }
  }

  /// Reserve a spot for priority access
  static Future<String> reserveSpot({
    required String shopperId,
    required String accessId,
    Map<String, dynamic>? reservationData,
  }) async {
    try {
      final hasFeature = await SubscriptionService.hasFeature(
        shopperId,
        'vendor_following_system',
      );

      if (!hasFeature) {
        throw Exception('Priority access is a premium feature');
      }

      // Check if access is still available
      final accessDoc = await _priorityAccessCollection.doc(accessId).get();
      if (!accessDoc.exists) {
        throw Exception('Priority access not found');
      }

      final accessData = accessDoc.data() as Map<String, dynamic>;
      
      if (!accessData['isActive']) {
        throw Exception('Priority access is no longer available');
      }

      // Check if user already has reservation
      final hasReservation = await _hasExistingReservation(shopperId, accessId);
      if (hasReservation) {
        throw Exception('You already have a reservation for this event');
      }

      // Check capacity limits
      final maxReservations = accessData['maxReservations'] as int?;
      final currentReservations = accessData['currentReservations'] as int;
      
      if (maxReservations != null && currentReservations >= maxReservations) {
        throw Exception('This event is fully booked');
      }

      // Create reservation
      final reservation = {
        'shopperId': shopperId,
        'accessId': accessId,
        'vendorId': accessData['vendorId'],
        'vendorName': accessData['vendorName'],
        'eventTitle': accessData['title'],
        'eventDateTime': accessData['eventDateTime'],
        'location': accessData['location'],
        'status': ReservationStatus.confirmed.name,
        'reservationData': reservationData ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'confirmationCode': _generateConfirmationCode(),
      };

      final reservationRef = await _eventReservationsCollection.add(reservation);

      // Update reservation count
      await _priorityAccessCollection.doc(accessId).update({
        'currentReservations': FieldValue.increment(1),
      });

      // Send confirmation notification
      await _sendReservationConfirmation(shopperId, reservation);

      debugPrint('✅ Spot reserved: ${reservationRef.id}');
      return reservationRef.id;
    } catch (e) {
      debugPrint('❌ Error reserving spot: $e');
      rethrow;
    }
  }

  /// Get user's reservations
  static Future<List<Map<String, dynamic>>> getUserReservations({
    required String shopperId,
    bool includeExpired = false,
  }) async {
    try {
      final hasFeature = await SubscriptionService.hasFeature(
        shopperId,
        'vendor_following_system',
      );

      if (!hasFeature) {
        return [];
      }

      Query query = _eventReservationsCollection
          .where('shopperId', isEqualTo: shopperId);

      if (!includeExpired) {
        query = query.where('status', whereNotIn: [
          ReservationStatus.expired.name,
          ReservationStatus.cancelled.name,
        ]);
      }

      final snapshot = await query
          .orderBy('eventDateTime', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'reservationId': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting user reservations: $e');
      return [];
    }
  }

  /// Cancel a reservation
  static Future<void> cancelReservation({
    required String shopperId,
    required String reservationId,
  }) async {
    try {
      final reservationDoc = await _eventReservationsCollection.doc(reservationId).get();
      if (!reservationDoc.exists) {
        throw Exception('Reservation not found');
      }

      final reservationData = reservationDoc.data() as Map<String, dynamic>;
      
      // Verify ownership
      if (reservationData['shopperId'] != shopperId) {
        throw Exception('You can only cancel your own reservations');
      }

      // Check if cancellation is allowed (e.g., not too close to event time)
      final eventDateTime = (reservationData['eventDateTime'] as Timestamp).toDate();
      final hoursUntilEvent = eventDateTime.difference(DateTime.now()).inHours;
      
      if (hoursUntilEvent < 2) {
        throw Exception('Cannot cancel reservation less than 2 hours before the event');
      }

      // Update reservation status
      await _eventReservationsCollection.doc(reservationId).update({
        'status': ReservationStatus.cancelled.name,
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // Decrease reservation count
      final accessId = reservationData['accessId'] as String;
      await _priorityAccessCollection.doc(accessId).update({
        'currentReservations': FieldValue.increment(-1),
      });

      // Notify vendor of cancellation
      await _notifyVendorOfCancellation(reservationData);

      debugPrint('✅ Reservation cancelled: $reservationId');
    } catch (e) {
      debugPrint('❌ Error cancelling reservation: $e');
      rethrow;
    }
  }

  /// Mark attendance for a reservation (vendor or system can call this)
  static Future<void> markAttendance({
    required String reservationId,
    required bool attended,
  }) async {
    try {
      final status = attended ? ReservationStatus.attended.name : ReservationStatus.expired.name;
      
      await _eventReservationsCollection.doc(reservationId).update({
        'status': status,
        'attendanceMarkedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Attendance marked for reservation: $reservationId (attended: $attended)');
    } catch (e) {
      debugPrint('❌ Error marking attendance: $e');
      rethrow;
    }
  }

  /// Get priority access analytics for vendors
  static Future<Map<String, dynamic>> getVendorAccessAnalytics(String vendorId) async {
    try {
      final accessSnapshot = await _priorityAccessCollection
          .where('vendorId', isEqualTo: vendorId)
          .get();

      final reservationsSnapshot = await _eventReservationsCollection
          .where('vendorId', isEqualTo: vendorId)
          .get();

      final stats = {
        'totalAccessOffers': accessSnapshot.docs.length,
        'totalReservations': reservationsSnapshot.docs.length,
        'attendanceRate': 0.0,
        'cancellationRate': 0.0,
        'averageReservationsPerEvent': 0.0,
        'byAccessType': <String, int>{},
        'byStatus': <String, int>{},
      };

      // Calculate metrics
      final reservations = reservationsSnapshot.docs.map((doc) => doc.data()).toList();
      
      if (reservations.isNotEmpty) {
        final attended = reservations.where((r) => (r as Map<String, dynamic>)['status'] == ReservationStatus.attended.name).length;
        final cancelled = reservations.where((r) => (r as Map<String, dynamic>)['status'] == ReservationStatus.cancelled.name).length;
        
        stats['attendanceRate'] = attended / reservations.length;
        stats['cancellationRate'] = cancelled / reservations.length;
        stats['averageReservationsPerEvent'] = reservations.length / accessSnapshot.docs.length;

        // Count by status
        for (final reservation in reservations) {
          final reservationMap = reservation as Map<String, dynamic>;
          final status = reservationMap['status'] as String;
          final byStatus = stats['byStatus'] as Map<String, int>;
          byStatus[status] = (byStatus[status] ?? 0) + 1;
        }
      }

      // Count by access type
      for (final doc in accessSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final accessType = data['accessType'] as String;
        final byAccessType = stats['byAccessType'] as Map<String, int>;
        byAccessType[accessType] = (byAccessType[accessType] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      debugPrint('❌ Error getting vendor access analytics: $e');
      return {
        'totalAccessOffers': 0,
        'totalReservations': 0,
        'attendanceRate': 0.0,
        'cancellationRate': 0.0,
        'averageReservationsPerEvent': 0.0,
        'byAccessType': <String, int>{},
        'byStatus': <String, int>{},
      };
    }
  }

  /// Helper methods

  static Future<List<Map<String, dynamic>>> _getGeneralPriorityAccess({
    String? location,
    int limit = 20,
  }) async {
    Query query = _priorityAccessCollection
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true);

    if (location != null && location.isNotEmpty) {
      query = query.where('location', isGreaterThanOrEqualTo: location)
             .where('location', isLessThan: location + '\uf8ff');
    }

    final snapshot = await query.limit(limit).get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'accessId': doc.id,
        ...data,
        'hasReservation': false,
        'canReserve': _canMakeReservation(data, false),
      };
    }).toList();
  }

  static Future<bool> _hasExistingReservation(String shopperId, String accessId) async {
    final reservationQuery = await _eventReservationsCollection
        .where('shopperId', isEqualTo: shopperId)
        .where('accessId', isEqualTo: accessId)
        .where('status', whereNotIn: [
          ReservationStatus.cancelled.name,
          ReservationStatus.expired.name,
        ])
        .get();

    return reservationQuery.docs.isNotEmpty;
  }

  static bool _canMakeReservation(Map<String, dynamic> accessData, bool hasReservation) {
    if (hasReservation) return false;
    if (!accessData['isActive']) return false;

    final maxReservations = accessData['maxReservations'] as int?;
    if (maxReservations == null) return true;

    final currentReservations = accessData['currentReservations'] as int;
    return currentReservations < maxReservations;
  }

  static Future<void> _notifyPremiumFollowers({
    required String vendorId,
    required String vendorName,
    required AccessType accessType,
    required String title,
    required DateTime eventDateTime,
    required String location,
    required String accessId,
  }) async {
    try {
      // Get premium followers of this vendor
      final followsSnapshot = await _firestore
          .collection('vendor_follows')
          .where('vendorId', isEqualTo: vendorId)
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in followsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final shopperId = data['shopperId'] as String;

        // Check if user has premium
        final hasFeature = await SubscriptionService.hasFeature(
          shopperId,
          'vendor_following_system',
        );

        if (hasFeature) {
          await ShopperNotificationService.createVendorPopupNotification(
            vendorId: vendorId,
            vendorName: vendorName,
            postId: accessId,
            location: location,
            popupDateTime: eventDateTime,
            description: 'Priority access available: $title',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error notifying premium followers: $e');
    }
  }

  static String _generateConfirmationCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    
    return List.generate(6, (index) => 
      chars[(random + index) % chars.length]
    ).join();
  }

  static Future<void> _sendReservationConfirmation(
    String shopperId,
    Map<String, dynamic> reservation,
  ) async {
    // This would integrate with push notification service
    debugPrint('📧 Reservation confirmation sent to shopper: $shopperId');
  }

  static Future<void> _notifyVendorOfCancellation(Map<String, dynamic> reservationData) async {
    // This would notify the vendor of the cancellation
    debugPrint('📧 Vendor notified of cancellation for: ${reservationData['eventTitle']}');
  }

  /// Clean up expired access and reservations
  static Future<void> cleanupExpiredAccess() async {
    try {
      final now = DateTime.now();
      
      // Mark expired priority access as inactive
      final expiredAccessQuery = await _priorityAccessCollection
          .where('isActive', isEqualTo: true)
          .where('eventDateTime', isLessThan: Timestamp.fromDate(now.subtract(const Duration(hours: 2))))
          .get();

      final batch = _firestore.batch();
      
      for (final doc in expiredAccessQuery.docs) {
        batch.update(doc.reference, {'isActive': false});
      }

      // Mark expired reservations
      final expiredReservationsQuery = await _eventReservationsCollection
          .where('status', isEqualTo: ReservationStatus.confirmed.name)
          .where('eventDateTime', isLessThan: Timestamp.fromDate(now.subtract(const Duration(hours: 1))))
          .get();

      for (final doc in expiredReservationsQuery.docs) {
        batch.update(doc.reference, {
          'status': ReservationStatus.expired.name,
          'expiredAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('✅ Cleaned up expired access and reservations');
    } catch (e) {
      debugPrint('❌ Error cleaning up expired access: $e');
    }
  }
}