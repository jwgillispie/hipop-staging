import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hipop/features/market/services/market_service.dart';
import 'package:hipop/features/vendor/services/managed_vendor_service.dart';
import 'package:hipop/features/shared/services/real_time_analytics_service.dart';
import '../models/user_favorite.dart';
import '../../market/models/market.dart';
import '../../vendor/models/managed_vendor.dart';
import '../models/event.dart';

import 'event_service.dart';

class FavoritesService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _favoritesCollection = _firestore.collection('user_favorites');

  // Add a favorite
  static Future<String> addFavorite({
    required String userId,
    required String itemId,
    required FavoriteType type,
  }) async {
    try {
      // Check if already favorited
      final existing = await _favoritesCollection
          .where('userId', isEqualTo: userId)
          .where('itemId', isEqualTo: itemId)
          .where('type', isEqualTo: type.name)
          .get();

      if (existing.docs.isNotEmpty) {
        // Already favorited, return existing ID
        return existing.docs.first.id;
      }

      // Create new favorite
      final favorite = UserFavorite(
        id: '',
        userId: userId,
        itemId: itemId,
        type: type,
        createdAt: DateTime.now(),
      );

      final docRef = await _favoritesCollection.add(favorite.toFirestore());
      
      // Track favorite added analytics
      try {
        await RealTimeAnalyticsService.trackEvent(
          EventTypes.favorite,
          {
            'action': 'add',
            'itemType': type.name,
            'itemId': itemId,
          },
          userId: userId,
        );
      } catch (e) {
        debugPrint('Failed to track favorite add: $e');
      }
      
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add favorite: $e');
    }
  }

  // Remove a favorite
  static Future<void> removeFavorite({
    required String userId,
    required String itemId,
    required FavoriteType type,
  }) async {
    try {
      final querySnapshot = await _favoritesCollection
          .where('userId', isEqualTo: userId)
          .where('itemId', isEqualTo: itemId)
          .where('type', isEqualTo: type.name)
          .get();

      for (final doc in querySnapshot.docs) {
        await doc.reference.delete();
      }
      
      // Track favorite removed analytics
      try {
        await RealTimeAnalyticsService.trackEvent(
          EventTypes.favorite,
          {
            'action': 'remove',
            'itemType': type.name,
            'itemId': itemId,
          },
          userId: userId,
        );
      } catch (e) {
        debugPrint('Failed to track favorite remove: $e');
      }
    } catch (e) {
      throw Exception('Failed to remove favorite: $e');
    }
  }

  // Check if an item is favorited
  static Future<bool> isFavorited({
    required String userId,
    required String itemId,
    required FavoriteType type,
  }) async {
    try {
      final querySnapshot = await _favoritesCollection
          .where('userId', isEqualTo: userId)
          .where('itemId', isEqualTo: itemId)
          .where('type', isEqualTo: type.name)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking if favorited: $e');
      return false;
    }
  }

  // Toggle favorite status
  static Future<bool> toggleFavorite({
    required String userId,
    required String itemId,
    required FavoriteType type,
  }) async {
    try {
      final isFav = await isFavorited(
        userId: userId,
        itemId: itemId,
        type: type,
      );

      if (isFav) {
        await removeFavorite(
          userId: userId,
          itemId: itemId,
          type: type,
        );
        return false;
      } else {
        await addFavorite(
          userId: userId,
          itemId: itemId,
          type: type,
        );
        return true;
      }
    } catch (e) {
      throw Exception('Failed to toggle favorite: $e');
    }
  }

  // Get user's favorite vendor IDs only (fast for BLoC state)
  static Future<List<String>> getUserFavoriteVendorIds(String userId) async {
    try {
      final favoritesSnapshot = await _favoritesCollection
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: FavoriteType.vendor.name)
          .get();

      return favoritesSnapshot.docs
          .map((doc) => UserFavorite.fromFirestore(doc).itemId)
          .toList();
    } catch (e) {
      throw Exception('Failed to get favorite vendor IDs: $e');
    }
  }

  // Get user's favorite vendors with full vendor data
  static Future<List<ManagedVendor>> getUserFavoriteVendors(String userId) async {
    try {
      final favoritesSnapshot = await _favoritesCollection
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: FavoriteType.vendor.name)
          .orderBy('createdAt', descending: true)
          .get();

      final vendors = <ManagedVendor>[];
      
      for (final doc in favoritesSnapshot.docs) {
        final favorite = UserFavorite.fromFirestore(doc);
        try {
          final vendor = await ManagedVendorService.getVendor(favorite.itemId);
          if (vendor != null) {
            vendors.add(vendor);
          }
        } catch (e) {
          debugPrint('Error fetching vendor ${favorite.itemId}: $e');
        }
      }

      return vendors;
    } catch (e) {
      throw Exception('Failed to get favorite vendors: $e');
    }
  }

  // Get user's favorite market IDs only (fast for BLoC state)
  static Future<List<String>> getUserFavoriteMarketIds(String userId) async {
    try {
      final favoritesSnapshot = await _favoritesCollection
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: FavoriteType.market.name)
          .get();

      return favoritesSnapshot.docs
          .map((doc) => UserFavorite.fromFirestore(doc).itemId)
          .toList();
    } catch (e) {
      throw Exception('Failed to get favorite market IDs: $e');
    }
  }

  // Get user's favorite markets with full market data
  static Future<List<Market>> getUserFavoriteMarkets(String userId) async {
    try {
      final favoritesSnapshot = await _favoritesCollection
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: FavoriteType.market.name)
          .orderBy('createdAt', descending: true)
          .get();

      final markets = <Market>[];
      
      for (final doc in favoritesSnapshot.docs) {
        final favorite = UserFavorite.fromFirestore(doc);
        try {
          final market = await MarketService.getMarket(favorite.itemId);
          if (market != null) {
            markets.add(market);
          }
        } catch (e) {
          debugPrint('Error fetching market ${favorite.itemId}: $e');
        }
      }

      return markets;
    } catch (e) {
      throw Exception('Failed to get favorite markets: $e');
    }
  }

  // Stream user's favorite vendors
  static Stream<List<ManagedVendor>> streamUserFavoriteVendors(String userId) {
    return _favoritesCollection
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: FavoriteType.vendor.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final vendors = <ManagedVendor>[];
      
      for (final doc in snapshot.docs) {
        final favorite = UserFavorite.fromFirestore(doc);
        try {
          final vendor = await ManagedVendorService.getVendor(favorite.itemId);
          if (vendor != null) {
            vendors.add(vendor);
          }
        } catch (e) {
          debugPrint('Error fetching vendor ${favorite.itemId}: $e');
        }
      }
      
      return vendors;
    });
  }

  // Stream user's favorite markets
  static Stream<List<Market>> streamUserFavoriteMarkets(String userId) {
    return _favoritesCollection
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: FavoriteType.market.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final markets = <Market>[];
      
      for (final doc in snapshot.docs) {
        final favorite = UserFavorite.fromFirestore(doc);
        try {
          final market = await MarketService.getMarket(favorite.itemId);
          if (market != null) {
            markets.add(market);
          }
        } catch (e) {
          debugPrint('Error fetching market ${favorite.itemId}: $e');
        }
      }
      
      return markets;
    });
  }

  // Get user's favorite event IDs only (fast for BLoC state)
  static Future<List<String>> getUserFavoriteEventIds(String userId) async {
    try {
      final favoritesSnapshot = await _favoritesCollection
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: FavoriteType.event.name)
          .get();

      return favoritesSnapshot.docs
          .map((doc) => UserFavorite.fromFirestore(doc).itemId)
          .toList();
    } catch (e) {
      throw Exception('Failed to get favorite event IDs: $e');
    }
  }

  // Get user's favorite events with full event data
  static Future<List<Event>> getUserFavoriteEvents(String userId) async {
    try {
      final favoritesSnapshot = await _favoritesCollection
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: FavoriteType.event.name)
          .orderBy('createdAt', descending: true)
          .get();

      final events = <Event>[];
      
      for (final doc in favoritesSnapshot.docs) {
        final favorite = UserFavorite.fromFirestore(doc);
        try {
          final event = await EventService.getEvent(favorite.itemId);
          if (event != null) {
            events.add(event);
          }
        } catch (e) {
          debugPrint('Error fetching event ${favorite.itemId}: $e');
        }
      }

      return events;
    } catch (e) {
      throw Exception('Failed to get favorite events: $e');
    }
  }

  // Stream user's favorite events
  static Stream<List<Event>> streamUserFavoriteEvents(String userId) {
    return _favoritesCollection
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: FavoriteType.event.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final events = <Event>[];
      
      for (final doc in snapshot.docs) {
        final favorite = UserFavorite.fromFirestore(doc);
        try {
          final event = await EventService.getEvent(favorite.itemId);
          if (event != null) {
            events.add(event);
          }
        } catch (e) {
          debugPrint('Error fetching event ${favorite.itemId}: $e');
        }
      }
      
      return events;
    });
  }

  // Get favorite counts for a user
  static Future<Map<String, int>> getFavoriteCounts(String userId) async {
    try {
      final snapshot = await _favoritesCollection
          .where('userId', isEqualTo: userId)
          .get();

      int vendorCount = 0;
      int marketCount = 0;
      int eventCount = 0;

      for (final doc in snapshot.docs) {
        final favorite = UserFavorite.fromFirestore(doc);
        if (favorite.type == FavoriteType.vendor) {
          vendorCount++;
        } else if (favorite.type == FavoriteType.market) {
          marketCount++;
        } else if (favorite.type == FavoriteType.event) {
          eventCount++;
        }
      }

      return {
        'vendors': vendorCount,
        'markets': marketCount,
        'events': eventCount,
      };
    } catch (e) {
      debugPrint('Error getting favorite counts: $e');
      return {'vendors': 0, 'markets': 0, 'events': 0};
    }
  }

  // Clear all favorites for a user
  static Future<void> clearAllFavorites(String userId) async {
    try {
      final snapshot = await _favoritesCollection
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to clear favorites: $e');
    }
  }
}