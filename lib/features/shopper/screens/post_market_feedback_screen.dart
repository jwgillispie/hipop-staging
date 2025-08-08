import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/models/customer_feedback.dart';
import '../../shared/widgets/common/loading_widget.dart';

/// Screen for collecting customer feedback after market visits
/// This replaces mock customer data with real satisfaction metrics
class PostMarketFeedbackScreen extends StatefulWidget {
  final String marketId;
  final String? marketName;
  final String? eventId;
  final DateTime visitDate;

  const PostMarketFeedbackScreen({
    super.key,
    required this.marketId,
    this.marketName,
    this.eventId,
    required this.visitDate,
  });

  @override
  State<PostMarketFeedbackScreen> createState() => _PostMarketFeedbackScreenState();
}

class _PostMarketFeedbackScreenState extends State<PostMarketFeedbackScreen> {
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
  Duration? _timeSpent;
  bool _isSubmitting = false;

  final List<String> _availableTags = [
    'family-friendly',
    'accessible',
    'great-value',
    'unique-products',
    'friendly-vendors',
    'well-organized',
    'crowded',
    'easy-parking',
    'music-entertainment',
    'food-trucks',
    'pet-friendly',
    'covered-areas',
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
      appBar: AppBar(
        title: Text('Rate Your Market Experience'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isSubmitting
          ? const LoadingWidget(message: 'Submitting your feedback...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMarketHeader(),
                    const SizedBox(height: 24),
                    _buildOverallRating(),
                    const SizedBox(height: 24),
                    _buildCategoryRatings(),
                    const SizedBox(height: 24),
                    _buildPurchaseInfo(),
                    const SizedBox(height: 24),
                    _buildRecommendation(),
                    const SizedBox(height: 24),
                    _buildWrittenReview(),
                    const SizedBox(height: 24),
                    _buildTags(),
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

  Widget _buildMarketHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.marketName ?? 'Farmers Market',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
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
            'Your feedback helps improve the market experience for everyone',
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
          'Overall Experience *',
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
                      : Colors.grey[400],
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
              color: _overallRating > 0 ? Theme.of(context).primaryColor : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryRatings() {
    final categories = [
      ReviewCategory.quality,
      ReviewCategory.variety,
      ReviewCategory.prices,
      ReviewCategory.service,
      ReviewCategory.cleanliness,
      ReviewCategory.atmosphere,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rate Specific Aspects',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        ...categories.map((category) => _buildCategoryRating(category)),
      ],
    );
  }

  Widget _buildCategoryRating(ReviewCategory category) {
    final rating = _categoryRatings[category] ?? 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
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
            category.description,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                  color: starValue <= rating ? Colors.amber : Colors.grey[400],
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
          title: const Text('I made a purchase'),
          subtitle: const Text('Help us understand customer conversion'),
          value: _madeAPurchase,
          onChanged: (value) {
            setState(() {
              _madeAPurchase = value;
              if (!value) {
                _spendAmountController.clear();
              }
            });
          },
          activeColor: Theme.of(context).primaryColor,
        ),
        if (_madeAPurchase) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _spendAmountController,
            decoration: InputDecoration(
              labelText: 'Estimated amount spent (optional)',
              hintText: 'e.g., 25.50',
              prefixText: '\$',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Theme.of(context).primaryColor),
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
          'Recommendation',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('I would recommend this market'),
          subtitle: const Text('Would you tell friends about this market?'),
          value: _wouldRecommend,
          onChanged: (value) {
            setState(() {
              _wouldRecommend = value;
            });
          },
          activeColor: Theme.of(context).primaryColor,
        ),
        const SizedBox(height: 16),
        const Text(
          'Net Promoter Score (0-10)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const Text(
          'How likely are you to recommend this market to others?',
          style: TextStyle(fontSize: 12, color: Colors.grey),
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
                  color: _npsScore == index ? Theme.of(context).primaryColor : Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _npsScore == index ? Theme.of(context).primaryColor : Colors.grey[400]!,
                  ),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: TextStyle(
                      color: _npsScore == index ? Colors.white : Colors.grey[700],
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
            labelText: 'Share your experience',
            hintText: 'What did you like? What could be improved?',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).primaryColor),
            ),
            counterText: '',
          ),
          maxLines: 4,
          maxLength: 500,
        ),
      ],
    );
  }

  Widget _buildTags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tags (Optional)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const Text(
          'Help others know what to expect',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableTags.map((tag) {
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
                  color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? Theme.of(context).primaryColor : Colors.grey[400]!,
                  ),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
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
          'Time Spent (Optional)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const Text(
          'Approximately how long did you spend at the market?',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: [
            _buildTimeOption('15 min', Duration(minutes: 15)),
            _buildTimeOption('30 min', Duration(minutes: 30)),
            _buildTimeOption('1 hour', Duration(hours: 1)),
            _buildTimeOption('2 hours', Duration(hours: 2)),
            _buildTimeOption('3+ hours', Duration(hours: 3)),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeOption(String label, Duration duration) {
    final isSelected = _timeSpent == duration;
    return GestureDetector(
      onTap: () {
        setState(() {
          _timeSpent = duration;
        });
        HapticFeedback.lightImpact();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey[400]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
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
          subtitle: const Text('Your identity will not be associated with this review'),
          value: _isAnonymous,
          onChanged: (value) {
            setState(() {
              _isAnonymous = value;
            });
          },
          activeColor: Theme.of(context).primaryColor,
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _overallRating > 0 ? _submitFeedback : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
        child: const Text(
          'Submit Feedback',
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
        return 'Poor - Not satisfied at all';
      case 2:
        return 'Fair - Below expectations';
      case 3:
        return 'Good - Met expectations';
      case 4:
        return 'Very Good - Exceeded expectations';
      case 5:
        return 'Excellent - Outstanding experience';
      default:
        return 'Please select a rating';
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _submitFeedback() async {
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
        eventId: widget.eventId,
        target: FeedbackTarget.market,
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
        timeSpentAtMarket: _timeSpent,
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
            content: Text('Thank you for your feedback!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting feedback: $e'),
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