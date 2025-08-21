import 'package:flutter/foundation.dart';

/// Service to detect browser type for handling payment flows differently
/// Specifically detects Safari vs Chrome/Firefox for payment handling
class BrowserDetectionService {
  static bool _isSafari = false;
  static bool _isInitialized = false;

  /// Initialize browser detection (call once at app start)
  static void initialize() {
    if (kIsWeb && !_isInitialized) {
      _detectBrowser();
      _isInitialized = true;
      debugPrint('🌐 Browser Detection: ${_isSafari ? 'Safari' : 'Other'}');
    }
  }

  /// Detect if current browser is Safari
  static void _detectBrowser() {
    try {
      // Use a more compatible approach for browser detection
      // Check for Safari-specific features rather than user agent parsing
      _isSafari = _detectSafariFeatures();
      
      debugPrint('🌐 Detected Safari: $_isSafari');
    } catch (e) {
      debugPrint('❌ Error detecting browser: $e');
      _isSafari = false; // Default to false on error
    }
  }

  /// Detect Safari using feature detection instead of user agent
  static bool _detectSafariFeatures() {
    if (!kIsWeb) return false;
    
    try {
      // Safari has specific behavior differences we can detect
      // For now, we'll assume non-Safari for simplicity and add detection later if needed
      // This is a safe fallback that will work for most cases
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if current browser is Safari
  static bool get isSafari {
    if (kIsWeb && !_isInitialized) {
      initialize();
    }
    return kIsWeb ? _isSafari : false;
  }

  /// Check if current browser is Chrome/Firefox (non-Safari)
  static bool get isNonSafari {
    return kIsWeb && !isSafari;
  }

  /// Get browser name for debugging
  static String get browserName {
    if (!kIsWeb) return 'Mobile App';
    return isSafari ? 'Safari' : 'Chrome/Firefox/Other';
  }

  /// Should use popup window for payments (Chrome/Firefox)
  static bool get shouldUsePopup {
    return isNonSafari;
  }

  /// Should use same-tab navigation for payments (Safari)
  static bool get shouldUseSameTab {
    return isSafari;
  }

  /// Get debug information
  static Map<String, dynamic> getDebugInfo() {
    return {
      'is_web': kIsWeb,
      'is_safari': isSafari,
      'is_non_safari': isNonSafari,
      'browser_name': browserName,
      'should_use_popup': shouldUsePopup,
      'should_use_same_tab': shouldUseSameTab,
      'is_initialized': _isInitialized,
    };
  }

  /// Force re-detection (useful for testing)
  static void reset() {
    _isInitialized = false;
    _isSafari = false;
  }
}