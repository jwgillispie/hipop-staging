import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String recipeId;

  const RecipeDetailScreen({
    super.key,
    required this.recipeId,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Recipe? _recipe;
  bool _isLoading = true;
  bool _isLiked = false;
  bool _isSaved = false;
  int _servings = 4;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRecipe();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipe() async {
    try {
      final recipe = await RecipeService.getRecipe(widget.recipeId);
      setState(() {
        _recipe = recipe;
        _servings = recipe?.servings ?? 4;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_recipe == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
        body: _buildErrorView(),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildRecipeHeader(),
                _buildTabBar(),
              ],
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildIngredientsTab(),
                _buildInstructionsTab(),
                _buildDetailsTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      backgroundColor: Colors.orange,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: _recipe!.imageUrl != null
            ? Image.network(
                _recipe!.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildImagePlaceholder();
                },
              )
            : _buildImagePlaceholder(),
      ),
      actions: [
        IconButton(
          icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_outline),
          onPressed: _toggleSave,
        ),
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: _shareRecipe,
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    final color = _getCategoryColor(_recipe!.category);
    return Container(
      color: color.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          _getCategoryIcon(_recipe!.category),
          size: 80,
          color: color,
        ),
      ),
    );
  }

  Widget _buildRecipeHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and Rating
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _recipe!.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_recipe!.chefName != null)
                      Text(
                        'by ${_recipe!.chefName}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              if (_recipe!.isFeatured)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 16, color: Colors.amber[800]),
                      const SizedBox(width: 4),
                      Text(
                        'Featured',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Description
          Text(
            _recipe!.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          // Stats Row
          Row(
            children: [
              _buildStatChip(
                Icons.schedule,
                _recipe!.formattedTotalTime,
                Colors.blue,
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                Icons.people,
                _getServingsText(),
                Colors.green,
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                Icons.bar_chart,
                _recipe!.difficultyDisplayName,
                _getDifficultyColor(_recipe!.difficulty),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Engagement Row
          Row(
            children: [
              _buildEngagementButton(
                icon: _isLiked ? Icons.favorite : Icons.favorite_outline,
                count: _recipe!.likes,
                color: Colors.red,
                onPressed: _toggleLike,
              ),
              const SizedBox(width: 16),
              _buildEngagementButton(
                icon: Icons.bookmark_outline,
                count: _recipe!.saves,
                color: Colors.blue,
                onPressed: _toggleSave,
              ),
              const SizedBox(width: 16),
              _buildEngagementButton(
                icon: Icons.share_outlined,
                count: _recipe!.shares,
                color: Colors.green,
                onPressed: _shareRecipe,
              ),
              const Spacer(),
              if (_recipe!.ratingCount > 0)
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber[600], size: 16),
                    const SizedBox(width: 4),
                    Text(
                      _recipe!.rating.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      ' (${_recipe!.ratingCount})',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
            ],
          ),
          // Dietary Restrictions
          if (_recipe!.dietaryRestrictions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recipe!.dietaryRestrictions.map((restriction) {
                return Chip(
                  label: Text(
                    _getDietaryDisplayName(restriction),
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.green[100],
                  labelStyle: TextStyle(color: Colors.green[800]),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementButton({
    required IconData icon,
    required int count,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 4),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.grey[50],
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.orange,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: Colors.orange,
        tabs: const [
          Tab(text: 'Ingredients'),
          Tab(text: 'Instructions'),
          Tab(text: 'Details'),
        ],
      ),
    );
  }

  Widget _buildIngredientsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Servings Adjuster
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Servings:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _servings > 1 ? () => _adjustServings(-1) : null,
                  icon: const Icon(Icons.remove),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _servings.toString(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: () => _adjustServings(1),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Ingredients List
        ..._recipe!.ingredients.asMap().entries.map((entry) {
          final index = entry.key;
          final ingredient = entry.value;
          return _buildIngredientCard(ingredient, index);
        }),
        // Vendor Featured Ingredients Section
        if (_recipe!.hasVendorIngredients) ...[
          const SizedBox(height: 24),
          const Text(
            'Featured Local Vendors',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._recipe!.vendorIngredients.map((ingredient) {
            return _buildVendorIngredientCard(ingredient);
          }),
        ],
      ],
    );
  }

  Widget _buildIngredientCard(RecipeIngredient ingredient, int index) {
    final adjustedAmount = _calculateAdjustedAmount(ingredient.amount);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange[100],
          child: Text(
            '${index + 1}',
            style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          ingredient.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$adjustedAmount ${ingredient.unit ?? ''}',
              style: const TextStyle(fontSize: 16),
            ),
            if (ingredient.substitutes != null) ...[
              const SizedBox(height: 4),
              Text(
                'Substitute: ${ingredient.substitutes}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        trailing: ingredient.isOptional
            ? Chip(
                label: const Text('Optional'),
                backgroundColor: Colors.grey[200],
                labelStyle: const TextStyle(fontSize: 10),
              )
            : null,
      ),
    );
  }

  Widget _buildVendorIngredientCard(RecipeIngredient ingredient) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green[100],
          child: Icon(Icons.store, color: Colors.green[800]),
        ),
        title: Text(
          ingredient.vendorName ?? 'Local Vendor',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('For: ${ingredient.name}'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // TODO: Navigate to vendor detail when implemented
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Vendor detail for ${ingredient.vendorName} coming soon!'),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInstructionsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ..._recipe!.instructions.asMap().entries.map((entry) {
          final index = entry.key;
          final instruction = entry.value;
          return _buildInstructionCard(instruction, index);
        }),
        if (_recipe!.tips.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'Tips & Notes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._recipe!.tips.map((tip) => _buildTipCard(tip)),
        ],
      ],
    );
  }

  Widget _buildInstructionCard(String instruction, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.orange,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                instruction,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard(String tip) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb, color: Colors.blue[600], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tip,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDetailSection('Category', _recipe!.categoryDisplayName),
        _buildDetailSection('Difficulty', _recipe!.difficultyDisplayName),
        _buildDetailSection('Prep Time', '${_recipe!.prepTimeMinutes} minutes'),
        _buildDetailSection('Cook Time', '${_recipe!.cookTimeMinutes} minutes'),
        _buildDetailSection('Total Time', _recipe!.formattedTotalTime),
        if (_recipe!.season != null)
          _buildDetailSection('Season', _recipe!.season!),
        if (_recipe!.tags.isNotEmpty)
          _buildTagsSection(),
        if (_recipe!.nutritionalInfo != null)
          _buildNutritionalSection(),
        if (_recipe!.chefBio != null)
          _buildChefSection(),
      ],
    );
  }

  Widget _buildDetailSection(String title, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: Text(
          value,
          style: TextStyle(color: Colors.grey[700]),
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tags',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recipe!.tags.map((tag) {
                return Chip(
                  label: Text(tag),
                  backgroundColor: Colors.grey[200],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionalSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nutritional Information',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ..._recipe!.nutritionalInfo!.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key),
                    Text(entry.value),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildChefSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About ${_recipe!.chefName}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _recipe!.chefBio!,
              style: const TextStyle(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _toggleLike,
              icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_outline),
              label: Text(_isLiked ? 'Liked' : 'Like'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isLiked ? Colors.red : Colors.grey[200],
                foregroundColor: _isLiked ? Colors.white : Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _toggleSave,
              icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_outline),
              label: Text(_isSaved ? 'Saved' : 'Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSaved ? Colors.blue : Colors.grey[200],
                foregroundColor: _isSaved ? Colors.white : Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Recipe not found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('The recipe you\'re looking for doesn\'t exist.'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  void _adjustServings(int change) {
    setState(() {
      _servings = (_servings + change).clamp(1, 20);
    });
  }

  String _calculateAdjustedAmount(String originalAmount) {
    // Try to parse the amount and adjust for servings
    final regex = RegExp(r'(\d+(?:\.\d+)?|\d+/\d+)');
    final match = regex.firstMatch(originalAmount);
    
    if (match != null) {
      final numberStr = match.group(1)!;
      double originalValue;
      
      // Handle fractions
      if (numberStr.contains('/')) {
        final parts = numberStr.split('/');
        originalValue = double.parse(parts[0]) / double.parse(parts[1]);
      } else {
        originalValue = double.parse(numberStr);
      }
      
      final adjustedValue = originalValue * (_servings / _recipe!.servings);
      
      // Format the result nicely
      if (adjustedValue == adjustedValue.toInt()) {
        return originalAmount.replaceFirst(numberStr, adjustedValue.toInt().toString());
      } else {
        return originalAmount.replaceFirst(numberStr, adjustedValue.toStringAsFixed(1));
      }
    }
    
    return originalAmount;
  }

  String _getServingsText() {
    return _servings == 1 ? '1 serving' : '$_servings servings';
  }

  void _toggleLike() async {
    try {
      await RecipeService.likeRecipe(widget.recipeId);
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          if (_isLiked) {
            _recipe = _recipe!.copyWith(likes: _recipe!.likes + 1);
          } else {
            _recipe = _recipe!.copyWith(likes: _recipe!.likes - 1);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update like')),
        );
      }
    }
  }

  void _toggleSave() async {
    try {
      await RecipeService.saveRecipe(widget.recipeId);
      if (mounted) {
        setState(() {
          _isSaved = !_isSaved;
          if (_isSaved) {
            _recipe = _recipe!.copyWith(saves: _recipe!.saves + 1);
          } else {
            _recipe = _recipe!.copyWith(saves: _recipe!.saves - 1);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update save')),
        );
      }
    }
  }

  void _shareRecipe() async {
    try {
      await RecipeService.shareRecipe(widget.recipeId);
      if (mounted) {
        setState(() {
          _recipe = _recipe!.copyWith(shares: _recipe!.shares + 1);
        });
        
        // TODO: Implement actual sharing functionality
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recipe "${_recipe!.title}" shared!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to share recipe')),
        );
      }
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

  Color _getDifficultyColor(DifficultyLevel difficulty) {
    switch (difficulty) {
      case DifficultyLevel.easy:
        return Colors.green;
      case DifficultyLevel.medium:
        return Colors.orange;
      case DifficultyLevel.hard:
        return Colors.red;
    }
  }
}