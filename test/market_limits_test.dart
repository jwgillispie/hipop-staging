import 'package:flutter_test/flutter_test.dart';
import 'package:hipop/features/premium/models/user_subscription.dart';

void main() {
  group('Market Creation Limits', () {
    group('Free Tier Market Limits', () {
      test('should enforce 2-market limit for free tier organizers', () {
        final freeOrganizer = UserSubscription.createFree('test_user', 'market_organizer');
        
        // Test market limit is 2
        expect(freeOrganizer.getLimit('markets_managed'), equals(2));
        
        // Test within limit scenarios
        expect(freeOrganizer.isWithinLimit('markets_managed', 0), isTrue, 
               reason: 'Should allow creating first market');
        expect(freeOrganizer.isWithinLimit('markets_managed', 1), isTrue, 
               reason: 'Should allow creating second market');
        
        // Test at and over limit scenarios
        expect(freeOrganizer.isWithinLimit('markets_managed', 2), isFalse, 
               reason: 'Should not allow creating third market');
        expect(freeOrganizer.isWithinLimit('markets_managed', 3), isFalse, 
               reason: 'Should not allow creating fourth market');
      });

      test('should handle grandfathered users with more than 2 markets', () {
        final freeOrganizer = UserSubscription.createFree('grandfathered_user', 'market_organizer');
        
        // Grandfathered user with 5 markets should not be able to create more
        expect(freeOrganizer.isWithinLimit('markets_managed', 5), isFalse,
               reason: 'Grandfathered users should not be able to create more markets');
        
        // But the limit should still be 2 for new users
        expect(freeOrganizer.getLimit('markets_managed'), equals(2));
      });

      test('should provide correct market usage calculations', () {
        final freeOrganizer = UserSubscription.createFree('test_user', 'market_organizer');
        final limit = freeOrganizer.getLimit('markets_managed');
        
        // Test usage calculations
        expect(limit, equals(2));
        
        // With 0 markets: can create 2 more
        final remaining0 = limit - 0;
        expect(remaining0, equals(2));
        
        // With 1 market: can create 1 more
        final remaining1 = limit - 1;
        expect(remaining1, equals(1));
        
        // With 2 markets: can create 0 more
        final remaining2 = limit - 2;
        expect(remaining2, equals(0));
      });
    });

    group('Premium Tier Market Limits', () {
      test('should allow unlimited markets for premium organizers', () {
        final freeOrganizer = UserSubscription.createFree('premium_user', 'market_organizer');
        final premiumOrganizer = freeOrganizer.upgradeToTier(SubscriptionTier.marketOrganizerPro);
        
        // Premium organizers should have unlimited markets
        expect(premiumOrganizer.getLimit('markets_managed'), equals(-1));
        
        // Should allow any number of markets
        expect(premiumOrganizer.isWithinLimit('markets_managed', 0), isTrue);
        expect(premiumOrganizer.isWithinLimit('markets_managed', 10), isTrue);
        expect(premiumOrganizer.isWithinLimit('markets_managed', 100), isTrue);
        expect(premiumOrganizer.isWithinLimit('markets_managed', 1000), isTrue);
      });

      test('should correctly identify premium status', () {
        final freeOrganizer = UserSubscription.createFree('test_user', 'market_organizer');
        final premiumOrganizer = freeOrganizer.upgradeToTier(SubscriptionTier.marketOrganizerPro);
        
        expect(freeOrganizer.isPremium, isFalse);
        expect(freeOrganizer.isFree, isTrue);
        
        expect(premiumOrganizer.isPremium, isTrue);
        expect(premiumOrganizer.isFree, isFalse);
      });
    });

    group('Null Safety and Error Handling', () {
      test('should handle invalid limit names gracefully', () {
        final subscription = UserSubscription.createFree('test_user', 'market_organizer');
        
        // Invalid limit names should return 0
        expect(subscription.getLimit('invalid_limit'), equals(0));
        expect(subscription.isWithinLimit('invalid_limit', 5), isFalse);
      });

      test('should handle negative usage values', () {
        final subscription = UserSubscription.createFree('test_user', 'market_organizer');
        
        // Negative usage should be treated as 0 (within limit)
        expect(subscription.isWithinLimit('markets_managed', -1), isTrue);
        expect(subscription.isWithinLimit('markets_managed', -10), isTrue);
      });

      test('should validate user type for market organizers', () {
        // Only market organizers should have market management limits
        final vendorSubscription = UserSubscription.createFree('vendor_user', 'vendor');
        final shopperSubscription = UserSubscription.createFree('shopper_user', 'shopper');
        final organizerSubscription = UserSubscription.createFree('organizer_user', 'market_organizer');
        
        // Vendors and shoppers should not have market management limits
        expect(vendorSubscription.getLimit('markets_managed'), equals(0));
        expect(shopperSubscription.getLimit('markets_managed'), equals(0));
        
        // Only organizers should have the 2-market limit
        expect(organizerSubscription.getLimit('markets_managed'), equals(2));
      });
    });

    group('UserSubscription Model Validation', () {
      test('should create correct subscription tiers', () {
        // Test all subscription tiers exist
        expect(SubscriptionTier.free, isNotNull);
        expect(SubscriptionTier.vendorPro, isNotNull);
        expect(SubscriptionTier.marketOrganizerPro, isNotNull);
        
        // Test tier names
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

    group('Market Limit Edge Cases', () {
      test('should handle boundary conditions', () {
        final subscription = UserSubscription.createFree('test_user', 'market_organizer');
        
        // Test exact limit boundary
        expect(subscription.isWithinLimit('markets_managed', 1), isTrue);  // 1 < 2
        expect(subscription.isWithinLimit('markets_managed', 2), isFalse); // 2 >= 2
        
        // Test zero usage
        expect(subscription.isWithinLimit('markets_managed', 0), isTrue);
      });

      test('should handle very large numbers', () {
        final subscription = UserSubscription.createFree('test_user', 'market_organizer');
        
        // Very large numbers should still be over limit
        expect(subscription.isWithinLimit('markets_managed', 999999), isFalse);
        expect(subscription.isWithinLimit('markets_managed', 1000000), isFalse);
      });

      test('should correctly implement limit checking logic', () {
        final subscription = UserSubscription.createFree('test_user', 'market_organizer');
        final limit = subscription.getLimit('markets_managed');
        
        // The logic should be: currentUsage < limit (not <=)
        for (int i = 0; i < limit; i++) {
          expect(subscription.isWithinLimit('markets_managed', i), isTrue,
                 reason: 'Usage $i should be within limit $limit');
        }
        
        for (int i = limit; i <= limit + 5; i++) {
          expect(subscription.isWithinLimit('markets_managed', i), isFalse,
                 reason: 'Usage $i should be over limit $limit');
        }
      });
    });
  });
}