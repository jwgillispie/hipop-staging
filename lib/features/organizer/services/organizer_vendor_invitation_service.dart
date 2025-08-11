import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class OrganizerVendorInvitationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send invitation to vendor for specific market
  static Future<String> sendInvitationToVendor(
    String organizerId,
    String vendorId,
    String marketId, {
    String? customMessage,
    String? organizerName,
  }) async {
    try {
      debugPrint('📧 Sending invitation from $organizerId to vendor $vendorId for market $marketId');

      final invitation = {
        'organizerId': organizerId,
        'vendorId': vendorId,
        'marketId': marketId,
        'status': 'pending', // pending, accepted, declined, expired
        'customMessage': customMessage,
        'organizerName': organizerName,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 14)) // 2 week expiration
        ),
      };

      final docRef = await _firestore
          .collection('vendor_invitations')
          .add(invitation);

      debugPrint('✅ Invitation sent successfully: ${docRef.id}');
      return docRef.id;

    } catch (e) {
      debugPrint('❌ Error sending invitation: $e');
      throw Exception('Failed to send invitation: $e');
    }
  }

  /// Send bulk invitations to multiple vendors
  static Future<List<String>> sendBulkInvitations(
    String organizerId,
    List<String> vendorIds,
    String marketId, {
    String? customMessage,
    String? organizerName,
  }) async {
    try {
      debugPrint('📧 Sending bulk invitations from $organizerId to ${vendorIds.length} vendors');

      final batch = _firestore.batch();
      final invitationIds = <String>[];

      for (final vendorId in vendorIds) {
        final docRef = _firestore.collection('vendor_invitations').doc();
        invitationIds.add(docRef.id);

        final invitation = {
          'organizerId': organizerId,
          'vendorId': vendorId,
          'marketId': marketId,
          'status': 'pending',
          'customMessage': customMessage,
          'organizerName': organizerName,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 14))
          ),
        };

        batch.set(docRef, invitation);
      }

      await batch.commit();
      debugPrint('✅ Sent ${invitationIds.length} bulk invitations successfully');
      return invitationIds;

    } catch (e) {
      debugPrint('❌ Error sending bulk invitations: $e');
      throw Exception('Failed to send bulk invitations: $e');
    }
  }

  /// Get invitation status for specific vendor-market combination
  static Future<Map<String, dynamic>?> getInvitationStatus(
    String organizerId,
    String vendorId,
    String marketId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('vendor_invitations')
          .where('organizerId', isEqualTo: organizerId)
          .where('vendorId', isEqualTo: vendorId)
          .where('marketId', isEqualTo: marketId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc = snapshot.docs.first;
      return {
        'id': doc.id,
        ...doc.data(),
      };

    } catch (e) {
      debugPrint('❌ Error getting invitation status: $e');
      return null;
    }
  }

  /// Get all invitations sent by organizer
  static Future<List<Map<String, dynamic>>> getOrganizerInvitations(
    String organizerId, {
    String? status,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore
          .collection('vendor_invitations')
          .where('organizerId', isEqualTo: organizerId);

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();

    } catch (e) {
      debugPrint('❌ Error getting organizer invitations: $e');
      return [];
    }
  }

  /// Get vendor's received invitations
  static Future<List<Map<String, dynamic>>> getVendorInvitations(
    String vendorId, {
    String? status,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore
          .collection('vendor_invitations')
          .where('vendorId', isEqualTo: vendorId);

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();

    } catch (e) {
      debugPrint('❌ Error getting vendor invitations: $e');
      return [];
    }
  }

  /// Update invitation status (vendor response)
  static Future<void> updateInvitationStatus(
    String invitationId,
    String status, {
    String? responseMessage,
  }) async {
    try {
      await _firestore
          .collection('vendor_invitations')
          .doc(invitationId)
          .update({
            'status': status,
            'responseMessage': responseMessage,
            'respondedAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          });

      debugPrint('✅ Updated invitation $invitationId status to $status');

    } catch (e) {
      debugPrint('❌ Error updating invitation status: $e');
      throw Exception('Failed to update invitation status: $e');
    }
  }

  /// Cancel invitation (organizer)
  static Future<void> cancelInvitation(String invitationId) async {
    try {
      await _firestore
          .collection('vendor_invitations')
          .doc(invitationId)
          .update({
            'status': 'cancelled',
            'updatedAt': Timestamp.now(),
          });

      debugPrint('✅ Cancelled invitation $invitationId');

    } catch (e) {
      debugPrint('❌ Error cancelling invitation: $e');
      throw Exception('Failed to cancel invitation: $e');
    }
  }

  /// Get invitation analytics for organizer
  static Future<Map<String, dynamic>> getInvitationAnalytics(String organizerId) async {
    try {
      final snapshot = await _firestore
          .collection('vendor_invitations')
          .where('organizerId', isEqualTo: organizerId)
          .get();

      final invitations = snapshot.docs;
      final totalSent = invitations.length;
      final pending = invitations.where((doc) => doc.data()['status'] == 'pending').length;
      final accepted = invitations.where((doc) => doc.data()['status'] == 'accepted').length;
      final declined = invitations.where((doc) => doc.data()['status'] == 'declined').length;
      final expired = invitations.where((doc) => doc.data()['status'] == 'expired').length;

      final responseRate = totalSent > 0 ? (accepted + declined) / totalSent : 0.0;
      final acceptanceRate = totalSent > 0 ? accepted / totalSent : 0.0;

      return {
        'totalSent': totalSent,
        'pending': pending,
        'accepted': accepted,
        'declined': declined,
        'expired': expired,
        'responseRate': responseRate,
        'acceptanceRate': acceptanceRate,
      };

    } catch (e) {
      debugPrint('❌ Error getting invitation analytics: $e');
      return {};
    }
  }

  /// Clean up expired invitations
  static Future<int> cleanupExpiredInvitations() async {
    try {
      final now = Timestamp.now();
      final expiredSnapshot = await _firestore
          .collection('vendor_invitations')
          .where('status', isEqualTo: 'pending')
          .where('expiresAt', isLessThan: now)
          .get();

      final batch = _firestore.batch();
      int updatedCount = 0;

      for (final doc in expiredSnapshot.docs) {
        batch.update(doc.reference, {
          'status': 'expired',
          'updatedAt': now,
        });
        updatedCount++;
      }

      if (updatedCount > 0) {
        await batch.commit();
        debugPrint('✅ Marked $updatedCount invitations as expired');
      }

      return updatedCount;

    } catch (e) {
      debugPrint('❌ Error cleaning up expired invitations: $e');
      return 0;
    }
  }
}