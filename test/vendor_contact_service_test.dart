import 'package:flutter_test/flutter_test.dart';
import 'package:hipop/features/vendor/services/vendor_contact_service.dart';

void main() {
  group('VendorContactService', () {
    test('should format phone numbers correctly', () {
      // Test US 10-digit format
      expect(
        VendorContactService.formatPhoneNumber('1234567890'),
        equals('(123) 456-7890'),
      );

      // Test US 11-digit format with country code
      expect(
        VendorContactService.formatPhoneNumber('11234567890'),
        equals('+1 (123) 456-7890'),
      );

      // Test non-standard format returns original
      expect(
        VendorContactService.formatPhoneNumber('123'),
        equals('123'),
      );

      // Test empty/null returns empty
      expect(
        VendorContactService.formatPhoneNumber(null),
        equals(''),
      );
      
      expect(
        VendorContactService.formatPhoneNumber(''),
        equals(''),
      );
    });

    test('should format Instagram handles correctly', () {
      // Test handle without @
      expect(
        VendorContactService.formatInstagramHandle('username'),
        equals('@username'),
      );

      // Test handle with @
      expect(
        VendorContactService.formatInstagramHandle('@username'),
        equals('@username'),
      );

      // Test empty/null returns empty
      expect(
        VendorContactService.formatInstagramHandle(null),
        equals(''),
      );
      
      expect(
        VendorContactService.formatInstagramHandle(''),
        equals(''),
      );
    });

    test('should format website URLs for display correctly', () {
      // Test full URL
      expect(
        VendorContactService.formatWebsiteForDisplay('https://example.com'),
        equals('example.com'),
      );

      // Test URL with www
      expect(
        VendorContactService.formatWebsiteForDisplay('https://www.example.com'),
        equals('example.com'),
      );

      // Test HTTP URL
      expect(
        VendorContactService.formatWebsiteForDisplay('http://example.com'),
        equals('example.com'),
      );

      // Test URL without protocol
      expect(
        VendorContactService.formatWebsiteForDisplay('example.com'),
        equals('example.com'),
      );

      // Test empty/null returns empty
      expect(
        VendorContactService.formatWebsiteForDisplay(null),
        equals(''),
      );
      
      expect(
        VendorContactService.formatWebsiteForDisplay(''),
        equals(''),
      );
    });

    test('should detect if contact info is available', () {
      // Test with contact info
      const contactWithInfo = VendorContactInfo(
        vendorId: 'test',
        businessName: 'Test Business',
        email: 'test@example.com',
        phoneNumber: '1234567890',
        instagramHandle: 'testuser',
        website: 'https://example.com',
      );

      expect(
        VendorContactService.hasContactInfo(contactWithInfo),
        isTrue,
      );

      // Test with only email (should still return true as email counts)
      const contactEmailOnly = VendorContactInfo(
        vendorId: 'test',
        email: 'test@example.com',
      );

      expect(
        VendorContactService.hasContactInfo(contactEmailOnly),
        isTrue,
      );

      // Test with null
      expect(
        VendorContactService.hasContactInfo(null),
        isFalse,
      );
    });
  });
}