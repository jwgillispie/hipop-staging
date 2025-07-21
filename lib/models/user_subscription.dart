import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum SubscriptionTier {
  free,
  premium,
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
      features: features ?? this.features,
      limits: limits ?? this.limits,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isFree => tier == SubscriptionTier.free;
  bool get isPremium => tier == SubscriptionTier.premium;
  bool get isActive => status == SubscriptionStatus.active;
  bool get isExpired => status == SubscriptionStatus.expired;
  bool get isCancelled => status == SubscriptionStatus.cancelled;
  bool get isPastDue => status == SubscriptionStatus.pastDue;

  bool get hasValidSubscription => isActive && isPremium;

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
        return ['basic_profile', 'market_application', 'basic_analytics'];
      case 'market_organizer':
        return ['market_creation', 'vendor_communication', 'basic_event_management'];
      case 'shopper':
        return ['browse_markets', 'basic_search', 'event_calendar'];
      default:
        return [];
    }
  }

  Map<String, int> _getFreeLimits(String userType) {
    switch (userType) {
      case 'vendor':
        return {'monthly_markets': 5, 'photo_uploads': 3};
      case 'market_organizer':
        return {'markets_managed': 1, 'events_per_month': 10};
      case 'shopper':
        return {'saved_favorites': 10};
      default:
        return {};
    }
  }

  Map<String, dynamic> get defaultPremiumFeatures {
    switch (userType) {
      case 'vendor':
        return {
          'unlimited_markets': true,
          'advanced_analytics': true,
          'priority_listing': true,
          'bulk_operations': true,
        };
      case 'market_organizer':
        return {
          'application_management': true,
          'advanced_analytics': true,
          'bulk_vendor_management': true,
          'custom_branding': true,
        };
      case 'shopper':
        return {
          'personalized_recommendations': true,
          'advanced_search': true,
          'vendor_notifications': true,
          'unlimited_favorites': true,
        };
      default:
        return {};
    }
  }

  Map<String, int> get defaultPremiumLimits {
    return {
      'monthly_markets': -1, // unlimited
      'photo_uploads': -1, // unlimited
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

  UserSubscription upgradeToPremium({
    String? stripeCustomerId,
    String? stripeSubscriptionId,
    String? paymentMethodId,
  }) {
    final now = DateTime.now();
    return copyWith(
      tier: SubscriptionTier.premium,
      status: SubscriptionStatus.active,
      subscriptionStartDate: now,
      features: defaultPremiumFeatures,
      limits: defaultPremiumLimits,
      stripeCustomerId: stripeCustomerId,
      stripeSubscriptionId: stripeSubscriptionId,
      paymentMethodId: paymentMethodId,
      updatedAt: now,
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