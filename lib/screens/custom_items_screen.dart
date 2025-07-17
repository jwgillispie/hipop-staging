import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';

class CustomItemsScreen extends StatefulWidget {
  const CustomItemsScreen({super.key});

  @override
  State<CustomItemsScreen> createState() => _CustomItemsScreenState();
}

class _CustomItemsScreenState extends State<CustomItemsScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this); // Only recipes for now
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Items'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.restaurant_menu),
              text: 'Recipes',
            ),
            // Future tabs can be added here
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RecipeManagementTab(),
          // Future custom item types can be added here
        ],
      ),
    );
  }
}

class _RecipeManagementTab extends StatefulWidget {
  @override
  State<_RecipeManagementTab> createState() => _RecipeManagementTabState();
}

class _RecipeManagementTabState extends State<_RecipeManagementTab> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return const Center(
            child: Text('Please log in to manage recipes'),
          );
        }

        // Get user info from auth state
        final userId = state.user.uid;
        final userProfile = state.userProfile;
        
        // Get market ID from user's managed markets (use first one if available)
        String? marketId;
        if (userProfile?.isMarketOrganizer == true && 
            userProfile!.managedMarketIds.isNotEmpty) {
          marketId = userProfile.managedMarketIds.first;
        }

        return Scaffold(
          body: marketId != null 
              ? _buildRecipesList(marketId!, userId)
              : _buildNoMarketsView(),
          floatingActionButton: marketId != null 
              ? FloatingActionButton.extended(
                  onPressed: () => _showCreateRecipeDialog(marketId!, userId),
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('New Recipe'),
                )
              : null,
        );
      },
    );
  }

  Widget _buildRecipesList(String marketId, String userId) {
    return StreamBuilder<List<Recipe>>(
      stream: RecipeService.getRecipesForMarket(marketId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final recipes = snapshot.data ?? [];

        if (recipes.isEmpty) {
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
                  'Recipe Management',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create and manage recipes featuring your market vendors\' products.',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _showCreateRecipeDialog(marketId, userId),
                  icon: const Icon(Icons.add),
                  label: const Text('Create First Recipe'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple[200]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb, color: Colors.purple[600], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Recipe Ideas',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Seasonal recipes using fresh vendor produce\n'
                        '• Showcase multiple vendors in one recipe\n'
                        '• Create themed collections (holiday, summer, etc.)\n'
                        '• Include preparation tips and vendor stories',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            final recipe = recipes[index];
            return _buildRecipeCard(recipe);
          },
        );
      },
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recipe Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recipe Image
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[200],
                  ),
                  child: recipe.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            recipe.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.restaurant_menu,
                                size: 40,
                                color: Colors.grey[400],
                              );
                            },
                          ),
                        )
                      : Icon(
                          Icons.restaurant_menu,
                          size: 40,
                          color: Colors.grey[400],
                        ),
                ),
                const SizedBox(width: 16),
                // Recipe Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              recipe.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (recipe.isFeatured)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 12,
                                    color: Colors.amber[800],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Featured',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.amber[800],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recipe.description,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Recipe Details Row
                      Row(
                        children: [
                          _buildDetailChip(
                            Icons.schedule,
                            recipe.formattedTotalTime,
                            Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          _buildDetailChip(
                            Icons.people,
                            recipe.formattedServings,
                            Colors.green,
                          ),
                          const SizedBox(width: 8),
                          _buildDetailChip(
                            Icons.bar_chart,
                            recipe.difficultyDisplayName,
                            _getDifficultyColor(recipe.difficulty),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Category and Status Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    recipe.categoryDisplayName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: recipe.isPublic ? Colors.green[100] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        recipe.isPublic ? Icons.public : Icons.lock,
                        size: 12,
                        color: recipe.isPublic ? Colors.green[800] : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        recipe.isPublic ? 'Public' : 'Private',
                        style: TextStyle(
                          fontSize: 12,
                          color: recipe.isPublic ? Colors.green[800] : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Rating
                if (recipe.ratingCount > 0)
                  Row(
                    children: [
                      Icon(
                        Icons.star,
                        size: 16,
                        color: Colors.amber[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        recipe.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Engagement Stats
          if (recipe.likes > 0 || recipe.saves > 0 || recipe.shares > 0)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (recipe.likes > 0) ...[
                    Icon(Icons.favorite, size: 16, color: Colors.red[400]),
                    const SizedBox(width: 4),
                    Text(
                      recipe.likes.toString(),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (recipe.saves > 0) ...[
                    Icon(Icons.bookmark, size: 16, color: Colors.blue[400]),
                    const SizedBox(width: 4),
                    Text(
                      recipe.saves.toString(),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (recipe.shares > 0) ...[
                    Icon(Icons.share, size: 16, color: Colors.green[400]),
                    const SizedBox(width: 4),
                    Text(
                      recipe.shares.toString(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          // Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editRecipe(recipe),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple,
                      side: BorderSide(color: Colors.purple[300]!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _toggleRecipeVisibility(recipe),
                    icon: Icon(
                      recipe.isPublic ? Icons.visibility_off : Icons.visibility,
                      size: 16,
                    ),
                    label: Text(recipe.isPublic ? 'Make Private' : 'Make Public'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: recipe.isPublic ? Colors.grey[600] : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
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

  void _editRecipe(Recipe recipe) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recipe editing coming soon!'),
      ),
    );
  }

  void _toggleRecipeVisibility(Recipe recipe) async {
    try {
      await RecipeService.togglePublic(recipe.id, !recipe.isPublic);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              recipe.isPublic 
                  ? 'Recipe made private' 
                  : 'Recipe made public',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating recipe: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildNoMarketsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.store,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No Markets Found',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You need to be associated with a market to create recipes.',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showCreateRecipeDialog(String marketId, String organizerId) {
    showDialog(
      context: context,
      builder: (context) => _CreateRecipeDialog(
        marketId: marketId,
        organizerId: organizerId,
      ),
    );
  }
}

class _CreateRecipeDialog extends StatefulWidget {
  final String marketId;
  final String organizerId;

  const _CreateRecipeDialog({
    required this.marketId,
    required this.organizerId,
  });

  @override
  State<_CreateRecipeDialog> createState() => _CreateRecipeDialogState();
}

class _CreateRecipeDialogState extends State<_CreateRecipeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prepTimeController = TextEditingController(text: '30');
  final _cookTimeController = TextEditingController(text: '30');
  final _servingsController = TextEditingController(text: '4');

  RecipeCategory _selectedCategory = RecipeCategory.mainCourse;
  DifficultyLevel _selectedDifficulty = DifficultyLevel.medium;
  bool _isPublic = true;
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Recipe'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Recipe Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a recipe title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<RecipeCategory>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: RecipeCategory.values.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(_getCategoryDisplayName(category)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedCategory = value;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<DifficultyLevel>(
                        value: _selectedDifficulty,
                        decoration: const InputDecoration(
                          labelText: 'Difficulty',
                          border: OutlineInputBorder(),
                        ),
                        items: DifficultyLevel.values.map((difficulty) {
                          return DropdownMenuItem(
                            value: difficulty,
                            child: Text(_getDifficultyDisplayName(difficulty)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedDifficulty = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _prepTimeController,
                        decoration: const InputDecoration(
                          labelText: 'Prep Time (min)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final minutes = int.tryParse(value);
                          if (minutes == null || minutes < 1) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _cookTimeController,
                        decoration: const InputDecoration(
                          labelText: 'Cook Time (min)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final minutes = int.tryParse(value);
                          if (minutes == null || minutes < 1) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _servingsController,
                        decoration: const InputDecoration(
                          labelText: 'Servings',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final servings = int.tryParse(value);
                          if (servings == null || servings < 1) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Make Public'),
                  subtitle: const Text('Visible to shoppers'),
                  value: _isPublic,
                  onChanged: (value) {
                    setState(() {
                      _isPublic = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createRecipe,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
          ),
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Create Recipe'),
        ),
      ],
    );
  }

  String _getCategoryDisplayName(RecipeCategory category) {
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

  String _getDifficultyDisplayName(DifficultyLevel difficulty) {
    switch (difficulty) {
      case DifficultyLevel.easy:
        return 'Easy';
      case DifficultyLevel.medium:
        return 'Medium';
      case DifficultyLevel.hard:
        return 'Hard';
    }
  }

  void _createRecipe() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final recipe = Recipe(
        id: '',
        marketId: widget.marketId,
        organizerId: widget.organizerId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        difficulty: _selectedDifficulty,
        prepTimeMinutes: int.parse(_prepTimeController.text),
        cookTimeMinutes: int.parse(_cookTimeController.text),
        servings: int.parse(_servingsController.text),
        isPublic: _isPublic,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await RecipeService.createRecipe(recipe);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipe created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating recipe: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}