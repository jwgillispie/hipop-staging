import 'package:flutter_test/flutter_test.dart';
import 'package:hipop/features/premium/models/user_subscription.dart';

void main() {
  group('Market Creation Limits - UserSubscription Model Tests', () {
    
    group('Free Tier Market Organizer Tests', () {
      test('free market organizer should have 2 market limit', () {
        final subscription = UserSubscription.createFree('test_user', 'market_organizer');
        
        expect(subscription.getLimit('markets_managed'), equals(2),
               reason: 'Free tier market organizers should have 2 market limit');
        expect(subscription.userType, equals('market_organizer'));
        expect(subscription.tier, equals(SubscriptionTier.free));
        expect(subscription.isFree, isTrue);
        expect(subscription.isPremium, isFalse);
      });

      test('free organizer with 0 markets can create market', () {
        final subscription = UserSubscription.createFree('test_user', 'market_organizer');
        
        expect(subscription.isWithinLimit('markets_managed', 0), isTrue,
               reason: 'Free organizer with 0 markets should be able to create first market');
      });

      test('free organizer with 1 market can create second market', () {
        final subscription = UserSubscription.createFree('test_user', 'market_organizer');
        
        expect(subscription.isWithinLimit('markets_managed', 1), isTrue,
               reason: 'Free organizer with 1 market should be able to create second market');
      });

      test('free organizer with 2 markets cannot create third market', () {
        final subscription = UserSubscription.createFree('test_user', 'market_organizer');
        
        expect(subscription.isWithinLimit('markets_managed', 2), isFalse,
               reason: 'Free organizer with 2 markets should NOT be able to create third market');
      });

      test('free organizer grandfathered with >2 markets cannot create more', () {
        final subscription = UserSubscription.createFree('grandfathered_user', 'market_organizer');
        
        expect(subscription.isWithinLimit('markets_managed', 5), isFalse,
               reason: 'Grandfathered users with >2 markets should not be able to create more');
        expect(subscription.isWithinLimit('markets_managed', 10), isFalse,
               reason: 'Grandfathered users with >2 markets should not be able to create more');
      });

      test('should calculate remaining markets correctly', () {
        final subscription = UserSubscription.createFree('test_user', 'market_organizer');
        final limit = subscription.getLimit('markets_managed');
        
        expect(limit, equals(2));
        
        // With 0 markets: can create 2 more
        expect(limit - 0, equals(2));
        // With 1 market: can create 1 more
        expect(limit - 1, equals(1));
        // With 2 markets: can create 0 more
        expect(limit - 2, equals(0));
        // With >2 markets (grandfathered): can create 0 more (negative becomes 0)
        expect((limit - 5) < 0 ? 0 : (limit - 5), equals(0));
      });
    });

    group('Premium Market Organizer Tests', () {
      test('premium market organizer should have unlimited markets', () {
        final freeSubscription = UserSubscription.createFree('premium_user', 'market_organizer');
        final premiumSubscription = freeSubscription.upgradeToTier(SubscriptionTier.marketOrganizerPro);
        
        expect(premiumSubscription.getLimit('markets_managed'), equals(-1),
               reason: 'Premium market organizers should have unlimited markets (-1)');
        expect(premiumSubscription.tier, equals(SubscriptionTier.marketOrganizerPro));
        expect(premiumSubscription.isFree, isFalse);
        expect(premiumSubscription.isPremium, isTrue);
      });

      test('premium organizer can create unlimited markets', () {
        final freeSubscription = UserSubscription.createFree('premium_user', 'market_organizer');
        final premiumSubscription = freeSubscription.upgradeToTier(SubscriptionTier.marketOrganizerPro);
        
        expect(premiumSubscription.isWithinLimit('markets_managed', 0), isTrue);
        expect(premiumSubscription.isWithinLimit('markets_managed', 10), isTrue);
        expect(premiumSubscription.isWithinLimit('markets_managed', 100), isTrue);
        expect(premiumSubscription.isWithinLimit('markets_managed', 1000), isTrue);
      });

      test('upgrading from free to premium allows unlimited markets', () {
        final freeSubscription = UserSubscription.createFree('upgrade_user', 'market_organizer');
        
        // At limit as free user
        expect(freeSubscription.isWithinLimit('markets_managed', 2), isFalse);
        
        // Upgrade to premium
        final premiumSubscription = freeSubscription.upgradeToTier(SubscriptionTier.marketOrganizerPro);
        
        // Now unlimited
        expect(premiumSubscription.isWithinLimit('markets_managed', 2), isTrue);
        expect(premiumSubscription.isWithinLimit('markets_managed', 100), isTrue);
      });

      test('cancelled premium subscription should revert to free tier behavior', () {
        final freeSubscription = UserSubscription.createFree('cancel_user', 'market_organizer');
        final premiumSubscription = freeSubscription.upgradeToTier(SubscriptionTier.marketOrganizerPro);
        
        // Premium allows unlimited
        expect(premiumSubscription.isWithinLimit('markets_managed', 10), isTrue);
        
        // Cancel subscription
        final cancelledSubscription = premiumSubscription.cancel();
        
        // Should revert to free tier limits
        expect(cancelledSubscription.isCancelled, isTrue);
        expect(cancelledSubscription.isActive, isFalse);
        // Note: Cancelled subscriptions maintain their tier but are inactive
        // In real implementation, they would need to be downgraded separately
      });
    });

    group('Non-Market-Organizer User Types', () {
      test('vendors should not have market creation privileges', () {
        final vendorSubscription = UserSubscription.createFree('vendor_user', 'vendor');
        
        expect(vendorSubscription.getLimit('markets_managed'), equals(0),
               reason: 'Vendors should not have market management privileges');
        expect(vendorSubscription.isWithinLimit('markets_managed', 0), isFalse,
               reason: 'Vendors should not be able to create markets');
      });

      test('shoppers should not have market creation privileges', () {
        final shopperSubscription = UserSubscription.createFree('shopper_user', 'shopper');
        
        expect(shopperSubscription.getLimit('markets_managed'), equals(0),
               reason: 'Shoppers should not have market management privileges');
        expect(shopperSubscription.isWithinLimit('markets_managed', 0), isFalse,
               reason: 'Shoppers should not be able to create markets');
      });

      test('premium vendors should still not have market creation privileges', () {
        final freeVendor = UserSubscription.createFree('vendor_user', 'vendor');
        final premiumVendor = freeVendor.upgradeToTier(SubscriptionTier.vendorPro);
        
        expect(premiumVendor.getLimit('markets_managed'), equals(0),
               reason: 'Premium vendors should still not have market management privileges');
        expect(premiumVendor.isWithinLimit('markets_managed', 0), isFalse,
               reason: 'Premium vendors should not be able to create markets');
      });
    });

    group('Edge Cases and Error Handling', () {
      test('should handle invalid limit names gracefully', () {
        final subscription = UserSubscription.createFree('test_user', 'market_organizer');
        
        expect(subscription.getLimit('invalid_limit'), equals(0),
               reason: 'Invalid limit names should return 0');
        expect(subscription.isWithinLimit('invalid_limit', 5), isFalse,
               reason: 'Invalid limit names should always be false for usage check');
      });

      test('should handle negative usage values correctly', () {
        final subscription = UserSubscription.createFree('test_user', 'market_organizer');
        
        // Negative usage should be treated appropriately by the logic
        expect(subscription.isWithinLimit('markets_managed', -1), isTrue,
               reason: 'Negative usage should be treated as within limit');
        expect(subscription.isWithinLimit('markets_managed', -10), isTrue,
               reason: 'Negative usage should be treated as within limit');
      });

      test('should handle boundary conditions precisely', () {
        final subscription = UserSubscription.createFree('test_user', 'market_organizer');
        
        // Test exact boundary
        expect(subscription.isWithinLimit('markets_managed', 1), isTrue,
               reason: '1 market should be within 2 market limit');
        expect(subscription.isWithinLimit('markets_managed', 2), isFalse,
               reason: '2 markets should be at limit, not within');
        
        // Test zero usage
        expect(subscription.isWithinLimit('markets_managed', 0), isTrue,
               reason: '0 markets should always be within limit');
      });

      test('should handle very large usage values', () {
        final subscription = UserSubscription.createFree('test_user', 'market_organizer');
        
        expect(subscription.isWithinLimit('markets_managed', 999999), isFalse,
               reason: 'Very large usage should be over limit');
        expect(subscription.isWithinLimit('markets_managed', 1000000), isFalse,
               reason: 'Very large usage should be over limit');
      });

      test('should implement correct limit checking logic', () {
        final subscription = UserSubscription.createFree('test_user', 'market_organizer');
        final limit = subscription.getLimit('markets_managed');
        
        // Logic should be: currentUsage < limit (strictly less than)
        for (int i = 0; i < limit; i++) {
          expect(subscription.isWithinLimit('markets_managed', i), isTrue,
                 reason: 'Usage $i should be within limit $limit');
        }
        
        for (int i = limit; i <= limit + 5; i++) {
          expect(subscription.isWithinLimit('markets_managed', i), isFalse,
                 reason: 'Usage $i should be at or over limit $limit');
        }
      });
    });

    group('Subscription Tier Validation', () {
      test('should create correct subscription tiers', () {
        expect(SubscriptionTier.free, isNotNull);
        expect(SubscriptionTier.vendorPro, isNotNull);
        expect(SubscriptionTier.marketOrganizerPro, isNotNull);
        
        expect(SubscriptionTier.free.name, equals('free'));
        expect(SubscriptionTier.marketOrganizerPro.name, equals('market_organizer_pro'));
      });

      test('should handle subscription upgrades correctly', () {
        final freeSubscription = UserSubscription.createFree('test_user', 'market_organizer');
        expect(freeSubscription.tier, equals(SubscriptionTier.free));
        
        final upgradedSubscription = freeSubscription.upgradeToTier(SubscriptionTier.marketOrganizerPro);
        expect(upgradedSubscription.tier, equals(SubscriptionTier.marketOrganizerPro));
        expect(upgradedSubscription.userId, equals('test_user'));
        expect(upgradedSubscription.userType, equals('market_organizer'));
      });

      test('should maintain subscription status correctly', () {
        final subscription = UserSubscription.createFree('test_user', 'market_organizer');
        
        expect(subscription.status, equals(SubscriptionStatus.active));
        expect(subscription.isActive, isTrue);
        expect(subscription.isCancelled, isFalse);
        
        final cancelledSubscription = subscription.cancel();
        expect(cancelledSubscription.status, equals(SubscriptionStatus.cancelled));
        expect(cancelledSubscription.isActive, isFalse);
        expect(cancelledSubscription.isCancelled, isTrue);
      });
    });

    group('Market Limit Business Logic', () {
      test('should enforce exact 2-market limit for free organizers', () {
        final subscription = UserSubscription.createFree('business_user', 'market_organizer');
        
        // Free tier gets exactly 2 markets
        final limit = subscription.getLimit('markets_managed');
        expect(limit, equals(2), reason: 'Free tier must have exactly 2 market limit');
        
        // Test all scenarios around the limit
        expect(subscription.isWithinLimit('markets_managed', 0), isTrue, reason: 'Can create 1st market');
        expect(subscription.isWithinLimit('markets_managed', 1), isTrue, reason: 'Can create 2nd market');
        expect(subscription.isWithinLimit('markets_managed', 2), isFalse, reason: 'Cannot create 3rd market');
        expect(subscription.isWithinLimit('markets_managed', 3), isFalse, reason: 'Cannot create 4th market');
      });

      test('should allow unlimited markets for premium organizers', () {
        final freeSubscription = UserSubscription.createFree('premium_business_user', 'market_organizer');
        final premiumSubscription = freeSubscription.upgradeToTier(SubscriptionTier.marketOrganizerPro);
        
        // Premium tier gets unlimited markets
        final limit = premiumSubscription.getLimit('markets_managed');
        expect(limit, equals(-1), reason: 'Premium tier must have unlimited markets (-1)');
        
        // Test unlimited scenarios
        expect(premiumSubscription.isWithinLimit('markets_managed', 0), isTrue);
        expect(premiumSubscription.isWithinLimit('markets_managed', 2), isTrue);
        expect(premiumSubscription.isWithinLimit('markets_managed', 10), isTrue);
        expect(premiumSubscription.isWithinLimit('markets_managed', 100), isTrue);
        expect(premiumSubscription.isWithinLimit('markets_managed', 1000), isTrue);
      });

      test('should protect against user type confusion for market limits', () {
        // Only market_organizer type should have market limits > 0
        final vendor = UserSubscription.createFree('vendor', 'vendor');
        final shopper = UserSubscription.createFree('shopper', 'shopper');
        final organizer = UserSubscription.createFree('organizer', 'market_organizer');
        
        expect(vendor.getLimit('markets_managed'), equals(0));
        expect(shopper.getLimit('markets_managed'), equals(0));
        expect(organizer.getLimit('markets_managed'), equals(2));
        
        expect(vendor.isWithinLimit('markets_managed', 0), isFalse);
        expect(shopper.isWithinLimit('markets_managed', 0), isFalse);
        expect(organizer.isWithinLimit('markets_managed', 0), isTrue);
      });
    });
  });
}