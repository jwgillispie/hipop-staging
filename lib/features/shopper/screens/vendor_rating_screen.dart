import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/models/customer_feedback.dart';
import '../../shared/widgets/common/loading_widget.dart';
import '../../../core/theme/hipop_colors.dart';

/// Screen for rating individual vendors after interactions
/// This provides vendor-specific feedback to replace mock customer insights
class VendorRatingScreen extends StatefulWidget {
  final String vendorId;
  final String? vendorName;
  final String? marketId;
  final String? eventId;
  final DateTime visitDate;

  const VendorRatingScreen({
    super.key,
    required this.vendorId,
    this.vendorName,
    this.marketId,
    this.eventId,
    required this.visitDate,
  });

  @override
  State<VendorRatingScreen> createState() => _VendorRatingScreenState();
}

class _VendorRatingScreenState extends State<VendorRatingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reviewController = TextEditingController();
  final _spendAmountController = TextEditingController();
  
  int _overallRating = 0;
  final Map<ReviewCategory, int> _categoryRatings = {};
  bool _isAnonymous = false;
  bool _wouldRecommend = false;
  int? _npsScore;
  bool _madeAPurchase = false;
  final List<String> _selectedTags = [];
  Duration? _timeSpentAtVendor;
  bool _isSubmitting = false;

  final List<String> _vendorSpecificTags = [
    'friendly-service',
    'knowledgeable',
    'great-prices',
    'unique-products',
    'fresh-quality',
    'quick-service',
    'accepts-cards',
    'gives-samples',
    'patient-with-questions',
    'sustainable-practices',
    'local-sourced',
    'creative-offerings',
  ];

  @override
  void dispose() {
    _reviewController.dispose();
    _spendAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        title: const Text('Rate This Vendor'),
        backgroundColor: HiPopColors.shopperAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isSubmitting
          ? const LoadingWidget(message: 'Submitting your rating...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildVendorHeader(),
                    const SizedBox(height: 24),
                    _buildOverallRating(),
                    const SizedBox(height: 24),
                    _buildVendorSpecificRatings(),
                    const SizedBox(height: 24),
                    _buildPurchaseInfo(),
                    const SizedBox(height: 24),
                    _buildRecommendation(),
                    const SizedBox(height: 24),
                    _buildWrittenReview(),
                    const SizedBox(height: 24),
                    _buildVendorTags(),
                    const SizedBox(height: 24),
                    _buildTimeSpent(),
                    const SizedBox(height: 24),
                    _buildPrivacyOptions(),
                    const SizedBox(height: 32),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildVendorHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            HiPopColors.shopperAccent,
            HiPopColors.shopperAccent.withValues(alpha: 0.8)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.store,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.vendorName ?? 'Vendor',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Visited on ${_formatDate(widget.visitDate)}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your feedback helps vendors improve their service',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallRating() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overall Vendor Experience *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (index) {
            final starValue = index + 1;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _overallRating = starValue;
                });
                HapticFeedback.lightImpact();
              },
              child: Container(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  starValue <= _overallRating ? Icons.star : Icons.star_border,
                  color: starValue <= _overallRating 
                      ? Colors.amber 
                      : HiPopColors.darkBorder,
                  size: 36,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _getRatingDescription(_overallRating),
            style: TextStyle(
              fontSize: 14,
              color: _overallRating > 0 ? HiPopColors.shopperAccent : HiPopColors.darkTextSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVendorSpecificRatings() {
    final vendorCategories = [
      ReviewCategory.quality,
      ReviewCategory.variety,
      ReviewCategory.prices,
      ReviewCategory.service,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rate Vendor Aspects',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        ...vendorCategories.map((category) => _buildCategoryRating(category)),
      ],
    );
  }

  Widget _buildCategoryRating(ReviewCategory category) {
    final rating = _categoryRatings[category] ?? 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: HiPopColors.darkBorder!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category.displayName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          Text(
            _getVendorCategoryDescription(category),
            style: TextStyle(fontSize: 12, color: HiPopColors.darkTextSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              final starValue = index + 1;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _categoryRatings[category] = starValue;
                  });
                  HapticFeedback.lightImpact();
                },
                child: Icon(
                  starValue <= rating ? Icons.star : Icons.star_border,
                  color: starValue <= rating ? Colors.amber : HiPopColors.darkBorder,
                  size: 24,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Purchase Information',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('I made a purchase from this vendor'),
          subtitle: const Text('Help us track vendor conversion rates'),
          value: _madeAPurchase,
          onChanged: (value) {
            setState(() {
              _madeAPurchase = value;
              if (!value) {
                _spendAmountController.clear();
              }
            });
          },
          activeColor: HiPopColors.shopperAccent,
        ),
        if (_madeAPurchase) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _spendAmountController,
            decoration: InputDecoration(
              labelText: 'Amount spent (optional)',
              hintText: 'e.g., 25.50',
              prefixText: '\$',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: HiPopColors.shopperAccent),
              ),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                final amount = double.tryParse(value);
                if (amount == null || amount < 0) {
                  return 'Please enter a valid amount';
                }
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildRecommendation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vendor Recommendation',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('I would recommend this vendor'),
          subtitle: const Text('Would you tell others about this vendor?'),
          value: _wouldRecommend,
          onChanged: (value) {
            setState(() {
              _wouldRecommend = value;
            });
          },
          activeColor: HiPopColors.shopperAccent,
        ),
        const SizedBox(height: 16),
        const Text(
          'Likelihood to Recommend (0-10)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const Text(
          'How likely are you to recommend this vendor to friends?',
          style: TextStyle(fontSize: 12, color: HiPopColors.darkTextSecondary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: List.generate(11, (index) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  _npsScore = index;
                });
                HapticFeedback.lightImpact();
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _npsScore == index ? HiPopColors.shopperAccent : HiPopColors.darkSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _npsScore == index ? HiPopColors.shopperAccent : HiPopColors.darkBorder!,
                  ),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: TextStyle(
                      color: _npsScore == index ? Colors.white : HiPopColors.darkTextPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildWrittenReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Written Review (Optional)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _reviewController,
          decoration: InputDecoration(
            labelText: 'Share your vendor experience',
            hintText: 'What made this vendor special? What could be improved?',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: HiPopColors.shopperAccent),
            ),
            counterText: '',
          ),
          maxLines: 4,
          maxLength: 500,
        ),
      ],
    );
  }

  Widget _buildVendorTags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vendor Highlights (Optional)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const Text(
          'What stood out about this vendor?',
          style: TextStyle(fontSize: 12, color: HiPopColors.darkTextSecondary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _vendorSpecificTags.map((tag) {
            final isSelected = _selectedTags.contains(tag);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedTags.remove(tag);
                  } else {
                    _selectedTags.add(tag);
                  }
                });
                HapticFeedback.lightImpact();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? HiPopColors.shopperAccent : HiPopColors.darkSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? HiPopColors.shopperAccent : HiPopColors.darkBorder!,
                  ),
                ),
                child: Text(
                  tag.replaceAll('-', ' '),
                  style: TextStyle(
                    color: isSelected ? Colors.white : HiPopColors.darkTextPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTimeSpent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Time at Vendor (Optional)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const Text(
          'Approximately how long did you spend at this vendor?',
          style: TextStyle(fontSize: 12, color: HiPopColors.darkTextSecondary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: [
            _buildTimeOption('2 min', const Duration(minutes: 2)),
            _buildTimeOption('5 min', const Duration(minutes: 5)),
            _buildTimeOption('10 min', const Duration(minutes: 10)),
            _buildTimeOption('15 min', const Duration(minutes: 15)),
            _buildTimeOption('20+ min', const Duration(minutes: 20)),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeOption(String label, Duration duration) {
    final isSelected = _timeSpentAtVendor == duration;
    return GestureDetector(
      onTap: () {
        setState(() {
          _timeSpentAtVendor = duration;
        });
        HapticFeedback.lightImpact();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? HiPopColors.shopperAccent : HiPopColors.darkSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? HiPopColors.shopperAccent : HiPopColors.darkBorder!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : HiPopColors.darkTextPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Privacy Options',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Submit anonymously'),
          subtitle: const Text('Your identity will not be shared with the vendor'),
          value: _isAnonymous,
          onChanged: (value) {
            setState(() {
              _isAnonymous = value;
            });
          },
          activeColor: HiPopColors.shopperAccent,
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _overallRating > 0 ? _submitRating : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: HiPopColors.shopperAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
        child: const Text(
          'Submit Vendor Rating',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _getRatingDescription(int rating) {
    switch (rating) {
      case 1:
        return 'Poor - Would not return';
      case 2:
        return 'Fair - Below average';
      case 3:
        return 'Good - Average experience';
      case 4:
        return 'Very Good - Above average';
      case 5:
        return 'Excellent - Outstanding vendor';
      default:
        return 'Please select a rating';
    }
  }

  String _getVendorCategoryDescription(ReviewCategory category) {
    switch (category) {
      case ReviewCategory.quality:
        return 'Freshness and quality of products';
      case ReviewCategory.variety:
        return 'Selection and range of offerings';
      case ReviewCategory.prices:
        return 'Value for money and fair pricing';
      case ReviewCategory.service:
        return 'Friendliness and knowledge of staff';
      default:
        return category.description;
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _submitRating() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final sessionId = '${DateTime.now().millisecondsSinceEpoch}_${user?.uid ?? 'anonymous'}';
      
      final feedback = CustomerFeedback(
        id: '', // Firestore will generate this
        userId: _isAnonymous ? null : user?.uid,
        marketId: widget.marketId,
        vendorId: widget.vendorId,
        eventId: widget.eventId,
        target: FeedbackTarget.vendor,
        overallRating: _overallRating,
        categoryRatings: _categoryRatings,
        reviewText: _reviewController.text.isNotEmpty ? _reviewController.text : null,
        isAnonymous: _isAnonymous,
        visitDate: widget.visitDate,
        createdAt: DateTime.now(),
        tags: _selectedTags.isNotEmpty ? _selectedTags : null,
        wouldRecommend: _wouldRecommend,
        npsScore: _npsScore,
        sessionId: sessionId,
        timeSpentAtVendor: _timeSpentAtVendor,
        madeAPurchase: _madeAPurchase,
        estimatedSpendAmount: _spendAmountController.text.isNotEmpty 
            ? double.tryParse(_spendAmountController.text) 
            : null,
      );

      await FirebaseFirestore.instance
          .collection('customer_feedback')
          .add(feedback.toFirestore());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for rating this vendor!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting rating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}