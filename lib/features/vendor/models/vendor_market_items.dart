import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class VendorMarketItems extends Equatable {
  final String id;
  final String vendorId;
  final String marketId;
  final List<String> itemList; // The actual items for this market
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  const VendorMarketItems({
    required this.id,
    required this.vendorId,
    required this.marketId,
    required this.itemList,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  factory VendorMarketItems.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return VendorMarketItems(
      id: doc.id,
      vendorId: data['vendorId'] ?? '',
      marketId: data['marketId'] ?? '',
      itemList: List<String>.from(data['itemList'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'vendorId': vendorId,
      'marketId': marketId,
      'itemList': itemList,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  VendorMarketItems copyWith({
    String? id,
    String? vendorId,
    String? marketId,
    List<String>? itemList,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return VendorMarketItems(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      marketId: marketId ?? this.marketId,
      itemList: itemList ?? this.itemList,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  // Check if vendor can add more items (based on subscription tier)
  bool canAddMoreItems(bool isPremium) {
    if (isPremium) return true; // Unlimited for premium
    return itemList.length < 3; // Free tier: max 3 items
  }

  // Get max items allowed for this vendor
  int getMaxItems(bool isPremium) {
    return isPremium ? -1 : 3; // -1 = unlimited, 3 = free tier limit
  }

  @override
  List<Object?> get props => [
        id,
        vendorId,
        marketId,
        itemList,
        createdAt,
        updatedAt,
        isActive,
      ];

  @override
  String toString() {
    return 'VendorMarketItems(id: $id, vendorId: $vendorId, marketId: $marketId, items: ${itemList.length})';
  }
}