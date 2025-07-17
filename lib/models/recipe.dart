import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum RecipeCategory {
  appetizer,
  mainCourse,
  dessert,
  beverage,
  salad,
  soup,
  breakfast,
  snack,
  sauce,
  preserves,
}

enum DifficultyLevel {
  easy,
  medium,
  hard,
}

enum DietaryRestriction {
  vegetarian,
  vegan,
  glutenFree,
  dairyFree,
  nutFree,
  kosher,
  halal,
  keto,
  paleo,
}

class RecipeIngredient extends Equatable {
  final String name;
  final String amount;
  final String? unit;
  final String? vendorId; // Links to specific vendor
  final String? vendorName; // Display name for vendor
  final bool isOptional;
  final String? substitutes; // Alternative ingredients

  const RecipeIngredient({
    required this.name,
    required this.amount,
    this.unit,
    this.vendorId,
    this.vendorName,
    this.isOptional = false,
    this.substitutes,
  });

  factory RecipeIngredient.fromMap(Map<String, dynamic> map) {
    return RecipeIngredient(
      name: map['name'] ?? '',
      amount: map['amount'] ?? '',
      unit: map['unit'],
      vendorId: map['vendorId'],
      vendorName: map['vendorName'],
      isOptional: map['isOptional'] ?? false,
      substitutes: map['substitutes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'unit': unit,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'isOptional': isOptional,
      'substitutes': substitutes,
    };
  }

  String get displayAmount {
    if (unit != null && unit!.isNotEmpty) {
      return '$amount $unit';
    }
    return amount;
  }

  String get displayName {
    if (vendorName != null && vendorName!.isNotEmpty) {
      return '$name (from $vendorName)';
    }
    return name;
  }

  @override
  List<Object?> get props => [name, amount, unit, vendorId, vendorName, isOptional, substitutes];
}

class Recipe extends Equatable {
  final String id;
  final String marketId; // Associated market
  final String organizerId; // Market organizer who created it
  final String title;
  final String description;
  final RecipeCategory category;
  final DifficultyLevel difficulty;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final int servings;
  
  // Ingredients and Instructions
  final List<RecipeIngredient> ingredients;
  final List<String> instructions;
  final List<String> tips; // Cooking tips and notes
  
  // Vendor connections
  final List<String> featuredVendorIds; // Vendors highlighted in this recipe
  final String? chefName; // Guest chef or organizer name
  final String? chefBio; // Brief bio of recipe creator
  
  // Media and presentation
  final String? imageUrl;
  final List<String> imageUrls; // Multiple step photos
  final String? videoUrl; // Cooking video
  
  // Categorization and discovery
  final List<String> tags; // Searchable tags (seasonal, quick, etc.)
  final List<DietaryRestriction> dietaryRestrictions;
  final String? season; // spring, summer, fall, winter
  final bool isFeatured; // Highlighted recipe
  final bool isPublic; // Visible to shoppers
  
  // Nutritional info (optional)
  final Map<String, String>? nutritionalInfo; // calories, protein, etc.
  
  // Engagement
  final int likes;
  final int shares;
  final int saves;
  final double rating; // Average user rating
  final int ratingCount;
  
  // Meta information
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata; // Flexible field for additional data

  const Recipe({
    required this.id,
    required this.marketId,
    required this.organizerId,
    required this.title,
    required this.description,
    this.category = RecipeCategory.mainCourse,
    this.difficulty = DifficultyLevel.medium,
    this.prepTimeMinutes = 30,
    this.cookTimeMinutes = 30,
    this.servings = 4,
    this.ingredients = const [],
    this.instructions = const [],
    this.tips = const [],
    this.featuredVendorIds = const [],
    this.chefName,
    this.chefBio,
    this.imageUrl,
    this.imageUrls = const [],
    this.videoUrl,
    this.tags = const [],
    this.dietaryRestrictions = const [],
    this.season,
    this.isFeatured = false,
    this.isPublic = true,
    this.nutritionalInfo,
    this.likes = 0,
    this.shares = 0,
    this.saves = 0,
    this.rating = 0.0,
    this.ratingCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.metadata = const {},
  });

  factory Recipe.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Recipe(
      id: doc.id,
      marketId: data['marketId'] ?? '',
      organizerId: data['organizerId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: RecipeCategory.values.firstWhere(
        (cat) => cat.name == data['category'],
        orElse: () => RecipeCategory.mainCourse,
      ),
      difficulty: DifficultyLevel.values.firstWhere(
        (diff) => diff.name == data['difficulty'],
        orElse: () => DifficultyLevel.medium,
      ),
      prepTimeMinutes: data['prepTimeMinutes'] ?? 30,
      cookTimeMinutes: data['cookTimeMinutes'] ?? 30,
      servings: data['servings'] ?? 4,
      ingredients: (data['ingredients'] as List?)
          ?.map((item) => RecipeIngredient.fromMap(item as Map<String, dynamic>))
          .toList() ?? [],
      instructions: List<String>.from(data['instructions'] ?? []),
      tips: List<String>.from(data['tips'] ?? []),
      featuredVendorIds: List<String>.from(data['featuredVendorIds'] ?? []),
      chefName: data['chefName'],
      chefBio: data['chefBio'],
      imageUrl: data['imageUrl'],
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      videoUrl: data['videoUrl'],
      tags: List<String>.from(data['tags'] ?? []),
      dietaryRestrictions: (data['dietaryRestrictions'] as List?)
          ?.map((item) => DietaryRestriction.values.firstWhere(
                (restriction) => restriction.name == item,
                orElse: () => DietaryRestriction.vegetarian,
              ))
          .toList() ?? [],
      season: data['season'],
      isFeatured: data['isFeatured'] ?? false,
      isPublic: data['isPublic'] ?? true,
      nutritionalInfo: data['nutritionalInfo'] != null 
          ? Map<String, String>.from(data['nutritionalInfo'])
          : null,
      likes: data['likes'] ?? 0,
      shares: data['shares'] ?? 0,
      saves: data['saves'] ?? 0,
      rating: (data['rating'] ?? 0.0).toDouble(),
      ratingCount: data['ratingCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'marketId': marketId,
      'organizerId': organizerId,
      'title': title,
      'description': description,
      'category': category.name,
      'difficulty': difficulty.name,
      'prepTimeMinutes': prepTimeMinutes,
      'cookTimeMinutes': cookTimeMinutes,
      'servings': servings,
      'ingredients': ingredients.map((ingredient) => ingredient.toMap()).toList(),
      'instructions': instructions,
      'tips': tips,
      'featuredVendorIds': featuredVendorIds,
      'chefName': chefName,
      'chefBio': chefBio,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'videoUrl': videoUrl,
      'tags': tags,
      'dietaryRestrictions': dietaryRestrictions.map((restriction) => restriction.name).toList(),
      'season': season,
      'isFeatured': isFeatured,
      'isPublic': isPublic,
      'nutritionalInfo': nutritionalInfo,
      'likes': likes,
      'shares': shares,
      'saves': saves,
      'rating': rating,
      'ratingCount': ratingCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'metadata': metadata,
    };
  }

  Recipe copyWith({
    String? id,
    String? marketId,
    String? organizerId,
    String? title,
    String? description,
    RecipeCategory? category,
    DifficultyLevel? difficulty,
    int? prepTimeMinutes,
    int? cookTimeMinutes,
    int? servings,
    List<RecipeIngredient>? ingredients,
    List<String>? instructions,
    List<String>? tips,
    List<String>? featuredVendorIds,
    String? chefName,
    String? chefBio,
    String? imageUrl,
    List<String>? imageUrls,
    String? videoUrl,
    List<String>? tags,
    List<DietaryRestriction>? dietaryRestrictions,
    String? season,
    bool? isFeatured,
    bool? isPublic,
    Map<String, String>? nutritionalInfo,
    int? likes,
    int? shares,
    int? saves,
    double? rating,
    int? ratingCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Recipe(
      id: id ?? this.id,
      marketId: marketId ?? this.marketId,
      organizerId: organizerId ?? this.organizerId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes ?? this.cookTimeMinutes,
      servings: servings ?? this.servings,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      tips: tips ?? this.tips,
      featuredVendorIds: featuredVendorIds ?? this.featuredVendorIds,
      chefName: chefName ?? this.chefName,
      chefBio: chefBio ?? this.chefBio,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      videoUrl: videoUrl ?? this.videoUrl,
      tags: tags ?? this.tags,
      dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
      season: season ?? this.season,
      isFeatured: isFeatured ?? this.isFeatured,
      isPublic: isPublic ?? this.isPublic,
      nutritionalInfo: nutritionalInfo ?? this.nutritionalInfo,
      likes: likes ?? this.likes,
      shares: shares ?? this.shares,
      saves: saves ?? this.saves,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  // Helper methods
  int get totalTimeMinutes => prepTimeMinutes + cookTimeMinutes;
  
  String get categoryDisplayName {
    switch (category) {
      case RecipeCategory.appetizer:
        return 'Appetizer';
      case RecipeCategory.mainCourse:
        return 'Main Course';
      case RecipeCategory.dessert:
        return 'Dessert';
      case RecipeCategory.beverage:
        return 'Beverage';
      case RecipeCategory.salad:
        return 'Salad';
      case RecipeCategory.soup:
        return 'Soup';
      case RecipeCategory.breakfast:
        return 'Breakfast';
      case RecipeCategory.snack:
        return 'Snack';
      case RecipeCategory.sauce:
        return 'Sauce';
      case RecipeCategory.preserves:
        return 'Preserves';
    }
  }

  String get difficultyDisplayName {
    switch (difficulty) {
      case DifficultyLevel.easy:
        return 'Easy';
      case DifficultyLevel.medium:
        return 'Medium';
      case DifficultyLevel.hard:
        return 'Hard';
    }
  }

  String get formattedTotalTime {
    final hours = totalTimeMinutes ~/ 60;
    final minutes = totalTimeMinutes % 60;
    
    if (hours > 0) {
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
    return '${minutes}m';
  }

  String get formattedServings {
    return servings == 1 ? '1 serving' : '$servings servings';
  }

  List<RecipeIngredient> get vendorIngredients {
    return ingredients.where((ingredient) => ingredient.vendorId != null).toList();
  }

  bool get hasVendorIngredients => vendorIngredients.isNotEmpty;

  String get ratingDisplayText {
    if (ratingCount == 0) return 'No ratings yet';
    return '${rating.toStringAsFixed(1)} ($ratingCount ${ratingCount == 1 ? 'rating' : 'ratings'})';
  }

  List<String> get allDietaryTags {
    return dietaryRestrictions.map((restriction) {
      switch (restriction) {
        case DietaryRestriction.vegetarian:
          return 'Vegetarian';
        case DietaryRestriction.vegan:
          return 'Vegan';
        case DietaryRestriction.glutenFree:
          return 'Gluten-Free';
        case DietaryRestriction.dairyFree:
          return 'Dairy-Free';
        case DietaryRestriction.nutFree:
          return 'Nut-Free';
        case DietaryRestriction.kosher:
          return 'Kosher';
        case DietaryRestriction.halal:
          return 'Halal';
        case DietaryRestriction.keto:
          return 'Keto';
        case DietaryRestriction.paleo:
          return 'Paleo';
      }
    }).toList();
  }

  @override
  List<Object?> get props => [
        id,
        marketId,
        organizerId,
        title,
        description,
        category,
        difficulty,
        prepTimeMinutes,
        cookTimeMinutes,
        servings,
        ingredients,
        instructions,
        tips,
        featuredVendorIds,
        chefName,
        chefBio,
        imageUrl,
        imageUrls,
        videoUrl,
        tags,
        dietaryRestrictions,
        season,
        isFeatured,
        isPublic,
        nutritionalInfo,
        likes,
        shares,
        saves,
        rating,
        ratingCount,
        createdAt,
        updatedAt,
        metadata,
      ];

  @override
  String toString() {
    return 'Recipe(id: $id, title: $title, category: $category, difficulty: $difficulty, servings: $servings)';
  }
}