import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/vendor_market_relationship.dart';
import '../models/vendor_application.dart';
import 'user_profile_service.dart';
import 'vendor_application_service.dart';

class VendorMarketRelationshipService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _relationshipsCollection = 
      _firestore.collection('vendor_market_relationships');

  /// Submit a market permission request
  static Future<String> submitMarketPermissionRequest({
    required String vendorId,
    required String marketId,
    String? specialMessage,
    String? howDidYouHear,
  }) async {
    try {
      // Validate vendor profile exists and is complete
      final vendorProfile = await UserProfileService().getUserProfile(vendorId);
      if (vendorProfile == null) {
        throw Exception('Vendor profile not found. Please complete your profile first.');
      }

      if (vendorProfile.userType != 'vendor') {
        throw Exception('User must be registered as a vendor to apply.');
      }

      if (!vendorProfile.isProfileComplete) {
        throw Exception('Please complete your vendor profile before applying to markets.');
      }

      // Check if vendor already has an active relationship or pending request for this market
      final existingRelationship = await getVendorMarketRelationship(vendorId, marketId);
      if (existingRelationship != null) {
        if (existingRelationship.isActive || existingRelationship.isApproved) {
          throw Exception('You already have permission for this market.');
        }
        if (existingRelationship.isPending) {
          throw Exception('You have a pending permission request for this market.');
        }
      }

      // Check if there's already a permission application pending
      final hasPermissionApplication = await _hasPermissionApplication(vendorId, marketId);
      if (hasPermissionApplication) {
        throw Exception('You have a pending permission request for this market.');
      }

      // Create the permission application
      final application = VendorApplication(
        id: '', // Will be set by Firestore
        marketId: marketId,
        vendorId: vendorId,
        applicationType: ApplicationType.marketPermission,
        operatingDays: [], // Not needed for permission requests
        requestedDates: [], // Not needed for permission requests
        specialMessage: specialMessage,
        howDidYouHear: howDidYouHear,
        status: ApplicationStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {
          'profileSnapshot': {
            'businessName': vendorProfile.businessName,
            'displayName': vendorProfile.displayName,
            'email': vendorProfile.email,
            'categories': vendorProfile.categories,
            'bio': vendorProfile.bio,
            'instagramHandle': vendorProfile.instagramHandle,
            'website': vendorProfile.website,
            'submittedAt': DateTime.now().toIso8601String(),
          },
          'isPermissionRequest': true,
        },
      );

      debugPrint('DEBUG: Submitting market permission request for vendor: ${vendorProfile.businessName ?? vendorProfile.displayName}');
      debugPrint('DEBUG: Market ID: $marketId');
      debugPrint('DEBUG: Application type: ${application.applicationType.name}');

      return await VendorApplicationService.submitApplication(application);
    } catch (e) {
      debugPrint('Error submitting market permission request: $e');
      rethrow;
    }
  }

  /// Check if vendor has a pending permission application for a market
  static Future<bool> _hasPermissionApplication(String vendorId, String marketId) async {
    try {
      final snapshot = await _firestore
          .collection('vendor_applications')
          .where('vendorId', isEqualTo: vendorId)
          .where('marketId', isEqualTo: marketId)
          .where('applicationType', isEqualTo: ApplicationType.marketPermission.name)
          .where('status', isEqualTo: ApplicationStatus.pending.name)
          .limit(1)
          .get();
      
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking permission application: $e');
      return false;
    }
  }

  /// Create vendor-market relationship from approved permission request
  static Future<VendorMarketRelationship> createRelationshipFromApplication(
    VendorApplication application,
    String approverId,
  ) async {
    try {
      if (!application.isMarketPermission) {
        throw Exception('Can only create relationships from permission requests.');
      }

      // Check if relationship already exists
      final existingRelationship = await getVendorMarketRelationship(
        application.vendorId, 
        application.marketId,
      );
      if (existingRelationship != null) {
        debugPrint('Relationship already exists, updating status to active');
        return await updateRelationshipStatus(
          existingRelationship.id,
          RelationshipStatus.active,
          approverId,
        );
      }

      // Create new relationship
      final relationship = VendorMarketRelationship(
        id: '', // Will be set by Firestore
        vendorId: application.vendorId,
        marketId: application.marketId,
        status: RelationshipStatus.approved,
        source: RelationshipSource.vendorApplication,
        createdBy: application.vendorId,
        approvedBy: approverId,
        approvedAt: DateTime.now(),
        operatingDays: application.operatingDays,
        notes: application.reviewNotes,
        metadata: {
          'createdFromApplication': true,
          'applicationId': application.id,
          'profileSnapshot': application.metadata['profileSnapshot'],
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final docRef = await _relationshipsCollection.add(relationship.toFirestore());
      debugPrint('✅ Vendor-Market relationship created with ID: ${docRef.id}');
      
      return relationship.copyWith(id: docRef.id);
    } catch (e) {
      debugPrint('❌ Error creating vendor-market relationship: $e');
      throw Exception('Failed to create vendor-market relationship: $e');
    }
  }

  /// Get vendor-market relationship
  static Future<VendorMarketRelationship?> getVendorMarketRelationship(
    String vendorId, 
    String marketId,
  ) async {
    try {
      final snapshot = await _relationshipsCollection
          .where('vendorId', isEqualTo: vendorId)
          .where('marketId', isEqualTo: marketId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return VendorMarketRelationship.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting vendor-market relationship: $e');
      return null;
    }
  }

  /// Get all approved markets for a vendor (for pop-up creation)
  static Future<List<String>> getApprovedMarketsForVendor(String vendorId) async {
    try {
      final snapshot = await _relationshipsCollection
          .where('vendorId', isEqualTo: vendorId)
          .where('status', whereIn: [
            RelationshipStatus.approved.name,
            RelationshipStatus.active.name,
          ])
          .get();
      
      return snapshot.docs
          .map((doc) => VendorMarketRelationship.fromFirestore(doc))
          .map((relationship) => relationship.marketId)
          .toList();
    } catch (e) {
      debugPrint('Error getting approved markets for vendor: $e');
      return [];
    }
  }

  /// Get all vendor relationships for a market
  static Stream<List<VendorMarketRelationship>> getVendorRelationshipsForMarket(String marketId) {
    return _relationshipsCollection
        .where('marketId', isEqualTo: marketId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VendorMarketRelationship.fromFirestore(doc))
            .toList());
  }

  /// Get all market relationships for a vendor
  static Stream<List<VendorMarketRelationship>> getMarketRelationshipsForVendor(String vendorId) {
    return _relationshipsCollection
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VendorMarketRelationship.fromFirestore(doc))
            .toList());
  }

  /// Update relationship status
  static Future<VendorMarketRelationship> updateRelationshipStatus(
    String relationshipId,
    RelationshipStatus newStatus,
    String updatedBy,
  ) async {
    try {
      final updateData = {
        'status': newStatus.name,
        'updatedAt': Timestamp.now(),
      };

      if (newStatus == RelationshipStatus.approved || newStatus == RelationshipStatus.active) {
        updateData['approvedBy'] = updatedBy;
        updateData['approvedAt'] = Timestamp.now();
      }

      await _relationshipsCollection.doc(relationshipId).update(updateData);
      
      final doc = await _relationshipsCollection.doc(relationshipId).get();
      return VendorMarketRelationship.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error updating relationship status: $e');
      throw Exception('Failed to update relationship status: $e');
    }
  }

  /// Approve relationship
  static Future<VendorMarketRelationship> approveRelationship(
    String relationshipId,
    String approverId, {
    String? notes,
  }) async {
    try {
      final updateData = {
        'status': RelationshipStatus.approved.name,
        'approvedBy': approverId,
        'approvedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      if (notes != null) {
        updateData['notes'] = notes;
      }

      await _relationshipsCollection.doc(relationshipId).update(updateData);
      
      final doc = await _relationshipsCollection.doc(relationshipId).get();
      return VendorMarketRelationship.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error approving relationship: $e');
      throw Exception('Failed to approve relationship: $e');
    }
  }

  /// Reject relationship
  static Future<VendorMarketRelationship> rejectRelationship(
    String relationshipId,
    String rejectedBy, {
    String? notes,
  }) async {
    try {
      final updateData = {
        'status': RelationshipStatus.rejected.name,
        'approvedBy': rejectedBy, // Reusing this field for who reviewed it
        'approvedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      if (notes != null) {
        updateData['notes'] = notes;
      }

      await _relationshipsCollection.doc(relationshipId).update(updateData);
      
      final doc = await _relationshipsCollection.doc(relationshipId).get();
      return VendorMarketRelationship.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error rejecting relationship: $e');
      throw Exception('Failed to reject relationship: $e');
    }
  }

  /// Delete relationship
  static Future<void> deleteRelationship(String relationshipId) async {
    try {
      await _relationshipsCollection.doc(relationshipId).delete();
      debugPrint('Relationship $relationshipId deleted');
    } catch (e) {
      debugPrint('Error deleting relationship: $e');
      throw Exception('Failed to delete relationship: $e');
    }
  }

  /// Check if vendor has permission for a market
  static Future<bool> hasMarketPermission(String vendorId, String marketId) async {
    try {
      final relationship = await getVendorMarketRelationship(vendorId, marketId);
      return relationship?.isApproved == true || relationship?.isActive == true;
    } catch (e) {
      debugPrint('Error checking market permission: $e');
      return false;
    }
  }

  /// Get relationship statistics for a market
  static Future<Map<String, int>> getRelationshipStats(String marketId) async {
    try {
      final snapshot = await _relationshipsCollection
          .where('marketId', isEqualTo: marketId)
          .get();
      
      final relationships = snapshot.docs
          .map((doc) => VendorMarketRelationship.fromFirestore(doc))
          .toList();
      
      final stats = <String, int>{
        'total': relationships.length,
        'pending': 0,
        'approved': 0,
        'active': 0,
        'inactive': 0,
        'rejected': 0,
      };
      
      for (final relationship in relationships) {
        switch (relationship.status) {
          case RelationshipStatus.pending:
            stats['pending'] = stats['pending']! + 1;
            break;
          case RelationshipStatus.approved:
            stats['approved'] = stats['approved']! + 1;
            break;
          case RelationshipStatus.active:
            stats['active'] = stats['active']! + 1;
            break;
          case RelationshipStatus.inactive:
            stats['inactive'] = stats['inactive']! + 1;
            break;
          case RelationshipStatus.rejected:
            stats['rejected'] = stats['rejected']! + 1;
            break;
        }
      }
      
      return stats;
    } catch (e) {
      debugPrint('Error getting relationship stats: $e');
      throw Exception('Failed to get relationship statistics: $e');
    }
  }

  /// Create market invitation token
  static String generateInvitationToken() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return 'inv_${timestamp}_$random';
  }

  /// Create vendor invitation (for Phase 1B)
  static Future<VendorMarketRelationship> createVendorInvitation({
    required String marketId,
    required String invitationEmail,
    required String createdBy,
    String? notes,
  }) async {
    try {
      final invitationToken = generateInvitationToken();
      
      final relationship = VendorMarketRelationship(
        id: '', // Will be set by Firestore
        vendorId: '', // Will be set when vendor accepts invitation
        marketId: marketId,
        status: RelationshipStatus.pending,
        source: RelationshipSource.marketInvitation,
        invitationToken: invitationToken,
        invitationEmail: invitationEmail,
        createdBy: createdBy,
        notes: notes,
        metadata: {
          'isInvitation': true,
          'invitationSentAt': DateTime.now().toIso8601String(),
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final docRef = await _relationshipsCollection.add(relationship.toFirestore());
      debugPrint('✅ Vendor invitation created with ID: ${docRef.id}');
      
      // TODO: Send invitation email here
      
      return relationship.copyWith(id: docRef.id);
    } catch (e) {
      debugPrint('❌ Error creating vendor invitation: $e');
      throw Exception('Failed to create vendor invitation: $e');
    }
  }

  /// Accept vendor invitation by token
  static Future<VendorMarketRelationship?> acceptInvitationByToken(
    String invitationToken, 
    String vendorId,
  ) async {
    try {
      final snapshot = await _relationshipsCollection
          .where('invitationToken', isEqualTo: invitationToken)
          .where('status', isEqualTo: RelationshipStatus.pending.name)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) {
        throw Exception('Invalid or expired invitation token.');
      }

      final doc = snapshot.docs.first;
      final relationship = VendorMarketRelationship.fromFirestore(doc);
      
      // Update relationship with vendor ID and approve it
      final updatedRelationship = relationship.copyWith(
        vendorId: vendorId,
        status: RelationshipStatus.approved,
        approvedBy: 'system', // Auto-approved via invitation
        approvedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {
          ...relationship.metadata,
          'invitationAcceptedAt': DateTime.now().toIso8601String(),
          'acceptedBy': vendorId,
        },
      );

      await _relationshipsCollection.doc(doc.id).update(updatedRelationship.toFirestore());
      
      return updatedRelationship;
    } catch (e) {
      debugPrint('Error accepting invitation: $e');
      return null;
    }
  }
}