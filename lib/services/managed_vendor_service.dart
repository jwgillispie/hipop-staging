import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/managed_vendor.dart';

class ManagedVendorService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _vendorsCollection =
      _firestore.collection('managed_vendors');

  /// Create a new managed vendor
  static Future<String> createVendor(ManagedVendor vendor) async {
    try {
      final docRef = await _vendorsCollection.add(vendor.toFirestore());
      debugPrint('Managed vendor created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating managed vendor: $e');
      throw Exception('Failed to create vendor: $e');
    }
  }

  /// Get all vendors for a specific market
  static Stream<List<ManagedVendor>> getVendorsForMarket(String marketId) {
    return _vendorsCollection
        .where('marketId', isEqualTo: marketId)
        .orderBy('businessName', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ManagedVendor.fromFirestore(doc))
            .toList());
  }

  /// Get all vendors for a specific market (async method for form usage)
  static Future<List<ManagedVendor>> getVendorsForMarketAsync(String marketId) async {
    try {
      final snapshot = await _vendorsCollection
          .where('marketId', isEqualTo: marketId)
          .orderBy('businessName', descending: false)
          .get();
      
      return snapshot.docs
          .map((doc) => ManagedVendor.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting vendors for market: $e');
      return [];
    }
  }

  /// Get vendors by organizer
  static Stream<List<ManagedVendor>> getVendorsByOrganizer(String organizerId) {
    return _vendorsCollection
        .where('organizerId', isEqualTo: organizerId)
        .orderBy('businessName', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ManagedVendor.fromFirestore(doc))
            .toList());
  }

  /// Get active vendors for a market
  static Stream<List<ManagedVendor>> getActiveVendorsForMarket(String marketId) {
    return _vendorsCollection
        .where('marketId', isEqualTo: marketId)
        .where('isActive', isEqualTo: true)
        .orderBy('businessName', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ManagedVendor.fromFirestore(doc))
            .toList());
  }

  /// Get featured vendors for a market
  static Stream<List<ManagedVendor>> getFeaturedVendorsForMarket(String marketId) {
    return _vendorsCollection
        .where('marketId', isEqualTo: marketId)
        .where('isFeatured', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .orderBy('businessName', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ManagedVendor.fromFirestore(doc))
            .toList());
  }

  /// Get vendors by category
  static Stream<List<ManagedVendor>> getVendorsByCategory(
    String marketId,
    VendorCategory category,
  ) {
    return _vendorsCollection
        .where('marketId', isEqualTo: marketId)
        .where('categories', arrayContains: category.name)
        .where('isActive', isEqualTo: true)
        .orderBy('businessName', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ManagedVendor.fromFirestore(doc))
            .toList());
  }

  /// Get a single vendor by ID
  static Future<ManagedVendor?> getVendor(String vendorId) async {
    try {
      final doc = await _vendorsCollection.doc(vendorId).get();
      if (doc.exists) {
        return ManagedVendor.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting managed vendor: $e');
      throw Exception('Failed to get vendor: $e');
    }
  }

  /// Update an existing vendor
  static Future<void> updateVendor(String vendorId, ManagedVendor vendor) async {
    try {
      await _vendorsCollection.doc(vendorId).update(vendor.toFirestore());
      debugPrint('Managed vendor $vendorId updated');
    } catch (e) {
      debugPrint('Error updating managed vendor: $e');
      throw Exception('Failed to update vendor: $e');
    }
  }

  /// Update specific fields of a vendor
  static Future<void> updateVendorFields(
    String vendorId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _vendorsCollection.doc(vendorId).update({
        ...updates,
        'updatedAt': Timestamp.now(),
      });
      debugPrint('Managed vendor $vendorId fields updated');
    } catch (e) {
      debugPrint('Error updating managed vendor fields: $e');
      throw Exception('Failed to update vendor fields: $e');
    }
  }

  /// Delete a vendor
  static Future<void> deleteVendor(String vendorId) async {
    try {
      await _vendorsCollection.doc(vendorId).delete();
      debugPrint('Managed vendor $vendorId deleted');
    } catch (e) {
      debugPrint('Error deleting managed vendor: $e');
      throw Exception('Failed to delete vendor: $e');
    }
  }

  /// Toggle vendor active status
  static Future<void> toggleActiveStatus(String vendorId, bool isActive) async {
    await updateVendorFields(vendorId, {
      'isActive': isActive,
    });
  }

  /// Toggle vendor featured status
  static Future<void> toggleFeaturedStatus(String vendorId, bool isFeatured) async {
    await updateVendorFields(vendorId, {
      'isFeatured': isFeatured,
    });
  }

  /// Search vendors by name or description
  static Future<List<ManagedVendor>> searchVendors(
    String marketId,
    String query,
  ) async {
    try {
      final snapshot = await _vendorsCollection
          .where('marketId', isEqualTo: marketId)
          .where('isActive', isEqualTo: true)
          .get();

      final vendors = snapshot.docs
          .map((doc) => ManagedVendor.fromFirestore(doc))
          .where((vendor) =>
              vendor.businessName.toLowerCase().contains(query.toLowerCase()) ||
              vendor.description.toLowerCase().contains(query.toLowerCase()) ||
              vendor.contactName.toLowerCase().contains(query.toLowerCase()) ||
              vendor.products.any((product) =>
                  product.toLowerCase().contains(query.toLowerCase())) ||
              vendor.tags.any((tag) =>
                  tag.toLowerCase().contains(query.toLowerCase())))
          .toList();

      return vendors;
    } catch (e) {
      debugPrint('Error searching managed vendors: $e');
      throw Exception('Failed to search vendors: $e');
    }
  }

  /// Get vendor statistics for a market
  static Future<Map<String, int>> getVendorStats(String marketId) async {
    try {
      final snapshot = await _vendorsCollection
          .where('marketId', isEqualTo: marketId)
          .get();

      final vendors = snapshot.docs
          .map((doc) => ManagedVendor.fromFirestore(doc))
          .toList();

      final stats = <String, int>{
        'total': vendors.length,
        'active': 0,
        'featured': 0,
        'organic': 0,
        'local': 0,
        'delivery': 0,
        'orders': 0,
      };

      // Count by category
      for (final category in VendorCategory.values) {
        stats[category.name] = 0;
      }

      for (final vendor in vendors) {
        if (vendor.isActive) stats['active'] = stats['active']! + 1;
        if (vendor.isFeatured) stats['featured'] = stats['featured']! + 1;
        if (vendor.isOrganic) stats['organic'] = stats['organic']! + 1;
        if (vendor.isLocallySourced) stats['local'] = stats['local']! + 1;
        if (vendor.canDeliver) stats['delivery'] = stats['delivery']! + 1;
        if (vendor.acceptsOrders) stats['orders'] = stats['orders']! + 1;

        // Count by category
        for (final category in vendor.categories) {
          stats[category.name] = (stats[category.name] ?? 0) + 1;
        }
      }

      return stats;
    } catch (e) {
      debugPrint('Error getting vendor stats: $e');
      throw Exception('Failed to get vendor statistics: $e');
    }
  }


  /// Bulk operations
  static Future<void> bulkUpdateVendorStatus(
    List<String> vendorIds,
    bool isActive,
  ) async {
    final batch = _firestore.batch();

    for (final vendorId in vendorIds) {
      final docRef = _vendorsCollection.doc(vendorId);
      batch.update(docRef, {
        'isActive': isActive,
        'updatedAt': Timestamp.now(),
      });
    }

    try {
      await batch.commit();
      debugPrint('Bulk updated ${vendorIds.length} vendors active status to: $isActive');
    } catch (e) {
      debugPrint('Error in bulk update: $e');
      throw Exception('Failed to bulk update vendors: $e');
    }
  }

  /// Delete all vendors for a market (use with caution)
  static Future<void> deleteAllVendorsForMarket(String marketId) async {
    try {
      final snapshot = await _vendorsCollection
          .where('marketId', isEqualTo: marketId)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('Deleted all managed vendors for market: $marketId');
    } catch (e) {
      debugPrint('Error deleting all managed vendors: $e');
      throw Exception('Failed to delete all vendors: $e');
    }
  }

  /// Get vendor categories summary for a market
  static Future<Map<VendorCategory, int>> getCategorySummary(String marketId) async {
    try {
      final snapshot = await _vendorsCollection
          .where('marketId', isEqualTo: marketId)
          .where('isActive', isEqualTo: true)
          .get();

      final vendors = snapshot.docs
          .map((doc) => ManagedVendor.fromFirestore(doc))
          .toList();

      final summary = <VendorCategory, int>{};
      for (final category in VendorCategory.values) {
        summary[category] = 0;
      }

      for (final vendor in vendors) {
        for (final category in vendor.categories) {
          summary[category] = (summary[category] ?? 0) + 1;
        }
      }

      return summary;
    } catch (e) {
      debugPrint('Error getting category summary: $e');
      throw Exception('Failed to get category summary: $e');
    }
  }
}