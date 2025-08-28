// import 'dart:async';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/foundation.dart';
// import 'package:rxdart/rxdart.dart';

// // Services
// import '../features/shared/services/cache_service.dart';
// import '../features/shared/services/user_profile_service.dart';
// import '../features/premium/services/subscription_service.dart';

// // Models
// import '../features/vendor/models/vendor_post.dart';
// import '../features/vendor/models/vendor_product.dart';
// import '../features/vendor/models/vendor_application.dart';
// import '../features/vendor/models/vendor_sales_data.dart';
// import '../features/vendor/models/vendor_market.dart';
// import '../features/shared/models/user_profile.dart';

// // Existing services to gradually replace
// import '../features/vendor/services/vendor_post_service.dart';  // Contains VendorPostData
// import '../features/vendor/services/vendor_product_service.dart';
// import '../features/vendor/services/vendor_application_service.dart';
// import '../features/vendor/services/vendor_sales_service.dart';
// import '../features/vendor/services/vendor_market_relationship_service.dart';
// import '../features/vendor/services/vendor_insights_service.dart';
// import '../features/vendor/services/vendor_monthly_tracking_service.dart';

// /// Cache TTL configurations for different data types
// class CacheTTL {
//   static const Duration vendor = Duration(minutes: 10);
//   static const Duration vendorPosts = Duration(minutes: 5);
//   static const Duration products = Duration(minutes: 15);
//   static const Duration analytics = Duration(minutes: 3);
//   static const Duration applications = Duration(minutes: 5);
//   static const Duration premiumStatus = Duration(minutes: 10);
//   static const Duration sales = Duration(minutes: 5);
//   static const Duration markets = Duration(minutes: 30);
// }

// /// Date range helper class
// class DateRange {
//   final DateTime start;
//   final DateTime end;
  
//   const DateRange({required this.start, required this.end});
  
//   String get cacheKey => '${start.toIso8601String()}_${end.toIso8601String()}';
// }

// /// Vendor analytics data model
// class VendorAnalytics {
//   final int totalPosts;
//   final int totalProducts;
//   final int totalSales;
//   final double totalRevenue;
//   final int totalApplications;
//   final int acceptedApplications;
//   final Map<String, dynamic> customMetrics;
//   final DateTime lastUpdated;
  
//   const VendorAnalytics({
//     required this.totalPosts,
//     required this.totalProducts,
//     required this.totalSales,
//     required this.totalRevenue,
//     required this.totalApplications,
//     required this.acceptedApplications,
//     this.customMetrics = const {},
//     required this.lastUpdated,
//   });
// }

// /// Premium status model
// class PremiumStatus {
//   final bool isPremium;
//   final String? subscriptionStatus;
//   final String? subscriptionId;
//   final DateTime? expiresAt;
//   final Map<String, int> limits;
//   final Map<String, int> usage;
  
//   const PremiumStatus({
//     required this.isPremium,
//     this.subscriptionStatus,
//     this.subscriptionId,
//     this.expiresAt,
//     this.limits = const {},
//     this.usage = const {},
//   });
  
//   bool isWithinLimit(String feature) {
//     final limit = limits[feature] ?? 0;
//     final currentUsage = usage[feature] ?? 0;
//     return limit == -1 || currentUsage < limit; // -1 means unlimited
//   }
// }

// /// Main Vendor Repository - Single source of truth for all vendor data
// class VendorRepository {
//   // Singleton pattern
//   static final VendorRepository _instance = VendorRepository._internal();
//   factory VendorRepository() => _instance;
//   VendorRepository._internal();
  
//   // Dependencies
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final CacheService _cache = CacheService();
//   final UserProfileService _userProfileService = UserProfileService();
  
//   // Legacy services (to be gradually phased out)
//   // Note: Most services use static methods, so we don't need instances
//   final VendorApplicationService _applicationService = VendorApplicationService();
//   final VendorSalesService _salesService = VendorSalesService();
//   final VendorMarketRelationshipService _marketRelationshipService = VendorMarketRelationshipService();
//   final VendorInsightsService _insightsService = VendorInsightsService();
//   final VendorMonthlyTrackingService _monthlyTrackingService = VendorMonthlyTrackingService();
  
//   // Stream controllers for real-time updates
//   final Map<String, BehaviorSubject<UserProfile?>> _vendorControllers = {};
//   final Map<String, BehaviorSubject<List<VendorPost>>> _postsControllers = {};
//   final Map<String, BehaviorSubject<List<VendorProduct>>> _productsControllers = {};
//   final Map<String, BehaviorSubject<VendorAnalytics?>> _analyticsControllers = {};
  
//   // Offline support
//   final Map<String, dynamic> _offlineCache = {};
//   bool _isOffline = false;
  
//   // =============================================================================
//   // VENDOR CRUD OPERATIONS
//   // =============================================================================
  
//   /// Get vendor profile with caching
//   Future<UserProfile?> getVendor(String vendorId) async {
//     final cacheKey = 'vendor_$vendorId';
    
//     try {
//       // Check cache first
//       final cached = _cache.get<UserProfile>(cacheKey);
//       if (cached != null) {
//         debugPrint('📦 VendorRepository: Returning cached vendor profile');
//         return cached;
//       }
      
//       // Fetch from UserProfileService
//       final profile = await _userProfileService.getUserProfile(vendorId);
      
//       if (profile != null) {
//         // Cache the result
//         _cache.set(cacheKey, profile, ttl: CacheTTL.vendor);
        
//         // Store in offline cache
//         _offlineCache[cacheKey] = profile;
//       }
      
//       return profile;
//     } catch (e) {
//       debugPrint('❌ VendorRepository: Error getting vendor: $e');
      
//       // Return offline cached data if available
//       if (_offlineCache.containsKey(cacheKey)) {
//         debugPrint('📱 VendorRepository: Returning offline cached vendor');
//         return _offlineCache[cacheKey] as UserProfile?;
//       }
      
//       rethrow;
//     }
//   }
  
//   /// Watch vendor profile changes in real-time
//   Stream<UserProfile?> watchVendor(String vendorId) {
//     final cacheKey = 'vendor_stream_$vendorId';
    
//     // Return existing stream if available
//     if (_vendorControllers.containsKey(vendorId)) {
//       return _vendorControllers[vendorId]!.stream;
//     }
    
//     // Create new stream controller
//     final controller = BehaviorSubject<UserProfile?>();
//     _vendorControllers[vendorId] = controller;
    
//     // Check cache first
//     final cached = _cache.get<UserProfile>('vendor_$vendorId');
//     if (cached != null) {
//       controller.add(cached);
//     }
    
//     // Subscribe to Firestore updates
//     _firestore
//         .collection('users')
//         .doc(vendorId)
//         .snapshots()
//         .listen(
//           (snapshot) {
//             if (snapshot.exists) {
//               final profile = UserProfile.fromFirestoreWithId(
//                 snapshot.id,
//                 snapshot.data() as Map<String, dynamic>,
//               );
              
//               // Update cache
//               _cache.set('vendor_$vendorId', profile, ttl: CacheTTL.vendor);
              
//               // Update offline cache
//               _offlineCache['vendor_$vendorId'] = profile;
              
//               // Emit to stream
//               controller.add(profile);
//             } else {
//               controller.add(null);
//             }
//           },
//           onError: (error) {
//             debugPrint('❌ VendorRepository: Error watching vendor: $error');
            
//             // Return cached data on error
//             final offline = _offlineCache['vendor_$vendorId'] as UserProfile?;
//             if (offline != null) {
//               controller.add(offline);
//             } else {
//               controller.addError(error);
//             }
//           },
//         );
    
//     return controller.stream;
//   }
  
//   /// Update vendor profile
//   Future<void> updateVendor(UserProfile vendor) async {
//     try {
//       await _userProfileService.updateUserProfile(vendor);
      
//       // Clear cache to force refresh
//       _cache.clear('vendor_${vendor.userId}');
      
//       // Update offline cache
//       _offlineCache['vendor_${vendor.userId}'] = vendor;
      
//       debugPrint('✅ VendorRepository: Vendor profile updated');
//     } catch (e) {
//       debugPrint('❌ VendorRepository: Error updating vendor: $e');
//       rethrow;
//     }
//   }
  
//   /// Delete vendor account
//   Future<void> deleteVendor(String vendorId) async {
//     try {
//       // This would need to be implemented with proper cleanup
//       // Including deleting all related data (posts, products, applications, etc.)
//       throw UnimplementedError('Vendor deletion requires comprehensive cleanup');
//     } catch (e) {
//       debugPrint('❌ VendorRepository: Error deleting vendor: $e');
//       rethrow;
//     }
//   }
  
//   // =============================================================================
//   // VENDOR POSTS OPERATIONS
//   // =============================================================================
  
//   /// Get vendor posts with pagination and caching
//   Stream<List<VendorPost>> getVendorPosts(
//     String vendorId, {
//     int limit = 20,
//     DocumentSnapshot? lastDoc,
//   }) {
//     final cacheKey = 'vendor_posts_$vendorId';
    
//     return _cache.getCachedStream(
//       cacheKey,
//       () {
//         Query query = _firestore
//             .collection('vendor_posts')
//             .where('vendorId', isEqualTo: vendorId)
//             .orderBy('createdAt', descending: true)
//             .limit(limit);
        
//         if (lastDoc != null) {
//           query = query.startAfterDocument(lastDoc);
//         }
        
//         return query.snapshots().map((snapshot) {
//           final posts = snapshot.docs
//               .map((doc) => VendorPost.fromFirestore(doc))
//               .toList();
          
//           // Store in offline cache
//           _offlineCache[cacheKey] = posts;
          
//           return posts;
//         });
//       },
//       ttl: CacheTTL.vendorPosts,
//     );
//   }
  
//   /// Create a new vendor post
//   Future<VendorPost> createPost(VendorPost post) async {
//     try {
//       // Create VendorPostData from the post
//       final postData = VendorPostData(
//         description: post.description,
//         location: post.location,
//         latitude: post.latitude,
//         longitude: post.longitude,
//         placeId: post.placeId,
//         locationName: post.locationName,
//         productListIds: post.productListIds,
//         popUpStartDateTime: post.popUpStartDateTime,
//         popUpEndDateTime: post.popUpEndDateTime,
//         photoUrls: post.photoUrls,
//         vendorNotes: post.vendorNotes,
//       );
      
//       final createdPost = await VendorPostService.createVendorPost(
//         postData: postData,
//         postType: post.postType,
//         selectedMarket: null, // Would need to fetch market if associatedMarketId is present
//       );
      
//       // Clear cache to force refresh
//       _cache.clear('vendor_posts_${post.vendorId}');
      
//       return createdPost;
//     } catch (e) {
//       debugPrint('❌ VendorRepository: Error creating post: $e');
//       rethrow;
//     }
//   }
  
//   /// Update an existing vendor post
//   Future<void> updatePost(VendorPost post) async {
//     try {
//       await VendorPostService.updateVendorPost(post);
      
//       // Clear cache to force refresh
//       _cache.clear('vendor_posts_${post.vendorId}');
      
//       debugPrint('✅ VendorRepository: Post updated');
//     } catch (e) {
//       debugPrint('❌ VendorRepository: Error updating post: $e');
//       rethrow;
//     }
//   }
  
//   /// Delete a vendor post
//   Future<void> deletePost(String postId) async {
//     try {
//       await VendorPostService.deleteVendorPost(postId);
      
//       // Clear all post caches (we don't know which vendor)
//       _cache.clearAll();
      
//       debugPrint('✅ VendorRepository: Post deleted');
//     } catch (e) {
//       debugPrint('❌ VendorRepository: Error deleting post: $e');
//       rethrow;
//     }
//   }
  
//   // =============================================================================
//   // PRODUCTS OPERATIONS
//   // =============================================================================
  
//   /// Get vendor products with caching
//   Stream<List<VendorProduct>> getVendorProducts(
//     String vendorId, {
//     int limit = 50,
//     DocumentSnapshot? lastDoc,
//   }) {
//     final cacheKey = 'vendor_products_$vendorId';
    
//     return _cache.getCachedStream(
//       cacheKey,
//       () {
//         return Stream.fromFuture(
//           VendorProductService.getVendorProducts(vendorId)
//         ).map((products) {
//           // Apply limit if specified
//           if (limit > 0 && products.length > limit) {
//             return products.take(limit).toList();
//           }
          
//           // Store in offline cache
//           _offlineCache[cacheKey] = products;
          
//           return products;
//         });
//       },
//       ttl: CacheTTL.products,
//     );
//   }
  
//   /// Create a new product
//   Future<VendorProduct> createProduct({
//     required String vendorId,
//     required String name,
//     required String category,
//     String? description,
//     double? basePrice,
//     String? imageUrl,
//     List<String>? tags,
//   }) async {
//     try {
//       final product = await VendorProductService.createProduct(
//         vendorId: vendorId,
//         name: name,
//         category: category,
//         description: description,
//         basePrice: basePrice,
//         imageUrl: imageUrl,
//         tags: tags,
//       );
      
//       // Clear cache to force refresh
//       _cache.clear('vendor_products_$vendorId');
      
//       return product;
//     } catch (e) {
//       debugPrint('❌ VendorRepository: Error creating product: $e');
//       rethrow;
//     }
//   }
  
//   /// Update a product
//   Future<VendorProduct> updateProduct(VendorProduct product) async {
//     try {
//       final updated = await VendorProductService.updateProduct(
//         productId: product.id,
//         name: product.name,
//         category: product.category,
//         description: product.description,
//         basePrice: product.basePrice,
//         imageUrl: product.imageUrl,
//         tags: product.tags,
//         isActive: product.isActive,
//       );
      
//       // Clear cache to force refresh
//       _cache.clear('vendor_products_${product.vendorId}');
      
//       return updated;
//     } catch (e) {
//       debugPrint('❌ VendorRepository: Error updating product: $e');
//       rethrow;
//     }
//   }
  
//   /// Delete a product
//   Future<void> deleteProduct(String productId) async {
//     try {
//       await VendorProductService.deleteProduct(productId);
      
//       // Clear all product caches
//       _cache.clearAll();
      
//       debugPrint('✅ VendorRepository: Product deleted');
//     } catch (e) {
//       debugPrint('❌ VendorRepository: Error deleting product: $e');
//       rethrow;
//     }
//   }
  
//   // =============================================================================
//   // ANALYTICS OPERATIONS
//   // =============================================================================
  
//   /// Get vendor analytics for a date range
//   Future<VendorAnalytics> getAnalytics(String vendorId, DateRange range) async {
//     final cacheKey = 'vendor_analytics_${vendorId}_${range.cacheKey}';
    
//     return _cache.getOrFetch(
//       cacheKey,
//       () async {
//         try {
//           // Aggregate data from multiple sources
//           final posts = await _firestore
//               .collection('vendor_posts')
//               .where('vendorId', isEqualTo: vendorId)
//               .where('createdAt', isGreaterThanOrEqualTo: range.start)
//               .where('createdAt', isLessThanOrEqualTo: range.end)
//               .get();
          
//           final products = await VendorProductService.getVendorProducts(vendorId);
          
//           final salesData = await _salesService.getSalesForDateRange(
//             vendorId,
//             range.start,
//             range.end,
//           );
          
//           final applications = await _applicationService.getVendorApplications(vendorId);
//           final acceptedApps = applications.where((a) => a.status == ApplicationStatus.accepted).length;
          
//           // Calculate totals
//           final totalRevenue = salesData.fold<double>(
//             0,
//             (sum, sale) => sum + sale.amount,
//           );
          
//           final analytics = VendorAnalytics(
//             totalPosts: posts.size,
//             totalProducts: products.length,
//             totalSales: salesData.length,
//             totalRevenue: totalRevenue,
//             totalApplications: applications.length,
//             acceptedApplications: acceptedApps,
//             customMetrics: await _insightsService.getVendorInsights(vendorId),
//             lastUpdated: DateTime.now(),
//           );
          
//           // Store in offline cache
//           _offlineCache[cacheKey] = analytics;
          
//           return analytics;
//         } catch (e) {
//           debugPrint('❌ VendorRepository: Error getting analytics: $e');
          
//           // Return offline cached data if available
//           if (_offlineCache.containsKey(cacheKey)) {
//             return _offlineCache[cacheKey] as VendorAnalytics;
//           }
          
//           // Return empty analytics on error
//           return VendorAnalytics(
//             totalPosts: 0,
//             totalProducts: 0,
//             totalSales: 0,
//             totalRevenue: 0,
//             totalApplications: 0,
//             acceptedApplications: 0,
//             lastUpdated: DateTime.now(),
//           );
//         }
//       },
//       ttl: CacheTTL.analytics,
//     );
//   }
  
//   /// Watch analytics in real-time
//   Stream<VendorAnalytics> watchAnalytics(String vendorId) {
//     final cacheKey = 'analytics_stream_$vendorId';
    
//     // Return existing stream if available
//     if (_analyticsControllers.containsKey(vendorId)) {
//       return _analyticsControllers[vendorId]!.stream.where((a) => a != null).cast<VendorAnalytics>();
//     }
    
//     // Create new stream controller
//     final controller = BehaviorSubject<VendorAnalytics?>();
//     _analyticsControllers[vendorId] = controller;
    
//     // Refresh analytics every minute
//     Timer.periodic(const Duration(minutes: 1), (timer) async {
//       if (!controller.isClosed) {
//         final analytics = await getAnalytics(
//           vendorId,
//           DateRange(
//             start: DateTime.now().subtract(const Duration(days: 30)),
//             end: DateTime.now(),
//           ),
//         );
//         controller.add(analytics);
//       } else {
//         timer.cancel();
//       }
//     });
    
//     // Initial load
//     getAnalytics(
//       vendorId,
//       DateRange(
//         start: DateTime.now().subtract(const Duration(days: 30)),
//         end: DateTime.now(),
//       ),
//     ).then((analytics) => controller.add(analytics));
    
//     return controller.stream.where((a) => a != null).cast<VendorAnalytics>();
//   }
  
//   // =============================================================================
//   // APPLICATIONS OPERATIONS
//   // =============================================================================
  
//   /// Get vendor applications
//   Stream<List<VendorApplication>> getApplications(String vendorId) {
//     final cacheKey = 'vendor_applications_$vendorId';
    
//     return _cache.getCachedStream(
//       cacheKey,
//       () {
//         return Stream.fromFuture(
//           _applicationService.getVendorApplications(vendorId)
//         ).map((applications) {
//           // Store in offline cache
//           _offlineCache[cacheKey] = applications;
//           return applications;
//         });
//       },
//       ttl: CacheTTL.applications,
//     );
//   }
  
//   /// Submit a new application
//   Future<void> submitApplication(VendorApplication application) async {
//     try {
//       await _applicationService.submitApplication(
//         vendorId: application.vendorId,
//         marketId: application.marketId,
//         message: application.message ?? '',
//       );
      
//       // Clear cache to force refresh
//       _cache.clear('vendor_applications_${application.vendorId}');
      
//       debugPrint('✅ VendorRepository: Application submitted');
//     } catch (e) {
//       debugPrint('❌ VendorRepository: Error submitting application: $e');
//       rethrow;
//     }
//   }
  
//   // =============================================================================
//   // PREMIUM STATUS OPERATIONS
//   // =============================================================================
  
//   /// Check if vendor has premium access
//   Stream<bool> isPremium(String vendorId) {
//     return watchVendor(vendorId).map((profile) {
//       if (profile == null) return false;
      
//       return profile.isPremium == true && 
//              (profile.subscriptionStatus == 'active' || 
//               profile.stripeSubscriptionId?.isNotEmpty == true);
//     });
//   }
  
//   /// Get detailed premium status
//   Future<PremiumStatus> getPremiumStatus(String vendorId) async {
//     final cacheKey = 'premium_status_$vendorId';
    
//     return _cache.getOrFetch(
//       cacheKey,
//       () async {
//         try {
//           final profile = await getVendor(vendorId);
//           if (profile == null) {
//             return const PremiumStatus(isPremium: false);
//           }
          
//           // Get subscription limits and usage
//           final limits = await SubscriptionService.getSubscriptionLimits(vendorId);
//           final usage = await _getFeatureUsage(vendorId);
          
//           return PremiumStatus(
//             isPremium: profile.isPremium == true,
//             subscriptionStatus: profile.subscriptionStatus,
//             subscriptionId: profile.stripeSubscriptionId,
//             expiresAt: profile.subscriptionExpiresAt,
//             limits: limits,
//             usage: usage,
//           );
//         } catch (e) {
//           debugPrint('❌ VendorRepository: Error getting premium status: $e');
//           return const PremiumStatus(isPremium: false);
//         }
//       },
//       ttl: CacheTTL.premiumStatus,
//     );
//   }
  
//   // =============================================================================
//   // SALES OPERATIONS
//   // =============================================================================
  
//   /// Get vendor sales for a date range
//   Stream<List<VendorSalesData>> getVendorSales(String vendorId, DateRange range) {
//     final cacheKey = 'vendor_sales_${vendorId}_${range.cacheKey}';
    
//     return _cache.getCachedStream(
//       cacheKey,
//       () {
//         return Stream.fromFuture(
//           _salesService.getSalesForDateRange(vendorId, range.start, range.end)
//         ).map((sales) {
//           // Store in offline cache
//           _offlineCache[cacheKey] = sales;
//           return sales;
//         });
//       },
//       ttl: CacheTTL.sales,
//     );
//   }
  
//   /// Record a new sale
//   Future<void> recordSale(VendorSalesData sale) async {
//     try {
//       await _salesService.recordSale(
//         vendorId: sale.vendorId,
//         marketId: sale.marketId,
//         amount: sale.amount,
//         description: sale.description,
//         paymentMethod: sale.paymentMethod,
//         customerInfo: sale.customerInfo,
//         productsSold: sale.productsSold,
//       );
      
//       // Clear cache to force refresh
//       _cache.clear('vendor_sales_${sale.vendorId}');
      
//       debugPrint('✅ VendorRepository: Sale recorded');
//     } catch (e) {
//       debugPrint('❌ VendorRepository: Error recording sale: $e');
//       rethrow;
//     }
//   }
  
//   // =============================================================================
//   // MARKETS OPERATIONS
//   // =============================================================================
  
//   /// Get markets where vendor is participating
//   Stream<List<VendorMarket>> getVendorMarkets(String vendorId) {
//     final cacheKey = 'vendor_markets_$vendorId';
    
//     return _cache.getCachedStream(
//       cacheKey,
//       () {
//         return _marketRelationshipService.getVendorMarkets(vendorId);
//       },
//       ttl: CacheTTL.markets,
//     );
//   }
  
//   /// Search for markets
//   Stream<List<VendorMarket>> searchMarkets(String query) {
//     final cacheKey = 'market_search_$query';
    
//     return _cache.getCachedStream(
//       cacheKey,
//       () {
//         return _firestore
//             .collection('markets')
//             .where('isActive', isEqualTo: true)
//             .snapshots()
//             .map((snapshot) {
//               final markets = snapshot.docs
//                   .map((doc) => VendorMarket.fromFirestore(doc))
//                   .where((market) {
//                     final searchLower = query.toLowerCase();
//                     return market.name.toLowerCase().contains(searchLower) ||
//                            market.location.toLowerCase().contains(searchLower) ||
//                            (market.description?.toLowerCase().contains(searchLower) ?? false);
//                   })
//                   .toList();
              
//               // Store in offline cache
//               _offlineCache[cacheKey] = markets;
              
//               return markets;
//             });
//       },
//       ttl: CacheTTL.markets,
//     );
//   }
  
//   // =============================================================================
//   // UTILITY METHODS
//   // =============================================================================
  
//   /// Clear all caches for a vendor
//   void clearVendorCache(String vendorId) {
//     _cache.clear('vendor_$vendorId');
//     _cache.clear('vendor_posts_$vendorId');
//     _cache.clear('vendor_products_$vendorId');
//     _cache.clear('vendor_applications_$vendorId');
//     _cache.clear('premium_status_$vendorId');
    
//     // Clear any vendor-specific entries from offline cache
//     _offlineCache.removeWhere((key, value) => key.contains(vendorId));
    
//     debugPrint('🧹 VendorRepository: Cleared all caches for vendor $vendorId');
//   }
  
//   /// Clear all caches
//   void clearAllCaches() {
//     _cache.clearAll();
//     _offlineCache.clear();
//     debugPrint('🧹 VendorRepository: Cleared all caches');
//   }
  
//   /// Set offline mode
//   void setOfflineMode(bool offline) {
//     _isOffline = offline;
//     debugPrint('📱 VendorRepository: Offline mode ${offline ? 'enabled' : 'disabled'}');
//   }
  
//   /// Get feature usage for premium limits
//   Future<Map<String, int>> _getFeatureUsage(String vendorId) async {
//     try {
//       final posts = await _firestore
//           .collection('vendor_posts')
//           .where('vendorId', isEqualTo: vendorId)
//           .where('countsTowardLimit', isEqualTo: true)
//           .get();
      
//       final products = await VendorProductService.getVendorProducts(vendorId);
//       final productLists = await VendorProductService.getProductLists(vendorId);
      
//       final monthlyData = await _monthlyTrackingService.getCurrentMonthData(vendorId);
      
//       return {
//         'posts': posts.size,
//         'monthly_posts': monthlyData?.monthlyPostCount ?? 0,
//         'global_products': products.length,
//         'product_lists': productLists.length,
//         'analytics_access': 1,
//         'bulk_operations': monthlyData?.bulkOperationsCount ?? 0,
//       };
//     } catch (e) {
//       debugPrint('❌ VendorRepository: Error getting feature usage: $e');
//       return {};
//     }
//   }
  
//   /// Dispose of resources
//   void dispose() {
//     // Close all stream controllers
//     for (final controller in _vendorControllers.values) {
//       controller.close();
//     }
//     for (final controller in _postsControllers.values) {
//       controller.close();
//     }
//     for (final controller in _productsControllers.values) {
//       controller.close();
//     }
//     for (final controller in _analyticsControllers.values) {
//       controller.close();
//     }
    
//     _vendorControllers.clear();
//     _postsControllers.clear();
//     _productsControllers.clear();
//     _analyticsControllers.clear();
    
//     debugPrint('♻️ VendorRepository: Disposed of resources');
//   }
// }