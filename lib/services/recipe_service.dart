import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/recipe.dart';

class RecipeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _recipesCollection = 
      _firestore.collection('recipes');

  /// Create a new recipe
  static Future<String> createRecipe(Recipe recipe) async {
    try {
      final docRef = await _recipesCollection.add(recipe.toFirestore());
      debugPrint('Recipe created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating recipe: $e');
      throw Exception('Failed to create recipe: $e');
    }
  }

  /// Get all recipes for a specific market
  static Stream<List<Recipe>> getRecipesForMarket(String marketId) {
    return _recipesCollection
        .where('marketId', isEqualTo: marketId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Recipe.fromFirestore(doc))
            .toList());
  }

  /// Get recipes by organizer
  static Stream<List<Recipe>> getRecipesByOrganizer(String organizerId) {
    return _recipesCollection
        .where('organizerId', isEqualTo: organizerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Recipe.fromFirestore(doc))
            .toList());
  }

  /// Get recipes by category
  static Stream<List<Recipe>> getRecipesByCategory(
    String marketId,
    RecipeCategory category,
  ) {
    return _recipesCollection
        .where('marketId', isEqualTo: marketId)
        .where('category', isEqualTo: category.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Recipe.fromFirestore(doc))
            .toList());
  }

  /// Get featured recipes
  static Stream<List<Recipe>> getFeaturedRecipes(String marketId) {
    return _recipesCollection
        .where('marketId', isEqualTo: marketId)
        .where('isFeatured', isEqualTo: true)
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Recipe.fromFirestore(doc))
            .toList());
  }

  /// Get public recipes (for shoppers)
  static Stream<List<Recipe>> getPublicRecipes() {
    return _recipesCollection
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Recipe.fromFirestore(doc))
            .toList());
  }

  /// Get recipes by difficulty level
  static Stream<List<Recipe>> getRecipesByDifficulty(
    String marketId,
    DifficultyLevel difficulty,
  ) {
    return _recipesCollection
        .where('marketId', isEqualTo: marketId)
        .where('difficulty', isEqualTo: difficulty.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Recipe.fromFirestore(doc))
            .toList());
  }

  /// Get recipes by season
  static Stream<List<Recipe>> getRecipesBySeason(
    String marketId,
    String season,
  ) {
    return _recipesCollection
        .where('marketId', isEqualTo: marketId)
        .where('season', isEqualTo: season)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Recipe.fromFirestore(doc))
            .toList());
  }

  /// Get recipes featuring a specific vendor
  static Stream<List<Recipe>> getRecipesByVendor(
    String marketId,
    String vendorId,
  ) {
    return _recipesCollection
        .where('marketId', isEqualTo: marketId)
        .where('featuredVendorIds', arrayContains: vendorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Recipe.fromFirestore(doc))
            .toList());
  }

  /// Get popular recipes (by rating)
  static Stream<List<Recipe>> getPopularRecipes(String marketId) {
    return _recipesCollection
        .where('marketId', isEqualTo: marketId)
        .where('isPublic', isEqualTo: true)
        .where('ratingCount', isGreaterThan: 0)
        .orderBy('ratingCount', descending: false)
        .orderBy('rating', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Recipe.fromFirestore(doc))
            .toList());
  }

  /// Get a single recipe by ID
  static Future<Recipe?> getRecipe(String recipeId) async {
    try {
      final doc = await _recipesCollection.doc(recipeId).get();
      if (doc.exists) {
        return Recipe.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting recipe: $e');
      throw Exception('Failed to get recipe: $e');
    }
  }

  /// Update an existing recipe
  static Future<void> updateRecipe(String recipeId, Recipe recipe) async {
    try {
      await _recipesCollection.doc(recipeId).update(recipe.toFirestore());
      debugPrint('Recipe $recipeId updated');
    } catch (e) {
      debugPrint('Error updating recipe: $e');
      throw Exception('Failed to update recipe: $e');
    }
  }

  /// Update specific fields of a recipe
  static Future<void> updateRecipeFields(
    String recipeId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _recipesCollection.doc(recipeId).update({
        ...updates,
        'updatedAt': Timestamp.now(),
      });
      debugPrint('Recipe $recipeId fields updated');
    } catch (e) {
      debugPrint('Error updating recipe fields: $e');
      throw Exception('Failed to update recipe fields: $e');
    }
  }

  /// Delete a recipe
  static Future<void> deleteRecipe(String recipeId) async {
    try {
      await _recipesCollection.doc(recipeId).delete();
      debugPrint('Recipe $recipeId deleted');
    } catch (e) {
      debugPrint('Error deleting recipe: $e');
      throw Exception('Failed to delete recipe: $e');
    }
  }

  /// Toggle featured status
  static Future<void> toggleFeatured(String recipeId, bool isFeatured) async {
    await updateRecipeFields(recipeId, {
      'isFeatured': isFeatured,
    });
  }

  /// Toggle public status
  static Future<void> togglePublic(String recipeId, bool isPublic) async {
    await updateRecipeFields(recipeId, {
      'isPublic': isPublic,
    });
  }

  /// Like a recipe
  static Future<void> likeRecipe(String recipeId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final recipeRef = _recipesCollection.doc(recipeId);
        final recipeDoc = await transaction.get(recipeRef);
        
        if (recipeDoc.exists) {
          final currentLikes = recipeDoc.data() as Map<String, dynamic>;
          final likes = (currentLikes['likes'] ?? 0) + 1;
          
          transaction.update(recipeRef, {
            'likes': likes,
            'updatedAt': Timestamp.now(),
          });
        }
      });
    } catch (e) {
      debugPrint('Error liking recipe: $e');
      throw Exception('Failed to like recipe: $e');
    }
  }

  /// Save a recipe
  static Future<void> saveRecipe(String recipeId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final recipeRef = _recipesCollection.doc(recipeId);
        final recipeDoc = await transaction.get(recipeRef);
        
        if (recipeDoc.exists) {
          final currentSaves = recipeDoc.data() as Map<String, dynamic>;
          final saves = (currentSaves['saves'] ?? 0) + 1;
          
          transaction.update(recipeRef, {
            'saves': saves,
            'updatedAt': Timestamp.now(),
          });
        }
      });
    } catch (e) {
      debugPrint('Error saving recipe: $e');
      throw Exception('Failed to save recipe: $e');
    }
  }

  /// Share a recipe
  static Future<void> shareRecipe(String recipeId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final recipeRef = _recipesCollection.doc(recipeId);
        final recipeDoc = await transaction.get(recipeRef);
        
        if (recipeDoc.exists) {
          final currentShares = recipeDoc.data() as Map<String, dynamic>;
          final shares = (currentShares['shares'] ?? 0) + 1;
          
          transaction.update(recipeRef, {
            'shares': shares,
            'updatedAt': Timestamp.now(),
          });
        }
      });
    } catch (e) {
      debugPrint('Error sharing recipe: $e');
      throw Exception('Failed to share recipe: $e');
    }
  }

  /// Rate a recipe
  static Future<void> rateRecipe(String recipeId, double rating) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final recipeRef = _recipesCollection.doc(recipeId);
        final recipeDoc = await transaction.get(recipeRef);
        
        if (recipeDoc.exists) {
          final currentData = recipeDoc.data() as Map<String, dynamic>;
          final currentRating = (currentData['rating'] ?? 0.0).toDouble();
          final currentCount = (currentData['ratingCount'] ?? 0);
          
          // Calculate new average rating
          final totalRating = (currentRating * currentCount) + rating;
          final newCount = currentCount + 1;
          final newRating = totalRating / newCount;
          
          transaction.update(recipeRef, {
            'rating': newRating,
            'ratingCount': newCount,
            'updatedAt': Timestamp.now(),
          });
        }
      });
    } catch (e) {
      debugPrint('Error rating recipe: $e');
      throw Exception('Failed to rate recipe: $e');
    }
  }

  /// Search recipes by title or description
  static Future<List<Recipe>> searchRecipes(
    String marketId, 
    String query,
  ) async {
    try {
      // Note: Firestore doesn't support full-text search natively
      // This is a basic search that gets all recipes and filters locally
      final snapshot = await _recipesCollection
          .where('marketId', isEqualTo: marketId)
          .where('isPublic', isEqualTo: true)
          .get();
      
      final recipes = snapshot.docs
          .map((doc) => Recipe.fromFirestore(doc))
          .where((recipe) => 
              recipe.title.toLowerCase().contains(query.toLowerCase()) ||
              recipe.description.toLowerCase().contains(query.toLowerCase()) ||
              recipe.tags.any((tag) => tag.toLowerCase().contains(query.toLowerCase())) ||
              recipe.ingredients.any((ingredient) => 
                  ingredient.name.toLowerCase().contains(query.toLowerCase())))
          .toList();
      
      return recipes;
    } catch (e) {
      debugPrint('Error searching recipes: $e');
      throw Exception('Failed to search recipes: $e');
    }
  }

  /// Get recipes with dietary restrictions
  static Stream<List<Recipe>> getRecipesByDietaryRestriction(
    String marketId,
    DietaryRestriction restriction,
  ) {
    return _recipesCollection
        .where('marketId', isEqualTo: marketId)
        .where('dietaryRestrictions', arrayContains: restriction.name)
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Recipe.fromFirestore(doc))
            .toList());
  }

  /// Get recipe statistics for dashboard
  static Future<Map<String, int>> getRecipeStats(String marketId) async {
    try {
      final snapshot = await _recipesCollection
          .where('marketId', isEqualTo: marketId)
          .get();
      
      final recipes = snapshot.docs
          .map((doc) => Recipe.fromFirestore(doc))
          .toList();
      
      final stats = <String, int>{
        'total': recipes.length,
        'public': 0,
        'featured': 0,
        'appetizers': 0,
        'mainCourses': 0,
        'desserts': 0,
        'easy': 0,
        'medium': 0,
        'hard': 0,
        'totalLikes': 0,
        'totalSaves': 0,
      };
      
      for (final recipe in recipes) {
        if (recipe.isPublic) stats['public'] = stats['public']! + 1;
        if (recipe.isFeatured) stats['featured'] = stats['featured']! + 1;
        
        // Count by category
        switch (recipe.category) {
          case RecipeCategory.appetizer:
            stats['appetizers'] = stats['appetizers']! + 1;
            break;
          case RecipeCategory.mainCourse:
            stats['mainCourses'] = stats['mainCourses']! + 1;
            break;
          case RecipeCategory.dessert:
            stats['desserts'] = stats['desserts']! + 1;
            break;
          default:
            break;
        }
        
        // Count by difficulty
        switch (recipe.difficulty) {
          case DifficultyLevel.easy:
            stats['easy'] = stats['easy']! + 1;
            break;
          case DifficultyLevel.medium:
            stats['medium'] = stats['medium']! + 1;
            break;
          case DifficultyLevel.hard:
            stats['hard'] = stats['hard']! + 1;
            break;
        }
        
        stats['totalLikes'] = stats['totalLikes']! + recipe.likes;
        stats['totalSaves'] = stats['totalSaves']! + recipe.saves;
      }
      
      return stats;
    } catch (e) {
      debugPrint('Error getting recipe stats: $e');
      throw Exception('Failed to get recipe statistics: $e');
    }
  }

  /// Add featured vendor to recipe
  static Future<void> addFeaturedVendor(String recipeId, String vendorId) async {
    final recipe = await getRecipe(recipeId);
    if (recipe == null) throw Exception('Recipe not found');
    
    if (!recipe.featuredVendorIds.contains(vendorId)) {
      final updatedVendors = List<String>.from(recipe.featuredVendorIds)..add(vendorId);
      await updateRecipeFields(recipeId, {
        'featuredVendorIds': updatedVendors,
      });
    }
  }

  /// Remove featured vendor from recipe
  static Future<void> removeFeaturedVendor(String recipeId, String vendorId) async {
    final recipe = await getRecipe(recipeId);
    if (recipe == null) throw Exception('Recipe not found');
    
    final updatedVendors = List<String>.from(recipe.featuredVendorIds)..remove(vendorId);
    await updateRecipeFields(recipeId, {
      'featuredVendorIds': updatedVendors,
    });
  }

  /// Bulk operations
  static Future<void> bulkUpdateRecipePublicStatus(
    List<String> recipeIds, 
    bool isPublic,
  ) async {
    final batch = _firestore.batch();
    
    for (final recipeId in recipeIds) {
      final docRef = _recipesCollection.doc(recipeId);
      batch.update(docRef, {
        'isPublic': isPublic,
        'updatedAt': Timestamp.now(),
      });
    }
    
    try {
      await batch.commit();
      debugPrint('Bulk updated ${recipeIds.length} recipes public status to: $isPublic');
    } catch (e) {
      debugPrint('Error in bulk update: $e');
      throw Exception('Failed to bulk update recipes: $e');
    }
  }

  /// Delete all recipes for a market (use with caution)
  static Future<void> deleteAllRecipesForMarket(String marketId) async {
    try {
      final snapshot = await _recipesCollection
          .where('marketId', isEqualTo: marketId)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      debugPrint('Deleted all recipes for market: $marketId');
    } catch (e) {
      debugPrint('Error deleting all recipes: $e');
      throw Exception('Failed to delete all recipes: $e');
    }
  }

  /// Get trending recipes (high engagement in last 30 days)
  static Future<List<Recipe>> getTrendingRecipes(String marketId) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final snapshot = await _recipesCollection
          .where('marketId', isEqualTo: marketId)
          .where('isPublic', isEqualTo: true)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();
      
      final recipes = snapshot.docs
          .map((doc) => Recipe.fromFirestore(doc))
          .toList();
      
      // Sort by engagement score (likes + saves + shares)
      recipes.sort((a, b) {
        final aEngagement = a.likes + a.saves + a.shares;
        final bEngagement = b.likes + b.saves + b.shares;
        return bEngagement.compareTo(aEngagement);
      });
      
      return recipes.take(10).toList();
    } catch (e) {
      debugPrint('Error getting trending recipes: $e');
      throw Exception('Failed to get trending recipes: $e');
    }
  }

  /// Get count of recipes by category (for shopper UI)
  static Future<int> getRecipeCountByCategory(RecipeCategory category) async {
    try {
      final snapshot = await _recipesCollection
          .where('category', isEqualTo: category.name)
          .where('isPublic', isEqualTo: true)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting recipe count by category: $e');
      return 0;
    }
  }

  /// Get featured recipes across all markets (for shopper UI)
  static Stream<List<Recipe>> getAllFeaturedRecipes() {
    return _recipesCollection
        .where('isFeatured', isEqualTo: true)
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Recipe.fromFirestore(doc))
            .toList());
  }
}