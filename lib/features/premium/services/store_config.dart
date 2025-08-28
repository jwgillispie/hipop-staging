import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Configuration for RevenueCat store
class StoreConfig {
  final Store store;
  final String apiKey;
  static StoreConfig? _instance;

  /// Create a new StoreConfig singleton instance
  factory StoreConfig({required Store store, required String apiKey}) {
    _instance ??= StoreConfig._internal(store, apiKey);
    return _instance!;
  }

  StoreConfig._internal(this.store, this.apiKey);

  /// Get the singleton instance
  static StoreConfig get instance {
    if (_instance == null) {
      throw StateError('StoreConfig has not been initialized');
    }
    return _instance!;
  }

  /// Check if the store is Apple App Store
  static bool isForAppleStore() => 
      !kIsWeb && (Platform.isIOS || Platform.isMacOS) && 
      instance.store == Store.appStore;

  /// Check if the store is Google Play Store
  static bool isForGooglePlay() => 
      !kIsWeb && Platform.isAndroid && 
      instance.store == Store.playStore;
      
  /// Initialize the store configuration
  static void initialize() {
    if (kIsWeb) {
      debugPrint('⚠️ RevenueCat not initialized - Web platform detected');
      return;
    }
    
    final apiKey = dotenv.env['REVENUE_CAT_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('⚠️ RevenueCat API key not found in environment');
      return;
    }
    
    if (Platform.isIOS || Platform.isMacOS) {
      StoreConfig(
        store: Store.appStore,
        apiKey: apiKey,
      );
      debugPrint('✅ StoreConfig initialized for App Store');
    } else if (Platform.isAndroid) {
      StoreConfig(
        store: Store.playStore,
        apiKey: apiKey,
      );
      debugPrint('✅ StoreConfig initialized for Play Store');
    }
  }
}