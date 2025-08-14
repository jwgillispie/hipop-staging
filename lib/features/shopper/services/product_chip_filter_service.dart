import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/services/user_profile_service.dart';
import '../../vendor/models/vendor_post.dart';

/// Service for managing product chip filtering in the shopper experience
class ProductChipFilterService {
  final UserProfileService _userProfileService;
  final FirebaseFirestore _firestore;

  ProductChipFilterService({
    UserProfileService? userProfileService,
    FirebaseFirestore? firestore,
  }) : _userProfileService = userProfileService ?? UserProfileService(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get unique product chips from vendor profiles in a specific location
  /// If [city] is empty, returns chips from all vendor profiles
  Future<List<String>> getAvailableProductChips({String city = ''}) async {
    try {
      debugPrint('🔍 Getting available product chips for location: ${city.isEmpty ? "All locations" : city}');
      
      Set<String> uniqueChips = {};

      if (city.isEmpty) {
        // Get all vendor profiles and extract their categories
        final allVendors = await _userProfileService.getProfilesByUserType('vendor');
        debugPrint('📊 Found ${allVendors.length} total vendors');
        
        for (final vendor in allVendors) {
          uniqueChips.addAll(vendor.categories);
        }
      } else {
        // Get vendor posts in the specified location to identify active vendors
        final vendorPosts = await _getVendorPostsByLocation(city);
        debugPrint('📊 Found ${vendorPosts.length} vendor posts in $city');
        
        // Get unique vendor IDs from posts
        final vendorIds = vendorPosts.map((post) => post.vendorId).toSet();
        debugPrint('👥 Found ${vendorIds.length} unique vendors in $city');
        
        // Get vendor profiles for these vendors
        for (final vendorId in vendorIds) {
          final vendorProfile = await _userProfileService.getUserProfile(vendorId);
          if (vendorProfile != null && vendorProfile.userType == 'vendor') {
            uniqueChips.addAll(vendorProfile.categories);
          }
        }
      }

      final chipsList = uniqueChips.toList()..sort();
      debugPrint('✅ Found ${chipsList.length} unique product chips: $chipsList');
      
      return chipsList;
    } catch (e) {
      debugPrint('❌ Error getting available product chips: $e');
      return [];
    }
  }

  /// Get vendor posts by location (helper method)
  Future<List<VendorPost>> _getVendorPostsByLocation(String city) async {
    try {
      final searchKeyword = city.toLowerCase().trim();
      
      final snapshot = await _firestore
          .collection('vendor_posts')
          .where('isActive', isEqualTo: true)
          .get();
      
      final allPosts = snapshot.docs
          .map((doc) => VendorPost.fromFirestore(doc))
          .toList();
      
      // Filter by location
      final filteredPosts = allPosts.where((post) {
        final locationMatch = post.location.toLowerCase().contains(searchKeyword);
        final keywordMatch = post.locationKeywords.any((keyword) => 
            keyword.toLowerCase().contains(searchKeyword));
        
        return locationMatch || keywordMatch;
      }).toList();
      
      return filteredPosts;
    } catch (e) {
      debugPrint('❌ Error getting vendor posts by location: $e');
      return [];
    }
  }

  /// Filter vendor posts by selected product chips
  Future<List<VendorPost>> filterVendorPostsByChips({
    required List<VendorPost> posts,
    required List<String> selectedChips,
  }) async {
    if (selectedChips.isEmpty) {
      return posts;
    }

    try {
      debugPrint('🔍 Filtering ${posts.length} posts by chips: $selectedChips');
      
      final filteredPosts = <VendorPost>[];
      
      for (final post in posts) {
        // Get vendor profile to check their categories
        final vendorProfile = await _userProfileService.getUserProfile(post.vendorId);
        
        if (vendorProfile != null && vendorProfile.userType == 'vendor') {
          // Check if vendor has any of the selected chips
          final hasMatchingChip = selectedChips.any((chip) => 
              vendorProfile.categories.contains(chip));
          
          if (hasMatchingChip) {
            filteredPosts.add(post);
          }
        }
      }
      
      debugPrint('✅ Filtered to ${filteredPosts.length} posts with matching chips');
      return filteredPosts;
    } catch (e) {
      debugPrint('❌ Error filtering vendor posts by chips: $e');
      return posts; // Return original posts if filtering fails
    }
  }

  /// Get vendor profiles by selected product chips and location
  Future<List<UserProfile>> getVendorsByChipsAndLocation({
    required List<String> selectedChips,
    String city = '',
  }) async {
    try {
      debugPrint('🔍 Getting vendors by chips: $selectedChips and location: ${city.isEmpty ? "All" : city}');
      
      if (selectedChips.isEmpty) {
        return [];
      }

      Set<UserProfile> matchingVendors = {};

      if (city.isEmpty) {
        // Get vendors for each selected chip and combine results
        for (final chip in selectedChips) {
          final vendorsForChip = await _userProfileService.getVendorsByCategory(chip);
          matchingVendors.addAll(vendorsForChip);
        }
      } else {
        // First get vendors active in the location
        final vendorPosts = await _getVendorPostsByLocation(city);
        final activeVendorIds = vendorPosts.map((post) => post.vendorId).toSet();
        
        // Then filter by chips
        for (final vendorId in activeVendorIds) {
          final vendor = await _userProfileService.getUserProfile(vendorId);
          if (vendor != null && 
              vendor.userType == 'vendor' && 
              vendor.categories.any((category) => selectedChips.contains(category))) {
            matchingVendors.add(vendor);
          }
        }
      }

      final result = matchingVendors.toList();
      debugPrint('✅ Found ${result.length} vendors matching criteria');
      
      return result;
    } catch (e) {
      debugPrint('❌ Error getting vendors by chips and location: $e');
      return [];
    }
  }

  /// Stream of available product chips for real-time updates
  Stream<List<String>> watchAvailableProductChips({String city = ''}) {
    // For simplicity, we'll return a stream that emits once with the current data
    // In a more complex implementation, you might want to listen to changes in vendor profiles
    return Stream.fromFuture(getAvailableProductChips(city: city));
  }

  /// Validate that the provided chips exist in the system
  Future<List<String>> validateChips(List<String> chips) async {
    try {
      final availableChips = await getAvailableProductChips();
      return chips.where((chip) => availableChips.contains(chip)).toList();
    } catch (e) {
      debugPrint('❌ Error validating chips: $e');
      return [];
    }
  }

  /// Get popular product chips (most common across vendors)
  Future<List<String>> getPopularProductChips({int limit = 10}) async {
    try {
      debugPrint('🔍 Getting popular product chips (limit: $limit)');
      
      final allVendors = await _userProfileService.getProfilesByUserType('vendor');
      
      // Count frequency of each chip
      final chipCounts = <String, int>{};
      for (final vendor in allVendors) {
        for (final category in vendor.categories) {
          chipCounts[category] = (chipCounts[category] ?? 0) + 1;
        }
      }
      
      // Sort by frequency and return top chips
      final sortedChips = chipCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      final popularChips = sortedChips
          .take(limit)
          .map((entry) => entry.key)
          .toList();
      
      debugPrint('✅ Popular chips: $popularChips');
      return popularChips;
    } catch (e) {
      debugPrint('❌ Error getting popular product chips: $e');
      return [];
    }
  }
}