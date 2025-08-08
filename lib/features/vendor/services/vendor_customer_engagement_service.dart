import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

/// Premium customer engagement service for vendors
/// Handles direct messaging, loyalty programs, feedback collection, and email marketing
class VendorCustomerEngagementService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get direct messages between vendor and shoppers
  static Future<List<Map<String, dynamic>>> getDirectMessages({
    required String vendorId,
    int limit = 50,
  }) async {
    try {
      // In a real implementation, this would query actual messages
      // For demo purposes, generate mock conversations
      final random = Random();
      final customerNames = ['Sarah M.', 'John D.', 'Emily R.', 'Michael B.', 'Lisa K.'];
      
      List<Map<String, dynamic>> messages = [];
      
      for (int i = 0; i < 5; i++) {
        final customer = customerNames[random.nextInt(customerNames.length)];
        final messageCount = random.nextInt(5) + 1;
        
        messages.add({
          'customerId': 'customer_${i + 1}',
          'customerName': customer,
          'lastMessage': _generateSampleMessage(random),
          'timestamp': DateTime.now().subtract(Duration(hours: random.nextInt(48))),
          'unreadCount': random.nextInt(3),
          'conversationStatus': random.nextBool() ? 'active' : 'resolved',
          'messageCount': messageCount,
        });
      }
      
      messages.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
      return messages;
    } catch (e) {
      debugPrint('Error getting direct messages: $e');
      return [];
    }
  }

  /// Send a message to a customer
  static Future<bool> sendMessage({
    required String vendorId,
    required String customerId,
    required String message,
  }) async {
    try {
      // In a real implementation, this would save to Firestore and send push notification
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay
      debugPrint('Message sent to customer $customerId: $message');
      return true;
    } catch (e) {
      debugPrint('Error sending message: $e');
      return false;
    }
  }

  /// Get loyalty program analytics
  static Future<Map<String, dynamic>> getLoyaltyProgramAnalytics({
    required String vendorId,
  }) async {
    try {
      final random = Random();
      
      return {
        'programStats': {
          'totalMembers': random.nextInt(150) + 50,
          'activeMembers': random.nextInt(100) + 30,
          'newMembersThisMonth': random.nextInt(20) + 5,
          'averageVisitsPerMember': random.nextDouble() * 3 + 2,
          'memberRetentionRate': random.nextDouble() * 0.3 + 0.6, // 60-90%
        },
        'tierDistribution': {
          'Bronze': random.nextInt(60) + 20,
          'Silver': random.nextInt(40) + 15,
          'Gold': random.nextInt(20) + 5,
          'Platinum': random.nextInt(10) + 2,
        },
        'rewardsIssued': {
          'thisMonth': random.nextInt(50) + 20,
          'totalValue': random.nextDouble() * 500 + 200,
          'redemptionRate': random.nextDouble() * 0.4 + 0.4, // 40-80%
        },
        'topRewards': [
          {'name': '10% off next purchase', 'timesRedeemed': random.nextInt(30) + 10},
          {'name': 'Free seasonal item', 'timesRedeemed': random.nextInt(25) + 8},
          {'name': '\$5 store credit', 'timesRedeemed': random.nextInt(20) + 5},
        ],
      };
    } catch (e) {
      debugPrint('Error getting loyalty program analytics: $e');
      return {};
    }
  }

  /// Create or update loyalty program settings
  static Future<bool> updateLoyaltyProgram({
    required String vendorId,
    required Map<String, dynamic> programSettings,
  }) async {
    try {
      // In a real implementation, this would save to Firestore
      await _firestore.collection('vendor_loyalty_programs')
          .doc(vendorId)
          .set(programSettings, SetOptions(merge: true));
      
      debugPrint('Loyalty program updated for vendor: $vendorId');
      return true;
    } catch (e) {
      debugPrint('Error updating loyalty program: $e');
      return false;
    }
  }

  /// Get customer feedback and reviews
  static Future<Map<String, dynamic>> getCustomerFeedback({
    required String vendorId,
  }) async {
    try {
      final random = Random();
      
      // Generate mock feedback data
      List<Map<String, dynamic>> reviews = [];
      final feedbackTypes = ['quality', 'service', 'value', 'variety'];
      
      for (int i = 0; i < 8; i++) {
        reviews.add({
          'id': 'review_$i',
          'customerName': 'Customer ${String.fromCharCode(65 + i)}',
          'rating': random.nextInt(3) + 3, // 3-5 stars
          'comment': _generateSampleReview(random),
          'date': DateTime.now().subtract(Duration(days: random.nextInt(30))),
          'category': feedbackTypes[random.nextInt(feedbackTypes.length)],
          'helpful': random.nextInt(10),
        });
      }
      
      // Calculate averages
      final averageRating = reviews.fold(0.0, (sum, review) => sum + review['rating']) / reviews.length;
      
      return {
        'overallRating': averageRating,
        'totalReviews': reviews.length,
        'ratingDistribution': {
          '5': reviews.where((r) => r['rating'] == 5).length,
          '4': reviews.where((r) => r['rating'] == 4).length,
          '3': reviews.where((r) => r['rating'] == 3).length,
          '2': reviews.where((r) => r['rating'] == 2).length,
          '1': reviews.where((r) => r['rating'] == 1).length,
        },
        'recentReviews': reviews.take(5).toList(),
        'feedbackTrends': {
          'quality': random.nextDouble() * 2 + 3,
          'service': random.nextDouble() * 2 + 3,
          'value': random.nextDouble() * 2 + 3,
          'variety': random.nextDouble() * 2 + 3,
        },
        'improvementAreas': _generateImprovementSuggestions(reviews),
      };
    } catch (e) {
      debugPrint('Error getting customer feedback: $e');
      return {};
    }
  }

  /// Get email marketing campaign analytics
  static Future<Map<String, dynamic>> getEmailMarketingStats({
    required String vendorId,
  }) async {
    try {
      final random = Random();
      
      List<Map<String, dynamic>> campaigns = [];
      
      for (int i = 0; i < 4; i++) {
        campaigns.add({
          'id': 'campaign_$i',
          'name': _generateCampaignName(i),
          'sentDate': DateTime.now().subtract(Duration(days: random.nextInt(60))),
          'recipients': random.nextInt(200) + 50,
          'openRate': random.nextDouble() * 0.4 + 0.15, // 15-55%
          'clickRate': random.nextDouble() * 0.15 + 0.05, // 5-20%
          'unsubscribeRate': random.nextDouble() * 0.05 + 0.01, // 1-6%
          'revenue': random.nextDouble() * 300 + 50,
        });
      }
      
      return {
        'totalSubscribers': random.nextInt(300) + 100,
        'growthRate': random.nextDouble() * 0.2 + 0.05, // 5-25% monthly growth
        'averageOpenRate': campaigns.fold(0.0, (sum, campaign) => sum + campaign['openRate']) / campaigns.length,
        'averageClickRate': campaigns.fold(0.0, (sum, campaign) => sum + campaign['clickRate']) / campaigns.length,
        'totalRevenue': campaigns.fold(0.0, (sum, campaign) => sum + campaign['revenue']),
        'recentCampaigns': campaigns,
        'bestPerformingContent': [
          'Seasonal produce announcements',
          'New product launches',
          'Market location updates',
          'Special offers and discounts',
        ],
      };
    } catch (e) {
      debugPrint('Error getting email marketing stats: $e');
      return {};
    }
  }

  /// Create email marketing campaign
  static Future<bool> createEmailCampaign({
    required String vendorId,
    required String subject,
    required String content,
    required List<String> recipients,
  }) async {
    try {
      // In a real implementation, this would integrate with an email service
      await Future.delayed(const Duration(seconds: 1)); // Simulate processing
      debugPrint('Email campaign created: $subject to ${recipients.length} recipients');
      return true;
    } catch (e) {
      debugPrint('Error creating email campaign: $e');
      return false;
    }
  }

  /// Get customer engagement insights
  static Future<Map<String, dynamic>> getEngagementInsights({
    required String vendorId,
  }) async {
    try {
      final random = Random();
      
      return {
        'engagementScore': random.nextDouble() * 40 + 60, // 60-100
        'communicationPreferences': {
          'email': random.nextDouble() * 0.6 + 0.3, // 30-90%
          'app_notifications': random.nextDouble() * 0.5 + 0.4, // 40-90%
          'sms': random.nextDouble() * 0.3 + 0.1, // 10-40%
        },
        'bestEngagementTimes': {
          'email': 'Tuesday 10AM',
          'social_media': 'Weekend mornings',
          'in_person': 'Saturday 11AM-1PM',
        },
        'customerLifecycle': {
          'new': random.nextInt(30) + 10,
          'returning': random.nextInt(50) + 25,
          'loyal': random.nextInt(40) + 15,
          'at_risk': random.nextInt(15) + 5,
        },
        'engagementTrends': _generateEngagementTrends(),
      };
    } catch (e) {
      debugPrint('Error getting engagement insights: $e');
      return {};
    }
  }

  // Helper methods

  static String _generateSampleMessage(Random random) {
    final messages = [
      'Hi! Do you have organic tomatoes this weekend?',
      'What time do you usually arrive at the market?',
      'I loved your honey! Do you have different varieties?',
      'Are your eggs free-range?',
      'Can you save some of those amazing strawberries for me?',
    ];
    return messages[random.nextInt(messages.length)];
  }

  static String _generateSampleReview(Random random) {
    final reviews = [
      'Amazing quality produce! Always fresh and delicious.',
      'Great variety and excellent customer service.',
      'Love supporting this local business. Highly recommend!',
      'Good products, but wish they had more variety.',
      'The best honey I\'ve ever tasted. Will definitely be back!',
      'Friendly staff and reasonable prices.',
    ];
    return reviews[random.nextInt(reviews.length)];
  }

  static String _generateCampaignName(int index) {
    final names = [
      'Weekly Harvest Update',
      'Summer Special Offers',
      'New Market Location',
      'Holiday Season Treats',
    ];
    return names[index % names.length];
  }

  static List<String> _generateImprovementSuggestions(List<Map<String, dynamic>> reviews) {
    return [
      'Consider expanding product variety based on customer requests',
      'Maintain consistent quality standards during peak season',
      'Engage more with customers to build personal connections',
    ];
  }

  static Map<String, double> _generateEngagementTrends() {
    final random = Random();
    return {
      'week1': random.nextDouble() * 20 + 60,
      'week2': random.nextDouble() * 20 + 65,
      'week3': random.nextDouble() * 20 + 70,
      'week4': random.nextDouble() * 20 + 68,
    };
  }
}