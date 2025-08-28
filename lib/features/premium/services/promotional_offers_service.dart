import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'revenuecat_service.dart';

/// Service to handle promotional offers and coupons in RevenueCat
class PromotionalOffersService {
  
  /// Check if user is eligible for introductory offer
  static Future<bool> checkIntroEligibility(Package package) async {
    try {
      final introPrice = package.storeProduct.introductoryPrice;
      
      if (introPrice == null) {
        debugPrint('No intro offer available for this package');
        return false;
      }
      
      // Check if user has already used intro offer
      final customerInfo = await RevenueCatService().getCustomerInfo();
      if (customerInfo == null) return false;
      
      // If user has previous purchases, they're not eligible
      final hasUsedIntro = customerInfo.allPurchasedProductIdentifiers.contains(
        package.storeProduct.identifier
      );
      
      return !hasUsedIntro;
    } catch (e) {
      debugPrint('Error checking intro eligibility: $e');
      return false;
    }
  }
  
  /// Apply a promotional offer code
  static Future<bool> applyPromoCode(String code) async {
    try {
      debugPrint('🎫 Applying promo code: $code');
      
      // For iOS, this opens the App Store redemption sheet
      await Purchases.presentCodeRedemptionSheet();
      
      // Note: The actual code entry happens in the native sheet
      // RevenueCat will automatically apply valid codes
      
      return true;
    } catch (e) {
      debugPrint('❌ Error applying promo code: $e');
      return false;
    }
  }
  
  /// Purchase with promotional offer (for eligible users)
  static Future<HipopPurchaseResult> purchaseWithOffer({
    required Package package,
    required PromotionalOffer offer,
  }) async {
    try {
      debugPrint('🎁 Purchasing with promotional offer: ${offer.identifier}');
      
      // Purchase with the promotional offer
      // Note: promotionalOffer parameter requires iOS 12.2+
      final result = await Purchases.purchasePackage(package);
      
      return HipopPurchaseResult(
        success: true,
        customerInfo: result.customerInfo,
      );
    } catch (e) {
      debugPrint('❌ Error purchasing with offer: $e');
      return HipopPurchaseResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  /// Get available promotional offers for a package
  static Future<List<PromotionalOffer>> getAvailableOffers(Package package) async {
    try {
      // Get the product
      final product = package.storeProduct;
      
      // Get discount offers (iOS only)
      final discounts = product.discounts ?? [];
      
      if (discounts.isEmpty) {
        debugPrint('No promotional offers available');
        return [];
      }
      
      // Convert to PromotionalOffer objects
      final offers = <PromotionalOffer>[];
      
      for (final discount in discounts) {
        // Check eligibility for each offer
        try {
          final isEligible = await Purchases.getPromotionalOffer(
            product,
            discount,
          );
          
          if (isEligible != null) {
            offers.add(isEligible);
          }
        } catch (e) {
          debugPrint('Could not get promotional offer for discount ${discount.identifier}: $e');
        }
      }
      
      debugPrint('Found ${offers.length} available offers');
      return offers;
    } catch (e) {
      debugPrint('Error getting promotional offers: $e');
      return [];
    }
  }
  
  /// Create a custom offer for a specific user (retention offer)
  static Future<PromotionalOffer?> createRetentionOffer(String userId) async {
    try {
      // This would typically call your backend to generate a signed offer
      // The backend uses Apple's StoreKit keys to sign the offer
      
      // For now, return null as this requires backend implementation
      debugPrint('Retention offers require backend signature implementation');
      return null;
    } catch (e) {
      debugPrint('Error creating retention offer: $e');
      return null;
    }
  }
  
  /// Display intro offer in UI
  static String getIntroOfferText(Package package) {
    final intro = package.storeProduct.introductoryPrice;
    
    if (intro == null) return '';
    
    // Format the intro offer text
    final price = intro.priceString;
    // IntroductoryPrice uses periodUnit and periodNumberOfUnits
    final period = intro.periodUnit;
    final cycles = intro.cycles;
    
    // Examples:
    // "Start with 7 days free"
    // "First month for $0.99"
    // "50% off for 3 months"
    
    if (intro.price == 0) {
      return 'Start with ${_formatPeriodUnit(period, cycles)} free';
    } else {
      return 'First ${_formatPeriodUnit(period, cycles)} for $price';
    }
  }
  
  /// Format subscription period for display
  static String _formatPeriodUnit(PeriodUnit period, int cycles) {
    final periodMap = {
      PeriodUnit.day: 'day',
      PeriodUnit.week: 'week',
      PeriodUnit.month: 'month',
      PeriodUnit.year: 'year',
    };
    
    final periodText = periodMap[period] ?? 'period';
    
    if (cycles == 1) {
      return periodText;
    } else {
      return '$cycles ${periodText}s';
    }
  }
}

/// Widget to display offer redemption UI
class PromoCodeRedemptionButton extends StatelessWidget {
  final VoidCallback? onSuccess;
  
  const PromoCodeRedemptionButton({
    super.key,
    this.onSuccess,
  });
  
  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () async {
        final applied = await PromotionalOffersService.applyPromoCode('');
        if (applied && onSuccess != null) {
          onSuccess!();
        }
      },
      icon: const Icon(Icons.local_offer),
      label: const Text('Have a promo code?'),
    );
  }
}

/// Widget to display introductory offer badge
class IntroOfferBadge extends StatelessWidget {
  final Package package;
  
  const IntroOfferBadge({
    super.key,
    required this.package,
  });
  
  @override
  Widget build(BuildContext context) {
    final offerText = PromotionalOffersService.getIntroOfferText(package);
    
    if (offerText.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        offerText.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}