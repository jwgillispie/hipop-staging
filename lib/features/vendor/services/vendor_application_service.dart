import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hipop/features/shared/services/user_profile_service.dart';
import '../models/vendor_application.dart';
import '../../vendor/models/managed_vendor.dart';
import 'managed_vendor_service.dart';
import 'vendor_market_relationship_service.dart';

class VendorApplicationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _applicationsCollection = 
      _firestore.collection('vendor_applications');

  /// Submit a new vendor application
  static Future<String> submitApplication(VendorApplication application) async {
    try {
      debugPrint('DEBUG: Submitting application to Firestore...');
      debugPrint('DEBUG: Market ID: ${application.marketId}');
      debugPrint('DEBUG: Vendor ID: ${application.vendorId}');
      debugPrint('DEBUG: Status: ${application.status.name}');
      debugPrint('DEBUG: Application Type: ${application.applicationType.name}');
      
      final docRef = await _applicationsCollection.add(application.toFirestore());
      debugPrint('SUCCESS: Vendor application submitted with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('ERROR: Error submitting vendor application: $e');
      throw Exception('Failed to submit application: $e');
    }
  }

  /// Submit a market permission request
  static Future<String> submitMarketPermissionRequest({
    required String vendorId,
    required String marketId,
    String? specialMessage,
    String? howDidYouHear,
  }) async {
    return await VendorMarketRelationshipService.submitMarketPermissionRequest(
      vendorId: vendorId,
      marketId: marketId,
      specialMessage: specialMessage,
      howDidYouHear: howDidYouHear,
    );
  }

  /// Submit a new vendor application with profile validation
  static Future<String> submitApplicationWithProfile(
    String vendorId,
    String marketId, {
    String? specialMessage,
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

      // Check if vendor has already applied to this market
      final hasApplied = await hasVendorApplied(vendorId, marketId);
      if (hasApplied) {
        throw Exception('You have already applied to this market.');
      }

      // Create the application
      final application = VendorApplication(
        id: '', // Will be set by Firestore
        marketId: marketId,
        vendorId: vendorId,
        specialMessage: specialMessage,
        status: ApplicationStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {
          'profileSnapshot': {
            'businessName': vendorProfile.businessName,
            'displayName': vendorProfile.displayName,
            'email': vendorProfile.email,
            'categories': vendorProfile.categories,
            'submittedAt': DateTime.now().toIso8601String(),
          },
        },
      );

      debugPrint('DEBUG: Submitting application for vendor: ${vendorProfile.businessName ?? vendorProfile.displayName}');
      debugPrint('DEBUG: Application market ID: $marketId');
      debugPrint('DEBUG: Profile metadata: ${application.metadata}');

      return await submitApplication(application);
    } catch (e) {
      debugPrint('Error submitting application with profile: $e');
      rethrow;
    }
  }

  /// Submit a new vendor application for a market event
  static Future<String> submitMarketEventApplication(
    String vendorId,
    String marketId, {
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

      // Check if vendor has already applied to this market
      final hasApplied = await hasVendorApplied(vendorId, marketId);
      if (hasApplied) {
        throw Exception('You have already applied to this market.');
      }

      // Create the application for the specific market event
      final application = VendorApplication(
        id: '', // Will be set by Firestore
        marketId: marketId,
        vendorId: vendorId,
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
            'submittedAt': DateTime.now().toIso8601String(),
          },
        },
      );

      debugPrint('DEBUG: Submitting application for vendor: ${vendorProfile.businessName ?? vendorProfile.displayName}');
      debugPrint('DEBUG: Application market ID: $marketId');
      debugPrint('DEBUG: Application type: ${application.applicationType.name}');
      debugPrint('DEBUG: Profile metadata: ${application.metadata}');

      return await submitApplication(application);
    } catch (e) {
      debugPrint('Error submitting application with dates: $e');
      rethrow;
    }
  }

  /// Helper method to generate legacy operating days from requested dates
  static List<String> _generateLegacyOperatingDays(List<DateTime> requestedDates) {
    final dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final Set<String> uniqueDays = {};
    
    for (final date in requestedDates) {
      uniqueDays.add(dayNames[date.weekday % 7]);
    }
    
    return uniqueDays.toList();
  }

  /// Get all applications for a specific market
  static Stream<List<VendorApplication>> getApplicationsForMarket(String marketId) {
    return _applicationsCollection
        .where('marketId', isEqualTo: marketId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VendorApplication.fromFirestore(doc))
            .toList());
  }

  /// Get applications by status for a specific market
  static Stream<List<VendorApplication>> getApplicationsByStatus(
    String marketId, 
    ApplicationStatus status,
  ) {
    return _applicationsCollection
        .where('marketId', isEqualTo: marketId)
        .where('status', isEqualTo: status.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VendorApplication.fromFirestore(doc))
            .toList());
  }

  /// Get approved applications for a specific market (async method for form usage)
  static Future<List<VendorApplication>> getApprovedApplicationsForMarket(String marketId) async {
    try {
      final snapshot = await _applicationsCollection
          .where('marketId', isEqualTo: marketId)
          .where('status', isEqualTo: ApplicationStatus.approved.name)
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => VendorApplication.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting approved applications for market: $e');
      return [];
    }
  }

  /// Get applications for a specific vendor
  static Stream<List<VendorApplication>> getApplicationsForVendor(String vendorId) {
    return _applicationsCollection
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VendorApplication.fromFirestore(doc))
            .toList());
  }

  /// Update application status (approve, reject, waitlist)
  static Future<void> updateApplicationStatus(
    String applicationId,
    ApplicationStatus newStatus,
    String reviewerId, {
    String? reviewNotes,
  }) async {
    try {
      await _applicationsCollection.doc(applicationId).update({
        'status': newStatus.name,
        'reviewedBy': reviewerId,
        'reviewedAt': Timestamp.now(),
        'reviewNotes': reviewNotes,
        'updatedAt': Timestamp.now(),
      });
      debugPrint('Application $applicationId updated to status: ${newStatus.name}');
    } catch (e) {
      debugPrint('Error updating application status: $e');
      throw Exception('Failed to update application: $e');
    }
  }

  /// Approve an application and create appropriate records
  static Future<void> approveApplication(
    String applicationId,
    String reviewerId, {
    String? notes,
  }) async {
    try {
      // Get the application details
      final application = await getApplication(applicationId);
      if (application == null) {
        throw Exception('Application not found');
      }

      // Update application status first
      await updateApplicationStatus(
        applicationId,
        ApplicationStatus.approved,
        reviewerId,
        reviewNotes: notes,
      );

      if (application.isMarketPermission) {
        // Get updated application with approved status
        final updatedApplication = await getApplication(applicationId);
        if (updatedApplication == null) {
          throw Exception('Could not fetch updated application');
        }
        
        debugPrint('DEBUG: Original application status: ${application.status.name}');
        debugPrint('DEBUG: Updated application status: ${updatedApplication.status.name}');
        debugPrint('DEBUG: Updated application isApproved: ${updatedApplication.isApproved}');
        debugPrint('DEBUG: Updated application isMarketPermission: ${updatedApplication.isMarketPermission}');
        
        // Create vendor-market relationship for permission requests
        await VendorMarketRelationshipService.createRelationshipFromApplication(
          updatedApplication,
          reviewerId,
        );
        
        // Also create ManagedVendor record so vendor appears in vendor management
        debugPrint('🔄 Starting ManagedVendor creation for permission application: ${application.id}');
        await _createManagedVendorFromApplication(application, reviewerId);
        debugPrint('SUCCESS: Application $applicationId approved - VendorMarketRelationship and ManagedVendor created');
      } else {
        // Create ManagedVendor record for event applications
        await _createManagedVendorFromApplication(application, reviewerId);
        debugPrint('Application $applicationId approved and ManagedVendor created');
      }
    } catch (e) {
      debugPrint('Error approving application: $e');
      throw Exception('Failed to approve application: $e');
    }
  }

  /// Reject an application
  static Future<void> rejectApplication(
    String applicationId,
    String reviewerId, {
    String? notes,
  }) async {
    await updateApplicationStatus(
      applicationId,
      ApplicationStatus.rejected,
      reviewerId,
      reviewNotes: notes,
    );
  }

  /// Waitlist an application
  static Future<void> waitlistApplication(
    String applicationId,
    String reviewerId, {
    String? notes,
  }) async {
    await updateApplicationStatus(
      applicationId,
      ApplicationStatus.waitlisted,
      reviewerId,
      reviewNotes: notes,
    );
  }

  /// Get application statistics for a market
  static Future<Map<String, int>> getApplicationStats(String marketId) async {
    try {
      final snapshot = await _applicationsCollection
          .where('marketId', isEqualTo: marketId)
          .get();
      
      final applications = snapshot.docs
          .map((doc) => VendorApplication.fromFirestore(doc))
          .toList();
      
      final stats = <String, int>{
        'total': applications.length,
        'pending': 0,
        'approved': 0,
        'rejected': 0,
        'waitlisted': 0,
      };
      
      for (final app in applications) {
        switch (app.status) {
          case ApplicationStatus.pending:
            stats['pending'] = stats['pending']! + 1;
            break;
          case ApplicationStatus.approved:
            stats['approved'] = stats['approved']! + 1;
            break;
          case ApplicationStatus.rejected:
            stats['rejected'] = stats['rejected']! + 1;
            break;
          case ApplicationStatus.waitlisted:
            stats['waitlisted'] = stats['waitlisted']! + 1;
            break;
        }
      }
      
      return stats;
    } catch (e) {
      debugPrint('Error getting application stats: $e');
      throw Exception('Failed to get application statistics: $e');
    }
  }

  /// Get a single application by ID
  static Future<VendorApplication?> getApplication(String applicationId) async {
    try {
      final doc = await _applicationsCollection.doc(applicationId).get();
      if (doc.exists) {
        return VendorApplication.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting application: $e');
      throw Exception('Failed to get application: $e');
    }
  }

  /// Update application details (before review)
  static Future<void> updateApplication(
    String applicationId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _applicationsCollection.doc(applicationId).update({
        ...updates,
        'updatedAt': Timestamp.now(),
      });
      debugPrint('Application $applicationId updated');
    } catch (e) {
      debugPrint('Error updating application: $e');
      throw Exception('Failed to update application: $e');
    }
  }

  /// Delete an application (usually only for pending applications)
  static Future<void> deleteApplication(String applicationId) async {
    try {
      await _applicationsCollection.doc(applicationId).delete();
      debugPrint('Application $applicationId deleted');
    } catch (e) {
      debugPrint('Error deleting application: $e');
      throw Exception('Failed to delete application: $e');
    }
  }

  /// Check if a vendor has already applied to a specific market
  static Future<bool> hasVendorApplied(String vendorId, String marketId) async {
    try {
      final snapshot = await _applicationsCollection
          .where('vendorId', isEqualTo: vendorId)
          .where('marketId', isEqualTo: marketId)
          .limit(1)
          .get();
      
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking vendor application: $e');
      return false;
    }
  }

  /// Create a ManagedVendor record from an approved application
  static Future<void> _createManagedVendorFromApplication(
    VendorApplication application, 
    String reviewerId,
  ) async {
    try {
      // Check if ManagedVendor already exists for this application
      final existingVendor = await _findManagedVendorByApplication(application.id);
      if (existingVendor != null) {
        debugPrint('ManagedVendor already exists for application: ${application.id}');
        return;
      }

      // Get the vendor's profile data
      final vendorProfile = await UserProfileService().getUserProfile(application.vendorId);
      if (vendorProfile == null) {
        throw Exception('Vendor profile not found for user: ${application.vendorId}');
      }

      // Convert profile categories to VendorCategory enum
      final vendorCategories = vendorProfile.categories
          .map((categoryName) {
            try {
              return VendorCategory.values.firstWhere(
                (category) => category.name == categoryName,
              );
            } catch (e) {
              debugPrint('Unknown category: $categoryName');
              return VendorCategory.other;
            }
          })
          .toList();

      // Create ManagedVendor from vendor profile data
      final managedVendor = ManagedVendor(
        id: '', // Will be set by Firestore
        marketId: application.marketId,
        organizerId: reviewerId,
        businessName: vendorProfile.businessName ?? vendorProfile.displayName ?? 'Unknown Business',
        contactName: vendorProfile.displayName ?? vendorProfile.email.split('@').first,
        email: vendorProfile.email,
        phoneNumber: vendorProfile.phoneNumber ?? '',
        description: vendorProfile.bio ?? '',
        categories: vendorCategories,
        website: vendorProfile.website ?? '',
        instagramHandle: vendorProfile.instagramHandle ?? '',
        facebookHandle: '', // Not in profile, leave empty
        address: '', // Not in profile, leave empty for now
        city: '', // Not in profile, leave empty for now
        state: '', // Not in profile, leave empty for now
        zipCode: '', // Not in profile, leave empty for now
        imageUrl: '', // Not in profile, leave empty for now
        imageUrls: [], // Not in profile, leave empty for now
        logoUrl: '', // Not in profile, leave empty for now
        products: [], // Not in profile, leave empty for now
        specialties: [], // Not in profile, leave empty for now
        priceRange: '', // Not in profile, leave empty for now
        certifications: '', // Not in profile, leave empty for now
        operatingDays: [], // Operating days are now handled at the market level
        boothPreferences: application.specialMessage ?? '',
        specialRequirements: application.specialMessage ?? '',
        canDeliver: false, // Default to false
        acceptsOrders: false, // Default to false
        deliveryNotes: '', // Not in profile, leave empty for now
        isActive: true, // Default to active since they were approved
        isFeatured: false, // Default to not featured
        isOrganic: false, // Default to false
        isLocallySourced: false, // Default to false
        story: '', // Not in profile, leave empty for now
        tags: [], // Not in profile, leave empty for now
        slogan: '', // Not in profile, leave empty for now
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {
          'createdFromApplication': true,
          'applicationId': application.id,
          'vendorUserId': application.vendorId,
          'applicationType': application.applicationType.name,
          'isPermissionBased': application.isMarketPermission,
        },
      );

      // Create the ManagedVendor record
      debugPrint('🔄 Calling ManagedVendorService.createVendor for: ${managedVendor.businessName}');
      debugPrint('INFO: ManagedVendor data: marketId=${managedVendor.marketId}, isPermissionBased=${managedVendor.metadata['isPermissionBased']}');

      final createdVendorId = await ManagedVendorService.createVendor(managedVendor);

      debugPrint('SUCCESS: ManagedVendor created from application: ${application.id} with ID: $createdVendorId');
    } catch (e) {
      debugPrint('Error creating ManagedVendor from application: $e');
      throw Exception('Failed to create vendor profile: $e');
    }
  }

  /// Find existing ManagedVendor created from an application
  static Future<ManagedVendor?> _findManagedVendorByApplication(String applicationId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('managed_vendors')
          .where('metadata.applicationId', isEqualTo: applicationId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return ManagedVendor.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error finding ManagedVendor by application: $e');
      return null;
    }
  }

  /// Get the ManagedVendor created from an approved application
  static Future<ManagedVendor?> getManagedVendorFromApplication(String applicationId) async {
    return await _findManagedVendorByApplication(applicationId);
  }

  /// Get application with vendor profile data for display
  static Future<Map<String, dynamic>?> getApplicationWithProfile(String applicationId) async {
    try {
      final application = await getApplication(applicationId);
      if (application == null) return null;

      final vendorProfile = await UserProfileService().getUserProfile(application.vendorId);
      if (vendorProfile == null) return null;

      return {
        'application': application,
        'vendorProfile': vendorProfile,
        'businessName': vendorProfile.businessName ?? vendorProfile.displayName ?? 'Unknown Business',
        'contactName': vendorProfile.displayName ?? vendorProfile.email.split('@').first,
        'email': vendorProfile.email,
        'phoneNumber': vendorProfile.phoneNumber,
        'description': vendorProfile.bio ?? 'No description provided',
        'categories': vendorProfile.categories,
        'website': vendorProfile.website,
        'instagramHandle': vendorProfile.instagramHandle,
      };
    } catch (e) {
      debugPrint('Error getting application with profile: $e');
      return null;
    }
  }

  /// Get pending applications count for a market (for dashboard)
  static Future<int> getPendingApplicationsCount(String marketId) async {
    try {
      final snapshot = await _applicationsCollection
          .where('marketId', isEqualTo: marketId)
          .where('status', isEqualTo: ApplicationStatus.pending.name)
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting pending applications count: $e');
      return 0;
    }
  }

  /// Auto-reject applications with requested dates before today
  static Future<int> autoRejectExpiredApplications(String marketId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      int rejectedCount = 0;

      // Get all pending applications for this market
      final snapshot = await _applicationsCollection
          .where('marketId', isEqualTo: marketId)
          .where('status', isEqualTo: ApplicationStatus.pending.name)
          .get();

      for (final doc in snapshot.docs) {
        final application = VendorApplication.fromFirestore(doc);
        
        // For the new 1:1 market-event system, applications are for specific market events
        // TODO: Add logic to fetch market and check if event date is in the past
        // For now, we don't auto-reject since this requires market lookup
        if (false) { // Disabled for now
          // Auto-reject this application
          await updateApplicationStatus(
            application.id,
            ApplicationStatus.rejected,
            'system', // System rejection
            reviewNotes: 'Automatically rejected: Market event date is in the past.',
          );
          rejectedCount++;
          debugPrint('Auto-rejected application ${application.id} for ${application.vendorBusinessName} - past dates');
        }
      }

      return rejectedCount;
    } catch (e) {
      debugPrint('Error auto-rejecting expired applications: $e');
      return 0;
    }
  }

  /// Auto-reject applications with requested dates before today for all markets
  static Future<int> autoRejectAllExpiredApplications() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      int rejectedCount = 0;

      // Get all pending applications
      final snapshot = await _applicationsCollection
          .where('status', isEqualTo: ApplicationStatus.pending.name)
          .get();

      for (final doc in snapshot.docs) {
        final application = VendorApplication.fromFirestore(doc);
        
        // For the new 1:1 market-event system, applications are for specific market events
        // TODO: Add logic to fetch market and check if event date is in the past
        // For now, we don't auto-reject since this requires market lookup
        if (false) { // Disabled for now
          // Auto-reject this application
          await updateApplicationStatus(
            application.id,
            ApplicationStatus.rejected,
            'system', // System rejection
            reviewNotes: 'Automatically rejected: Market event date is in the past.',
          );
          rejectedCount++;
          debugPrint('Auto-rejected application ${application.id} for ${application.vendorBusinessName} - past dates');
        }
      }

      return rejectedCount;
    } catch (e) {
      debugPrint('Error auto-rejecting all expired applications: $e');
      return 0;
    }
  }
}