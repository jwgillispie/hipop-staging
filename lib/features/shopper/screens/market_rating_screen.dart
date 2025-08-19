import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/models/customer_feedback.dart';
import '../../shared/widgets/common/loading_widget.dart';
import '../../../core/theme/hipop_colors.dart';

/// Screen for rating overall market experience
/// This provides comprehensive market-level feedback for organizers
class MarketRatingScreen extends StatefulWidget {
  final String marketId;
  final String? marketName;
  final String? eventId;
  final DateTime visitDate;

  const MarketRatingScreen({
    super.key,
    required this.marketId,
    this.marketName,
    this.eventId,
    required this.visitDate,
  });

  @override
  State<MarketRatingScreen> createState() => _MarketRatingScreenState();
}

class _MarketRatingScreenState extends State<MarketRatingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reviewController = TextEditingController();
  final _spendAmountController = TextEditingController();
  final _suggestionController = TextEditingController();
  
  int _overallRating = 0;
  final Map<ReviewCategory, int> _categoryRatings = {};
  bool _isAnonymous = false;
  bool _wouldRecommend = false;
  int? _npsScore;
  bool _madeAPurchase = false;
  final List<String> _selectedTags = [];
  Duration? _timeSpentAtMarket;
  int? _vendorsVisited;
  String? _arrivalMethod;
  bool _foundParking = true;
  bool _feltSafe = true;
  bool _wasAccessible = true;
  bool _isSubmitting = false;

  final List<String> _marketTags = [
    'well-organized',
    'good-variety',
    'family-friendly',
    'pet-friendly',
    'accessible',
    'clean-facilities',
    'good-signage',
    'ample-parking',
    'music-entertainment',
    'food-options',
    'covered-areas',
    'restrooms-available',
    'safe-environment',
    'easy-to-navigate',
    'crowded',
    'good-value',
  ];

  final List<String> _arrivalMethods = [
    'Walking',
    'Driving',
    'Cycling',
    'Public Transit',
    'Rideshare/Taxi',
  ];

  @override
  void dispose() {
    _reviewController.dispose();
    _spendAmountController.dispose();
    _suggestionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        title: const Text('Rate Market Experience'),
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
                    _buildMarketHeader(),
                    const SizedBox(height: 24),
                    _buildOverallRating(),
                    const SizedBox(height: 24),
                    _buildMarketSpecificRatings(),
                    const SizedBox(height: 24),
                    _buildVisitDetails(),
                    const SizedBox(height: 24),
                    _buildAccessibilityQuestions(),
                    const SizedBox(height: 24),
                    _buildPurchaseInfo(),
                    const SizedBox(height: 24),
                    _buildRecommendation(),
                    const SizedBox(height: 24),
                    _buildWrittenReview(),
                    const SizedBox(height: 24),
                    _buildImprovementSuggestions(),
                    const SizedBox(height: 24),
                    _buildMarketTags(),
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
              const Icon(
                Icons.location_on,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.marketName ?? 'Farmers Market',
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
            'Market visited on ${_formatDate(widget.visitDate)}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your feedback helps improve the market for everyone',
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
          'Overall Market Experience *',
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

  Widget _buildMarketSpecificRatings() {
    final marketCategories = [
      ReviewCategory.organization,
      ReviewCategory.variety,
      ReviewCategory.atmosphere,
      ReviewCategory.cleanliness,
      ReviewCategory.accessibility,
      ReviewCategory.prices,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rate Market Aspects',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        ...marketCategories.map((category) => _buildCategoryRating(category)),
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
            _getMarketCategoryDescription(category),
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

  Widget _buildVisitDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Visit Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        
        // How they arrived
        const Text(
          'How did you get to the market?',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _arrivalMethods.map((method) {
            final isSelected = _arrivalMethod == method;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _arrivalMethod = method;
                });
                HapticFeedback.lightImpact();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? HiPopColors.shopperAccent : HiPopColors.darkSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? HiPopColors.shopperAccent : HiPopColors.darkBorder!,
                  ),
                ),
                child: Text(
                  method,
                  style: TextStyle(
                    color: isSelected ? Colors.white : HiPopColors.darkTextPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        
        const SizedBox(height: 20),
        
        // Number of vendors visited
        const Text(
          'Approximately how many vendors did you visit?',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((vendorCount) {
            final isSelected = _vendorsVisited == vendorCount;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _vendorsVisited = vendorCount;
                });
                HapticFeedback.lightImpact();
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected ? HiPopColors.shopperAccent : HiPopColors.darkSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? HiPopColors.shopperAccent : HiPopColors.darkBorder!,
                  ),
                ),
                child: Center(
                  child: Text(
                    vendorCount == 10 ? '10+' : '$vendorCount',
                    style: TextStyle(
                      color: isSelected ? Colors.white : HiPopColors.darkTextPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        
        const SizedBox(height: 20),
        
        // Time spent
        const Text(
          'How long did you spend at the market?',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _buildTimeOption('15 min', const Duration(minutes: 15)),
            _buildTimeOption('30 min', const Duration(minutes: 30)),
            _buildTimeOption('1 hour', const Duration(hours: 1)),
            _buildTimeOption('1.5 hours', const Duration(minutes: 90)),
            _buildTimeOption('2 hours', const Duration(hours: 2)),
            _buildTimeOption('2+ hours', const Duration(hours: 3)),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeOption(String label, Duration duration) {
    final isSelected = _timeSpentAtMarket == duration;
    return GestureDetector(
      onTap: () {
        setState(() {
          _timeSpentAtMarket = duration;
        });
        HapticFeedback.lightImpact();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  Widget _buildAccessibilityQuestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Market Experience',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        
        if (_arrivalMethod == 'Driving') ...[
          SwitchListTile(
            title: const Text('I found parking easily'),
            subtitle: const Text('Was parking available and convenient?'),
            value: _foundParking,
            onChanged: (value) {
              setState(() {
                _foundParking = value;
              });
            },
            activeColor: HiPopColors.shopperAccent,
          ),
        ],
        
        SwitchListTile(
          title: const Text('I felt safe at the market'),
          subtitle: const Text('Did you feel secure during your visit?'),
          value: _feltSafe,
          onChanged: (value) {
            setState(() {
              _feltSafe = value;
            });
          },
          activeColor: HiPopColors.shopperAccent,
        ),
        
        SwitchListTile(
          title: const Text('The market was accessible'),
          subtitle: const Text('Easy to navigate with mobility aids, strollers, etc.'),
          value: _wasAccessible,
          onChanged: (value) {
            setState(() {
              _wasAccessible = value;
            });
          },
          activeColor: HiPopColors.shopperAccent,
        ),
      ],
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
          title: const Text('I made purchases at the market'),
          subtitle: const Text('Help us understand market conversion rates'),
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
              labelText: 'Total amount spent (optional)',
              hintText: 'e.g., 45.75',
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
          'Market Recommendation',
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
          activeColor: HiPopColors.shopperAccent,
        ),
        const SizedBox(height: 16),
        const Text(
          'Net Promoter Score (0-10)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const Text(
          'How likely are you to recommend this market to others?',
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
            labelText: 'Share your market experience',
            hintText: 'What did you enjoy? What was the atmosphere like?',
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

  Widget _buildImprovementSuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Suggestions for Improvement (Optional)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _suggestionController,
          decoration: InputDecoration(
            labelText: 'How could this market be improved?',
            hintText: 'Share specific ideas for enhancement',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: HiPopColors.shopperAccent),
            ),
            counterText: '',
          ),
          maxLines: 3,
          maxLength: 300,
        ),
      ],
    );
  }

  Widget _buildMarketTags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Market Characteristics (Optional)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const Text(
          'What best describes this market?',
          style: TextStyle(fontSize: 12, color: HiPopColors.darkTextSecondary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _marketTags.map((tag) {
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
          'Submit Market Rating',
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
        return 'Fair - Below expectations';
      case 3:
        return 'Good - Met expectations';
      case 4:
        return 'Very Good - Exceeded expectations';
      case 5:
        return 'Excellent - Outstanding market';
      default:
        return 'Please select a rating';
    }
  }

  String _getMarketCategoryDescription(ReviewCategory category) {
    switch (category) {
      case ReviewCategory.organization:
        return 'Layout, signage, and overall management';
      case ReviewCategory.variety:
        return 'Diversity of vendors and products';
      case ReviewCategory.atmosphere:
        return 'Overall ambiance and community feel';
      case ReviewCategory.cleanliness:
        return 'Cleanliness of facilities and area';
      case ReviewCategory.accessibility:
        return 'Ease of access and navigation';
      case ReviewCategory.prices:
        return 'Overall value and pricing fairness';
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
      
      // Create base feedback
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
        timeSpentAtMarket: _timeSpentAtMarket,
        madeAPurchase: _madeAPurchase,
        estimatedSpendAmount: _spendAmountController.text.isNotEmpty 
            ? double.tryParse(_spendAmountController.text) 
            : null,
      );

      // Add to Firestore with additional market-specific data
      final feedbackData = feedback.toFirestore();
      feedbackData.addAll({
        'vendorsVisited': _vendorsVisited,
        'arrivalMethod': _arrivalMethod,
        'foundParking': _foundParking,
        'feltSafe': _feltSafe,
        'wasAccessible': _wasAccessible,
        'improvementSuggestion': _suggestionController.text.isNotEmpty 
            ? _suggestionController.text 
            : null,
      });

      await FirebaseFirestore.instance
          .collection('customer_feedback')
          .add(feedbackData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your market feedback!'),
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