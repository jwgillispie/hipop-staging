import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hipop/features/vendor/models/vendor_market.dart';
import '../../market/models/market.dart';
import '../models/market_schedule.dart';

class MarketService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection references
  static final CollectionReference _marketsCollection = _firestore.collection('markets');
  static final CollectionReference _marketSchedulesCollection = _firestore.collection('market_schedules');
  static final CollectionReference _vendorMarketsCollection = _firestore.collection('vendor_markets');

  // Market CRUD operations
  static Future<String> createMarket(Market market) async {
    try {
      final docRef = await _marketsCollection.add(market.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create market: $e');
    }
  }

  static Future<Market?> getMarket(String marketId) async {
    try {
      final doc = await _marketsCollection.doc(marketId).get();
      if (doc.exists) {
        final market = Market.fromFirestore(doc);
        // Only return active markets
        if (market.isActive) {
          return market;
        }
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get market: $e');
    }
  }

  static Future<List<Market>> getMarketsByCity(String city) async {
    try {
      debugPrint('MarketService: Searching for markets with city = "$city"');
      
      final querySnapshot = await _marketsCollection
          .where('city', isEqualTo: city)
          .where('isActive', isEqualTo: true)
          .get();
      
      final markets = querySnapshot.docs
          .map((doc) => Market.fromFirestore(doc))
          .toList();
          
      debugPrint('MarketService: Query returned ${markets.length} markets');
      
      // If no exact match found, try more flexible searching
      if (markets.isEmpty) {
        debugPrint('MarketService: No exact match found, trying flexible search...');
        return await _getMarketsByCityFlexible(city);
      }
      
      return markets;
    } catch (e) {
      throw Exception('Failed to get markets by city: $e');
    }
  }
  
  // City aliases for common abbreviations and alternative names
  static const Map<String, List<String>> _cityAliases = {
    'atlanta': ['atl', 'hotlanta', 'the a', 'atlanta georgia', 'atlanta ga'],
    'decatur': ['dec', 'decatur georgia', 'decatur ga'],
    'marietta': ['marietta georgia', 'marietta ga'],
    'athens': ['athens georgia', 'athens ga', 'classic city'],
    'savannah': ['savannah georgia', 'savannah ga', 'sav'],
    'columbus': ['columbus georgia', 'columbus ga'],
    'augusta': ['augusta georgia', 'augusta ga'],
    'macon': ['macon georgia', 'macon ga'],
    'sandy springs': ['sandy springs georgia', 'sandy springs ga'],
    'roswell': ['roswell georgia', 'roswell ga'],
    'johns creek': ['johns creek georgia', 'johns creek ga'],
    'alpharetta': ['alpharetta georgia', 'alpharetta ga'],
    'warner robins': ['warner robins georgia', 'warner robins ga'],
    'smyrna': ['smyrna georgia', 'smyrna ga'],
    'dunwoody': ['dunwoody georgia', 'dunwoody ga'],
  };

  static String _normalizeSearchCity(String searchCity) {
    final normalized = searchCity.toLowerCase().trim();
    
    // Check if the search term is an alias
    for (final entry in _cityAliases.entries) {
      final city = entry.key;
      final aliases = entry.value;
      
      // Check if normalized search matches any alias
      for (final alias in aliases) {
        if (normalized == alias || 
            normalized.startsWith('$alias ') || 
            normalized.endsWith(' $alias') ||
            normalized.contains(' $alias ')) {
          return city;
        }
      }
    }
    
    // Remove common suffixes and return normalized
    return normalized
        .replaceAll(RegExp(r',\s*(ga|georgia|al|alabama|fl|florida|sc|south carolina|nc|north carolina|tn|tennessee)\s*$'), '')
        .replaceAll(RegExp(r',\s*usa\s*$'), '')
        .trim();
  }

  static Future<List<Market>> _getMarketsByCityFlexible(String searchCity) async {
    try {
      // Get all active markets and filter in memory for flexible matching
      final querySnapshot = await _marketsCollection
          .where('isActive', isEqualTo: true)
          .get();
      
      final allMarkets = querySnapshot.docs
          .map((doc) => Market.fromFirestore(doc))
          .toList();
          
      debugPrint('MarketService: Total active markets: ${allMarkets.length}');
      
      // Normalize search city for comparison (handles aliases)
      final normalizedSearchCity = _normalizeSearchCity(searchCity);
      debugPrint('MarketService: Normalized search city: "$searchCity" -> "$normalizedSearchCity"');
      
      // Filter markets with flexible matching
      final matchingMarkets = allMarkets.where((market) {
        final marketCity = market.city.toLowerCase().trim();
        final marketState = market.state.toLowerCase().trim();
        final marketAddress = market.address.toLowerCase().trim();
        
        // Exact match (case insensitive)
        if (marketCity == normalizedSearchCity) {
          return true;
        }
        
        // Check if search city contains market city (e.g., "Atlanta, GA" contains "Atlanta")
        if (normalizedSearchCity.contains(marketCity)) {
          return true;
        }
        
        // Check if market city contains search city (e.g., "Atlanta" contains "Atlan")
        if (marketCity.contains(normalizedSearchCity)) {
          return true;
        }
        
        // Check market address for partial matches
        if (marketAddress.contains(normalizedSearchCity)) {
          return true;
        }
        
        // Check state matches for abbreviations
        if (normalizedSearchCity.length == 2 && marketState.startsWith(normalizedSearchCity)) {
          return true;
        }
        
        // Check common variations (e.g., "Decatur" matches "Decatur City")
        final searchWords = normalizedSearchCity.split(' ');
        final marketWords = marketCity.split(' ');
        
        for (final searchWord in searchWords) {
          for (final marketWord in marketWords) {
            if (searchWord.length >= 3 && marketWord.length >= 3) {
              if (searchWord.startsWith(marketWord) || marketWord.startsWith(searchWord)) {
                return true;
              }
            }
          }
        }
        
        return false;
      }).toList();
      
      debugPrint('MarketService: Flexible search found ${matchingMarkets.length} markets');
      for (final market in matchingMarkets) {
        debugPrint('  - ${market.name} in ${market.city}, ${market.state}');
      }
      
      return matchingMarkets;
    } catch (e) {
      debugPrint('MarketService: Error in flexible search: $e');
      return [];
    }
  }

  static Future<List<Market>> getAllActiveMarkets() async {
    try {
      final querySnapshot = await _marketsCollection
          .where('isActive', isEqualTo: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) => Market.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get all markets: $e');
    }
  }

  // Stream-based methods for real-time updates
  static Stream<List<Market>> getAllActiveMarketsStream() {
    return _marketsCollection
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Market.fromFirestore(doc))
            .toList());
  }

  static Stream<List<Market>> getMarketsByCityStream(String city) {
    return _marketsCollection
        .where('city', isEqualTo: city)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Market.fromFirestore(doc))
            .toList());
  }

  static Stream<List<Market>> getMarketsByIdsStream(List<String> marketIds) {
    if (marketIds.isEmpty) {
      return Stream.value([]);
    }
    
    return _marketsCollection
        .where(FieldPath.documentId, whereIn: marketIds)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Market.fromFirestore(doc))
            .toList());
  }

  static Future<void> updateMarket(String marketId, Map<String, dynamic> updates) async {
    try {
      await _marketsCollection.doc(marketId).update(updates);
    } catch (e) {
      throw Exception('Failed to update market: $e');
    }
  }

  static Future<void> deleteMarket(String marketId) async {
    try {
      await _marketsCollection.doc(marketId).update({'isActive': false});
    } catch (e) {
      throw Exception('Failed to delete market: $e');
    }
  }

  // Market Schedule operations
  static Future<String> createMarketSchedule(MarketSchedule schedule) async {
    try {
      final docRef = await _marketSchedulesCollection.add(schedule.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create market schedule: $e');
    }
  }

  static Future<List<MarketSchedule>> getMarketSchedules(String marketId) async {
    try {
      final querySnapshot = await _marketSchedulesCollection
          .where('marketId', isEqualTo: marketId)
          .get();
      
      return querySnapshot.docs
          .map((doc) => MarketSchedule.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get market schedules: $e');
    }
  }

  static Future<void> updateMarketSchedule(String scheduleId, Map<String, dynamic> updates) async {
    try {
      await _marketSchedulesCollection.doc(scheduleId).update(updates);
    } catch (e) {
      throw Exception('Failed to update market schedule: $e');
    }
  }

  static Future<void> deleteMarketSchedule(String scheduleId) async {
    try {
      await _marketSchedulesCollection.doc(scheduleId).delete();
    } catch (e) {
      throw Exception('Failed to delete market schedule: $e');
    }
  }

  // VendorMarket relationship operations
  static Future<String> createVendorMarketRelationship(VendorMarket vendorMarket) async {
    try {
      final docRef = await _vendorMarketsCollection.add(vendorMarket.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create vendor-market relationship: $e');
    }
  }

  static Future<List<VendorMarket>> getVendorMarkets(String vendorId) async {
    try {
      final querySnapshot = await _vendorMarketsCollection
          .where('vendorId', isEqualTo: vendorId)
          .where('isActive', isEqualTo: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) => VendorMarket.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get vendor markets: $e');
    }
  }

  static Future<List<VendorMarket>> getMarketVendors(String marketId) async {
    try {
      final querySnapshot = await _vendorMarketsCollection
          .where('marketId', isEqualTo: marketId)
          .where('isActive', isEqualTo: true)
          .where('isApproved', isEqualTo: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) => VendorMarket.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get market vendors: $e');
    }
  }

  static Future<List<VendorMarket>> getActiveVendorsForMarketToday(String marketId) async {
    try {
      final today = DateTime.now().weekday;
      final dayName = _getDayName(today);
      
      final querySnapshot = await _vendorMarketsCollection
          .where('marketId', isEqualTo: marketId)
          .where('isActive', isEqualTo: true)
          .where('isApproved', isEqualTo: true)
          .where('schedule', arrayContains: dayName)
          .get();
      
      return querySnapshot.docs
          .map((doc) => VendorMarket.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get active vendors for today: $e');
    }
  }

  static Future<void> updateVendorMarketRelationship(String relationshipId, Map<String, dynamic> updates) async {
    try {
      await _vendorMarketsCollection.doc(relationshipId).update(updates);
    } catch (e) {
      throw Exception('Failed to update vendor-market relationship: $e');
    }
  }

  static Future<void> approveVendorForMarket(String relationshipId) async {
    try {
      await _vendorMarketsCollection.doc(relationshipId).update({'isApproved': true});
    } catch (e) {
      throw Exception('Failed to approve vendor for market: $e');
    }
  }

  static Future<void> removeVendorFromMarket(String relationshipId) async {
    try {
      await _vendorMarketsCollection.doc(relationshipId).update({'isActive': false});
    } catch (e) {
      throw Exception('Failed to remove vendor from market: $e');
    }
  }

  // Helper methods
  static String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'monday';
      case 2: return 'tuesday';
      case 3: return 'wednesday';
      case 4: return 'thursday';
      case 5: return 'friday';
      case 6: return 'saturday';
      case 7: return 'sunday';
      default: return '';
    }
  }

}