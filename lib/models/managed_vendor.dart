import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum VendorCategory {
  produce,
  dairy,
  meat,
  bakery,
  prepared_foods,
  beverages,
  flowers,
  crafts,
  skincare,
  clothing,
  jewelry,
  art,
  plants,
  honey,
  preserves,
  spices,
  other,
}

extension VendorCategoryExtension on VendorCategory {
  String get displayName {
    switch (this) {
      case VendorCategory.produce:
        return 'Produce';
      case VendorCategory.dairy:
        return 'Dairy';
      case VendorCategory.meat:
        return 'Meat & Poultry';
      case VendorCategory.bakery:
        return 'Bakery';
      case VendorCategory.prepared_foods:
        return 'Prepared Foods';
      case VendorCategory.beverages:
        return 'Beverages';
      case VendorCategory.flowers:
        return 'Flowers';
      case VendorCategory.crafts:
        return 'Crafts';
      case VendorCategory.skincare:
        return 'Skincare';
      case VendorCategory.clothing:
        return 'Clothing';
      case VendorCategory.jewelry:
        return 'Jewelry';
      case VendorCategory.art:
        return 'Art';
      case VendorCategory.plants:
        return 'Plants';
      case VendorCategory.honey:
        return 'Honey';
      case VendorCategory.preserves:
        return 'Preserves';
      case VendorCategory.spices:
        return 'Spices';
      case VendorCategory.other:
        return 'Other';
    }
  }
}

class ManagedVendor extends Equatable {
  final String id;
  final String marketId;
  final String organizerId; // Market organizer who created this vendor
  final String businessName;
  final String? vendorName; // Individual vendor name (separate from business)
  final String contactName;
  final String description;
  final List<VendorCategory> categories;
  final String? imageUrl;
  final List<String> imageUrls; // Multiple product images
  final String? logoUrl;
  
  // Contact Information
  final String? email;
  final String? phoneNumber;
  final List<String> ccEmails; // Additional contact emails for CC
  final String? website;
  final String? instagramHandle;
  final String? facebookHandle;
  
  // Location & Logistics
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final bool canDeliver;
  final bool acceptsOrders;
  final String? deliveryNotes;
  
  // Products & Services
  final List<String> products; // List of main products/services
  final String? specificProducts; // Detailed product description from application
  final List<String> specialties; // What they're known for
  final String? priceRange; // e.g., "$", "$$", "$$$"
  final bool isOrganic;
  final bool isLocallySourced;
  final String? certifications; // Organic, Fair Trade, etc.
  
  // Market Information
  final bool isActive;
  final bool isFeatured;
  final List<String> operatingDays; // Days they typically attend
  final String? boothPreferences; // Size, location preferences
  final String? specialRequirements; // Electricity, water, etc.
  
  // Content for Display
  final String? story; // Vendor story/background
  final List<String> tags; // Keywords for search
  final String? slogan; // Business tagline
  
  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  const ManagedVendor({
    required this.id,
    required this.marketId,
    required this.organizerId,
    required this.businessName,
    this.vendorName,
    required this.contactName,
    required this.description,
    this.categories = const [],
    this.imageUrl,
    this.imageUrls = const [],
    this.logoUrl,
    this.email,
    this.phoneNumber,
    this.ccEmails = const [],
    this.website,
    this.instagramHandle,
    this.facebookHandle,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.canDeliver = false,
    this.acceptsOrders = false,
    this.deliveryNotes,
    this.products = const [],
    this.specificProducts,
    this.specialties = const [],
    this.priceRange,
    this.isOrganic = false,
    this.isLocallySourced = false,
    this.certifications,
    this.isActive = true,
    this.isFeatured = false,
    this.operatingDays = const [],
    this.boothPreferences,
    this.specialRequirements,
    this.story,
    this.tags = const [],
    this.slogan,
    required this.createdAt,
    required this.updatedAt,
    this.metadata = const {},
  });

  factory ManagedVendor.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ManagedVendor(
      id: doc.id,
      marketId: data['marketId'] ?? '',
      organizerId: data['organizerId'] ?? '',
      businessName: data['businessName'] ?? '',
      vendorName: data['vendorName'],
      contactName: data['contactName'] ?? '',
      description: data['description'] ?? '',
      categories: (data['categories'] as List?)
          ?.map((item) => VendorCategory.values.firstWhere(
                (cat) => cat.name == item,
                orElse: () => VendorCategory.other,
              ))
          .toList() ?? [],
      imageUrl: data['imageUrl'],
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      logoUrl: data['logoUrl'],
      email: data['email'],
      phoneNumber: data['phoneNumber'],
      ccEmails: List<String>.from(data['ccEmails'] ?? []),
      website: data['website'],
      instagramHandle: data['instagramHandle'],
      facebookHandle: data['facebookHandle'],
      address: data['address'],
      city: data['city'],
      state: data['state'],
      zipCode: data['zipCode'],
      canDeliver: data['canDeliver'] ?? false,
      acceptsOrders: data['acceptsOrders'] ?? false,
      deliveryNotes: data['deliveryNotes'],
      products: List<String>.from(data['products'] ?? []),
      specificProducts: data['specificProducts'],
      specialties: List<String>.from(data['specialties'] ?? []),
      priceRange: data['priceRange'],
      isOrganic: data['isOrganic'] ?? false,
      isLocallySourced: data['isLocallySourced'] ?? false,
      certifications: data['certifications'],
      isActive: data['isActive'] ?? true,
      isFeatured: data['isFeatured'] ?? false,
      operatingDays: List<String>.from(data['operatingDays'] ?? []),
      boothPreferences: data['boothPreferences'],
      specialRequirements: data['specialRequirements'],
      story: data['story'],
      tags: List<String>.from(data['tags'] ?? []),
      slogan: data['slogan'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'marketId': marketId,
      'organizerId': organizerId,
      'businessName': businessName,
      'vendorName': vendorName,
      'contactName': contactName,
      'description': description,
      'categories': categories.map((cat) => cat.name).toList(),
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'logoUrl': logoUrl,
      'email': email,
      'phoneNumber': phoneNumber,
      'ccEmails': ccEmails,
      'website': website,
      'instagramHandle': instagramHandle,
      'facebookHandle': facebookHandle,
      'address': address,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'canDeliver': canDeliver,
      'acceptsOrders': acceptsOrders,
      'deliveryNotes': deliveryNotes,
      'products': products,
      'specificProducts': specificProducts,
      'specialties': specialties,
      'priceRange': priceRange,
      'isOrganic': isOrganic,
      'isLocallySourced': isLocallySourced,
      'certifications': certifications,
      'isActive': isActive,
      'isFeatured': isFeatured,
      'operatingDays': operatingDays,
      'boothPreferences': boothPreferences,
      'specialRequirements': specialRequirements,
      'story': story,
      'tags': tags,
      'slogan': slogan,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'metadata': metadata,
    };
  }

  ManagedVendor copyWith({
    String? id,
    String? marketId,
    String? organizerId,
    String? businessName,
    String? vendorName,
    String? contactName,
    String? description,
    List<VendorCategory>? categories,
    String? imageUrl,
    List<String>? imageUrls,
    String? logoUrl,
    String? email,
    String? phoneNumber,
    List<String>? ccEmails,
    String? website,
    String? instagramHandle,
    String? facebookHandle,
    String? address,
    String? city,
    String? state,
    String? zipCode,
    bool? canDeliver,
    bool? acceptsOrders,
    String? deliveryNotes,
    List<String>? products,
    String? specificProducts,
    List<String>? specialties,
    String? priceRange,
    bool? isOrganic,
    bool? isLocallySourced,
    String? certifications,
    bool? isActive,
    bool? isFeatured,
    List<String>? operatingDays,
    String? boothPreferences,
    String? specialRequirements,
    String? story,
    List<String>? tags,
    String? slogan,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return ManagedVendor(
      id: id ?? this.id,
      marketId: marketId ?? this.marketId,
      organizerId: organizerId ?? this.organizerId,
      businessName: businessName ?? this.businessName,
      vendorName: vendorName ?? this.vendorName,
      contactName: contactName ?? this.contactName,
      description: description ?? this.description,
      categories: categories ?? this.categories,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      logoUrl: logoUrl ?? this.logoUrl,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      ccEmails: ccEmails ?? this.ccEmails,
      website: website ?? this.website,
      instagramHandle: instagramHandle ?? this.instagramHandle,
      facebookHandle: facebookHandle ?? this.facebookHandle,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      canDeliver: canDeliver ?? this.canDeliver,
      acceptsOrders: acceptsOrders ?? this.acceptsOrders,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      products: products ?? this.products,
      specificProducts: specificProducts ?? this.specificProducts,
      specialties: specialties ?? this.specialties,
      priceRange: priceRange ?? this.priceRange,
      isOrganic: isOrganic ?? this.isOrganic,
      isLocallySourced: isLocallySourced ?? this.isLocallySourced,
      certifications: certifications ?? this.certifications,
      isActive: isActive ?? this.isActive,
      isFeatured: isFeatured ?? this.isFeatured,
      operatingDays: operatingDays ?? this.operatingDays,
      boothPreferences: boothPreferences ?? this.boothPreferences,
      specialRequirements: specialRequirements ?? this.specialRequirements,
      story: story ?? this.story,
      tags: tags ?? this.tags,
      slogan: slogan ?? this.slogan,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  // Helper methods
  String get categoriesDisplay {
    if (categories.isEmpty) return 'No categories';
    return categories.map((cat) => cat.displayName).join(', ');
  }

  String get productsDisplay {
    if (products.isEmpty) return 'No products listed';
    return products.join(', ');
  }

  String get contactInfo {
    final info = <String>[];
    if (email != null) info.add(email!);
    if (phoneNumber != null) info.add(phoneNumber!);
    return info.join(' • ');
  }

  String get socialMediaDisplay {
    final social = <String>[];
    if (instagramHandle != null) social.add('@$instagramHandle');
    if (facebookHandle != null) social.add('Facebook: $facebookHandle');
    return social.join(' • ');
  }

  bool get hasLocation {
    return address != null || city != null;
  }

  String get locationDisplay {
    final location = <String>[];
    if (address != null) location.add(address!);
    if (city != null && state != null) {
      location.add('$city, $state');
    } else if (city != null) {
      location.add(city!);
    }
    return location.join(', ');
  }

  @override
  List<Object?> get props => [
        id,
        marketId,
        organizerId,
        businessName,
        vendorName,
        contactName,
        description,
        categories,
        imageUrl,
        imageUrls,
        logoUrl,
        email,
        phoneNumber,
        ccEmails,
        website,
        instagramHandle,
        facebookHandle,
        address,
        city,
        state,
        zipCode,
        canDeliver,
        acceptsOrders,
        deliveryNotes,
        products,
        specificProducts,
        specialties,
        priceRange,
        isOrganic,
        isLocallySourced,
        certifications,
        isActive,
        isFeatured,
        operatingDays,
        boothPreferences,
        specialRequirements,
        story,
        tags,
        slogan,
        createdAt,
        updatedAt,
        metadata,
      ];

  @override
  String toString() {
    return 'ManagedVendor(id: $id, businessName: $businessName, contactName: $contactName, categories: $categories)';
  }
}