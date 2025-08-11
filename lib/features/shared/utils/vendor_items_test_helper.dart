import 'package:flutter/foundation.dart';
import '../../vendor/services/vendor_market_items_service.dart';

/// Helper class for testing vendor items integration
/// This will help validate the implementation and provide debugging info
class VendorItemsTestHelper {
  
  /// Test vendor items loading for a specific market
  static Future<void> testMarketVendorItems(String marketId) async {
    try {
      debugPrint('🧪 Testing vendor items for market: $marketId');
      
      // Test the basic future method
      final items = await VendorMarketItemsService.getMarketVendorItems(marketId);
      debugPrint('✅ Future method returned ${items.length} vendors with items');
      
      if (items.isNotEmpty) {
        items.forEach((vendorId, itemList) {
          debugPrint('  📦 Vendor $vendorId has ${itemList.length} items: ${itemList.join(", ")}');
        });
      } else {
        debugPrint('⚠️ No vendor items found for market $marketId');
      }
      
      // Test the stream method
      debugPrint('🔄 Testing stream method...');
      final stream = VendorMarketItemsService.getMarketVendorItemsStream(marketId);
      await for (final streamItems in stream.take(1)) {
        debugPrint('✅ Stream method returned ${streamItems.length} vendors with items');
        break;
      }
      
    } catch (e) {
      debugPrint('❌ Test failed for market $marketId: $e');
    }
  }
  
  /// Test the vendor items widgets with sample data
  static Map<String, List<String>> getSampleVendorItems() {
    return {
      'vendor1': ['Fresh Tomatoes', 'Organic Lettuce', 'Handmade Bread'],
      'vendor2': ['Artisan Cheese', 'Local Honey', 'Seasonal Fruits'],
      'vendor3': ['Craft Beer', 'Homemade Jams', 'Fresh Herbs'],
    };
  }
  
  /// Get common items across vendors (for testing the preview logic)
  static List<String> getCommonItems(Map<String, List<String>> vendorItemsMap) {
    final Map<String, int> itemCounts = {};
    
    for (final vendorItems in vendorItemsMap.values) {
      for (final item in vendorItems) {
        itemCounts[item] = (itemCounts[item] ?? 0) + 1;
      }
    }

    // Sort items by frequency (most common first)
    return itemCounts.entries
        .where((e) => e.value > 1) // Only items from multiple vendors
        .map((e) => e.key)
        .take(6)
        .toList();
  }
  
  /// Test performance metrics
  static Future<void> testPerformance(String marketId) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      await VendorMarketItemsService.getMarketVendorItems(marketId);
      stopwatch.stop();
      
      final duration = stopwatch.elapsedMilliseconds;
      debugPrint('⏱️ Market vendor items loaded in ${duration}ms');
      
      if (duration > 2000) {
        debugPrint('⚠️ Performance warning: Loading took ${duration}ms (>2s)');
      } else {
        debugPrint('✅ Performance good: Loading completed in ${duration}ms');
      }
      
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ Performance test failed: $e');
    }
  }
  
  /// Validate that UI components handle edge cases
  static void logUiTestCases() {
    debugPrint('🎨 UI Test Cases to Validate:');
    debugPrint('1. Empty vendor items map');
    debugPrint('2. Single vendor with single item');
    debugPrint('3. Multiple vendors with overlapping items');
    debugPrint('4. Long item names that need truncation');
    debugPrint('5. Many items that exceed display limits');
    debugPrint('6. Network error handling');
    debugPrint('7. Loading state transitions');
    debugPrint('8. Real-time updates via stream');
  }
}