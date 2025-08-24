import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Global product catalog item for vendors
/// Represents a product that can be sold across multiple markets
class VendorProduct extends Equatable {
  final String id;
  final String vendorId;
  final String name;
  final String category;
  final String? description;
  final double? basePrice;
  final String? imageUrl; // @deprecated Use photoUrls instead
  final List<String> photoUrls;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  const VendorProduct({
    required this.id,
    required this.vendorId,
    required this.name,
    required this.category,
    this.description,
    this.basePrice,
    this.imageUrl,
    this.photoUrls = const [],
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  factory VendorProduct.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return VendorProduct(
      id: doc.id,
      vendorId: data['vendorId'] ?? '',
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      description: data['description'],
      basePrice: data['basePrice']?.toDouble(),
      imageUrl: data['imageUrl'],
      photoUrls: data['photoUrls'] != null 
          ? List<String>.from(data['photoUrls'])
          : (data['imageUrl'] != null ? [data['imageUrl']] : []), // Migration support
      tags: List<String>.from(data['tags'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'vendorId': vendorId,
      'name': name,
      'category': category,
      'description': description,
      'basePrice': basePrice,
      'imageUrl': imageUrl,
      'photoUrls': photoUrls,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  VendorProduct copyWith({
    String? id,
    String? vendorId,
    String? name,
    String? category,
    String? description,
    double? basePrice,
    String? imageUrl,
    List<String>? photoUrls,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return VendorProduct(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      basePrice: basePrice ?? this.basePrice,
      imageUrl: imageUrl ?? this.imageUrl,
      photoUrls: photoUrls ?? this.photoUrls,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [
        id,
        vendorId,
        name,
        category,
        description,
        basePrice,
        imageUrl,
        photoUrls,
        tags,
        createdAt,
        updatedAt,
        isActive,
      ];

  @override
  String toString() {
    return 'VendorProduct(id: $id, vendorId: $vendorId, name: $name, category: $category)';
  }

  /// Common product categories for vendors
  static const List<String> commonCategories = [
    'Artisan Goods',
    'Baked Goods',
    'Beverages',
    'Clothing & Accessories',
    'Crafts & Handmade',
    'Food & Produce',
    'Health & Beauty',
    'Home & Garden',
    'Jewelry',
    'Prepared Foods',
    'Specialty Items',
    'Other',
  ];

  /// Check if product has valid data for creation
  bool get isValid {
    return name.isNotEmpty && 
           category.isNotEmpty && 
           vendorId.isNotEmpty;
  }

  /// Get display price with fallback
  String get displayPrice {
    if (basePrice == null) return 'Price varies';
    return '\$${basePrice!.toStringAsFixed(2)}';
  }

  /// Get formatted tags string
  String get formattedTags {
    return tags.join(', ');
  }

  /// Get primary image URL (first photo or imageUrl for backward compatibility)
  String? get primaryImageUrl {
    if (photoUrls.isNotEmpty) {
      return photoUrls.first;
    }
    return imageUrl;
  }

  /// Check if product has any images
  bool get hasImages {
    return photoUrls.isNotEmpty || imageUrl != null;
  }

  /// Get all image URLs (combines photoUrls with imageUrl for migration)
  List<String> get allImageUrls {
    final urls = <String>[];
    urls.addAll(photoUrls);
    if (imageUrl != null && !urls.contains(imageUrl)) {
      urls.add(imageUrl!);
    }
    return urls;
  }
}