import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';

class ShopperRecipesScreen extends StatefulWidget {
  const ShopperRecipesScreen({super.key});

  @override
  State<ShopperRecipesScreen> createState() => _ShopperRecipesScreenState();
}

class _ShopperRecipesScreenState extends State<ShopperRecipesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  RecipeCategory? _selectedCategory;
  DifficultyLevel? _selectedDifficulty;
  final List<DietaryRestriction> _selectedDietaryRestrictions = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipes'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'All Recipes'),
            Tab(text: 'Featured'),
            Tab(text: 'Categories'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search recipes, ingredients, or vendors...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          // Filters Row
          _buildFiltersRow(),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllRecipesTab(),
                _buildFeaturedRecipesTab(),
                _buildCategoriesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Category Filter
          _buildFilterChip(
            'Category',
            _selectedCategory?.toString().split('.').last ?? 'All',
            Icons.restaurant_menu,
            () => _showCategoryFilter(),
          ),
          const SizedBox(width: 8),
          // Difficulty Filter
          _buildFilterChip(
            'Difficulty',
            _selectedDifficulty?.toString().split('.').last ?? 'All',
            Icons.bar_chart,
            () => _showDifficultyFilter(),
          ),
          const SizedBox(width: 8),
          // Dietary Filter
          _buildFilterChip(
            'Dietary',
            _selectedDietaryRestrictions.isEmpty 
                ? 'All' 
                : '${_selectedDietaryRestrictions.length} selected',
            Icons.local_dining,
            () => _showDietaryFilter(),
          ),
          const SizedBox(width: 8),
          // Clear Filters
          if (_selectedCategory != null || 
              _selectedDifficulty != null || 
              _selectedDietaryRestrictions.isNotEmpty)
            ActionChip(
              label: const Text('Clear'),
              onPressed: _clearFilters,
              backgroundColor: Colors.grey[200],
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon, VoidCallback onTap) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text('$label: $value'),
        ],
      ),
      selected: value != 'All',
      onSelected: (_) => onTap(),
      selectedColor: Colors.orange[100],
    );
  }

  Widget _buildAllRecipesTab() {
    return StreamBuilder<List<Recipe>>(
      stream: RecipeService.getPublicRecipes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorView(snapshot.error.toString());
        }

        List<Recipe> recipes = snapshot.data ?? [];
        
        // Apply filters
        recipes = _applyFilters(recipes);

        if (recipes.isEmpty) {
          return _buildEmptyView();
        }

        return _buildRecipeGrid(recipes);
      },
    );
  }

  Widget _buildFeaturedRecipesTab() {
    return StreamBuilder<List<Recipe>>(
      stream: RecipeService.getAllFeaturedRecipes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorView(snapshot.error.toString());
        }

        List<Recipe> recipes = snapshot.data ?? [];
        recipes = _applyFilters(recipes);

        if (recipes.isEmpty) {
          return _buildEmptyFeaturedView();
        }

        return _buildRecipeGrid(recipes, isFeatured: true);
      },
    );
  }

  Widget _buildCategoriesTab() {
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: RecipeCategory.values.map((category) {
        return _buildCategoryCard(category);
      }).toList(),
    );
  }

  Widget _buildCategoryCard(RecipeCategory category) {
    final categoryName = _getCategoryDisplayName(category);
    final icon = _getCategoryIcon(category);
    final color = _getCategoryColor(category);

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCategory = category;
            _tabController.animateTo(0); // Switch to All Recipes tab
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              categoryName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            FutureBuilder<int>(
              future: RecipeService.getRecipeCountByCategory(category),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return Text(
                  '$count recipes',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeGrid(List<Recipe> recipes, {bool isFeatured = false}) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        return _buildRecipeCard(recipes[index], isFeatured: isFeatured);
      },
    );
  }

  Widget _buildRecipeCard(Recipe recipe, {bool isFeatured = false}) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.pushNamed('recipeDetail', pathParameters: {'recipeId': recipe.id});
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe Image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                color: Colors.grey[200],
                child: recipe.imageUrl != null
                    ? Image.network(
                        recipe.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildRecipeImagePlaceholder(recipe);
                        },
                      )
                    : _buildRecipeImagePlaceholder(recipe),
              ),
            ),
            // Recipe Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Featured Badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            recipe.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (recipe.isFeatured || isFeatured)
                          Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber[600],
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Time and Difficulty
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          recipe.formattedTotalTime,
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.bar_chart, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          recipe.difficultyDisplayName,
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Engagement
                    Row(
                      children: [
                        Icon(Icons.favorite, size: 12, color: Colors.red[300]),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.likes}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.bookmark, size: 12, color: Colors.blue[300]),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.saves}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeImagePlaceholder(Recipe recipe) {
    return Container(
      color: _getCategoryColor(recipe.category).withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          _getCategoryIcon(recipe.category),
          size: 48,
          color: _getCategoryColor(recipe.category),
        ),
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Failed to load recipes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() {}),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No recipes found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or search terms',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFeaturedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.star_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No featured recipes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for featured recipes from market organizers',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<Recipe> _applyFilters(List<Recipe> recipes) {
    return recipes.where((recipe) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!recipe.title.toLowerCase().contains(query) &&
            !recipe.description.toLowerCase().contains(query) &&
            !recipe.ingredients.any((ingredient) => 
                ingredient.name.toLowerCase().contains(query) ||
                (ingredient.vendorName?.toLowerCase().contains(query) ?? false))) {
          return false;
        }
      }

      // Category filter
      if (_selectedCategory != null && recipe.category != _selectedCategory) {
        return false;
      }

      // Difficulty filter
      if (_selectedDifficulty != null && recipe.difficulty != _selectedDifficulty) {
        return false;
      }

      // Dietary restrictions filter
      if (_selectedDietaryRestrictions.isNotEmpty) {
        if (!_selectedDietaryRestrictions.every((restriction) =>
            recipe.dietaryRestrictions.contains(restriction))) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void _showCategoryFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Category',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('All Categories'),
                selected: _selectedCategory == null,
                onTap: () {
                  setState(() {
                    _selectedCategory = null;
                  });
                  Navigator.pop(context);
                },
              ),
              ...RecipeCategory.values.map((category) {
                return ListTile(
                  title: Text(_getCategoryDisplayName(category)),
                  selected: _selectedCategory == category,
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                    });
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showDifficultyFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Difficulty',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('All Difficulties'),
                selected: _selectedDifficulty == null,
                onTap: () {
                  setState(() {
                    _selectedDifficulty = null;
                  });
                  Navigator.pop(context);
                },
              ),
              ...DifficultyLevel.values.map((difficulty) {
                return ListTile(
                  title: Text(difficulty.toString().split('.').last.toUpperCase()),
                  selected: _selectedDifficulty == difficulty,
                  onTap: () {
                    setState(() {
                      _selectedDifficulty = difficulty;
                    });
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showDietaryFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dietary Restrictions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...DietaryRestriction.values.map((restriction) {
                    return CheckboxListTile(
                      title: Text(_getDietaryDisplayName(restriction)),
                      value: _selectedDietaryRestrictions.contains(restriction),
                      onChanged: (selected) {
                        setModalState(() {
                          if (selected == true) {
                            _selectedDietaryRestrictions.add(restriction);
                          } else {
                            _selectedDietaryRestrictions.remove(restriction);
                          }
                        });
                        setState(() {});
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedDietaryRestrictions.clear();
                          });
                          setState(() {});
                        },
                        child: const Text('Clear All'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = null;
      _selectedDifficulty = null;
      _selectedDietaryRestrictions.clear();
      _searchQuery = '';
      _searchController.clear();
    });
  }

  String _getCategoryDisplayName(RecipeCategory category) {
    switch (category) {
      case RecipeCategory.appetizer:
        return 'Appetizers';
      case RecipeCategory.mainCourse:
        return 'Main Course';
      case RecipeCategory.dessert:
        return 'Desserts';
      case RecipeCategory.beverage:
        return 'Beverages';
      case RecipeCategory.salad:
        return 'Salads';
      case RecipeCategory.soup:
        return 'Soups';
      case RecipeCategory.breakfast:
        return 'Breakfast';
      case RecipeCategory.snack:
        return 'Snacks';
      case RecipeCategory.sauce:
        return 'Sauces';
      case RecipeCategory.preserves:
        return 'Preserves';
    }
  }

  String _getDietaryDisplayName(DietaryRestriction restriction) {
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
  }

  IconData _getCategoryIcon(RecipeCategory category) {
    switch (category) {
      case RecipeCategory.appetizer:
        return Icons.restaurant;
      case RecipeCategory.mainCourse:
        return Icons.dinner_dining;
      case RecipeCategory.dessert:
        return Icons.cake;
      case RecipeCategory.beverage:
        return Icons.local_drink;
      case RecipeCategory.salad:
        return Icons.eco;
      case RecipeCategory.soup:
        return Icons.soup_kitchen;
      case RecipeCategory.breakfast:
        return Icons.free_breakfast;
      case RecipeCategory.snack:
        return Icons.cookie;
      case RecipeCategory.sauce:
        return Icons.water_drop;
      case RecipeCategory.preserves:
        return Icons.inventory;
    }
  }

  Color _getCategoryColor(RecipeCategory category) {
    switch (category) {
      case RecipeCategory.appetizer:
        return Colors.green;
      case RecipeCategory.mainCourse:
        return Colors.blue;
      case RecipeCategory.dessert:
        return Colors.pink;
      case RecipeCategory.beverage:
        return Colors.cyan;
      case RecipeCategory.salad:
        return Colors.lightGreen;
      case RecipeCategory.soup:
        return Colors.orange;
      case RecipeCategory.breakfast:
        return Colors.amber;
      case RecipeCategory.snack:
        return Colors.purple;
      case RecipeCategory.sauce:
        return Colors.red;
      case RecipeCategory.preserves:
        return Colors.brown;
    }
  }
}