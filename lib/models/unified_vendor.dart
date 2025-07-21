import '../models/vendor_application.dart';
import '../models/managed_vendor.dart';

enum VendorSource {
  permissionRequest,
  eventApplication, 
  manuallyCreated,
  marketInvitation
}

class UnifiedVendor {
  final String id;
  final String businessName;
  final String email;
  final VendorSource source;
  final VendorApplication? application;
  final ManagedVendor? managedVendor;
  final bool isSelected;
  
  const UnifiedVendor({
    required this.id,
    required this.businessName,
    required this.email,
    required this.source,
    this.application,
    this.managedVendor,
    this.isSelected = false,
  });

  factory UnifiedVendor.fromApplication(VendorApplication application) {
    VendorSource source;
    
    if (application.isMarketPermission) {
      source = VendorSource.permissionRequest;
    } else {
      source = VendorSource.eventApplication;
    }

    return UnifiedVendor(
      id: application.vendorId,
      businessName: application.vendorBusinessName,
      email: application.vendorDisplayName, // Using display name as fallback for email display
      source: source,
      application: application,
      managedVendor: null,
    );
  }
  
  factory UnifiedVendor.fromManagedVendor(ManagedVendor vendor) {
    VendorSource source;
    
    // Check metadata to determine if this was created from a permission request
    final isPermissionBased = vendor.metadata['isPermissionBased'] == true;
    final createdFromApplication = vendor.metadata['createdFromApplication'] == true;
    
    if (isPermissionBased) {
      source = VendorSource.permissionRequest;
    } else if (createdFromApplication) {
      source = VendorSource.eventApplication;
    } else {
      source = VendorSource.manuallyCreated;
    }

    // Get vendor user ID from metadata if available, otherwise use the managed vendor ID
    final vendorUserId = vendor.metadata['vendorUserId'] as String? ?? vendor.id;

    return UnifiedVendor(
      id: vendorUserId,
      businessName: vendor.businessName,
      email: vendor.email ?? vendor.contactName,
      source: source,
      application: null,
      managedVendor: vendor,
    );
  }

  UnifiedVendor copyWith({
    String? id,
    String? businessName,
    String? email,
    VendorSource? source,
    VendorApplication? application,
    ManagedVendor? managedVendor,
    bool? isSelected,
  }) {
    return UnifiedVendor(
      id: id ?? this.id,
      businessName: businessName ?? this.businessName,
      email: email ?? this.email,
      source: source ?? this.source,
      application: application ?? this.application,
      managedVendor: managedVendor ?? this.managedVendor,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  String toString() {
    return 'UnifiedVendor(id: $id, businessName: $businessName, source: $source)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnifiedVendor &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}