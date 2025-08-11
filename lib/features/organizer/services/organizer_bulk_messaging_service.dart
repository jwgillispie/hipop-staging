import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/message_template.dart';
import '../models/bulk_message.dart';

class OrganizerBulkMessagingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all vendors available for bulk messaging for an organizer
  Future<List<Map<String, dynamic>>> getOrganizerVendors(String organizerId) async {
    try {
      final vendors = <Map<String, dynamic>>[];
      
      // Get organizer's markets first
      final marketsQuery = await _firestore
          .collection('markets')
          .where('organizerId', isEqualTo: organizerId)
          .get();
      
      final marketIds = marketsQuery.docs.map((doc) => doc.id).toList();
      final marketNameMap = <String, String>{};
      
      for (final marketDoc in marketsQuery.docs) {
        marketNameMap[marketDoc.id] = marketDoc.data()['name'] ?? 'Unknown Market';
      }
      
      if (marketIds.isEmpty) {
        debugPrint('No markets found for organizer: $organizerId');
        return vendors;
      }
      
      // Get approved vendor applications for these markets
      final vendorAppsQuery = await _firestore
          .collection('vendor_applications')
          .where('marketId', whereIn: marketIds)
          .where('status', isEqualTo: 'approved')
          .get();
      
      // Get unique vendor IDs
      final vendorIds = vendorAppsQuery.docs
          .map((doc) => doc.data()['vendorId'] as String)
          .toSet()
          .toList();
      
      if (vendorIds.isEmpty) {
        debugPrint('No approved vendors found for organizer markets');
        return vendors;
      }
      
      // Get vendor profiles in batches (Firestore limit is 10 for whereIn)
      final vendorProfiles = <String, Map<String, dynamic>>{};
      for (int i = 0; i < vendorIds.length; i += 10) {
        final batch = vendorIds.sublist(i, i + 10 > vendorIds.length ? vendorIds.length : i + 10);
        final profilesQuery = await _firestore
            .collection('user_profiles')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        
        for (final profileDoc in profilesQuery.docs) {
          final data = profileDoc.data();
          vendorProfiles[profileDoc.id] = data;
        }
      }
      
      // Combine vendor data with application info
      for (final appDoc in vendorAppsQuery.docs) {
        final appData = appDoc.data();
        final vendorId = appData['vendorId'] as String;
        final marketId = appData['marketId'] as String;
        final vendorProfile = vendorProfiles[vendorId];
        
        if (vendorProfile != null) {
          vendors.add({
            'id': vendorId,
            'applicationId': appDoc.id,
            'marketId': marketId,
            'marketName': marketNameMap[marketId],
            'displayName': vendorProfile['displayName'] ?? 'Unknown Vendor',
            'email': vendorProfile['email'] ?? '',
            'businessName': appData['businessName'] ?? vendorProfile['businessName'],
            'category': appData['vendorType'] ?? appData['category'] ?? 'General',
            'phone': vendorProfile['phone'] ?? appData['contactPhone'] ?? '',
            'status': appData['status'],
            'approvedAt': appData['approvedAt'],
            'applicationData': appData,
            'profileData': vendorProfile,
          });
        }
      }
      
      debugPrint('Found ${vendors.length} vendors for bulk messaging');
      return vendors;
      
    } catch (e) {
      debugPrint('Error getting organizer vendors: $e');
      rethrow;
    }
  }

  /// Get message templates for an organizer
  Future<List<MessageTemplate>> getMessageTemplates(String organizerId) async {
    try {
      final templatesQuery = await _firestore
          .collection('message_templates')
          .where('organizerId', isEqualTo: organizerId)
          .orderBy('updatedAt', descending: true)
          .get();
      
      final templates = templatesQuery.docs
          .map((doc) => MessageTemplate.fromFirestore(doc))
          .toList();
      
      debugPrint('Loaded ${templates.length} message templates');
      return templates;
    } catch (e) {
      debugPrint('Error loading message templates: $e');
      rethrow;
    }
  }

  /// Save or update a message template
  Future<void> saveMessageTemplate(MessageTemplate template) async {
    try {
      if (template.id.isEmpty) {
        // Create new template
        await _firestore
            .collection('message_templates')
            .add(template.toFirestore());
        debugPrint('Created new message template: ${template.name}');
      } else {
        // Update existing template
        await _firestore
            .collection('message_templates')
            .doc(template.id)
            .update(template.toFirestore());
        debugPrint('Updated message template: ${template.name}');
      }
    } catch (e) {
      debugPrint('Error saving message template: $e');
      rethrow;
    }
  }

  /// Delete a message template
  Future<void> deleteMessageTemplate(String templateId) async {
    try {
      await _firestore
          .collection('message_templates')
          .doc(templateId)
          .delete();
      debugPrint('Deleted message template: $templateId');
    } catch (e) {
      debugPrint('Error deleting message template: $e');
      rethrow;
    }
  }

  /// Send a bulk message
  Future<void> sendBulkMessage(BulkMessage bulkMessage) async {
    try {
      // Save the bulk message record
      final messageDoc = await _firestore
          .collection('bulk_messages')
          .add(bulkMessage.toFirestore());
      
      final messageId = messageDoc.id;
      
      // Update status to processing
      await messageDoc.update({
        'status': MessageStatus.processing.name,
      });
      
      debugPrint('Created bulk message: $messageId');
      
      // In a real implementation, this would trigger a cloud function
      // to process the message sending asynchronously
      // For now, we'll simulate immediate processing
      await _processBulkMessage(messageId, bulkMessage);
      
    } catch (e) {
      debugPrint('Error sending bulk message: $e');
      rethrow;
    }
  }

  /// Process bulk message (simulate cloud function processing)
  Future<void> _processBulkMessage(String messageId, BulkMessage bulkMessage) async {
    try {
      int successCount = 0;
      int failureCount = 0;
      
      // Get vendor contact information for recipients
      final recipientData = await _getRecipientContactInfo(bulkMessage.recipientIds);
      
      // Simulate message delivery (in real app, integrate with email service)
      for (final recipientId in bulkMessage.recipientIds) {
        final recipient = recipientData[recipientId];
        if (recipient != null && recipient['email'] != null) {
          try {
            // Simulate email sending with variables replaced
            final personalizedContent = _processMessageVariables(
              bulkMessage.content, 
              recipient,
            );
            final personalizedSubject = _processMessageVariables(
              bulkMessage.subject, 
              recipient,
            );
            
            // In real implementation, send actual email here
            debugPrint('Sending message to ${recipient['email']}: $personalizedSubject');
            
            // Create delivery record
            await _createDeliveryRecord(
              messageId,
              recipientId,
              recipient,
              'delivered',
            );
            
            successCount++;
            
            // Simulate processing time
            await Future.delayed(const Duration(milliseconds: 100));
            
          } catch (e) {
            debugPrint('Failed to send message to $recipientId: $e');
            
            // Create failed delivery record
            await _createDeliveryRecord(
              messageId,
              recipientId,
              recipient,
              'failed',
              errorMessage: e.toString(),
            );
            
            failureCount++;
          }
        } else {
          // No email address available
          await _createDeliveryRecord(
            messageId,
            recipientId,
            recipient ?? {},
            'failed',
            errorMessage: 'No email address available',
          );
          failureCount++;
        }
      }
      
      // Update bulk message with final status and statistics
      await _firestore
          .collection('bulk_messages')
          .doc(messageId)
          .update({
        'status': MessageStatus.sent.name,
        'sentAt': FieldValue.serverTimestamp(),
        'deliveryStats': {
          'total': bulkMessage.recipientIds.length,
          'delivered': successCount,
          'failed': failureCount,
          'deliveryRate': bulkMessage.recipientIds.length > 0 
              ? successCount / bulkMessage.recipientIds.length 
              : 0.0,
          'processedAt': FieldValue.serverTimestamp(),
        },
      });
      
      debugPrint('Bulk message processing complete: $successCount delivered, $failureCount failed');
      
    } catch (e) {
      // Mark message as failed
      await _firestore
          .collection('bulk_messages')
          .doc(messageId)
          .update({
        'status': MessageStatus.failed.name,
        'metadata': {
          'error': e.toString(),
          'failedAt': FieldValue.serverTimestamp(),
        },
      });
      
      debugPrint('Bulk message processing failed: $e');
      rethrow;
    }
  }

  /// Get contact information for recipients
  Future<Map<String, Map<String, dynamic>>> _getRecipientContactInfo(List<String> recipientIds) async {
    final recipientData = <String, Map<String, dynamic>>{};
    
    // Get recipient profiles in batches
    for (int i = 0; i < recipientIds.length; i += 10) {
      final batch = recipientIds.sublist(i, i + 10 > recipientIds.length ? recipientIds.length : i + 10);
      final profilesQuery = await _firestore
          .collection('user_profiles')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      
      for (final profileDoc in profilesQuery.docs) {
        recipientData[profileDoc.id] = profileDoc.data();
      }
    }
    
    return recipientData;
  }

  /// Process message variables with recipient data
  String _processMessageVariables(String content, Map<String, dynamic> recipient) {
    String processedContent = content;
    
    // Replace common variables
    processedContent = processedContent.replaceAll(
      '{vendor_name}',
      recipient['displayName'] ?? recipient['businessName'] ?? 'Vendor',
    );
    
    processedContent = processedContent.replaceAll(
      '{market_name}',
      recipient['marketName'] ?? 'the market',
    );
    
    processedContent = processedContent.replaceAll(
      '{current_date}',
      DateTime.now().toString().split(' ')[0],
    );
    
    processedContent = processedContent.replaceAll(
      '{organizer_name}',
      recipient['organizerName'] ?? 'Market Organizer',
    );
    
    return processedContent;
  }

  /// Create individual delivery record
  Future<void> _createDeliveryRecord(
    String bulkMessageId,
    String recipientId,
    Map<String, dynamic> recipient,
    String status, {
    String? errorMessage,
  }) async {
    final delivery = MessageDelivery(
      id: '',
      bulkMessageId: bulkMessageId,
      recipientId: recipientId,
      recipientEmail: recipient['email'] ?? '',
      recipientName: recipient['displayName'] ?? recipient['businessName'] ?? 'Unknown',
      status: status,
      deliveredAt: status == 'delivered' ? DateTime.now() : null,
      errorMessage: errorMessage,
    );
    
    await _firestore
        .collection('message_deliveries')
        .add(delivery.toFirestore());
  }

  /// Get bulk messages for an organizer
  Future<List<BulkMessage>> getBulkMessages(String organizerId) async {
    try {
      final messagesQuery = await _firestore
          .collection('bulk_messages')
          .where('organizerId', isEqualTo: organizerId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      
      final messages = messagesQuery.docs
          .map((doc) => BulkMessage.fromFirestore(doc))
          .toList();
      
      debugPrint('Loaded ${messages.length} bulk messages');
      return messages;
    } catch (e) {
      debugPrint('Error loading bulk messages: $e');
      rethrow;
    }
  }

  /// Get delivery statistics for a bulk message
  Future<List<MessageDelivery>> getMessageDeliveries(String bulkMessageId) async {
    try {
      final deliveriesQuery = await _firestore
          .collection('message_deliveries')
          .where('bulkMessageId', isEqualTo: bulkMessageId)
          .orderBy('recipientName')
          .get();
      
      final deliveries = deliveriesQuery.docs
          .map((doc) => MessageDelivery.fromFirestore(doc))
          .toList();
      
      debugPrint('Loaded ${deliveries.length} message deliveries');
      return deliveries;
    } catch (e) {
      debugPrint('Error loading message deliveries: $e');
      rethrow;
    }
  }

  /// Get communication analytics for an organizer
  Future<Map<String, dynamic>> getCommunicationAnalytics(String organizerId) async {
    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      
      // Get recent bulk messages
      final messagesQuery = await _firestore
          .collection('bulk_messages')
          .where('organizerId', isEqualTo: organizerId)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();
      
      final messages = messagesQuery.docs
          .map((doc) => BulkMessage.fromFirestore(doc))
          .toList();
      
      // Calculate aggregated statistics
      int totalMessages = messages.length;
      int totalRecipients = 0;
      int totalDelivered = 0;
      int totalOpened = 0;
      int totalClicked = 0;
      
      for (final message in messages) {
        totalRecipients += message.totalRecipients;
        totalDelivered += message.deliveredCount;
        totalOpened += message.openedCount;
        totalClicked += message.clickedCount;
      }
      
      final analytics = {
        'period': '30 days',
        'totalMessages': totalMessages,
        'totalRecipients': totalRecipients,
        'totalDelivered': totalDelivered,
        'totalOpened': totalOpened,
        'totalClicked': totalClicked,
        'deliveryRate': totalRecipients > 0 ? totalDelivered / totalRecipients : 0.0,
        'openRate': totalDelivered > 0 ? totalOpened / totalDelivered : 0.0,
        'clickRate': totalOpened > 0 ? totalClicked / totalOpened : 0.0,
        'messagesPerDay': totalMessages / 30,
        'recipientsPerMessage': totalMessages > 0 ? totalRecipients / totalMessages : 0.0,
        'lastCalculated': DateTime.now().toIso8601String(),
      };
      
      debugPrint('Generated communication analytics: ${analytics['totalMessages']} messages');
      return analytics;
      
    } catch (e) {
      debugPrint('Error generating communication analytics: $e');
      rethrow;
    }
  }

  /// Initialize default templates for a new organizer
  Future<void> initializeDefaultTemplates(String organizerId) async {
    try {
      final existingTemplatesQuery = await _firestore
          .collection('message_templates')
          .where('organizerId', isEqualTo: organizerId)
          .limit(1)
          .get();
      
      // Only create default templates if none exist
      if (existingTemplatesQuery.docs.isEmpty) {
        final defaultTemplates = DefaultTemplates.getDefaultTemplates(organizerId);
        
        for (final template in defaultTemplates) {
          await _firestore
              .collection('message_templates')
              .add(template.toFirestore());
        }
        
        debugPrint('Initialized ${defaultTemplates.length} default templates for organizer');
      }
    } catch (e) {
      debugPrint('Error initializing default templates: $e');
      // Don't rethrow - this is not critical
    }
  }

  /// Validate premium access for bulk messaging features
  Future<bool> validatePremiumAccess(String organizerId) async {
    try {
      // This would check the user's subscription status
      // For now, we'll simulate premium access validation
      final userDoc = await _firestore
          .collection('user_profiles')
          .doc(organizerId)
          .get();
      
      if (!userDoc.exists) return false;
      
      final userData = userDoc.data()!;
      final isPremium = userData['isPremium'] as bool? ?? false;
      final userType = userData['userType'] as String? ?? '';
      
      // Check if user has Market Organizer Pro subscription
      if (userType == 'market_organizer' && isPremium) {
        return true;
      }
      
      // Also check the subscription collection for more detailed validation
      final subscriptionQuery = await _firestore
          .collection('user_subscriptions')
          .where('userId', isEqualTo: organizerId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      
      if (subscriptionQuery.docs.isNotEmpty) {
        final subscription = subscriptionQuery.docs.first.data();
        final tier = subscription['tier'] as String?;
        return tier == 'marketOrganizerPro' || tier == 'enterprise';
      }
      
      return false;
    } catch (e) {
      debugPrint('Error validating premium access: $e');
      return false;
    }
  }
}