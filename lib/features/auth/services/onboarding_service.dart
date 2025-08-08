import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _organizerOnboardingKey = 'organizer_onboarding_completed';
  static const String _shopperOnboardingKey = 'shopper_onboarding_completed';

  /// Check if market organizer onboarding has been completed
  static Future<bool> isOrganizerOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_organizerOnboardingKey) ?? false;
  }

  /// Mark market organizer onboarding as completed
  static Future<void> markOrganizerOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_organizerOnboardingKey, true);
  }

  /// Reset market organizer onboarding (for testing or re-showing)
  static Future<void> resetOrganizerOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_organizerOnboardingKey);
  }

  /// Check if shopper onboarding has been completed
  static Future<bool> isShopperOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_shopperOnboardingKey) ?? false;
  }

  /// Mark shopper onboarding as completed
  static Future<void> markShopperOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shopperOnboardingKey, true);
  }

  /// Reset shopper onboarding (for testing or re-showing)
  static Future<void> resetShopperOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_shopperOnboardingKey);
  }

  /// Reset all onboarding states
  static Future<void> resetAllOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_organizerOnboardingKey);
    await prefs.remove(_shopperOnboardingKey);
  }
}