import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/services/user_profile_service.dart';

/// Service for managing vendor contact information using UserProfile as single source of truth
/// This eliminates duplication and provides consistent contact data across the app
class VendorContactService {
  final UserProfileService _userProfileService;

  VendorContactService({UserProfileService? userProfileService})
      : _userProfileService = userProfileService ?? UserProfileService();

  /// Get contact information for a vendor from their UserProfile
  Future<VendorContactInfo?> getVendorContactInfo(String vendorId) async {
    try {
      final profile = await _userProfileService.getUserProfile(vendorId);
      if (profile == null || profile.userType != 'vendor') {
        return null;
      }

      return VendorContactInfo.fromUserProfile(profile);
    } catch (e) {
      debugPrint('Error fetching vendor contact info: $e');
      return null;
    }
  }

  /// Launch phone call to vendor
  Future<bool> launchPhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      return false;
    }

    final uri = Uri.parse('tel:$phoneNumber');
    try {
      return await launchUrl(uri);
    } catch (e) {
      debugPrint('Error launching phone call: $e');
      return false;
    }
  }

  /// Launch Instagram profile
  Future<bool> launchInstagram(String? instagramHandle) async {
    if (instagramHandle == null || instagramHandle.isEmpty) {
      return false;
    }

    // Remove @ if present
    final handle = instagramHandle.startsWith('@') 
        ? instagramHandle.substring(1) 
        : instagramHandle;
    
    final uri = Uri.parse('https://instagram.com/$handle');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching Instagram: $e');
      return false;
    }
  }

  /// Launch website
  Future<bool> launchWebsite(String? website) async {
    if (website == null || website.isEmpty) {
      return false;
    }

    // Add https:// if no protocol is specified
    String url = website;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    final uri = Uri.parse(url);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching website: $e');
      return false;
    }
  }

  /// Send email to vendor
  Future<bool> launchEmail(String email, {String? subject, String? body}) async {
    if (email.isEmpty) {
      return false;
    }

    String emailUrl = 'mailto:$email';
    final params = <String>[];
    
    if (subject != null && subject.isNotEmpty) {
      params.add('subject=${Uri.encodeComponent(subject)}');
    }
    
    if (body != null && body.isNotEmpty) {
      params.add('body=${Uri.encodeComponent(body)}');
    }
    
    if (params.isNotEmpty) {
      emailUrl += '?${params.join('&')}';
    }

    final uri = Uri.parse(emailUrl);
    try {
      return await launchUrl(uri);
    } catch (e) {
      debugPrint('Error launching email: $e');
      return false;
    }
  }

  /// Check if vendor has any contact information available
  static bool hasContactInfo(VendorContactInfo? contactInfo) {
    if (contactInfo == null) return false;
    
    return contactInfo.hasPhoneNumber || 
           contactInfo.hasInstagram || 
           contactInfo.hasWebsite || 
           contactInfo.hasEmail;
  }

  /// Format phone number for display
  static String formatPhoneNumber(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      return '';
    }

    // Remove all non-digit characters
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    
    if (digits.length == 10) {
      // US phone number format: (123) 456-7890
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    } else if (digits.length == 11 && digits.startsWith('1')) {
      // US phone number with country code: +1 (123) 456-7890
      return '+1 (${digits.substring(1, 4)}) ${digits.substring(4, 7)}-${digits.substring(7)}';
    }
    
    // Return original if not standard US format
    return phoneNumber;
  }

  /// Format Instagram handle for display
  static String formatInstagramHandle(String? instagramHandle) {
    if (instagramHandle == null || instagramHandle.isEmpty) {
      return '';
    }

    // Ensure it starts with @ for display
    return instagramHandle.startsWith('@') ? instagramHandle : '@$instagramHandle';
  }

  /// Format website URL for display
  static String formatWebsiteForDisplay(String? website) {
    if (website == null || website.isEmpty) {
      return '';
    }

    // Remove protocol for cleaner display
    return website
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceFirst(RegExp(r'^www\.'), '');
  }
}

/// Contact information for a vendor extracted from their UserProfile
class VendorContactInfo {
  final String vendorId;
  final String? businessName;
  final String email;
  final String? phoneNumber;
  final String? instagramHandle;
  final String? website;

  const VendorContactInfo({
    required this.vendorId,
    this.businessName,
    required this.email,
    this.phoneNumber,
    this.instagramHandle,
    this.website,
  });

  /// Create VendorContactInfo from UserProfile
  factory VendorContactInfo.fromUserProfile(UserProfile profile) {
    return VendorContactInfo(
      vendorId: profile.userId,
      businessName: profile.businessName,
      email: profile.email,
      phoneNumber: profile.phoneNumber,
      instagramHandle: profile.instagramHandle,
      website: profile.website,
    );
  }

  bool get hasPhoneNumber => phoneNumber != null && phoneNumber!.isNotEmpty;
  bool get hasInstagram => instagramHandle != null && instagramHandle!.isNotEmpty;
  bool get hasWebsite => website != null && website!.isNotEmpty;
  bool get hasEmail => email.isNotEmpty;

  String get displayName => businessName ?? 'Vendor';
  
  String get formattedPhoneNumber => VendorContactService.formatPhoneNumber(phoneNumber);
  String get formattedInstagramHandle => VendorContactService.formatInstagramHandle(instagramHandle);
  String get formattedWebsite => VendorContactService.formatWebsiteForDisplay(website);

  @override
  String toString() {
    return 'VendorContactInfo(vendorId: $vendorId, businessName: $businessName, email: $email)';
  }
}