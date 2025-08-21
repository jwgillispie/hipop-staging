import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service to store and restore payment state for Safari web flows
/// This is needed because Safari redirects lose app state
class PaymentStateStorageService {
  static const String _paymentStateKey = 'payment_flow_state';
  static const String _paymentTimestampKey = 'payment_flow_timestamp';
  static const Duration _stateExpirationDuration = Duration(hours: 2);

  /// Store payment state before Safari redirect
  static Future<bool> storePaymentState({
    required String userId,
    required String userType,
    required String userEmail,
    String? couponCode,
    required String checkoutUrl,
  }) async {
    try {
      if (!kIsWeb) {
        debugPrint('⚠️ Payment state storage only needed on web');
        return false;
      }

      debugPrint('💾 Storing payment state for Safari redirect');
      final prefs = await SharedPreferences.getInstance();

      final paymentState = {
        'userId': userId,
        'userType': userType,
        'userEmail': userEmail,
        'couponCode': couponCode,
        'checkoutUrl': checkoutUrl,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final stateJson = jsonEncode(paymentState);
      await prefs.setString(_paymentStateKey, stateJson);
      await prefs.setInt(_paymentTimestampKey, DateTime.now().millisecondsSinceEpoch);

      debugPrint('✅ Payment state stored successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error storing payment state: $e');
      return false;
    }
  }

  /// Retrieve stored payment state after return from Safari
  static Future<Map<String, dynamic>?> getStoredPaymentState() async {
    try {
      if (!kIsWeb) {
        debugPrint('⚠️ Payment state retrieval only needed on web');
        return null;
      }

      debugPrint('📥 Retrieving stored payment state');
      final prefs = await SharedPreferences.getInstance();

      final stateJson = prefs.getString(_paymentStateKey);
      final timestamp = prefs.getInt(_paymentTimestampKey);

      if (stateJson == null || timestamp == null) {
        debugPrint('📭 No stored payment state found');
        return null;
      }

      // Check if state has expired
      final stateAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (stateAge > _stateExpirationDuration.inMilliseconds) {
        debugPrint('⏰ Stored payment state has expired, clearing');
        await clearStoredPaymentState();
        return null;
      }

      final paymentState = jsonDecode(stateJson) as Map<String, dynamic>;
      debugPrint('✅ Retrieved payment state: ${paymentState.keys}');
      return paymentState;
    } catch (e) {
      debugPrint('❌ Error retrieving payment state: $e');
      await clearStoredPaymentState(); // Clear corrupted state
      return null;
    }
  }

  /// Clear stored payment state (after successful retrieval or on error)
  static Future<void> clearStoredPaymentState() async {
    try {
      debugPrint('🗑️ Clearing stored payment state');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_paymentStateKey);
      await prefs.remove(_paymentTimestampKey);
      debugPrint('✅ Payment state cleared');
    } catch (e) {
      debugPrint('❌ Error clearing payment state: $e');
    }
  }

  /// Check if there is stored payment state available
  static Future<bool> hasStoredPaymentState() async {
    try {
      if (!kIsWeb) return false;
      
      final prefs = await SharedPreferences.getInstance();
      final hasState = prefs.containsKey(_paymentStateKey);
      debugPrint('🔍 Has stored payment state: $hasState');
      return hasState;
    } catch (e) {
      debugPrint('❌ Error checking stored payment state: $e');
      return false;
    }
  }

  /// Store user navigation state before payment
  static Future<void> storeNavigationState(String currentRoute) async {
    try {
      if (!kIsWeb) return;
      
      debugPrint('🗂️ Storing navigation state: $currentRoute');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pre_payment_route', currentRoute);
    } catch (e) {
      debugPrint('❌ Error storing navigation state: $e');
    }
  }

  /// Get stored navigation state to return user to correct screen
  static Future<String?> getStoredNavigationState() async {
    try {
      if (!kIsWeb) return null;
      
      final prefs = await SharedPreferences.getInstance();
      final route = prefs.getString('pre_payment_route');
      debugPrint('📥 Retrieved navigation state: $route');
      return route;
    } catch (e) {
      debugPrint('❌ Error retrieving navigation state: $e');
      return null;
    }
  }

  /// Clear stored navigation state
  static Future<void> clearNavigationState() async {
    try {
      if (!kIsWeb) return;
      
      debugPrint('🗑️ Clearing navigation state');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pre_payment_route');
    } catch (e) {
      debugPrint('❌ Error clearing navigation state: $e');
    }
  }

  /// Get debug information about stored state
  static Future<Map<String, dynamic>> getDebugInfo() async {
    final prefs = await SharedPreferences.getInstance();
    
    return {
      'has_payment_state': prefs.containsKey(_paymentStateKey),
      'has_timestamp': prefs.containsKey(_paymentTimestampKey),
      'has_navigation_state': prefs.containsKey('pre_payment_route'),
      'state_expiration_hours': _stateExpirationDuration.inHours,
      'is_web': kIsWeb,
    };
  }

  /// Clear all stored payment-related state (cleanup utility)
  static Future<void> clearAllStoredState() async {
    try {
      debugPrint('🧹 Clearing all stored payment state');
      await clearStoredPaymentState();
      await clearNavigationState();
      debugPrint('✅ All payment state cleared');
    } catch (e) {
      debugPrint('❌ Error clearing all stored state: $e');
    }
  }
}