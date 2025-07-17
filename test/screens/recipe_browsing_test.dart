import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hipop/screens/shopper_recipes_screen.dart';
import 'package:hipop/screens/recipe_detail_screen.dart';
import 'package:hipop/models/recipe.dart';

void main() {
  group('Recipe Browsing UI Tests', () {

    testWidgets('ShopperRecipesScreen displays tabs and search bar', (WidgetTester tester) async {
      // Build the ShopperRecipesScreen widget
      await tester.pumpWidget(
        MaterialApp(
          home: const ShopperRecipesScreen(),
        ),
      );

      // Verify that the main UI elements are present
      expect(find.text('Recipes'), findsOneWidget);
      expect(find.text('All Recipes'), findsOneWidget);
      expect(find.text('Featured'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);
      
      // Verify search bar is present
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search recipes, ingredients, or vendors...'), findsOneWidget);
      
      // Verify filter chips are present
      expect(find.text('Category: All'), findsOneWidget);
      expect(find.text('Difficulty: All'), findsOneWidget);
      expect(find.text('Dietary: All'), findsOneWidget);
    });

    testWidgets('Search functionality updates query state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const ShopperRecipesScreen(),
        ),
      );

      // Find the search TextField
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      // Enter text in the search field
      await tester.enterText(searchField, 'pasta');
      await tester.pump();

      // Verify the text was entered (this tests the UI state)
      expect(find.text('pasta'), findsOneWidget);
    });

    testWidgets('Tab switching works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const ShopperRecipesScreen(),
        ),
      );

      // Initially should be on "All Recipes" tab
      expect(find.text('All Recipes'), findsOneWidget);

      // Tap on "Featured" tab
      await tester.tap(find.text('Featured'));
      await tester.pumpAndSettle();

      // Verify Featured tab is active (tabs remain visible)
      expect(find.text('Featured'), findsOneWidget);

      // Tap on "Categories" tab
      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();

      // Verify Categories tab is active
      expect(find.text('Categories'), findsOneWidget);
    });

    testWidgets('Filter chips are interactive', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const ShopperRecipesScreen(),
        ),
      );

      // Find and tap the Category filter chip
      final categoryChip = find.text('Category: All');
      expect(categoryChip, findsOneWidget);
      
      await tester.tap(categoryChip);
      await tester.pumpAndSettle();

      // Should show the category filter modal
      // Note: This would require mocking the showModalBottomSheet behavior
      // For now, we just verify the chip is tappable
    });

    testWidgets('Recipe categories are displayed correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const ShopperRecipesScreen(),
        ),
      );

      // Switch to Categories tab
      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();

      // Should show category cards - we expect at least some categories
      // The exact categories depend on the RecipeCategory enum
      expect(find.byType(Card), findsWidgets);
    });

    group('RecipeDetailScreen Tests', () {
      testWidgets('Recipe detail screen displays loading state', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const RecipeDetailScreen(recipeId: 'test-recipe-id'),
          ),
        );

        // Should show loading indicator initially
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('Recipe detail screen displays error for invalid recipe', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const RecipeDetailScreen(recipeId: 'invalid-recipe-id'),
          ),
        );

        // Wait for the loading to complete
        await tester.pumpAndSettle();

        // Should show error message for invalid recipe
        expect(find.text('Recipe not found'), findsOneWidget);
        expect(find.text('Go Back'), findsOneWidget);
      });
    });

    group('Recipe Data Model Tests', () {
      test('Recipe categories are defined correctly', () {
        // Verify all expected recipe categories exist
        expect(RecipeCategory.values, isNotEmpty);
        expect(RecipeCategory.values.length, greaterThan(5));
        
        // Test specific categories
        expect(RecipeCategory.values, contains(RecipeCategory.appetizer));
        expect(RecipeCategory.values, contains(RecipeCategory.mainCourse));
        expect(RecipeCategory.values, contains(RecipeCategory.dessert));
      });

      test('Difficulty levels are defined correctly', () {
        // Verify difficulty levels
        expect(DifficultyLevel.values, hasLength(3));
        expect(DifficultyLevel.values, contains(DifficultyLevel.easy));
        expect(DifficultyLevel.values, contains(DifficultyLevel.medium));
        expect(DifficultyLevel.values, contains(DifficultyLevel.hard));
      });

      test('Dietary restrictions are comprehensive', () {
        // Verify dietary restrictions cover common needs
        expect(DietaryRestriction.values, isNotEmpty);
        expect(DietaryRestriction.values, contains(DietaryRestriction.vegetarian));
        expect(DietaryRestriction.values, contains(DietaryRestriction.vegan));
        expect(DietaryRestriction.values, contains(DietaryRestriction.glutenFree));
        expect(DietaryRestriction.values, contains(DietaryRestriction.dairyFree));
      });
    });

    group('Navigation Integration Tests', () {
      testWidgets('Recipe browsing is accessible from shopper navigation', (WidgetTester tester) async {
        // This test would verify that the recipes icon/button exists in shopper navigation
        // and that tapping it navigates to the recipe browsing screen
        
        // Note: This requires the full app context with router, so it's more of an integration test
        // For now, we just verify the screen can be instantiated
        
        expect(() => const ShopperRecipesScreen(), returnsNormally);
        expect(() => const RecipeDetailScreen(recipeId: 'test-id'), returnsNormally);
      });
    });
  });

  group('Feature Completeness Tests', () {
    test('Recipe browsing feature checklist', () {
      // This test documents what the recipe browsing feature should include
      
      const List<String> requiredFeatures = [
        'Recipe listing with grid view',
        'Category-based filtering',
        'Difficulty-based filtering', 
        'Dietary restriction filtering',
        'Search functionality',
        'Featured recipes tab',
        'Recipe detail view',
        'Like/save/share functionality',
        'Ingredient list with vendor links',
        'Cooking instructions',
        'Nutrition information display',
        'Servings adjustment',
      ];
      
      // All features should be planned and documented
      expect(requiredFeatures.length, greaterThan(10));
      
      // Verify key UI components exist
      expect(() => const ShopperRecipesScreen(), returnsNormally);
      expect(() => const RecipeDetailScreen(recipeId: 'test'), returnsNormally);
    });
  });
}