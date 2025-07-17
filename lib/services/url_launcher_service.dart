import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

// Conditional import for web-only features
import 'url_launcher_web_stub.dart' 
  if (dart.library.html) 'url_launcher_web_impl.dart' as web_launcher;

class UrlLauncherService {
  /// Launch Instagram profile
  static Future<void> launchInstagram(String handle) async {
    final cleanHandle = handle.startsWith('@') ? handle.substring(1) : handle;
    final url = 'https://instagram.com/$cleanHandle';
    await _launchUrl(url);
  }
  
  /// Launch address in maps app
  static Future<void> launchMaps(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final url = 'https://maps.google.com/?q=$encodedAddress';
    await _launchUrl(url);
  }
  
  /// Launch website URL
  static Future<void> launchWebsite(String url) async {
    String finalUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      finalUrl = 'https://$url';
    }
    await _launchUrl(finalUrl);
  }
  
  /// Launch email
  static Future<void> launchEmail(String email) async {
    final url = 'mailto:$email';
    await _launchUrl(url);
  }
  
  /// Launch phone number
  static Future<void> launchPhone(String phoneNumber) async {
    final url = 'tel:$phoneNumber';
    await _launchUrl(url);
  }
  
  /// Internal method to launch URL with error handling
  static Future<void> _launchUrl(String url) async {
    try {
      if (kIsWeb) {
        // For Flutter Web, use web-specific implementation
        web_launcher.openUrl(url);
        return;
      }
      
      // For mobile platforms
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Cannot launch URL: $url');
      }
    } catch (e) {
      debugPrint('Error launching URL $url: $e');
      throw Exception('Cannot open link: $url');
    }
  }
}