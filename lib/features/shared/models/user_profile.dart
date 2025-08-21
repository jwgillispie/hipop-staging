import 'package:cloud_firestore/cloud_firestore.dart';

enum VerificationStatus {
  pending,
  approved,
  rejected,
}

class UserProfile {
  final String userId;
  final String userType; // 'vendor', 'shopper', or 'market_organizer'
  final String email;
  final String? displayName;
  final String? businessName; // For vendors
  final String? organizationName; // For market organizers
  final List<String> managedMarketIds; // For market organizers - markets they manage
  final String? bio;
  final String? instagramHandle;
  final String? phoneNumber;
  final String? website;
  final List<String> categories; // For vendors - what they sell
  final String? specificProducts; // For vendors - specific product details
  final String? featuredItems; // For vendors - featured items text field
  final List<String> ccEmails; // For vendors - additional contact emails
  final Map<String, dynamic> preferences; // General user preferences
  final DateTime createdAt;
  final DateTime updatedAt;
  // Verification fields
  final VerificationStatus verificationStatus;
  final DateTime? verificationRequestedAt;
  final String? verificationNotes; // CEO review notes
  final String? verifiedBy; // CEO user ID
  final DateTime? verifiedAt;
  final bool profileSubmitted; // Has completed full signup flow
  final bool? welcomeNotificationShown; // Has seen welcome notification after verification
  
  // Subscription fields
  final bool isPremium;
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final String? stripePriceId;
  final DateTime? subscriptionStartDate;
  final DateTime? subscriptionEndDate;
  final String subscriptionStatus; // 'free', 'active', 'past_due', 'cancelled'

  UserProfile({
    required this.userId,
    required this.userType,
    required this.email,
    this.displayName,
    this.businessName,
    this.organizationName,
    this.managedMarketIds = const [],
    this.bio,
    this.instagramHandle,
    this.phoneNumber,
    this.website,
    this.categories = const [],
    this.specificProducts,
    this.featuredItems,
    this.ccEmails = const [],
    this.preferences = const {},
    required this.createdAt,
    required this.updatedAt,
    this.verificationStatus = VerificationStatus.pending,
    this.verificationRequestedAt,
    this.verificationNotes,
    this.verifiedBy,
    this.verifiedAt,
    this.profileSubmitted = false,
    this.welcomeNotificationShown,
    // Subscription parameters
    this.isPremium = false,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    this.stripePriceId,
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.subscriptionStatus = 'free',
  });

  // Create a copy with updated fields
  UserProfile copyWith({
    String? userId,
    String? userType,
    String? email,
    String? displayName,
    String? businessName,
    String? organizationName,
    List<String>? managedMarketIds,
    String? bio,
    String? instagramHandle,
    String? phoneNumber,
    String? website,
    List<String>? categories,
    String? specificProducts,
    String? featuredItems,
    List<String>? ccEmails,
    Map<String, dynamic>? preferences,
    DateTime? createdAt,
    DateTime? updatedAt,
    VerificationStatus? verificationStatus,
    DateTime? verificationRequestedAt,
    String? verificationNotes,
    String? verifiedBy,
    DateTime? verifiedAt,
    bool? profileSubmitted,
    bool? welcomeNotificationShown,
    // Subscription parameters
    bool? isPremium,
    String? stripeCustomerId,
    String? stripeSubscriptionId,
    String? stripePriceId,
    DateTime? subscriptionStartDate,
    DateTime? subscriptionEndDate,
    String? subscriptionStatus,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      userType: userType ?? this.userType,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      businessName: businessName ?? this.businessName,
      organizationName: organizationName ?? this.organizationName,
      managedMarketIds: managedMarketIds ?? this.managedMarketIds,
      bio: bio ?? this.bio,
      instagramHandle: instagramHandle ?? this.instagramHandle,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      website: website ?? this.website,
      categories: categories ?? this.categories,
      specificProducts: specificProducts ?? this.specificProducts,
      featuredItems: featuredItems ?? this.featuredItems,
      ccEmails: ccEmails ?? this.ccEmails,
      preferences: preferences ?? this.preferences,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verificationRequestedAt: verificationRequestedAt ?? this.verificationRequestedAt,
      verificationNotes: verificationNotes ?? this.verificationNotes,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      profileSubmitted: profileSubmitted ?? this.profileSubmitted,
      welcomeNotificationShown: welcomeNotificationShown ?? this.welcomeNotificationShown,
      // Subscription fields
      isPremium: isPremium ?? this.isPremium,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      stripeSubscriptionId: stripeSubscriptionId ?? this.stripeSubscriptionId,
      stripePriceId: stripePriceId ?? this.stripePriceId,
      subscriptionStartDate: subscriptionStartDate ?? this.subscriptionStartDate,
      subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userType': userType,
      'email': email,
      'displayName': displayName,
      'businessName': businessName,
      'organizationName': organizationName,
      'managedMarketIds': managedMarketIds,
      'bio': bio,
      'instagramHandle': instagramHandle,
      'phoneNumber': phoneNumber,
      'website': website,
      'categories': categories,
      'specificProducts': specificProducts,
      'featuredItems': featuredItems,
      'ccEmails': ccEmails,
      'preferences': preferences,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'verificationStatus': verificationStatus.name,
      'verificationRequestedAt': verificationRequestedAt != null ? Timestamp.fromDate(verificationRequestedAt!) : null,
      'verificationNotes': verificationNotes,
      'verifiedBy': verifiedBy,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'profileSubmitted': profileSubmitted,
      'welcomeNotificationShown': welcomeNotificationShown,
      // Subscription fields
      'isPremium': isPremium,
      'stripeCustomerId': stripeCustomerId,
      'stripeSubscriptionId': stripeSubscriptionId,
      'stripePriceId': stripePriceId,
      'subscriptionStartDate': subscriptionStartDate != null ? Timestamp.fromDate(subscriptionStartDate!) : null,
      'subscriptionEndDate': subscriptionEndDate != null ? Timestamp.fromDate(subscriptionEndDate!) : null,
      'subscriptionStatus': subscriptionStatus,
    };
  }

  // Create from Firestore document
  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return UserProfile(
      userId: data['userId'] ?? doc.id,
      userType: data['userType'] ?? 'shopper',
      email: data['email'] ?? '',
      displayName: data['displayName'],
      businessName: data['businessName'],
      organizationName: data['organizationName'],
      managedMarketIds: List<String>.from(data['managedMarketIds'] ?? []),
      bio: data['bio'],
      instagramHandle: data['instagramHandle'],
      phoneNumber: data['phoneNumber'],
      website: data['website'],
      categories: List<String>.from(data['categories'] ?? []),
      specificProducts: data['specificProducts'],
      featuredItems: data['featuredItems'],
      ccEmails: List<String>.from(data['ccEmails'] ?? []),
      preferences: Map<String, dynamic>.from(data['preferences'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      verificationStatus: VerificationStatus.values.firstWhere(
        (status) => status.name == data['verificationStatus'],
        orElse: () => VerificationStatus.pending,
      ),
      verificationRequestedAt: (data['verificationRequestedAt'] as Timestamp?)?.toDate(),
      verificationNotes: data['verificationNotes'],
      verifiedBy: data['verifiedBy'],
      verifiedAt: (data['verifiedAt'] as Timestamp?)?.toDate(),
      profileSubmitted: data['profileSubmitted'] ?? false,
      welcomeNotificationShown: data['welcomeNotificationShown'],
      // Subscription fields
      isPremium: data['isPremium'] ?? false,
      stripeCustomerId: data['stripeCustomerId'],
      stripeSubscriptionId: data['stripeSubscriptionId'],
      stripePriceId: data['stripePriceId'],
      subscriptionStartDate: (data['subscriptionStartDate'] as Timestamp?)?.toDate(),
      subscriptionEndDate: (data['subscriptionEndDate'] as Timestamp?)?.toDate(),
      subscriptionStatus: data['subscriptionStatus'] ?? 'free',
    );
  }

  // Create from Firestore document with explicit ID
  factory UserProfile.fromFirestoreWithId(String id, Map<String, dynamic> data) {
    return UserProfile(
      userId: data['userId'] ?? id,
      userType: data['userType'] ?? 'shopper',
      email: data['email'] ?? '',
      displayName: data['displayName'],
      businessName: data['businessName'],
      organizationName: data['organizationName'],
      managedMarketIds: List<String>.from(data['managedMarketIds'] ?? []),
      bio: data['bio'],
      instagramHandle: data['instagramHandle'],
      phoneNumber: data['phoneNumber'],
      website: data['website'],
      categories: List<String>.from(data['categories'] ?? []),
      specificProducts: data['specificProducts'],
      ccEmails: List<String>.from(data['ccEmails'] ?? []),
      preferences: Map<String, dynamic>.from(data['preferences'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      verificationStatus: VerificationStatus.values.firstWhere(
        (status) => status.name == data['verificationStatus'],
        orElse: () => VerificationStatus.pending,
      ),
      verificationRequestedAt: (data['verificationRequestedAt'] as Timestamp?)?.toDate(),
      verificationNotes: data['verificationNotes'],
      verifiedBy: data['verifiedBy'],
      verifiedAt: (data['verifiedAt'] as Timestamp?)?.toDate(),
      profileSubmitted: data['profileSubmitted'] ?? false,
      welcomeNotificationShown: data['welcomeNotificationShown'],
      // Subscription fields
      isPremium: data['isPremium'] ?? false,
      stripeCustomerId: data['stripeCustomerId'],
      stripeSubscriptionId: data['stripeSubscriptionId'],
      stripePriceId: data['stripePriceId'],
      subscriptionStartDate: (data['subscriptionStartDate'] as Timestamp?)?.toDate(),
      subscriptionEndDate: (data['subscriptionEndDate'] as Timestamp?)?.toDate(),
      subscriptionStatus: data['subscriptionStatus'] ?? 'free',
    );
  }

  // Helper method to get full name or business name for display
  String get displayTitle {
    if (userType == 'vendor' && businessName != null && businessName!.isNotEmpty) {
      return businessName!;
    }
    if (userType == 'market_organizer' && organizationName != null && organizationName!.isNotEmpty) {
      return organizationName!;
    }
    return displayName ?? email.split('@').first;
  }

  // Helper method to check if profile is complete
  bool get isProfileComplete {
    final hasBasicInfo = displayName != null && displayName!.isNotEmpty;
    
    if (userType == 'vendor') {
      // Vendors need business name or display name
      return hasBasicInfo || (businessName != null && businessName!.isNotEmpty);
    } else if (userType == 'market_organizer') {
      // Market organizers need organization name or display name, plus at least one managed market
      return (hasBasicInfo || (organizationName != null && organizationName!.isNotEmpty)) 
          && managedMarketIds.isNotEmpty;
    } else {
      // Shoppers just need display name
      return hasBasicInfo;
    }
  }

  // Helper method to get profile completion percentage
  double get profileCompletionPercentage {
    int totalFields;
    int completedFields = 0;

    // Always required
    if (email.isNotEmpty) completedFields++;
    if (displayName != null && displayName!.isNotEmpty) completedFields++;

    if (userType == 'vendor') {
      totalFields = 7;
      // Vendor-specific fields
      if (businessName != null && businessName!.isNotEmpty) completedFields++;
      if (bio != null && bio!.isNotEmpty) completedFields++;
      if (instagramHandle != null && instagramHandle!.isNotEmpty) completedFields++;
      if (categories.isNotEmpty) completedFields++;
      if (website != null && website!.isNotEmpty) completedFields++;
    } else if (userType == 'market_organizer') {
      totalFields = 8;
      // Market organizer-specific fields
      if (organizationName != null && organizationName!.isNotEmpty) completedFields++;
      if (managedMarketIds.isNotEmpty) completedFields++;
      if (bio != null && bio!.isNotEmpty) completedFields++;
      if (instagramHandle != null && instagramHandle!.isNotEmpty) completedFields++;
      if (phoneNumber != null && phoneNumber!.isNotEmpty) completedFields++;
      if (website != null && website!.isNotEmpty) completedFields++;
    } else {
      totalFields = 4;
      // Shopper-specific fields
      if (bio != null && bio!.isNotEmpty) completedFields++;
      if (instagramHandle != null && instagramHandle!.isNotEmpty) completedFields++;
    }

    return completedFields / totalFields;
  }

  @override
  String toString() {
    return 'UserProfile(userId: $userId, userType: $userType, email: $email, displayName: $displayName, businessName: $businessName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is UserProfile &&
        other.userId == userId &&
        other.userType == userType &&
        other.email == email &&
        other.displayName == displayName &&
        other.businessName == businessName &&
        other.organizationName == organizationName &&
        other.bio == bio &&
        other.instagramHandle == instagramHandle &&
        other.phoneNumber == phoneNumber &&
        other.website == website;
  }

  @override
  int get hashCode {
    return userId.hashCode ^
        userType.hashCode ^
        email.hashCode ^
        displayName.hashCode ^
        businessName.hashCode ^
        organizationName.hashCode ^
        bio.hashCode ^
        instagramHandle.hashCode ^
        phoneNumber.hashCode ^
        website.hashCode;
  }

  // Helper methods for market organizers
  bool get isMarketOrganizer => userType == 'market_organizer';
  
  bool canManageMarket(String marketId) {
    return isMarketOrganizer && managedMarketIds.contains(marketId);
  }
  
  // Add a market to managed markets (for organizers)
  UserProfile addManagedMarket(String marketId) {
    if (!isMarketOrganizer) return this;
    
    final updatedMarkets = List<String>.from(managedMarketIds);
    if (!updatedMarkets.contains(marketId)) {
      updatedMarkets.add(marketId);
    }
    
    return copyWith(
      managedMarketIds: updatedMarkets,
      updatedAt: DateTime.now(),
    );
  }
  
  // Remove a market from managed markets (for organizers)
  UserProfile removeManagedMarket(String marketId) {
    if (!isMarketOrganizer) return this;
    
    final updatedMarkets = List<String>.from(managedMarketIds);
    updatedMarkets.remove(marketId);
    
    return copyWith(
      managedMarketIds: updatedMarkets,
      updatedAt: DateTime.now(),
    );
  }

  // Verification helper methods
  bool get isVerified => verificationStatus == VerificationStatus.approved;
  bool get isPendingVerification => verificationStatus == VerificationStatus.pending;
  bool get isRejected => verificationStatus == VerificationStatus.rejected;
  bool get canAccessApp => isVerified;
  
  // CEO check - add your actual CEO email here
  bool get isCEO => email == 'jordangillispie@outlook.com';
  
  String get verificationStatusDisplayName {
    switch (verificationStatus) {
      case VerificationStatus.pending:
        return 'Pending Review';
      case VerificationStatus.approved:
        return 'Verified';
      case VerificationStatus.rejected:
        return 'Rejected';
    }
  }
  
  // Mark profile as submitted for verification
  UserProfile submitForVerification() {
    return copyWith(
      profileSubmitted: true,
      verificationStatus: VerificationStatus.pending,
      verificationRequestedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
  
  // Approve verification (CEO only)
  UserProfile approveVerification(String ceoUserId, {String? notes}) {
    return copyWith(
      verificationStatus: VerificationStatus.approved,
      verifiedBy: ceoUserId,
      verifiedAt: DateTime.now(),
      verificationNotes: notes,
      updatedAt: DateTime.now(),
    );
  }
  
  // Reject verification (CEO only)
  UserProfile rejectVerification(String ceoUserId, {String? notes}) {
    return copyWith(
      verificationStatus: VerificationStatus.rejected,
      verifiedBy: ceoUserId,
      verifiedAt: DateTime.now(),
      verificationNotes: notes,
      updatedAt: DateTime.now(),
    );
  }
}