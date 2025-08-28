import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'store_config.dart';

/// Service that handles all RevenueCat subscription interactions
class RevenueCatService {
  // Singleton pattern
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  bool _isInitialized = false;
  CustomerInfo? _customerInfo;
  String? _lastPurchaseError;
  
  // Controller for subscription status changes
  final _subscriptionStatusController = StreamController<bool>.broadcast();
  
  /// Stream that emits when premium status changes
  Stream<bool> get onSubscriptionStatusChanged => 
      _subscriptionStatusController.stream;
      
  /// Get the last purchase error message
  String? get lastPurchaseError => _lastPurchaseError;
  
  /// Get entitlement ID from environment
  String get entitlementId => dotenv.env['REVENUE_CAT_ENTITLEMENT_ID'] ?? 'entlda111f7997';
  
  /// Get offering IDs from environment
  String get vendorOfferingId => dotenv.env['REVENUE_CAT_VENDOR_OFFERING_ID'] ?? 'ofrngca1e4066ea';
  String get organizerOfferingId => dotenv.env['REVENUE_CAT_ORGANIZER_OFFERING_ID'] ?? 'ofrng41e09efeab';
  
  /// Clear RevenueCat cache to force fresh data fetch
  Future<void> clearCache() async {
    try {
      debugPrint('🧹 Clearing RevenueCat cache...');
      // Invalidate cached customer info
      await Purchases.invalidateCustomerInfoCache();
      debugPrint('✅ RevenueCat cache cleared');
    } catch (e) {
      debugPrint('❌ Error clearing RevenueCat cache: $e');
    }
  }
  
  /// Initialize the subscription service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Handle web or unsupported platforms
      if (kIsWeb) {
        debugPrint('⚠️ RevenueCat not available on web platform');
        _isInitialized = true;
        return;
      }
      
      // Initialize the store configuration
      StoreConfig.initialize();
      
      // Set log level for debugging
      if (kDebugMode) {
        try {
          await Purchases.setLogLevel(LogLevel.debug);
        } catch (e) {
          if (e is MissingPluginException) {
            debugPrint('⚠️ RevenueCat plugin not available');
            _isInitialized = true;
            return;
          }
          rethrow;
        }
      }
      
      // Configure the SDK
      try {
        final configuration = PurchasesConfiguration(StoreConfig.instance.apiKey);
        await Purchases.configure(configuration);
        
        // Login with Firebase user ID if available
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await _loginUser(currentUser);
        }
        
        // Listen for auth state changes
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
          if (user != null) {
            _loginUser(user);
          } else {
            Purchases.logOut();
          }
        });
        
        // Fetch initial customer info
        final customerInfo = await Purchases.getCustomerInfo();
        _handleCustomerInfoUpdate(customerInfo);
        
        // Listen for customer info updates
        Purchases.addCustomerInfoUpdateListener(_handleCustomerInfoUpdate);
        
        _isInitialized = true;
        debugPrint('✅ RevenueCat initialized successfully');
      } catch (e) {
        debugPrint('❌ Error initializing RevenueCat: $e');
        _isInitialized = true; // Mark as initialized to prevent retry loops
      }
    } catch (e) {
      debugPrint('❌ Error in RevenueCat initialization: $e');
      _isInitialized = true;
    }
  }
  
  /// Login user to RevenueCat
  Future<void> _loginUser(User user) async {
    try {
      // Use Firebase UID as RevenueCat app user ID
      await Purchases.logIn(user.uid);
      
      // Set user attributes for better analytics
      await Purchases.setAttributes({
        'email': user.email ?? '',
        'display_name': user.displayName ?? '',
      });
      
      // Sync user type from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(user.uid)
          .get();
          
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final isVendor = userData['isVendor'] ?? false;
        final isOrganizer = userData['isMarketOrganizer'] ?? false;
        
        String userType = 'shopper';
        if (isVendor) userType = 'vendor';
        if (isOrganizer) userType = 'market_organizer';
        
        await Purchases.setAttributes({
          'user_type': userType,
          'is_vendor': isVendor.toString(),
          'is_organizer': isOrganizer.toString(),
        });
      }
      
      debugPrint('✅ User logged in to RevenueCat: ${user.uid}');
    } catch (e) {
      debugPrint('❌ Error logging in to RevenueCat: $e');
    }
  }
  
  /// Handles customer info updates and notifies listeners
  void _handleCustomerInfoUpdate(CustomerInfo info) {
    debugPrint('\n📱 === CUSTOMER INFO UPDATE ===');
    final oldPremiumStatus = isPremium;
    _customerInfo = info;
    
    final currentPremiumStatus = isPremium;
    debugPrint('📊 Old premium status: $oldPremiumStatus');
    debugPrint('📊 New premium status: $currentPremiumStatus');
    debugPrint('🔄 Premium status changed: ${oldPremiumStatus != currentPremiumStatus}');
    
    // Always sync on customer info update to ensure Firebase is current
    debugPrint('🔄 Syncing to Firebase (customer info update)...');
    _syncSubscriptionToFirebase(info).catchError((error) {
      debugPrint('❌ Error during customer info sync: $error');
    });
    
    // Check if premium status changed and notify listeners
    if (oldPremiumStatus != currentPremiumStatus) {
      debugPrint('📢 Notifying subscription status change: $currentPremiumStatus');
      _subscriptionStatusController.add(currentPremiumStatus);
    }
    
    debugPrint('📱 === END CUSTOMER INFO UPDATE ===\n');
  }
  
  /// Check if the user has premium access
  bool get isPremium {
    if (_customerInfo == null) return false;
    
    final hasActiveEntitlement = _customerInfo!.entitlements.active.containsKey(entitlementId);
    
    // Additional validation: check if the entitlement is not expired
    if (hasActiveEntitlement) {
      final entitlement = _customerInfo!.entitlements.active[entitlementId];
      if (entitlement != null) {
        return entitlement.isActive;
      }
    }
    
    return false;
  }
  
  /// Get active subscriptions for the user
  Set<String> get activeSubscriptions {
    return _customerInfo?.activeSubscriptions.toSet() ?? <String>{};
  }
  
  /// Get offerings for a specific user type
  Future<Offering?> getOfferingForUserType(String userType) async {
    if (!_isInitialized) await initialize();
    
    // If on web or plugin not available, return null
    if (kIsWeb) {
      debugPrint('⚠️ RevenueCat not available on web');
      return null;
    }
    
    try {
      // Clear cache to ensure fresh offerings
      await clearCache();
      
      final offerings = await Purchases.getOfferings();
      
      debugPrint('📦 All offerings fetched: ${offerings.all.keys.toList()}');
      debugPrint('📦 Current offering: ${offerings.current?.identifier}');
      
      if (offerings.all.isEmpty) {
        debugPrint('❌ No offerings available from RevenueCat');
        debugPrint('ℹ️ This usually means:');
        debugPrint('  1. Products not created in App Store Connect');
        debugPrint('  2. Product IDs mismatch between RevenueCat and App Store Connect');
        debugPrint('  3. Bundle ID mismatch (current: com.jozo.hipop.staging)');
        debugPrint('  4. Products not in "Ready to Submit" state');
        debugPrint('  5. Check RevenueCat dashboard for product configuration');
      }
      
      // Get the appropriate offering based on user type
      String offeringId;
      if (userType == 'vendor') {
        offeringId = vendorOfferingId;
      } else if (userType == 'market_organizer') {
        offeringId = organizerOfferingId;
      } else {
        debugPrint('⚠️ Invalid user type for premium: $userType');
        return null;
      }
      
      debugPrint('🔍 Looking for offering with ID: $offeringId');
      final offering = offerings.getOffering(offeringId);
      
      if (offering == null) {
        debugPrint('⚠️ No offering found with ID: $offeringId');
        debugPrint('📋 Available offering IDs: ${offerings.all.keys.toList()}');
        
        // Try to get by identifier (fallback)
        if (userType == 'vendor') {
          debugPrint('🔄 Trying fallback: vendor_premium');
          final fallback = offerings.getOffering('vendor_premium');
          if (fallback != null) {
            debugPrint('✅ Found fallback offering: vendor_premium');
            return fallback;
          }
        } else if (userType == 'market_organizer') {
          debugPrint('🔄 Trying fallback: organizer_premium');
          final fallback = offerings.getOffering('organizer_premium');
          if (fallback != null) {
            debugPrint('✅ Found fallback offering: organizer_premium');
            return fallback;
          }
        }
        
        // Last resort - try current offering
        if (offerings.current != null) {
          debugPrint('🔄 Using current offering as last resort: ${offerings.current!.identifier}');
          return offerings.current;
        }
      }
      
      debugPrint('✅ Found offering for $userType: ${offering?.identifier}');
      return offering;
    } catch (e) {
      debugPrint('❌ Error fetching offerings: $e');
      _lastPurchaseError = 'Failed to load subscription options';
      return null;
    }
  }
  
  /// Purchase a package
  Future<HipopPurchaseResult> purchasePackage(Package package) async {
    try {
      debugPrint('🛒 Attempting to purchase package: ${package.identifier}');
      _lastPurchaseError = null;
      
      final purchaseResult = await Purchases.purchasePackage(package);
      
      debugPrint('✅ Purchase completed successfully');
      debugPrint('📦 Customer info received: ${purchaseResult.customerInfo.originalAppUserId}');
      debugPrint('📋 Active entitlements: ${purchaseResult.customerInfo.entitlements.active.keys}');
      debugPrint('📦 Active subscriptions: ${purchaseResult.customerInfo.activeSubscriptions}');
      
      // Store customer info
      _customerInfo = purchaseResult.customerInfo;
      
      // Sync with Firebase after successful purchase with detailed logging
      debugPrint('🔄 Starting Firebase sync after purchase...');
      try {
        await _syncSubscriptionToFirebase(purchaseResult.customerInfo);
        debugPrint('✅ Firebase sync completed successfully');
      } catch (syncError) {
        debugPrint('⚠️ Firebase sync failed, will retry: $syncError');
        // Try verification and sync as fallback
        final verified = await verifyAndSyncPurchase();
        if (verified) {
          debugPrint('✅ Purchase verified and synced on retry');
        } else {
          debugPrint('❌ Could not verify purchase on retry');
        }
      }
      
      return HipopPurchaseResult(
        success: true,
        customerInfo: purchaseResult.customerInfo,
      );
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      
      String errorMessage;
      switch (errorCode) {
        case PurchasesErrorCode.purchaseCancelledError:
          errorMessage = 'Purchase was cancelled';
          break;
        case PurchasesErrorCode.purchaseNotAllowedError:
          errorMessage = 'Purchase not allowed on this device';
          break;
        case PurchasesErrorCode.purchaseInvalidError:
          errorMessage = 'Invalid purchase';
          break;
        case PurchasesErrorCode.productNotAvailableForPurchaseError:
          errorMessage = 'Product not available';
          break;
        case PurchasesErrorCode.productAlreadyPurchasedError:
          errorMessage = 'Already subscribed';
          break;
        case PurchasesErrorCode.networkError:
          errorMessage = 'Network error. Please check your connection';
          break;
        case PurchasesErrorCode.paymentPendingError:
          errorMessage = 'Payment is pending';
          break;
        default:
          errorMessage = 'Purchase failed: ${e.message}';
      }
      
      debugPrint('❌ Purchase failed: $errorMessage');
      _lastPurchaseError = errorMessage;
      
      return HipopPurchaseResult(
        success: false,
        errorMessage: errorMessage,
      );
    } catch (e) {
      final errorMessage = 'Unexpected error: $e';
      debugPrint('❌ $errorMessage');
      _lastPurchaseError = errorMessage;
      
      return HipopPurchaseResult(
        success: false,
        errorMessage: errorMessage,
      );
    }
  }
  
  /// Purchase subscription for a specific user type
  Future<HipopPurchaseResult> purchaseSubscription(String userType) async {
    try {
      debugPrint('📱 Starting purchase for user type: $userType');
      
      // Get offering for user type
      final offering = await getOfferingForUserType(userType);
      
      if (offering == null) {
        debugPrint('❌ No offering found for $userType');
        return HipopPurchaseResult(
          success: false,
          errorMessage: 'No subscription available for $userType',
        );
      }
      
      debugPrint('✅ Found offering: ${offering.identifier}');
      debugPrint('📦 Available packages: ${offering.availablePackages.map((p) => p.identifier).toList()}');
      
      // Get the monthly package using the SDK's built-in property (like TUG does)
      Package? monthlyPackage = offering.monthly;
      
      // If monthly doesn't exist, try other methods
      if (monthlyPackage == null) {
        debugPrint('⚠️ No monthly package found using offering.monthly');
        
        // Try standard identifier as fallback
        monthlyPackage = offering.getPackage('\$rc_monthly');
        
        if (monthlyPackage == null && offering.availablePackages.isNotEmpty) {
          debugPrint('⚠️ Trying to find any monthly package in available packages...');
          
          // Look for monthly package type or identifier
          try {
            monthlyPackage = offering.availablePackages.firstWhere(
              (package) => package.packageType == PackageType.monthly ||
                          package.identifier.toLowerCase().contains('monthly'),
            );
          } catch (e) {
            // If no monthly found, use first available as last resort
            debugPrint('⚠️ No monthly package found, using first available package');
            monthlyPackage = offering.availablePackages.first;
          }
        }
      }
      
      if (monthlyPackage == null) {
        debugPrint('❌ No monthly package available in offering');
        return HipopPurchaseResult(
          success: false,
          errorMessage: 'Monthly subscription not available',
        );
      }
      
      debugPrint('🎯 Selected package: ${monthlyPackage.identifier}');
      debugPrint('💰 Package price: ${monthlyPackage.storeProduct.priceString}');
      
      // Make the purchase
      return await purchasePackage(monthlyPackage);
    } catch (e, stackTrace) {
      debugPrint('❌ Purchase error: $e');
      debugPrint('Stack trace: $stackTrace');
      return HipopPurchaseResult(
        success: false,
        errorMessage: 'Failed to purchase subscription: $e',
      );
    }
  }
  
  /// Restore purchases
  Future<CustomerInfo?> restorePurchases() async {
    try {
      debugPrint('🔄 Restoring purchases...');
      
      final customerInfo = await Purchases.restorePurchases();
      
      // Store customer info
      _customerInfo = customerInfo;
      
      // Sync with Firebase with error handling
      try {
        await _syncSubscriptionToFirebase(customerInfo);
      } catch (syncError) {
        debugPrint('⚠️ Firebase sync failed during restore: $syncError');
        // Try force sync as fallback
        await forceSyncSubscription();
      }
      
      debugPrint('✅ Purchases restored successfully');
      return customerInfo;
    } catch (e) {
      debugPrint('❌ Error restoring purchases: $e');
      _lastPurchaseError = 'Failed to restore purchases';
      return null;
    }
  }
  
  /// Get current customer info
  /// Get customer info with optional force refresh
  Future<CustomerInfo?> getCustomerInfo({bool forceRefresh = false}) async {
    try {
      if (forceRefresh) {
        debugPrint('🔄 Force refreshing customer info...');
        await clearCache();
      }
      final customerInfo = await Purchases.getCustomerInfo();
      
      // Cache the customer info
      _customerInfo = customerInfo;
      
      // Log subscription state for debugging
      debugPrint('📱 Customer info retrieved:');
      debugPrint('  - Active entitlements: ${customerInfo.entitlements.active.keys.toList()}');
      debugPrint('  - Active subscriptions: ${customerInfo.activeSubscriptions}');
      debugPrint('  - Original App User ID: ${customerInfo.originalAppUserId}');
      
      return customerInfo;
    } catch (e) {
      debugPrint('❌ Error getting customer info: $e');
      return null;
    }
  }
  
  /// Check if user has active subscription
  Future<bool> hasActiveSubscription() async {
    try {
      final customerInfo = await getCustomerInfo();
      if (customerInfo == null) return false;
      
      // Check both entitlements and active subscriptions
      // This handles cases where entitlements might not be synced yet
      final hasEntitlements = customerInfo.entitlements.active.isNotEmpty;
      final hasSubscriptions = customerInfo.activeSubscriptions.isNotEmpty;
      
      if (hasEntitlements || hasSubscriptions) {
        debugPrint('✅ User has active subscription');
        debugPrint('  - Has entitlements: $hasEntitlements');
        debugPrint('  - Has subscriptions: $hasSubscriptions');
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ Error checking subscription status: $e');
      return false;
    }
  }
  
  /// Force sync current subscription status to Firebase (for debugging)
  Future<void> forceSyncToFirebase() async {
    debugPrint('🔧 === FORCED SYNC TRIGGERED ===');
    try {
      // Use the improved force sync method
      final success = await forceSyncSubscription();
      if (!success) {
        debugPrint('⚠️ First sync attempt failed, trying verification flow...');
        // Try the verification flow as fallback
        await verifyAndSyncPurchase();
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error in forced sync: $e');
      debugPrint('❌ Stack trace: $stackTrace');
    }
    debugPrint('🔧 === END FORCED SYNC ===');
  }
  
  /// Sync RevenueCat subscription to Firebase
  Future<void> _syncSubscriptionToFirebase(CustomerInfo customerInfo) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    debugPrint('\n🔄 === STARTING FIREBASE SYNC ===');
    debugPrint('👤 Current user: ${currentUser?.uid}');
    debugPrint('👤 RevenueCat user ID: ${customerInfo.originalAppUserId}');
    debugPrint('🎫 Entitlement ID to check: $entitlementId');
    
    try {
      final userId = currentUser?.uid;
      if (userId == null) {
        debugPrint('❌ No authenticated user found - cannot sync to Firebase');
        return;
      }
      
      final firestore = FirebaseFirestore.instance;
      
      // Get active entitlements with detailed logging
      final activeEntitlements = customerInfo.entitlements.active;
      debugPrint('📋 All active entitlements: ${activeEntitlements.keys.toList()}');
      
      // Also check active subscriptions as fallback
      final activeSubscriptions = customerInfo.activeSubscriptions;
      debugPrint('📦 Active subscriptions: $activeSubscriptions');
      
      // Check both entitlements and active subscriptions
      bool hasActiveSubscription = activeEntitlements.containsKey(entitlementId);
      
      // If no entitlement but has active subscriptions, consider it active
      if (!hasActiveSubscription && activeSubscriptions.isNotEmpty) {
        debugPrint('⚠️ No entitlement found but has active subscriptions, considering as active');
        hasActiveSubscription = true;
      }
      
      debugPrint('✅ Has active subscription: $hasActiveSubscription');
      
      // Determine subscription tier and product
      String tier = 'free';
      String? productIdentifier;
      
      if (hasActiveSubscription) {
        // Try to get product identifier from entitlement first
        if (activeEntitlements.containsKey(entitlementId)) {
          final entitlement = activeEntitlements[entitlementId]!;
          productIdentifier = entitlement.productIdentifier;
          debugPrint('📦 Product identifier from entitlement: $productIdentifier');
          debugPrint('📅 Expiration date: ${entitlement.expirationDate}');
          debugPrint('🔒 Is active: ${entitlement.isActive}');
        } else if (activeSubscriptions.isNotEmpty) {
          // Fallback to first active subscription
          productIdentifier = activeSubscriptions.first;
          debugPrint('📦 Product identifier from active subscription: $productIdentifier');
        }
        
        // Determine tier based on product ID
        if (productIdentifier != null) {
          if (productIdentifier.toLowerCase().contains('vendor')) {
            tier = 'vendorPremium';
          } else if (productIdentifier.toLowerCase().contains('market') || 
                     productIdentifier.toLowerCase().contains('organizer')) {
            tier = 'marketOrganizerPremium';
          }
          debugPrint('🎯 Determined tier: $tier');
        }
      } else {
        debugPrint('⚠️ No active subscription found');
      }
      
      // Update user subscription document
      final subscriptionData = {
        'userId': userId,
        'tier': tier,
        'status': hasActiveSubscription ? 'active' : 'cancelled',
        'revenuecatUserId': customerInfo.originalAppUserId,
        'productIdentifier': productIdentifier,
        'isActive': hasActiveSubscription,
        'activeSubscriptions': customerInfo.activeSubscriptions.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Add expiration date if available
      if (hasActiveSubscription && activeEntitlements.containsKey(entitlementId)) {
        // Only access entitlement if it exists
        final entitlement = activeEntitlements[entitlementId]!;
        if (entitlement.expirationDate != null) {
          subscriptionData['expirationDate'] = entitlement.expirationDate;
        }
      } else if (hasActiveSubscription) {
        // For active subscriptions without entitlements, try to get expiration from purchaser info
        // This handles the case where subscription is active but entitlement is not yet synced
        debugPrint('⚠️ Active subscription without entitlement - expiration date not available');
        // Optional: Set a future date to indicate subscription is active
        subscriptionData['expirationDate'] = DateTime.now().add(const Duration(days: 30)).toIso8601String();
        subscriptionData['note'] = 'Expiration date estimated - entitlement pending sync';
      }
      
      debugPrint('📊 Subscription data to save: $subscriptionData');
      
      // Update or create subscription document
      debugPrint('🔍 Checking for existing subscription document...');
      final subscriptionQuery = await firestore
          .collection('user_subscriptions')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
          
      if (subscriptionQuery.docs.isNotEmpty) {
        debugPrint('📝 Updating existing subscription document');
        await subscriptionQuery.docs.first.reference.update(subscriptionData);
        debugPrint('✅ Subscription document updated');
      } else {
        debugPrint('📝 Creating new subscription document');
        await firestore.collection('user_subscriptions').add({
          ...subscriptionData,
          'createdAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ New subscription document created');
      }
      
      // Update user profile to match Stripe updates
      final profileUpdates = <String, dynamic>{
        'isPremium': hasActiveSubscription,
        'subscriptionStatus': hasActiveSubscription ? tier : 'free',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Add subscription details if active
      if (hasActiveSubscription) {
        profileUpdates['subscriptionStartDate'] = FieldValue.serverTimestamp();
        
        // Add expiration date if available from entitlement
        if (activeEntitlements.containsKey(entitlementId)) {
          final entitlement = activeEntitlements[entitlementId]!;
          if (entitlement.expirationDate != null) {
            profileUpdates['subscriptionEndDate'] = Timestamp.fromDate(
              DateTime.parse(entitlement.expirationDate!)
            );
          }
        }
        
        // RevenueCat specific fields (instead of Stripe IDs)
        profileUpdates['revenueCatProductId'] = productIdentifier;
        profileUpdates['revenueCatUserId'] = customerInfo.originalAppUserId;
        profileUpdates['paymentProvider'] = 'revenueCat';
      } else {
        // Clear subscription fields when cancelled
        profileUpdates['subscriptionStartDate'] = null;
        profileUpdates['subscriptionEndDate'] = null;
        profileUpdates['revenueCatProductId'] = null;
        profileUpdates['revenueCatUserId'] = null;
        profileUpdates['paymentProvider'] = null;
      }
      
      debugPrint('📊 Profile updates to apply: $profileUpdates');
      debugPrint('🔄 Updating userProfiles document for user: $userId');
      
      // Check if profile exists first
      final profileDoc = await firestore.collection('user_profiles').doc(userId).get();
      if (!profileDoc.exists) {
        debugPrint('⚠️ User profile does not exist, creating with subscription data...');
        // Create a new profile with basic required fields
        final currentUser = FirebaseAuth.instance.currentUser;
        profileUpdates['userId'] = userId;
        profileUpdates['email'] = currentUser?.email ?? '';
        profileUpdates['displayName'] = currentUser?.displayName ?? 'User';
        profileUpdates['userType'] = 'vendor'; // Default, should be set properly during signup
        profileUpdates['createdAt'] = FieldValue.serverTimestamp();
        profileUpdates['profileSubmitted'] = false;
      }
      
      // Use set with merge to create or update document
      await firestore.collection('user_profiles').doc(userId).set(
        profileUpdates,
        SetOptions(merge: true),
      );
      
      debugPrint('✅ UserProfile document updated successfully');
      debugPrint('📊 Profile updated with isPremium: ${profileUpdates['isPremium']}');
      debugPrint('🎯 Subscription status set to: ${profileUpdates['subscriptionStatus']}');
      
      // Verify the update by reading back the document
      debugPrint('🔍 Verifying profile update...');
      final updatedProfile = await firestore.collection('user_profiles').doc(userId).get();
      if (updatedProfile.exists) {
        final data = updatedProfile.data()!;
        debugPrint('✅ Verification - isPremium: ${data['isPremium']}');
        debugPrint('✅ Verification - subscriptionStatus: ${data['subscriptionStatus']}');
      } else {
        debugPrint('❌ Profile document not found during verification');
      }
      
      // Notify subscription status listeners
      debugPrint('📢 Notifying subscription status listeners: $hasActiveSubscription');
      _subscriptionStatusController.add(hasActiveSubscription);
      
      debugPrint('✅ === FIREBASE SYNC COMPLETED SUCCESSFULLY ===\n');
    } catch (e, stackTrace) {
      debugPrint('❌ === ERROR IN FIREBASE SYNC ===');
      debugPrint('❌ Error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Stack trace: $stackTrace');
      debugPrint('❌ === END ERROR ===\n');
      
      // Re-throw the error so it's visible to the caller
      rethrow;
    }
  }
  
  /// Force sync subscription state with Firebase (public method)
  /// Call this after a purchase to ensure Firebase is up to date
  Future<bool> forceSyncSubscription() async {
    try {
      debugPrint('🔄 Force syncing subscription with Firebase...');
      
      // Get fresh customer info
      final customerInfo = await getCustomerInfo(forceRefresh: true);
      if (customerInfo == null) {
        debugPrint('❌ Cannot sync: Customer info not available');
        return false;
      }
      
      // Sync to Firebase
      await _syncSubscriptionToFirebase(customerInfo);
      
      debugPrint('✅ Force sync completed successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error during force sync: $e');
      return false;
    }
  }
  
  /// Verify and sync subscription after purchase
  /// This ensures the subscription is properly recorded in Firebase
  Future<bool> verifyAndSyncPurchase() async {
    try {
      debugPrint('🔍 Verifying and syncing purchase...');
      
      // Clear cache to get fresh data
      await clearCache();
      
      // Wait a moment for RevenueCat to process
      await Future.delayed(const Duration(seconds: 2));
      
      // Get fresh customer info
      final customerInfo = await getCustomerInfo(forceRefresh: true);
      if (customerInfo == null) {
        debugPrint('❌ Cannot verify: Customer info not available');
        return false;
      }
      
      // Check subscription status
      final hasSubscription = customerInfo.entitlements.active.isNotEmpty || 
                              customerInfo.activeSubscriptions.isNotEmpty;
      
      if (!hasSubscription) {
        debugPrint('⚠️ No active subscription found after purchase');
        return false;
      }
      
      debugPrint('✅ Purchase verified, syncing to Firebase...');
      
      // Sync to Firebase
      await _syncSubscriptionToFirebase(customerInfo);
      
      debugPrint('✅ Purchase verification and sync completed');
      return true;
    } catch (e) {
      debugPrint('❌ Error verifying purchase: $e');
      return false;
    }
  }
  
  /// Dispose of resources
  void dispose() {
    _subscriptionStatusController.close();
  }
}

/// Result of a purchase attempt
class HipopPurchaseResult {
  final bool success;
  final CustomerInfo? customerInfo;
  final String? errorMessage;
  
  HipopPurchaseResult({
    required this.success,
    this.customerInfo,
    this.errorMessage,
  });
}