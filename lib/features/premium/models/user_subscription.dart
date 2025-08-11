import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum SubscriptionTier {
  free,
  shopperPro,
  vendorPro,
  marketOrganizerPro,
  enterprise,
}

enum SubscriptionStatus {
  active,
  cancelled,
  pastDue,
  expired,
}

class UserSubscription extends Equatable {
  final String id;
  final String userId;
  final String userType;
  final SubscriptionTier tier;
  final SubscriptionStatus status;
  final DateTime? subscriptionStartDate;
  final DateTime? subscriptionEndDate;
  final DateTime? lastPaymentDate;
  final DateTime? nextPaymentDate;
  final String? paymentMethodId;
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final String? stripePriceId;
  final double? monthlyPrice;
  final Map<String, dynamic> features;
  final Map<String, dynamic> limits;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserSubscription({
    required this.id,
    required this.userId,
    required this.userType,
    required this.tier,
    required this.status,
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.lastPaymentDate,
    this.nextPaymentDate,
    this.paymentMethodId,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    this.stripePriceId,
    this.monthlyPrice,
    this.features = const {},
    this.limits = const {},
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserSubscription.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return UserSubscription(
      id: doc.id,
      userId: data['userId'] ?? '',
      userType: data['userType'] ?? 'shopper',
      tier: SubscriptionTier.values.firstWhere(
        (tier) => tier.name == data['tier'],
        orElse: () => SubscriptionTier.free,
      ),
      status: SubscriptionStatus.values.firstWhere(
        (status) => status.name == data['status'],
        orElse: () => SubscriptionStatus.active,
      ),
      subscriptionStartDate: (data['subscriptionStartDate'] as Timestamp?)?.toDate(),
      subscriptionEndDate: (data['subscriptionEndDate'] as Timestamp?)?.toDate(),
      lastPaymentDate: (data['lastPaymentDate'] as Timestamp?)?.toDate(),
      nextPaymentDate: (data['nextPaymentDate'] as Timestamp?)?.toDate(),
      paymentMethodId: data['paymentMethodId'],
      stripeCustomerId: data['stripeCustomerId'],
      stripeSubscriptionId: data['stripeSubscriptionId'],
      stripePriceId: data['stripePriceId'],
      monthlyPrice: data['monthlyPrice']?.toDouble(),
      features: Map<String, dynamic>.from(data['features'] ?? {}),
      limits: Map<String, dynamic>.from(data['limits'] ?? {}),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userType': userType,
      'tier': tier.name,
      'status': status.name,
      'subscriptionStartDate': subscriptionStartDate != null 
          ? Timestamp.fromDate(subscriptionStartDate!) : null,
      'subscriptionEndDate': subscriptionEndDate != null 
          ? Timestamp.fromDate(subscriptionEndDate!) : null,
      'lastPaymentDate': lastPaymentDate != null 
          ? Timestamp.fromDate(lastPaymentDate!) : null,
      'nextPaymentDate': nextPaymentDate != null 
          ? Timestamp.fromDate(nextPaymentDate!) : null,
      'paymentMethodId': paymentMethodId,
      'stripeCustomerId': stripeCustomerId,
      'stripeSubscriptionId': stripeSubscriptionId,
      'stripePriceId': stripePriceId,
      'monthlyPrice': monthlyPrice,
      'features': features,
      'limits': limits,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserSubscription copyWith({
    String? id,
    String? userId,
    String? userType,
    SubscriptionTier? tier,
    SubscriptionStatus? status,
    DateTime? subscriptionStartDate,
    DateTime? subscriptionEndDate,
    DateTime? lastPaymentDate,
    DateTime? nextPaymentDate,
    String? paymentMethodId,
    String? stripeCustomerId,
    String? stripeSubscriptionId,
    String? stripePriceId,
    double? monthlyPrice,
    Map<String, dynamic>? features,
    Map<String, dynamic>? limits,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserSubscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userType: userType ?? this.userType,
      tier: tier ?? this.tier,
      status: status ?? this.status,
      subscriptionStartDate: subscriptionStartDate ?? this.subscriptionStartDate,
      subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
      nextPaymentDate: nextPaymentDate ?? this.nextPaymentDate,
      paymentMethodId: paymentMethodId ?? this.paymentMethodId,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      stripeSubscriptionId: stripeSubscriptionId ?? this.stripeSubscriptionId,
      stripePriceId: stripePriceId ?? this.stripePriceId,
      monthlyPrice: monthlyPrice ?? this.monthlyPrice,
      features: features ?? this.features,
      limits: limits ?? this.limits,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isFree => tier == SubscriptionTier.free;
  bool get isPremium => tier != SubscriptionTier.free;
  bool get isShopperPro => tier == SubscriptionTier.shopperPro;
  bool get isVendorPro => tier == SubscriptionTier.vendorPro;
  bool get isMarketOrganizerPro => tier == SubscriptionTier.marketOrganizerPro;
  bool get isEnterprise => tier == SubscriptionTier.enterprise;
  bool get isActive => status == SubscriptionStatus.active;
  bool get isExpired => status == SubscriptionStatus.expired;
  bool get isCancelled => status == SubscriptionStatus.cancelled;
  bool get isPastDue => status == SubscriptionStatus.pastDue;

  bool get hasValidSubscription => isActive && isPremium;

  /// Get the monthly price for this subscription tier
  double getMonthlyPrice() {
    if (monthlyPrice != null) return monthlyPrice!;
    return _getPriceForTier(tier, userType);
  }

  /// Get Stripe Price ID for this subscription tier
  String getStripePriceId() {
    if (stripePriceId != null) return stripePriceId!;
    return _getStripePriceIdForTier(tier, userType);
  }

  static double _getPriceForTier(SubscriptionTier tier, String userType) {
    switch (tier) {
      case SubscriptionTier.free:
        return 0.00;
      case SubscriptionTier.shopperPro:
        return 4.00; // $4.00/month
      case SubscriptionTier.vendorPro:
        return 29.00; // $29.00/month
      case SubscriptionTier.marketOrganizerPro:
        return 99.00; // $99.00/month
      case SubscriptionTier.enterprise:
        return 199.99; // $199.99/month
      default:
        return 0.00;
    }
  }

  static String _getStripePriceIdForTier(SubscriptionTier tier, String userType) {
    switch (tier) {
      case SubscriptionTier.free:
        return '';
      case SubscriptionTier.shopperPro:
        return dotenv.env['STRIPE_PRICE_SHOPPER_PRO'] ?? '';
      case SubscriptionTier.vendorPro:
        return dotenv.env['STRIPE_PRICE_VENDOR_PRO'] ?? '';
      case SubscriptionTier.marketOrganizerPro:
        return dotenv.env['STRIPE_PRICE_MARKET_ORGANIZER_PRO'] ?? '';
      case SubscriptionTier.enterprise:
        return dotenv.env['STRIPE_PRICE_ENTERPRISE'] ?? '';
    }
  }

  bool hasFeature(String featureName) {
    if (isFree) {
      return _getFreeFeatures(userType).contains(featureName);
    }
    return features.containsKey(featureName) ? features[featureName] == true : true;
  }

  int getLimit(String limitName) {
    if (isFree) {
      return _getFreeLimits(userType)[limitName] ?? 0;
    }
    return limits[limitName] ?? -1; // -1 means unlimited
  }

  bool isWithinLimit(String limitName, int currentUsage) {
    final limit = getLimit(limitName);
    return limit == -1 || currentUsage < limit; // -1 means unlimited
  }

  List<String> _getFreeFeatures(String userType) {
    switch (userType) {
      case 'vendor':
        return [
          'basic_profile',
          'market_application',
          'basic_post_creation',
          'application_status_tracking',
        ];
      case 'market_organizer':
        return [
          'market_creation',
          'basic_editing',
          'vendor_communication',
          'basic_event_management',
          'application_review',
        ];
      case 'shopper':
        return [
          'browse_markets',
          'basic_search_location',
          'event_calendar_viewing',
          'limited_favorites',
        ];
      default:
        return [];
    }
  }

  Map<String, int> _getFreeLimits(String userType) {
    switch (userType) {
      case 'vendor':
        return {
          'market_applications_per_month': 5,
          'photo_uploads_per_post': 3,
          'markets_managed': -1, // unlimited for vendors
        };
      case 'market_organizer':
        return {
          'markets_managed': -1, // unlimited
          'events_per_month': 10,
          'vendor_communications_per_day': 50,
        };
      case 'shopper':
        return {
          'saved_favorites': 10,
          'searches_per_day': 25,
          'followed_vendors': 0, // no following in free tier
        };
      default:
        return {};
    }
  }

  Map<String, dynamic> get defaultFeaturesForTier {
    switch (tier) {
      case SubscriptionTier.free:
        return {};
      case SubscriptionTier.shopperPro:
        return {
          // Shopper Pro Features
          'enhanced_search': true,
          'unlimited_favorites': true,
          'vendor_following': true,
          'personalized_recommendations': true,
          'exclusive_deals_access': true,
          'priority_notifications': true,
          'advanced_filtering': true,
          'market_alerts': true,
          'seasonal_insights': true,
          'recipe_integration': true,
        };
      case SubscriptionTier.vendorPro:
        return {
          // Vendor Pro Features
          'market_discovery': true,
          'full_vendor_analytics': true,
          'unlimited_markets': true,
          'sales_tracking': true,
          'customer_acquisition_analysis': true,
          'profit_optimization': true,
          'market_expansion_recommendations': true,
          'seasonal_business_planning': true,
          'weather_correlation_data': true,
        };
      case SubscriptionTier.marketOrganizerPro:
        return {
          // Market Organizer Pro Features
          'vendor_discovery': true,
          'multi_market_management': true,
          'vendor_analytics_dashboard': true,
          'vendor_communication_suite': true,
          'bulk_messaging': true,
          'message_templates': true,
          'communication_analytics': true,
          'financial_reporting': true,
          'vendor_performance_ranking': true,
          'automated_recruitment': true,
          'budget_planning_tools': true,
          'financial_forecasting': true,
          'advanced_market_intelligence': true,
        };
      case SubscriptionTier.enterprise:
        return {
          // All Market Organizer Pro features
          'vendor_discovery': true,
          'multi_market_management': true,
          'vendor_analytics_dashboard': true,
          'vendor_communication_suite': true,
          'bulk_messaging': true,
          'message_templates': true,
          'communication_analytics': true,
          'financial_reporting': true,
          'vendor_performance_ranking': true,
          'automated_recruitment': true,
          'budget_planning_tools': true,
          'financial_forecasting': true,
          'advanced_market_intelligence': true,
          
          // Enterprise-specific features
          'white_label_analytics': true,
          'api_access': true,
          'custom_reporting': true,
          'custom_branding': true,
          'dedicated_account_manager': true,
          'advanced_data_export': true,
          'third_party_integrations': true,
          'enterprise_sla': true,
        };
      default:
        return {};
    }
  }

  Map<String, int> get defaultPremiumLimits {
    return {
      'monthly_markets': -1, // unlimited
      'photo_uploads': -1, // unlimited
      'global_products': -1, // unlimited
      'markets_managed': -1, // unlimited
      'events_per_month': -1, // unlimited
      'saved_favorites': -1, // unlimited
    };
  }

  factory UserSubscription.createFree(String userId, String userType) {
    final now = DateTime.now();
    return UserSubscription(
      id: '',
      userId: userId,
      userType: userType,
      tier: SubscriptionTier.free,
      status: SubscriptionStatus.active,
      features: {},
      limits: {},
      metadata: {},
      createdAt: now,
      updatedAt: now,
    );
  }

  UserSubscription upgradeToTier(
    SubscriptionTier newTier, {
    String? stripeCustomerId,
    String? stripeSubscriptionId,
    String? paymentMethodId,
    String? stripePriceId,
  }) {
    final now = DateTime.now();
    final upgradedSubscription = copyWith(
      tier: newTier,
      status: SubscriptionStatus.active,
      subscriptionStartDate: now,
      stripeCustomerId: stripeCustomerId,
      stripeSubscriptionId: stripeSubscriptionId,
      paymentMethodId: paymentMethodId,
      stripePriceId: stripePriceId ?? _getStripePriceIdForTier(newTier, userType),
      monthlyPrice: _getPriceForTier(newTier, userType),
      updatedAt: now,
    );
    
    return upgradedSubscription.copyWith(
      features: upgradedSubscription.defaultFeaturesForTier,
      limits: upgradedSubscription.defaultPremiumLimits,
    );
  }

  // Keep backward compatibility
  UserSubscription upgradeToPremium({
    String? stripeCustomerId,
    String? stripeSubscriptionId,
    String? paymentMethodId,
    String? stripePriceId,
  }) {
    // Default to appropriate tier based on user type
    final targetTier = userType == 'shopper' 
        ? SubscriptionTier.shopperPro
        : userType == 'vendor' 
        ? SubscriptionTier.vendorPro
        : userType == 'market_organizer'
        ? SubscriptionTier.marketOrganizerPro
        : SubscriptionTier.shopperPro; // Default fallback
    
    return upgradeToTier(
      targetTier,
      stripeCustomerId: stripeCustomerId,
      stripeSubscriptionId: stripeSubscriptionId,
      paymentMethodId: paymentMethodId,
      stripePriceId: stripePriceId,
    );
  }

  UserSubscription cancel() {
    return copyWith(
      status: SubscriptionStatus.cancelled,
      subscriptionEndDate: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        userType,
        tier,
        status,
        subscriptionStartDate,
        subscriptionEndDate,
        lastPaymentDate,
        nextPaymentDate,
        paymentMethodId,
        stripeCustomerId,
        stripeSubscriptionId,
        stripePriceId,
        monthlyPrice,
        features,
        limits,
        metadata,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() {
    return 'UserSubscription(id: $id, userId: $userId, userType: $userType, tier: ${tier.name}, status: ${status.name})';
  }
}