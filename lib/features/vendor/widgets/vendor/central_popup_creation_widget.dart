import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/hipop_colors.dart';


class CentralPopupCreationWidget extends StatefulWidget {
  final bool isCompact;
  
  const CentralPopupCreationWidget({
    super.key,
    this.isCompact = false,
  });

  @override
  State<CentralPopupCreationWidget> createState() => _CentralPopupCreationWidgetState();
}

class _CentralPopupCreationWidgetState extends State<CentralPopupCreationWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.add_business,
                  size: 28,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Pop-Up Event',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Choose independent or market-associated',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? HiPopColors.darkTextSecondary 
                              : HiPopColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (!widget.isCompact) ...[
              Column(
                children: [
                  _buildMobileTypeOption(
                    title: 'Independent',
                    subtitle: 'Create a pop-up at any location you choose',
                    icon: Icons.location_on,
                    color: HiPopColors.primaryDeepSage,
                    onTap: () => context.go('/vendor/create-popup?type=independent'),
                  ),
                  const SizedBox(height: 12),
                  _buildMobileTypeOption(
                    title: 'Market-Associated',
                    subtitle: 'Connect with an existing market event',
                    icon: Icons.storefront,
                    color: HiPopColors.accentMauve,
                    isEnabled: true,
                    onTap: () => context.go('/vendor/select-market'),
                  ),
                ],
              ),
            ] else ...[
              // Compact version - single button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showCreatePopupMenu(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Pop-Up'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileTypeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isEnabled = true,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? HiPopColors.darkSurface : HiPopColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled 
              ? color.withValues(alpha: 0.4) 
              : (isDark ? HiPopColors.darkBorder : HiPopColors.lightBorder),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? HiPopColors.darkShadow : HiPopColors.lightShadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isEnabled 
                        ? color.withValues(alpha: isDark ? 0.2 : 0.1) 
                        : (isDark ? HiPopColors.darkSurfaceVariant : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: isEnabled 
                        ? color 
                        : (isDark ? HiPopColors.darkTextDisabled : Colors.grey.shade400),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isEnabled 
                              ? (isDark ? HiPopColors.darkTextPrimary : HiPopColors.lightTextPrimary)
                              : (isDark ? HiPopColors.darkTextDisabled : HiPopColors.lightTextDisabled),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: isEnabled 
                              ? (isDark ? HiPopColors.darkTextSecondary : HiPopColors.lightTextSecondary)
                              : (isDark ? HiPopColors.darkTextDisabled : HiPopColors.lightTextDisabled),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: isEnabled 
                      ? (isDark ? HiPopColors.darkTextTertiary : HiPopColors.lightTextTertiary)
                      : (isDark ? HiPopColors.darkTextDisabled : HiPopColors.lightTextDisabled),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  void _showCreatePopupMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Create New Pop-up',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: _buildBottomSheetOption(
                    context,
                    'Independent',
                    'Create a pop-up at any location you choose',
                    Icons.location_on,
                    HiPopColors.primaryDeepSage,
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/vendor/create-popup?type=independent');
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: _buildBottomSheetOption(
                    context,
                    'Market-Associated',
                    'Connect with an existing market event',
                    Icons.storefront,
                    HiPopColors.accentMauve,
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/vendor/select-market');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheetOption(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color, {
    bool isEnabled = true,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? HiPopColors.darkSurface : HiPopColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled 
              ? color.withValues(alpha: 0.4) 
              : (isDark ? HiPopColors.darkBorder : HiPopColors.lightBorder),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? HiPopColors.darkShadow : HiPopColors.lightShadow,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isEnabled 
                        ? color.withValues(alpha: isDark ? 0.2 : 0.1) 
                        : (isDark ? HiPopColors.darkSurfaceVariant : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: isEnabled 
                        ? color 
                        : (isDark ? HiPopColors.darkTextDisabled : Colors.grey.shade400),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isEnabled 
                              ? (isDark ? HiPopColors.darkTextPrimary : HiPopColors.lightTextPrimary)
                              : (isDark ? HiPopColors.darkTextDisabled : HiPopColors.lightTextDisabled),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: isEnabled 
                              ? (isDark ? HiPopColors.darkTextSecondary : HiPopColors.lightTextSecondary)
                              : (isDark ? HiPopColors.darkTextDisabled : HiPopColors.lightTextDisabled),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: isEnabled 
                      ? (isDark ? HiPopColors.darkTextTertiary : HiPopColors.lightTextTertiary)
                      : (isDark ? HiPopColors.darkTextDisabled : HiPopColors.lightTextDisabled),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}