import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/organizer_vendor_post.dart';
import '../services/organizer_vendor_post_service.dart';
import '../../shared/widgets/common/loading_widget.dart';
import '../../shared/widgets/common/hipop_text_field.dart';
import '../../market/models/market.dart';
import '../../premium/services/subscription_service.dart';

class CreateVendorPostScreen extends StatefulWidget {
  const CreateVendorPostScreen({super.key});

  @override
  State<CreateVendorPostScreen> createState() => _CreateVendorPostScreenState();
}

class _CreateVendorPostScreenState extends State<CreateVendorPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _boothFeeController = TextEditingController();
  final _commissionController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingMarkets = true;
  List<Market> _markets = [];
  int _remainingPosts = 0;
  String? _selectedMarketId;
  List<String> _selectedCategories = [];
  ExperienceLevel _selectedExperience = ExperienceLevel.beginner;
  ContactMethod _preferredContact = ContactMethod.email;
  PostVisibility _visibility = PostVisibility.public;
  String _urgency = 'medium';
  DateTime? _applicationDeadline;
  DateTime? _startDate;
  DateTime? _endDate;

  final List<String> _availableCategories = [
    'produce', 'baked_goods', 'prepared_foods', 'crafts', 'beverages',
    'health_beauty', 'flowers', 'meat_seafood', 'dairy', 'jewelry',
    'clothing', 'art', 'music', 'other'
  ];

  final List<String> _urgencyLevels = ['low', 'medium', 'high'];

  @override
  void initState() {
    super.initState();
    _loadOrganizerMarkets();
    _loadUserContactInfo();
    _loadRemainingPosts();
  }

  Future<void> _loadRemainingPosts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final remaining = await SubscriptionService.getRemainingVendorPosts(user.uid);
        setState(() => _remainingPosts = remaining);
      } catch (e) {
        debugPrint('Error loading remaining posts: $e');
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _boothFeeController.dispose();
    _commissionController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadOrganizerMarkets() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final marketsQuery = await FirebaseFirestore.instance
          .collection('markets')
          .where('organizerId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .get();

      final markets = marketsQuery.docs
          .map((doc) => Market.fromFirestore(doc))
          .toList();

      setState(() {
        _markets = markets;
        _isLoadingMarkets = false;
        if (markets.isNotEmpty && _selectedMarketId == null) {
          _selectedMarketId = markets.first.id;
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingMarkets = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading markets: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadUserContactInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        _emailController.text = data['email'] ?? user.email ?? '';
        _phoneController.text = data['phone'] ?? '';
      }
    } catch (e) {
      debugPrint('Error loading user contact info: $e');
    }
  }

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMarketId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a market for this post'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check post limits first
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final canCreate = await SubscriptionService.canCreateVendorPost(user.uid);
      if (!canCreate) {
        await _showPostLimitDialog();
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final post = OrganizerVendorPost(
        id: '', // Will be set by Firestore
        organizerId: user.uid,
        marketId: _selectedMarketId!,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        categories: _selectedCategories,
        requirements: VendorRequirements(
          experienceLevel: _selectedExperience,
          applicationDeadline: _applicationDeadline,
          startDate: _startDate,
          endDate: _endDate,
          boothFee: _boothFeeController.text.isNotEmpty
              ? double.tryParse(_boothFeeController.text)
              : null,
          commissionRate: _commissionController.text.isNotEmpty
              ? double.tryParse(_commissionController.text)
              : null,
        ),
        contactInfo: ContactInfo(
          preferredMethod: _preferredContact,
          email: _emailController.text.trim().isNotEmpty
              ? _emailController.text.trim()
              : null,
          phone: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
        ),
        status: PostStatus.active,
        visibility: _visibility,
        analytics: const PostAnalytics(),
        metadata: PostMetadata(
          urgency: _urgency,
          tags: [],
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        expiresAt: _applicationDeadline,
      );

      await OrganizerVendorPostService.createVendorPost(post);

      // Increment post count
      try {
        await SubscriptionService.incrementPostCount(user.uid);
      } catch (e) {
        debugPrint('Error incrementing post count: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vendor post created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/organizer/vendor-posts');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate(String field) async {
    final now = DateTime.now();
    final initialDate = field == 'deadline'
        ? (_applicationDeadline ?? now.add(const Duration(days: 30)))
        : field == 'start'
        ? (_startDate ?? now.add(const Duration(days: 7)))
        : (_endDate ?? now.add(const Duration(days: 60)));

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        switch (field) {
          case 'deadline':
            _applicationDeadline = date;
            break;
          case 'start':
            _startDate = date;
            break;
          case 'end':
            _endDate = date;
            break;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Create Vendor Post'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Remaining Posts Banner
          if (_remainingPosts >= -1) _buildRemainingPostsBanner(),
          
          // Main Content
          Expanded(
            child: _isLoadingMarkets
                ? const LoadingWidget(message: 'Loading your markets...')
                : _markets.isEmpty
                    ? _buildNoMarketsState()
                    : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBasicInfoSection(),
                        const SizedBox(height: 24),
                        _buildMarketSelectionSection(),
                        const SizedBox(height: 24),
                        _buildCategoriesSection(),
                        const SizedBox(height: 24),
                        _buildRequirementsSection(),
                        const SizedBox(height: 24),
                        _buildContactInfoSection(),
                        const SizedBox(height: 24),
                        _buildPostSettingsSection(),
                        const SizedBox(height: 32),
                        _buildCreateButton(),
                      ],
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMarketsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.store_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Active Markets',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You need to have at least one active market before creating vendor posts.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context.go('/organizer/markets/create');
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Market'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            HiPopTextField(
              controller: _titleController,
              labelText: 'Post Title',
              hintText: 'e.g., "Looking for Organic Produce Vendors"',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                if (value.length < 10) {
                  return 'Title must be at least 10 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            HiPopTextField(
              controller: _descriptionController,
              labelText: 'Description',
              hintText: 'Describe what type of vendors you\'re looking for, any specific requirements, and what makes your market attractive...',
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a description';
                }
                if (value.length < 50) {
                  return 'Description must be at least 50 characters';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketSelectionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Market Selection',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedMarketId,
              decoration: const InputDecoration(
                labelText: 'Select Market',
                border: OutlineInputBorder(),
              ),
              items: _markets.map((market) => DropdownMenuItem(
                value: market.id,
                child: Text(market.name),
              )).toList(),
              onChanged: (value) {
                setState(() => _selectedMarketId = value);
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select a market';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vendor Categories',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select the types of vendors you\'re looking for',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableCategories.map((category) => FilterChip(
                label: Text(_formatCategoryName(category)),
                selected: _selectedCategories.contains(category),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedCategories.add(category);
                    } else {
                      _selectedCategories.remove(category);
                    }
                  });
                },
                selectedColor: Colors.deepPurple.withValues(alpha: 0.2),
                checkmarkColor: Colors.deepPurple[700],
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vendor Requirements',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Experience Level
            DropdownButtonFormField<ExperienceLevel>(
              value: _selectedExperience,
              decoration: const InputDecoration(
                labelText: 'Required Experience Level',
                border: OutlineInputBorder(),
              ),
              items: ExperienceLevel.values.map((level) => DropdownMenuItem(
                value: level,
                child: Text(_formatExperienceLevel(level)),
              )).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedExperience = value);
                }
              },
            ),
            
            const SizedBox(height: 16),
            
            // Dates Row
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate('deadline'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Application Deadline',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _applicationDeadline?.toString().split(' ')[0] ?? 'Select Date',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Fees Row
            Row(
              children: [
                Expanded(
                  child: HiPopTextField(
                    controller: _boothFeeController,
                    labelText: 'Booth Fee (\$)',
                    hintText: '0.00',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: HiPopTextField(
                    controller: _commissionController,
                    labelText: 'Commission Rate (%)',
                    hintText: '0.0',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Preferred Contact Method
            DropdownButtonFormField<ContactMethod>(
              value: _preferredContact,
              decoration: const InputDecoration(
                labelText: 'Preferred Contact Method',
                border: OutlineInputBorder(),
              ),
              items: ContactMethod.values.map((method) => DropdownMenuItem(
                value: method,
                child: Text(_formatContactMethod(method)),
              )).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _preferredContact = value);
                }
              },
            ),
            
            const SizedBox(height: 16),
            
            // Contact Fields
            HiPopTextField(
              controller: _emailController,
              labelText: 'Email Address',
              hintText: 'your@email.com',
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (_preferredContact == ContactMethod.email && 
                    (value == null || value.trim().isEmpty)) {
                  return 'Email is required when email is preferred contact method';
                }
                if (value != null && value.isNotEmpty && 
                    !value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            HiPopTextField(
              controller: _phoneController,
              labelText: 'Phone Number',
              hintText: '(555) 123-4567',
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (_preferredContact == ContactMethod.phone && 
                    (value == null || value.trim().isEmpty)) {
                  return 'Phone is required when phone is preferred contact method';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Post Settings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Visibility
            DropdownButtonFormField<PostVisibility>(
              value: _visibility,
              decoration: const InputDecoration(
                labelText: 'Post Visibility',
                border: OutlineInputBorder(),
              ),
              items: PostVisibility.values.map((visibility) => DropdownMenuItem(
                value: visibility,
                child: Text(_formatVisibility(visibility)),
              )).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _visibility = value);
                }
              },
            ),
            
            const SizedBox(height: 16),
            
            // Urgency
            DropdownButtonFormField<String>(
              value: _urgency,
              decoration: const InputDecoration(
                labelText: 'Urgency Level',
                border: OutlineInputBorder(),
              ),
              items: _urgencyLevels.map((urgency) => DropdownMenuItem(
                value: urgency,
                child: Text(_formatUrgency(urgency)),
              )).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _urgency = value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createPost,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Creating Post...'),
                ],
              )
            : const Text(
                'Create Vendor Post',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildRemainingPostsBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _remainingPosts > 0 || _remainingPosts == -1 
            ? Colors.green.shade50 
            : Colors.red.shade50,
        border: Border(
          bottom: BorderSide(
            color: _remainingPosts > 0 || _remainingPosts == -1 
                ? Colors.green.shade200 
                : Colors.red.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _remainingPosts > 0 || _remainingPosts == -1 
                ? Icons.check_circle_outline 
                : Icons.warning_amber_rounded,
            color: _remainingPosts > 0 || _remainingPosts == -1 
                ? Colors.green.shade700 
                : Colors.red.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _remainingPosts == -1 
                  ? 'Unlimited posts available with your Premium subscription'
                  : _remainingPosts > 0
                      ? 'You have $_remainingPosts vendor post${_remainingPosts == 1 ? '' : 's'} remaining this month'
                      : 'Post limit reached. Upgrade to Premium for unlimited posts.',
              style: TextStyle(
                color: _remainingPosts > 0 || _remainingPosts == -1 
                    ? Colors.green.shade700 
                    : Colors.red.shade700,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (_remainingPosts == 0) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                // Navigate to premium upgrade
                // You can add navigation to premium screen here
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: const Text(
                'Upgrade',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatCategoryName(String category) {
    return category.split('_').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  String _formatExperienceLevel(ExperienceLevel level) {
    switch (level) {
      case ExperienceLevel.beginner:
        return 'Beginner (New vendors welcome)';
      case ExperienceLevel.intermediate:
        return 'Intermediate (Some experience preferred)';
      case ExperienceLevel.experienced:
        return 'Experienced (Established vendors)';
      case ExperienceLevel.expert:
        return 'Expert (Highly experienced only)';
    }
  }

  String _formatContactMethod(ContactMethod method) {
    switch (method) {
      case ContactMethod.email:
        return 'Email';
      case ContactMethod.phone:
        return 'Phone';
      case ContactMethod.form:
        return 'Application Form';
    }
  }

  String _formatVisibility(PostVisibility visibility) {
    switch (visibility) {
      case PostVisibility.public:
        return 'Public (All vendors can see)';
      case PostVisibility.premiumOnly:
        return 'Premium Only (Premium vendors only)';
    }
  }

  String _formatUrgency(String urgency) {
    switch (urgency) {
      case 'low':
        return 'Low Priority';
      case 'medium':
        return 'Medium Priority';
      case 'high':
        return 'High Priority (Urgent)';
      default:
        return urgency;
    }
  }

  Future<void> _showPostLimitDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final remaining = await SubscriptionService.getRemainingVendorPosts(user.uid);
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.deepPurple[700]),
            const SizedBox(width: 8),
            const Text('Post Limit Reached'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You\'ve reached your monthly limit of 1 vendor post. Upgrade to Organizer Pro for unlimited posts.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.deepPurple.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Organizer Pro Benefits:',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...([
                    'Unlimited vendor posts',
                    'Advanced analytics dashboard',
                    'Priority vendor matching',
                    'Response management tools',
                  ]).map((benefit) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(Icons.check, size: 16, color: Colors.green[600]),
                        const SizedBox(width: 8),
                        Expanded(child: Text(benefit)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/premium/upgrade?tier=organizer&userId=${user.uid}');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Upgrade to Pro'),
          ),
        ],
      ),
    );
  }
}