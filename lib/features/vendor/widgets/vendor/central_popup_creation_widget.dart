import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';


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
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (!widget.isCompact) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildTypeOption(
                      title: 'Independent',
                      subtitle: 'Any location you choose',
                      icon: Icons.location_on,
                      color: Colors.deepOrange,
                      onTap: () => context.go('/vendor/create-popup?type=independent'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTypeOption(
                      title: 'Market-Associated',
                      subtitle: 'Connect with a market',
                      icon: Icons.storefront,
                      color: Colors.orange,
                      isEnabled: true,
                      onTap: () => context.go('/vendor/select-market'),
                    ),
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

  Widget _buildTypeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isEnabled = true,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isEnabled ? color.withValues(alpha: 0.3) : Colors.grey.shade300,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isEnabled ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: isEnabled ? color : Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isEnabled ? Colors.black87 : Colors.grey.shade400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isEnabled ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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
            Row(
              children: [
                Expanded(
                  child: _buildPopupTypeCard(
                    context,
                    'Independent',
                    'Any location',
                    Icons.location_on,
                    Colors.deepOrange,
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/vendor/create-popup?type=independent');
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPopupTypeCard(
                    context,
                    'Market-Associated',
                    'Connect with a market',
                    Icons.storefront,
                    Colors.orange,
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

  Widget _buildPopupTypeCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color, {
    bool isEnabled = true,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isEnabled ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: isEnabled ? color : Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isEnabled ? Colors.black87 : Colors.grey.shade400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isEnabled ? Colors.grey[600] : Colors.grey.shade400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}