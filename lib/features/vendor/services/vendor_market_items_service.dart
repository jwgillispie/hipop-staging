import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/vendor_market_items.dart';
import '../../shared/services/user_profile_service.dart';

class VendorMarketItemsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final UserProfileService _userProfileService = UserProfileService();

  /// Get vendor's item list for a specific market
  static Future<VendorMarketItems?> getVendorMarketItems(
    String vendorId,
    String marketId,
  ) async {
    try {
      final query = await _firestore
          .collection('vendor_market_items')
          .where('vendorId', isEqualTo: vendorId)
          .where('marketId', isEqualTo: marketId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return VendorMarketItems.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting vendor market items: $e');
      return null;
    }
  }

  /// Get all market item lists for a vendor
  static Future<List<VendorMarketItems>> getVendorAllMarketItems(String vendorId) async {
    try {
      final query = await _firestore
          .collection('vendor_market_items')
          .where('vendorId', isEqualTo: vendorId)
          .where('isActive', isEqualTo: true)
          .orderBy('updatedAt', descending: true)
          .get();

      return query.docs
          .map((doc) => VendorMarketItems.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting vendor all market items: $e');
      return [];
    }
  }

  /// Update or create vendor's item list for a market
  static Future<bool> updateVendorMarketItems(
    String vendorId,
    String marketId,
    List<String> itemList,
  ) async {
    try {
      // Check vendor's premium status for item limits
      final userProfile = await _userProfileService.getUserProfile(vendorId);
      final isPremium = userProfile?.isPremium == true;
      
      // Enforce item limits for free users
      if (!isPremium && itemList.length > 3) {
        debugPrint('❌ Free vendor $vendorId tried to add ${itemList.length} items (limit: 3)');
        throw Exception('Free vendors can only have 3 items per market. Upgrade to Vendor Pro for unlimited items!');
      }

      // Check if entry exists
      final existingQuery = await _firestore
          .collection('vendor_market_items')
          .where('vendorId', isEqualTo: vendorId)
          .where('marketId', isEqualTo: marketId)
          .limit(1)
          .get();

      final now = DateTime.now();

      if (existingQuery.docs.isNotEmpty) {
        // Update existing
        await existingQuery.docs.first.reference.update({
          'itemList': itemList,
          'updatedAt': Timestamp.fromDate(now),
        });
        debugPrint('✅ Updated ${itemList.length} items for vendor $vendorId at market $marketId');
      } else {
        // Create new
        final newItem = VendorMarketItems(
          id: '', // Firestore will generate
          vendorId: vendorId,
          marketId: marketId,
          itemList: itemList,
          createdAt: now,
          updatedAt: now,
        );

        await _firestore.collection('vendor_market_items').add(newItem.toFirestore());
        debugPrint('✅ Created ${itemList.length} items for vendor $vendorId at market $marketId');
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error updating vendor market items: $e');
      return false;
    }
  }

  /// Get all vendors and their items for a specific market (for shoppers)
  static Future<Map<String, List<String>>> getMarketVendorItems(String marketId) async {
    try {
      debugPrint('🔍 Getting vendor items for market: $marketId');
      
      final query = await _firestore
          .collection('vendor_market_items')
          .where('marketId', isEqualTo: marketId)
          .where('isActive', isEqualTo: true)
          .get();

      final Map<String, List<String>> vendorItems = {};
      
      for (final doc in query.docs) {
        try {
          final items = VendorMarketItems.fromFirestore(doc);
          if (items.itemList.isNotEmpty) {
            vendorItems[items.vendorId] = items.itemList;
          }
        } catch (docError) {
          debugPrint('⚠️ Error processing vendor items document ${doc.id}: $docError');
          continue; // Skip this document and continue with others
        }
      }

      debugPrint('📦 Found ${vendorItems.length} vendors with items for market $marketId');
      
      // Log sample items for debugging
      if (vendorItems.isNotEmpty) {
        final sampleVendor = vendorItems.keys.first;
        final sampleItems = vendorItems[sampleVendor]!;
        debugPrint('📦 Sample items from vendor $sampleVendor: ${sampleItems.take(3).join(', ')}');
      }
      
      return vendorItems;
    } catch (e) {
      debugPrint('❌ Error getting market vendor items for market $marketId: $e');
      // Return empty map instead of throwing, so UI can handle gracefully
      return {};
    }
  }

  /// Get real-time stream of vendor items for a market (for reactive UI)
  static Stream<Map<String, List<String>>> getMarketVendorItemsStream(String marketId) {
    try {
      debugPrint('🔄 Setting up real-time stream for market vendor items: $marketId');
      
      return _firestore
          .collection('vendor_market_items')
          .where('marketId', isEqualTo: marketId)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
            final Map<String, List<String>> vendorItems = {};
            
            for (final doc in snapshot.docs) {
              try {
                final items = VendorMarketItems.fromFirestore(doc);
                if (items.itemList.isNotEmpty) {
                  vendorItems[items.vendorId] = items.itemList;
                }
              } catch (docError) {
                debugPrint('⚠️ Error processing vendor items document ${doc.id} in stream: $docError');
                continue;
              }
            }
            
            debugPrint('📦 Stream update: ${vendorItems.length} vendors with items for market $marketId');
            return vendorItems;
          });
    } catch (e) {
      debugPrint('❌ Error setting up market vendor items stream for market $marketId: $e');
      // Return empty stream
      return Stream.value(<String, List<String>>{});
    }
  }

  /// Delete vendor's item list for a market
  static Future<bool> deleteVendorMarketItems(String vendorId, String marketId) async {
    try {
      final query = await _firestore
          .collection('vendor_market_items')
          .where('vendorId', isEqualTo: vendorId)
          .where('marketId', isEqualTo: marketId)
          .get();

      for (final doc in query.docs) {
        await doc.reference.delete();
      }

      debugPrint('🗑️ Deleted items for vendor $vendorId at market $marketId');
      return true;
    } catch (e) {
      debugPrint('Error deleting vendor market items: $e');
      return false;
    }
  }

  /// Get vendor's approved markets (for item management UI)
  static Future<List<Map<String, dynamic>>> getVendorApprovedMarkets(String vendorId) async {
    try {
      // Get approved vendor applications
      final appsQuery = await _firestore
          .collection('vendor_applications')
          .where('vendorId', isEqualTo: vendorId)
          .where('status', isEqualTo: 'approved')
          .get();

      final List<Map<String, dynamic>> markets = [];

      for (final appDoc in appsQuery.docs) {
        final marketId = appDoc.data()['marketId'] as String?;
        if (marketId != null) {
          // Get market details
          final marketDoc = await _firestore.collection('markets').doc(marketId).get();
          if (marketDoc.exists) {
            final marketData = marketDoc.data()!;
            
            // Get current items for this market
            final currentItems = await getVendorMarketItems(vendorId, marketId);
            
            markets.add({
              'marketId': marketId,
              'marketName': marketData['name'] ?? 'Unknown Market',
              'city': marketData['city'] ?? '',
              'currentItems': currentItems?.itemList ?? <String>[],
              'itemCount': currentItems?.itemList.length ?? 0,
            });
          }
        }
      }

      debugPrint('🏪 Found ${markets.length} approved markets for vendor $vendorId');
      return markets;
    } catch (e) {
      debugPrint('Error getting vendor approved markets: $e');
      return [];
    }
  }
}