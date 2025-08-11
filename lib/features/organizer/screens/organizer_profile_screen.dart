import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_state.dart';
import '../../shared/models/user_feedback.dart';
import '../../shared/services/user_feedback_service.dart';

class OrganizerProfileScreen extends StatefulWidget {
  const OrganizerProfileScreen({super.key});

  @override
  State<OrganizerProfileScreen> createState() => _OrganizerProfileScreenState();
}

class _OrganizerProfileScreenState extends State<OrganizerProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organizer Profile'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile header
            const Center(
              child: Column(
                children: [
                  Icon(Icons.person, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text(
                    'Organizer Profile',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Manage your organizer profile and market settings.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Settings sections
            Expanded(
              child: ListView(
                children: [
                  _buildSettingsSection(),
                  const SizedBox(height: 24),
                  _buildFeedbackSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            ListTile(
              leading: const Icon(Icons.store, color: Colors.green),
              title: const Text('Market Management'),
              subtitle: const Text('Manage your markets and events'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Navigate to market management
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Market management coming soon!')),
                );
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.notifications, color: Colors.green),
              title: const Text('Notifications'),
              subtitle: const Text('Manage notification preferences'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Navigate to notifications
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notification settings coming soon!')),
                );
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.analytics, color: Colors.green),
              title: const Text('Analytics'),
              subtitle: const Text('View market and vendor analytics'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Navigate to analytics
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Analytics coming soon!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Help & Support',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showFeedbackDialog,
                icon: const Icon(Icons.feedback),
                label: const Text('Send Feedback'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Help us improve HiPOP by sharing your thoughts, suggestions, or reporting issues.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showFeedbackDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    FeedbackCategory selectedCategory = FeedbackCategory.general;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Feedback'),
        content: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Help us improve HiPOP! Your feedback goes directly to our team.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                
                // Category selection
                const Text('Category:'),
                const SizedBox(height: 8),
                DropdownButtonFormField<FeedbackCategory>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: FeedbackCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(_getCategoryDisplayName(category)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedCategory = value);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Title
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Brief summary of your feedback',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 200,
                ),
                const SizedBox(height: 16),

                // Description
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Please provide details about your feedback',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  maxLength: 2000,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              final description = descriptionController.text.trim();
              
              if (title.isEmpty || description.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in all fields')),
                );
                return;
              }

              Navigator.pop(context);
              _submitFeedback(selectedCategory, title, description);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Feedback'),
          ),
        ],
      ),
    );
  }

  String _getCategoryDisplayName(FeedbackCategory category) {
    switch (category) {
      case FeedbackCategory.bug:
        return 'Bug Report';
      case FeedbackCategory.feature:
        return 'Feature Request';
      case FeedbackCategory.improvement:
        return 'Improvement Suggestion';
      case FeedbackCategory.general:
        return 'General Feedback';
      case FeedbackCategory.tutorial:
        return 'Tutorial Feedback';
      case FeedbackCategory.support:
        return 'Support Request';
    }
  }

  Future<void> _submitFeedback(FeedbackCategory category, String title, String description) async {
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! Authenticated) return;

      await UserFeedbackService.submitFeedback(
        userId: authState.user.uid,
        userType: 'market_organizer',
        userEmail: authState.user.email ?? '',
        userName: authState.user.displayName,
        category: category,
        title: title,
        description: description,
        metadata: {
          'screen': 'organizer_profile',
          'timestamp': DateTime.now().toIso8601String(),
          'appSection': 'organizer_settings',
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback! We\'ll review it soon.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending feedback: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}