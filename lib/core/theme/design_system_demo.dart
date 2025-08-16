import 'package:flutter/material.dart';
import '../widgets/hipop_app_bar.dart';
import '../widgets/hipop_button.dart';
import '../widgets/hipop_card.dart';
import 'hipop_colors.dart';
import 'hipop_theme.dart';

/// Design System Demo Screen
/// Showcases the new HiPop color palette and component system
class DesignSystemDemo extends StatefulWidget {
  const DesignSystemDemo({super.key});

  @override
  State<DesignSystemDemo> createState() => _DesignSystemDemoState();
}

class _DesignSystemDemoState extends State<DesignSystemDemo> {
  bool _isDarkMode = false;
  String _selectedRole = 'shopper';

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _isDarkMode ? HiPopTheme.darkTheme : HiPopTheme.lightTheme,
      child: Scaffold(
        backgroundColor: _isDarkMode 
          ? HiPopColors.darkBackground 
          : HiPopColors.backgroundMutedGray.withValues(alpha: 0.1),
        appBar: HiPopAppBar(
          title: 'HiPop Design System',
          useGradient: true,
          actions: [
            IconButton(
              icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: () {
                setState(() {
                  _isDarkMode = !_isDarkMode;
                });
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildColorPaletteSection(),
              const SizedBox(height: 32),
              _buildButtonSection(),
              const SizedBox(height: 32),
              _buildCardSection(),
              const SizedBox(height: 32),
              _buildRoleSpecificSection(),
              const SizedBox(height: 32),
              _buildFormSection(),
              const SizedBox(height: 32),
              _buildNavigationSection(),
            ],
          ),
        ),
        floatingActionButton: HiPopFAB(
          icon: Icons.add,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Floating Action Button Pressed'),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: HiPopColors.primaryDeepSage,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildColorPaletteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Color Palette'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildColorChip('Deep Sage', HiPopColors.primaryDeepSage),
            _buildColorChip('Soft Sage', HiPopColors.secondarySoftSage),
            _buildColorChip('Muted Gray', HiPopColors.backgroundMutedGray),
            _buildColorChip('Warm Gray', HiPopColors.backgroundWarmGray),
            _buildColorChip('Dusty Plum', HiPopColors.accentDustyPlum),
            _buildColorChip('Mauve', HiPopColors.accentMauve),
            _buildColorChip('Dusty Rose', HiPopColors.accentDustyRose),
            _buildColorChip('Soft Pink', HiPopColors.surfaceSoftPink),
            _buildColorChip('Pale Pink', HiPopColors.surfacePalePink),
            _buildColorChip('Premium Gold', HiPopColors.premiumGold),
          ],
        ),
      ],
    );
  }

  Widget _buildColorChip(String label, Color color) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: HiPopColors.getTextColorFor(color).withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: HiPopColors.getTextColorFor(color),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildButtonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Buttons'),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            HiPopButton.primary(
              text: 'Primary Action',
              icon: Icons.shopping_cart,
              onPressed: () {},
            ),
            HiPopButton.accent(
              text: 'Accent CTA',
              icon: Icons.star,
              onPressed: () {},
            ),
            HiPopButton(
              text: 'Secondary',
              type: HiPopButtonType.secondary,
              onPressed: () {},
            ),
            HiPopButton(
              text: 'Success',
              type: HiPopButtonType.success,
              icon: Icons.check_circle,
              onPressed: () {},
            ),
            HiPopButton.danger(
              text: 'Delete',
              icon: Icons.delete,
              onPressed: () {},
            ),
            HiPopButton(
              text: 'Premium',
              type: HiPopButtonType.premium,
              icon: Icons.workspace_premium,
              onPressed: () {},
            ),
            HiPopButton.ghost(
              text: 'Ghost Button',
              onPressed: () {},
            ),
            HiPopButton(
              text: 'Outlined',
              type: HiPopButtonType.primary,
              outlined: true,
              onPressed: () {},
            ),
            HiPopButton(
              text: 'Loading',
              isLoading: true,
              onPressed: null,
            ),
            HiPopButton(
              text: 'Disabled',
              onPressed: null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Cards'),
        Column(
          children: [
            HiPopCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Standard Card',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Beautiful nested widget styling with proper shadows and borders. The soft pink background creates a warm, inviting feel.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      HiPopButton(
                        text: 'Learn More',
                        type: HiPopButtonType.primary,
                        size: HiPopButtonSize.small,
                        onPressed: () {},
                      ),
                      const SizedBox(width: 12),
                      HiPopButton(
                        text: 'Share',
                        type: HiPopButtonType.ghost,
                        size: HiPopButtonSize.small,
                        icon: Icons.share,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            HiPopCard(
              isPremium: true,
              gradient: HiPopColors.premiumGradient,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.workspace_premium,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Premium Feature Card',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Unlock advanced features with HiPop Premium. Get priority placement, analytics, and more.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const MarketCard(
              marketName: 'Farmers Market Downtown',
              location: '123 Main Street, City',
              schedule: 'Saturdays 8AM - 2PM',
              vendorCount: 45,
              rating: 4.8,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleSpecificSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Role-Specific Styling'),
        Row(
          children: [
            _buildRoleChip('Vendor', 'vendor'),
            const SizedBox(width: 8),
            _buildRoleChip('Organizer', 'organizer'),
            const SizedBox(width: 8),
            _buildRoleChip('Shopper', 'shopper'),
          ],
        ),
        const SizedBox(height: 16),
        HiPopCard(
          backgroundColor: HiPopColors.getRoleAccent(
            _selectedRole, 
            isDark: _isDarkMode
          ).withValues(alpha: 0.1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _selectedRole == 'vendor' 
                      ? Icons.store
                      : _selectedRole == 'organizer'
                        ? Icons.event
                        : Icons.shopping_bag,
                    color: HiPopColors.getRoleAccent(_selectedRole, isDark: _isDarkMode),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedRole.substring(0, 1).toUpperCase()}${_selectedRole.substring(1)} Dashboard',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: HiPopColors.getRoleAccent(_selectedRole, isDark: _isDarkMode),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _selectedRole == 'vendor'
                  ? 'Manage your products, track sales, and connect with customers.'
                  : _selectedRole == 'organizer'
                    ? 'Organize markets, manage vendors, and track performance.'
                    : 'Discover local markets, save favorites, and shop fresh.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleChip(String label, String role) {
    final isSelected = _selectedRole == role;
    final color = HiPopColors.getRoleAccent(role, isDark: _isDarkMode);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = role;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildFormSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Form Elements'),
        HiPopCard(
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Market Name',
                  hintText: 'Enter market name',
                  prefixIcon: const Icon(Icons.store),
                  filled: true,
                  fillColor: HiPopColors.surfacePalePink,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe your market',
                  prefixIcon: const Icon(Icons.description),
                  filled: true,
                  fillColor: HiPopColors.surfacePalePink,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: HiPopButton.primary(
                      text: 'Save Changes',
                      icon: Icons.save,
                      onPressed: () {},
                      fullWidth: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: HiPopButton(
                      text: 'Cancel',
                      type: HiPopButtonType.secondary,
                      onPressed: () {},
                      fullWidth: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Navigation Components'),
        Container(
          decoration: BoxDecoration(
            gradient: HiPopColors.navigationGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: HiPopColors.primaryDeepSage.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(Icons.home, 'Home', true),
              _buildNavItem(Icons.explore, 'Explore', false),
              _buildNavItem(Icons.favorite, 'Favorites', false),
              _buildNavItem(Icons.person, 'Profile', false),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HiPopColors.accentMauve,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                'Premium Upgrade',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Unlock all features and get priority support',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              HiPopButton(
                text: 'Upgrade Now',
                type: HiPopButtonType.premium,
                icon: Icons.rocket_launch,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.white : Colors.white70,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}