import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Links a vendor's global product to a specific market
/// Allows market-specific pricing, availability, and settings
class VendorMarketProductAssignment extends Equatable {
  final String id;
  final String vendorId;
  final String marketId;
  final String productId;
  final double? marketSpecificPrice;
  final bool isAvailable;
  final int? inventory;
  final String? marketSpecificNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VendorMarketProductAssignment({
    required this.id,
    required this.vendorId,
    required this.marketId,
    required this.productId,
    this.marketSpecificPrice,
    this.isAvailable = true,
    this.inventory,
    this.marketSpecificNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VendorMarketProductAssignment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return VendorMarketProductAssignment(
      id: doc.id,
      vendorId: data['vendorId'] ?? '',
      marketId: data['marketId'] ?? '',
      productId: data['productId'] ?? '',
      marketSpecificPrice: data['marketSpecificPrice']?.toDouble(),
      isAvailable: data['isAvailable'] ?? true,
      inventory: data['inventory']?.toInt(),
      marketSpecificNotes: data['marketSpecificNotes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'vendorId': vendorId,
      'marketId': marketId,
      'productId': productId,
      'marketSpecificPrice': marketSpecificPrice,
      'isAvailable': isAvailable,
      'inventory': inventory,
      'marketSpecificNotes': marketSpecificNotes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  VendorMarketProductAssignment copyWith({
    String? id,
    String? vendorId,
    String? marketId,
    String? productId,
    double? marketSpecificPrice,
    bool? isAvailable,
    int? inventory,
    String? marketSpecificNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VendorMarketProductAssignment(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      marketId: marketId ?? this.marketId,
      productId: productId ?? this.productId,
      marketSpecificPrice: marketSpecificPrice ?? this.marketSpecificPrice,
      isAvailable: isAvailable ?? this.isAvailable,
      inventory: inventory ?? this.inventory,
      marketSpecificNotes: marketSpecificNotes ?? this.marketSpecificNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        vendorId,
        marketId,
        productId,
        marketSpecificPrice,
        isAvailable,
        inventory,
        marketSpecificNotes,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() {
    return 'VendorMarketProductAssignment(id: $id, vendorId: $vendorId, marketId: $marketId, productId: $productId)';
  }

  /// Get display price with fallback to base price
  String getDisplayPrice(double? basePrice) {
    final price = marketSpecificPrice ?? basePrice;
    if (price == null) return 'Price varies';
    return '\$${price.toStringAsFixed(2)}';
  }

  /// Get availability status with inventory info
  String get availabilityStatus {
    if (!isAvailable) return 'Unavailable';
    if (inventory == null) return 'Available';
    if (inventory! <= 0) return 'Out of stock';
    if (inventory! <= 5) return 'Low stock ($inventory left)';
    return 'In stock ($inventory available)';
  }

  /// Check if assignment has valid data
  bool get isValid {
    return vendorId.isNotEmpty && 
           marketId.isNotEmpty && 
           productId.isNotEmpty;
  }

  /// Create a unique composite key for vendor+market+product
  String get compositeKey {
    return '${vendorId}_${marketId}_$productId';
  }
}