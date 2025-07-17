import 'package:flutter/foundation.dart';
import '../repositories/favorites_repository.dart';
import '../services/favorites_service.dart';
import '../models/user_favorite.dart';

class FavoritesMigrationService {
  static final FavoritesRepository _localRepository = FavoritesRepository();

  /// Migrates local favorites to user account when user logs in
  static Future<void> migrateLocalFavoritesToUser(String userId) async {
    try {
      // Get existing local favorites
      final localPostIds = await _localRepository.getFavoritePostIds();
      final localVendorIds = await _localRepository.getFavoriteVendorIds();
      final localMarketIds = await _localRepository.getFavoriteMarketIds();

      // Check if user already has cloud favorites to avoid duplicates
      final existingVendorFavorites = await FavoritesService.getUserFavoriteVendors(userId);
      final existingMarketFavorites = await FavoritesService.getUserFavoriteMarkets(userId);
      
      final existingVendorIds = existingVendorFavorites.map((v) => v.id).toSet();
      final existingMarketIds = existingMarketFavorites.map((m) => m.id).toSet();

      // Migrate vendor favorites
      for (final vendorId in localVendorIds) {
        if (!existingVendorIds.contains(vendorId)) {
          try {
            await FavoritesService.addFavorite(
              userId: userId,
              itemId: vendorId,
              type: FavoriteType.vendor,
            );
            debugPrint('Migrated vendor favorite: $vendorId');
          } catch (e) {
            debugPrint('Failed to migrate vendor favorite $vendorId: $e');
          }
        }
      }

      // Migrate market favorites
      for (final marketId in localMarketIds) {
        if (!existingMarketIds.contains(marketId)) {
          try {
            await FavoritesService.addFavorite(
              userId: userId,
              itemId: marketId,
              type: FavoriteType.market,
            );
            debugPrint('Migrated market favorite: $marketId');
          } catch (e) {
            debugPrint('Failed to migrate market favorite $marketId: $e');
          }
        }
      }

      // Note: Post favorites are not migrated as they're not supported in Firestore service yet
      if (localPostIds.isNotEmpty) {
        debugPrint('${localPostIds.length} post favorites not migrated (not supported in cloud storage yet)');
      }

      debugPrint('Favorites migration completed. Migrated ${localVendorIds.length} vendors, ${localMarketIds.length} markets');
    } catch (e) {
      debugPrint('Error during favorites migration: $e');
      throw Exception('Failed to migrate favorites: $e');
    }
  }

  /// Checks if local favorites exist (to decide whether migration is needed)
  static Future<bool> hasLocalFavorites() async {
    try {
      final localPostIds = await _localRepository.getFavoritePostIds();
      final localVendorIds = await _localRepository.getFavoriteVendorIds();
      final localMarketIds = await _localRepository.getFavoriteMarketIds();

      return localPostIds.isNotEmpty || localVendorIds.isNotEmpty || localMarketIds.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking local favorites: $e');
      return false;
    }
  }

  /// Clears local favorites after successful migration
  static Future<void> clearLocalFavoritesAfterMigration() async {
    try {
      await _localRepository.clearAllFavorites();
      debugPrint('Local favorites cleared after migration');
    } catch (e) {
      debugPrint('Error clearing local favorites: $e');
    }
  }

  /// Gets count of local favorites for migration preview
  static Future<Map<String, int>> getLocalFavoritesCounts() async {
    try {
      final localPostIds = await _localRepository.getFavoritePostIds();
      final localVendorIds = await _localRepository.getFavoriteVendorIds();
      final localMarketIds = await _localRepository.getFavoriteMarketIds();

      return {
        'posts': localPostIds.length,
        'vendors': localVendorIds.length,
        'markets': localMarketIds.length,
      };
    } catch (e) {
      debugPrint('Error getting local favorites counts: $e');
      return {'posts': 0, 'vendors': 0, 'markets': 0};
    }
  }
}