# Subscription Implementation Plan

## **📋 OVERVIEW**
This document outlines the technical implementation strategy for HiPop's subscription system based on the feature breakdown. This plan follows a phased approach to minimize risk and validate market demand at each step.

---

## **🏗️ PHASE 1: FOUNDATION (Weeks 1-4)**

### **1.1 Database Schema Updates**

#### **User Subscription Model**
```dart
class UserSubscription {
  String id;
  String userId;
  SubscriptionType type; // shopper_premium, vendor_premium, free
  SubscriptionStatus status; // active, cancelled, expired, trial
  DateTime startDate;
  DateTime endDate;
  DateTime? trialEndDate;
  String? stripeSubscriptionId;
  String? stripeCustomerId;
  Map<String, dynamic> features; // Feature flags
  DateTime createdAt;
  DateTime updatedAt;
}

enum SubscriptionType {
  free,
  shopperPremium,
  vendorPremium
}

enum SubscriptionStatus {
  trial,
  active,
  pastDue,
  cancelled,
  expired
}
```

#### **Usage Tracking Model** (Already exists, enhance)
```dart
// Enhance existing usage_tracking.dart
class UsageTracking {
  // ... existing fields ...
  
  // Add subscription-specific tracking
  int searchQueriesUsed;
  int favoritesCount;
  int notificationsReceived;
  int featuredPostsUsed;
  Map<String, int> featureUsage;
  
  // Limits based on subscription
  Map<String, int> featureLimits;
}
```

#### **Firestore Collections Structure**
```
/subscriptions/{userId}
  - subscription data
  - feature flags
  - usage limits

/subscription_transactions/{transactionId}
  - payment records
  - stripe webhook data

/feature_flags/{userId}
  - granular feature permissions
  - A/B testing flags
```

### **1.2 Core Services Implementation**

#### **SubscriptionService**
```dart
class SubscriptionService {
  // Subscription management
  Future<UserSubscription?> getUserSubscription(String userId);
  Future<void> createSubscription(UserSubscription subscription);
  Future<void> updateSubscription(String userId, Map<String, dynamic> updates);
  
  // Feature checking
  bool hasFeature(String userId, String featureName);
  bool canUseFeature(String userId, String featureName);
  Future<void> trackFeatureUsage(String userId, String featureName);
  
  // Stripe integration
  Future<String> createStripeCustomer(UserProfile user);
  Future<String> createStripeSubscription(String customerId, String priceId);
  Future<void> cancelStripeSubscription(String subscriptionId);
}
```

#### **FeatureGateService**
```dart
class FeatureGateService {
  // Feature gates for different subscription tiers
  static const Map<String, Map<String, dynamic>> FEATURE_GATES = {
    'shopper_free': {
      'favorites_limit': 10,
      'search_advanced': false,
      'notifications_push': false,
      'feed_unlimited': false,
    },
    'shopper_premium': {
      'favorites_limit': -1, // unlimited
      'search_advanced': true,
      'notifications_push': true,
      'feed_unlimited': true,
    },
    'vendor_free': {
      'featured_posts': 0,
      'post_scheduling': false,
      'premium_badge': false,
      'enhanced_visibility': false,
    },
    'vendor_premium': {
      'featured_posts': 5,
      'post_scheduling': true,
      'premium_badge': true,
      'enhanced_visibility': true,
    },
  };
  
  static bool canAccessFeature(UserSubscription subscription, String feature);
  static int getFeatureLimit(UserSubscription subscription, String feature);
}
```

### **1.3 Payment Integration (Stripe)**

#### **Payment Models**
```dart
class PaymentIntent {
  String id;
  String userId;
  String stripePaymentIntentId;
  int amount;
  String currency;
  PaymentStatus status;
  String subscriptionType;
  DateTime createdAt;
}

class SubscriptionPlan {
  String id;
  String name;
  String stripePriceId;
  int priceInCents;
  String currency;
  String interval; // month, year
  SubscriptionType type;
  Map<String, dynamic> features;
}
```

#### **Stripe Service**
```dart
class StripeService {
  static const STRIPE_PRICE_IDS = {
    'shopper_premium_monthly': 'price_shopper_premium_monthly',
    'vendor_premium_monthly': 'price_vendor_premium_monthly',
  };
  
  Future<PaymentIntent> createPaymentIntent(String userId, String planId);
  Future<void> confirmPayment(String paymentIntentId);
  Future<void> handleWebhook(Map<String, dynamic> webhookData);
}
```

---

## **🔧 PHASE 2: CORE FEATURES (Weeks 5-8)**

### **2.1 Shopper Premium Features**

#### **Advanced Search Implementation**
```dart
class AdvancedSearchService {
  Future<List<VendorPost>> searchWithFilters({
    String? query,
    double? radiusKm,
    List<String>? marketTypes,
    DateTimeRange? timeRange,
    PriceRange? priceRange,
    List<String>? certifications,
  });
  
  // Elasticsearch/Algolia integration for product search
  Future<List<VendorPost>> searchProducts(String query, SearchFilters filters);
}

class SearchFilters {
  double? maxDistance;
  List<MarketType>? marketTypes;
  DateTimeRange? dateRange;
  PriceRange? priceRange;
  List<Certification>? certifications;
  Location? userLocation;
}
```

#### **Enhanced Favorites System**
```dart
class FavoriteList {
  String id;
  String userId;
  String name;
  String? description;
  List<String> itemIds;
  FavoriteItemType type; // vendors, markets, mixed
  List<String> tags;
  DateTime createdAt;
  DateTime updatedAt;
}

class FavoritesService {
  // List management
  Future<List<FavoriteList>> getUserFavoriteLists(String userId);
  Future<String> createFavoriteList(String userId, String name);
  Future<void> addToFavoriteList(String listId, String itemId);
  
  // Premium features
  Future<void> addTagsToFavorite(String favoriteId, List<String> tags);
  Future<void> addNoteToFavorite(String favoriteId, String note);
  
  // Limits checking
  bool canAddFavorite(String userId);
  int getFavoriteLimit(String userId);
}
```

#### **Push Notification System**
```dart
class NotificationService {
  // Setup
  Future<void> initializePushNotifications();
  Future<String?> getFCMToken();
  
  // Subscription-based notifications
  Future<void> subscribeToVendorUpdates(String userId, String vendorId);
  Future<void> subscribeToMarketUpdates(String userId, String marketId);
  
  // Smart notifications
  Future<void> sendSmartTimingNotification(String userId, String message);
  Future<void> sendLocationBasedNotification(String userId, List<String> favoriteIds);
  
  // Notification types
  Future<void> sendVendorPostNotification(String vendorId, String postId);
  Future<void> sendMarketOpeningSoonNotification(String marketId);
  Future<void> sendCustomAlertNotification(String userId, AlertCriteria criteria);
}
```

### **2.2 Vendor Premium Features**

#### **Featured Posts System**
```dart
class FeaturedPost {
  String id;
  String postId;
  String vendorId;
  DateTime startTime;
  DateTime endTime;
  FeaturedPostStatus status;
  int creditsUsed;
  Map<String, dynamic> performance; // views, clicks, etc.
}

class FeaturedPostService {
  Future<void> promotePost(String postId, Duration duration);
  Future<int> getRemainingCredits(String vendorId);
  Future<void> deductCredit(String vendorId);
  Future<List<FeaturedPost>> getFeaturedPostsInArea(Location location);
}
```

#### **Premium Badge & Visibility**
```dart
class VendorVisibilityService {
  Future<bool> isPremiumVendor(String vendorId);
  Future<List<VendorPost>> getPostsWithPremiumBoost(List<VendorPost> posts);
  Future<int> calculatePostRanking(VendorPost post, Location userLocation);
  
  // Search result enhancement
  Future<List<SearchResult>> enhanceSearchResults(
    List<SearchResult> results,
    String query,
    Location userLocation
  );
}
```

---

## **🎨 PHASE 3: UI/UX IMPLEMENTATION (Weeks 9-12)**

### **3.1 Subscription Management UI**

#### **Subscription Screen**
```dart
class SubscriptionScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Subscription')),
      body: Column(
        children: [
          CurrentPlanCard(),
          if (!user.isPremium) ...[
            PremiumBenefitsList(),
            UpgradeButton(),
          ],
          if (user.isPremium) ...[
            UsageStatsCard(),
            ManageSubscriptionButton(),
          ],
        ],
      ),
    );
  }
}
```

#### **Paywall Components**
```dart
class FeaturePaywallDialog extends StatelessWidget {
  final String featureName;
  final String description;
  final VoidCallback onUpgrade;
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Premium Feature'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 48, color: Colors.amber),
          SizedBox(height: 16),
          Text(description),
          SizedBox(height: 16),
          Text('Upgrade to Premium to unlock this feature'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Maybe Later'),
        ),
        ElevatedButton(
          onPressed: onUpgrade,
          child: Text('Upgrade Now'),
        ),
      ],
    );
  }
}
```

### **3.2 Premium Feature Integration**

#### **Search Screen Enhancement**
```dart
class SearchScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SearchBar(),
        if (user.isPremium) ...[
          AdvancedFiltersSection(),
          RadiusSlider(),
          MarketTypeChips(),
        ] else ...[
          PremiumFeaturePreview(),
        ],
        SearchResults(),
      ],
    );
  }
}
```

#### **Favorites Screen Enhancement**
```dart
class FavoritesScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (user.isPremium) ...[
          FavoriteListTabs(),
          CreateListButton(),
        ],
        FavoritesList(),
        if (!user.isPremium && favorites.length >= 10) ...[
          FavoriteLimitReachedCard(),
        ],
      ],
    );
  }
}
```

---

## **⚡ PHASE 4: ADVANCED FEATURES (Weeks 13-16)**

### **4.1 Personalized Feed Algorithm**

#### **Feed Ranking Service**
```dart
class FeedRankingService {
  Future<List<VendorPost>> rankPostsForUser(
    String userId,
    List<VendorPost> posts,
    Location userLocation
  ) async {
    final userPreferences = await getUserPreferences(userId);
    final interactionHistory = await getInteractionHistory(userId);
    
    return posts.map((post) {
      double score = calculatePostScore(
        post,
        userPreferences,
        interactionHistory,
        userLocation
      );
      return PostWithScore(post, score);
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score))
      ..map((p) => p.post).toList();
  }
  
  double calculatePostScore(
    VendorPost post,
    UserPreferences preferences,
    InteractionHistory history,
    Location userLocation
  ) {
    double score = 0.0;
    
    // Recency score
    score += calculateRecencyScore(post.createdAt);
    
    // Distance score
    score += calculateDistanceScore(post.location, userLocation);
    
    // User preference alignment
    score += calculatePreferenceScore(post, preferences);
    
    // Historical interaction alignment
    score += calculateInteractionScore(post, history);
    
    // Premium boost
    if (post.vendor.isPremium) {
      score *= 1.2;
    }
    
    return score;
  }
}
```

### **4.2 Smart Recommendations**

#### **Recommendation Engine**
```dart
class RecommendationService {
  Future<List<VendorPost>> getRecommendationsForUser(String userId) async {
    final userProfile = await getUserProfile(userId);
    final favorites = await getFavorites(userId);
    final interactionHistory = await getInteractionHistory(userId);
    
    // Content-based recommendations
    final contentBased = await getContentBasedRecommendations(
      favorites, 
      userProfile.preferences
    );
    
    // Collaborative filtering
    final collaborative = await getCollaborativeRecommendations(
      userId,
      interactionHistory
    );
    
    // Location-based
    final locationBased = await getLocationBasedRecommendations(
      userProfile.location,
      userProfile.preferences
    );
    
    // Merge and rank
    return mergeAndRankRecommendations([
      contentBased,
      collaborative,
      locationBased,
    ]);
  }
}
```

---

## **🔄 PHASE 5: VENDOR ADVANCED FEATURES (Weeks 17-20)**

### **5.1 Post Scheduling System**

#### **Scheduled Post Model**
```dart
class ScheduledPost {
  String id;
  String vendorId;
  VendorPost postContent;
  DateTime scheduledTime;
  ScheduledPostStatus status;
  String? recurringPattern; // daily, weekly, monthly
  DateTime? recurringEndDate;
  DateTime createdAt;
}

class PostSchedulingService {
  Future<void> schedulePost(String vendorId, VendorPost post, DateTime scheduleTime);
  Future<void> scheduleRecurringPost(String vendorId, VendorPost post, RecurringPattern pattern);
  Future<List<ScheduledPost>> getScheduledPosts(String vendorId);
  Future<void> executeScheduledPosts();
}
```

### **5.2 Post Templates**

#### **Template System**
```dart
class PostTemplate {
  String id;
  String vendorId;
  String name;
  String description;
  Map<String, dynamic> template; // Post content template
  List<String> tags;
  DateTime createdAt;
  DateTime updatedAt;
}

class PostTemplateService {
  Future<void> savePostAsTemplate(String vendorId, VendorPost post, String templateName);
  Future<List<PostTemplate>> getVendorTemplates(String vendorId);
  Future<VendorPost> createPostFromTemplate(String templateId, Map<String, dynamic> variables);
}
```

### **5.3 Follower Management**

#### **Follower System**
```dart
class VendorFollower {
  String id;
  String vendorId;
  String followerId;
  DateTime followedAt;
  bool notificationsEnabled;
  List<String> interestedCategories;
}

class FollowerManagementService {
  Future<List<VendorFollower>> getVendorFollowers(String vendorId);
  Future<void> sendDirectUpdateToFollowers(String vendorId, String message);
  Future<Map<String, dynamic>> getFollowerInsights(String vendorId);
  Future<void> segmentFollowers(String vendorId, FollowerSegment segment);
}
```

---

## **📊 PHASE 6: ANALYTICS & OPTIMIZATION (Weeks 21-24)**

### **6.1 Subscription Analytics**

#### **Analytics Service**
```dart
class SubscriptionAnalyticsService {
  // Conversion tracking
  Future<void> trackConversionEvent(String userId, String event, Map<String, dynamic> properties);
  
  // Usage analytics
  Future<Map<String, dynamic>> getUserUsageStats(String userId);
  Future<Map<String, dynamic>> getFeatureUsageStats(String feature);
  
  // Retention metrics
  Future<double> calculateRetentionRate(SubscriptionType type, Duration period);
  Future<List<ChurnPrediction>> getChurnPredictions();
  
  // Revenue analytics
  Future<Map<String, dynamic>> getSubscriptionRevenue(DateTimeRange period);
  Future<double> calculateLTV(SubscriptionType type);
}
```

### **6.2 A/B Testing Framework**

#### **Feature Flag System**
```dart
class FeatureFlagService {
  Future<bool> isFeatureEnabled(String userId, String featureName);
  Future<Map<String, dynamic>> getFeatureConfig(String userId, String featureName);
  
  // A/B testing
  Future<String> getTestVariant(String userId, String testName);
  Future<void> trackTestEvent(String userId, String testName, String event);
}
```

---

## **🚀 DEPLOYMENT STRATEGY**

### **Environment Setup**
1. **Development**: Full feature development and testing
2. **Staging**: Integration testing with real Stripe test environment
3. **Production**: Gradual rollout with feature flags

### **Feature Flag Rollout**
```dart
// Gradual rollout percentages
const ROLLOUT_SCHEDULE = {
  'week_1': 0.05,  // 5% of users
  'week_2': 0.15,  // 15% of users
  'week_3': 0.35,  // 35% of users
  'week_4': 0.70,  // 70% of users
  'week_5': 1.00,  // 100% of users
};
```

### **Monitoring & Alerts**
- Revenue tracking dashboards
- Subscription conversion funnels
- Feature usage analytics
- Performance monitoring
- Error tracking and alerting

---

## **📝 TECHNICAL CONSIDERATIONS**

### **Performance Optimization**
- Implement caching for subscription status checks
- Lazy loading for premium features
- Optimize search indexing for advanced filters
- Background processing for scheduled posts

### **Security**
- Stripe webhook signature verification
- Secure payment processing
- Feature access validation on server-side
- Rate limiting for premium features

### **Scalability**
- Horizontal scaling for notification service
- Database indexing for subscription queries
- CDN for enhanced media uploads
- Queue system for background jobs

### **Error Handling**
- Graceful degradation when payment fails
- Retry logic for failed payments
- Clear error messages for users
- Automatic subscription status updates

---

## **✅ SUCCESS CRITERIA**

### **Technical Metrics**
- **Uptime**: 99.9% availability for payment processing
- **Performance**: <2s load time for premium features
- **Security**: Zero payment security incidents
- **Scalability**: Handle 10x current user base

### **Business Metrics**
- **Conversion Rate**: 20% shopper, 30% vendor premium adoption
- **Retention**: 85% monthly retention for premium users
- **Revenue**: $50K+ monthly recurring revenue within 6 months
- **Feature Usage**: 80%+ premium users actively use key features

This implementation plan provides a comprehensive roadmap for building HiPop's subscription system with a focus on user experience, technical excellence, and business success.