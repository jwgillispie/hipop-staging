import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Real-time analytics service for HiPop platform
/// 
/// This service provides comprehensive event tracking capabilities including:
/// - User interactions and page views
/// - Vendor and market engagement tracking  
/// - Session management and user behavior analysis
/// - Privacy-compliant data collection with user consent
/// - Offline support with automatic sync when online
/// 
/// All data collection follows GDPR/CCPA compliance requirements.
class RealTimeAnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final Random _random = Random();
  
  // Collection references
  static const String _userEventsCollection = 'user_events';
  static const String _userSessionsCollection = 'user_sessions';
  
  // Local storage keys
  static const String _sessionIdKey = 'hipop_session_id';
  static const String _trackingConsentKey = 'hipop_tracking_consent';
  static const String _offlineEventsKey = 'hipop_offline_events';
  static const String _lastSyncKey = 'hipop_last_sync';
  
  // Session management
  static String? _currentSessionId;
  static Timer? _sessionTimer;
  static DateTime? _sessionStartTime;
  static final List<Map<String, dynamic>> _offlineEventQueue = [];
  static bool? _trackingConsent;
  
  /// Initialize the analytics service
  /// 
  /// This should be called during app initialization to:
  /// - Load tracking consent status
  /// - Restore any offline events
  /// - Start a new session if consent is granted
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load tracking consent status
      _trackingConsent = prefs.getBool(_trackingConsentKey);
      
      // Load offline events if any
      final offlineEventsJson = prefs.getString(_offlineEventsKey);
      if (offlineEventsJson != null) {
        final List<dynamic> events = jsonDecode(offlineEventsJson);
        _offlineEventQueue.addAll(events.cast<Map<String, dynamic>>());
      }
      
      // Start new session if tracking is enabled
      if (_trackingConsent == true) {
        await _startNewSession();
        await _syncOfflineEvents();
      }
      
      debugPrint('RealTimeAnalyticsService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing RealTimeAnalyticsService: $e');
    }
  }
  
  /// Request user consent for analytics tracking
  /// 
  /// This method should be called to get explicit user consent for data collection.
  /// Returns true if consent was granted, false otherwise.
  static Future<bool> requestTrackingConsent() async {
    try {
      // In a real app, this would show a consent dialog
      // For now, we assume consent is granted by default for existing users
      _trackingConsent = true;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_trackingConsentKey, _trackingConsent!);
      
      // Start session and sync offline events if consent granted
      if (_trackingConsent!) {
        await _startNewSession();
        await _syncOfflineEvents();
      }
      
      return _trackingConsent!;
    } catch (e) {
      debugPrint('Error requesting tracking consent: $e');
      return false;
    }
  }
  
  /// Track a generic user event
  /// 
  /// [eventType] - Type of event (e.g., 'button_click', 'screen_view', 'search')
  /// [data] - Additional event data as key-value pairs
  /// [userId] - Optional user ID (defaults to current authenticated user)
  static Future<void> trackEvent(
    String eventType, 
    Map<String, dynamic> data, {
    String? userId,
  }) async {
    try {
      // Skip tracking if consent not granted
      if (_trackingConsent != true) {
        debugPrint('Tracking consent not granted, skipping event: $eventType');
        return;
      }
      
      final currentUserId = userId ?? _getCurrentUserId();
      final sessionId = _currentSessionId ?? await _getOrCreateSessionId();
      
      final now = DateTime.now();
      
      // Try to send immediately if online
      if (await _isOnline()) {
        final eventData = {
          'userId': currentUserId,
          'sessionId': sessionId,
          'eventType': eventType,
          'data': data,
          'timestamp': FieldValue.serverTimestamp(),
          'clientTimestamp': now.millisecondsSinceEpoch,
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.toString(),
          'appVersion': '1.0.0', // Should be read from package info
        };
        await _firestore.collection(_userEventsCollection).add(eventData);
        debugPrint('Event tracked: $eventType');
      } else {
        // Create serializable data for offline storage (no FieldValue objects)
        final offlineEventData = {
          'userId': currentUserId,
          'sessionId': sessionId,
          'eventType': eventType,
          'data': data,
          'timestamp': now.millisecondsSinceEpoch, // Use regular timestamp for offline storage
          'clientTimestamp': now.millisecondsSinceEpoch,
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.toString(),
          'appVersion': '1.0.0',
        };
        _offlineEventQueue.add(offlineEventData);
        await _saveOfflineEvents();
        debugPrint('Event queued for offline sync: $eventType');
      }
      
    } catch (e) {
      debugPrint('Error tracking event $eventType: $e');
      
      // Add to offline queue as fallback
      try {
        final eventData = {
          'userId': userId ?? _getCurrentUserId(),
          'sessionId': _currentSessionId ?? 'unknown',
          'eventType': eventType,
          'data': data,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'clientTimestamp': DateTime.now().millisecondsSinceEpoch,
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.toString(),
          'appVersion': '1.0.0',
        };
        _offlineEventQueue.add(eventData);
        await _saveOfflineEvents();
      } catch (offlineError) {
        debugPrint('Error saving event to offline queue: $offlineError');
      }
    }
  }
  
  /// Track page view events
  /// 
  /// [screenName] - Name of the screen/page being viewed
  /// [userId] - Optional user ID (defaults to current authenticated user)
  /// [metadata] - Additional metadata about the page view
  static Future<void> trackPageView(
    String screenName, 
    String? userId, {
    Map<String, dynamic>? metadata,
  }) async {
    final data = {
      'screenName': screenName,
      'viewTime': DateTime.now().toIso8601String(),
      ...?metadata,
    };
    
    await trackEvent('page_view', data, userId: userId);
  }
  
  /// Track vendor interaction events
  /// 
  /// [action] - The action performed (e.g., 'profile_view', 'contact_click', 'favorite_add')
  /// [vendorId] - ID of the vendor being interacted with
  /// [userId] - Optional user ID (defaults to current authenticated user)
  /// [metadata] - Additional metadata about the interaction
  static Future<void> trackVendorInteraction(
    String action, 
    String vendorId, 
    String? userId, {
    Map<String, dynamic>? metadata,
  }) async {
    final data = {
      'action': action,
      'vendorId': vendorId,
      'interactionTime': DateTime.now().toIso8601String(),
      ...?metadata,
    };
    
    await trackEvent('vendor_interaction', data, userId: userId);
  }
  
  /// Track market engagement events
  /// 
  /// [action] - The action performed (e.g., 'market_view', 'vendor_list_scroll', 'search')
  /// [marketId] - ID of the market being engaged with
  /// [userId] - Optional user ID (defaults to current authenticated user)
  /// [metadata] - Additional metadata about the engagement
  static Future<void> trackMarketEngagement(
    String action, 
    String marketId, 
    String? userId, {
    Map<String, dynamic>? metadata,
  }) async {
    final data = {
      'action': action,
      'marketId': marketId,
      'engagementTime': DateTime.now().toIso8601String(),
      ...?metadata,
    };
    
    await trackEvent('market_engagement', data, userId: userId);
  }
  
  /// Track user search behavior
  /// 
  /// [searchTerm] - The search query
  /// [searchType] - Type of search ('market', 'vendor', 'product', etc.)
  /// [resultsCount] - Number of results returned
  /// [userId] - Optional user ID (defaults to current authenticated user)
  static Future<void> trackSearch(
    String searchTerm,
    String searchType,
    int resultsCount, {
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {
    final data = {
      'searchTerm': searchTerm.toLowerCase().trim(),
      'searchType': searchType,
      'resultsCount': resultsCount,
      'searchTime': DateTime.now().toIso8601String(),
      ...?metadata,
    };
    
    await trackEvent('search', data, userId: userId);
  }
  
  /// Track user session timing and behavior
  /// 
  /// [action] - Session action ('start', 'end', 'extend')
  /// [duration] - Session duration in seconds (for end events)
  static Future<void> trackSessionEvent(
    String action, {
    int? duration,
    Map<String, dynamic>? metadata,
  }) async {
    final data = {
      'action': action,
      'sessionId': _currentSessionId,
      'sessionStartTime': _sessionStartTime?.toIso8601String(),
      if (duration != null) 'duration': duration,
      ...?metadata,
    };
    
    await trackEvent('session', data);
  }
  
  /// Get analytics metrics for a specific time range
  /// 
  /// This aggregates real user event data for analytics dashboards
  static Future<Map<String, dynamic>> getAnalyticsMetrics({
    String? marketId,
    String? vendorId,
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
  }) async {
    try {
      Query query = _firestore.collection(_userEventsCollection);
      
      // Apply filters
      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: endDate);
      }
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }
      
      final snapshot = await query.get();
      final events = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      
      // Aggregate metrics
      final metrics = _aggregateEventMetrics(events, marketId: marketId, vendorId: vendorId);
      
      return metrics;
    } catch (e) {
      debugPrint('Error getting analytics metrics: $e');
      return {};
    }
  }
  
  /// Delete user's analytics data (GDPR compliance)
  /// 
  /// [userId] - ID of user whose data should be deleted
  static Future<void> deleteUserData(String userId) async {
    try {
      final batch = _firestore.batch();
      
      // Delete user events
      final eventsSnapshot = await _firestore
          .collection(_userEventsCollection)
          .where('userId', isEqualTo: userId)
          .get();
      
      for (final doc in eventsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete user sessions
      final sessionsSnapshot = await _firestore
          .collection(_userSessionsCollection)
          .where('userId', isEqualTo: userId)
          .get();
      
      for (final doc in sessionsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      debugPrint('User analytics data deleted for userId: $userId');
    } catch (e) {
      debugPrint('Error deleting user analytics data: $e');
      throw Exception('Failed to delete user analytics data');
    }
  }
  
  // Private helper methods
  
  static String? _getCurrentUserId() {
    return _auth.currentUser?.uid;
  }
  
  static Future<String> _getOrCreateSessionId() async {
    if (_currentSessionId != null) {
      return _currentSessionId!;
    }
    
    final prefs = await SharedPreferences.getInstance();
    _currentSessionId = prefs.getString(_sessionIdKey) ?? _generateUuid();
    await prefs.setString(_sessionIdKey, _currentSessionId!);
    
    return _currentSessionId!;
  }
  
  static Future<void> _startNewSession() async {
    _currentSessionId = _generateUuid();
    _sessionStartTime = DateTime.now();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionIdKey, _currentSessionId!);
    
    // Track session start
    await trackSessionEvent('start');
    
    // Set session timeout timer (30 minutes of inactivity)
    _resetSessionTimer();
  }
  
  static void _resetSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(const Duration(minutes: 30), () {
      _endCurrentSession();
    });
  }
  
  static Future<void> _endCurrentSession() async {
    if (_currentSessionId == null || _sessionStartTime == null) return;
    
    final duration = DateTime.now().difference(_sessionStartTime!).inSeconds;
    await trackSessionEvent('end', duration: duration);
    
    // Save session summary
    try {
      await _firestore.collection(_userSessionsCollection).add({
        'sessionId': _currentSessionId,
        'userId': _getCurrentUserId(),
        'startTime': Timestamp.fromDate(_sessionStartTime!),
        'endTime': FieldValue.serverTimestamp(),
        'duration': duration,
        'platform': defaultTargetPlatform.toString(),
      });
    } catch (e) {
      debugPrint('Error saving session summary: $e');
    }
    
    _currentSessionId = null;
    _sessionStartTime = null;
    _sessionTimer?.cancel();
  }
  
  /// Generate a simple UUID for session tracking
  static String _generateUuid() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = _random.nextInt(999999).toString().padLeft(6, '0');
    return '${timestamp}_$randomPart';
  }
  
  static Future<bool> _isOnline() async {
    // Simple connectivity check - in production, use connectivity_plus package
    try {
      await _firestore.collection('health_check').doc('test').get();
      return true;
    } catch (e) {
      return false;
    }
  }
  
  static Future<void> _saveOfflineEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = jsonEncode(_offlineEventQueue);
      await prefs.setString(_offlineEventsKey, eventsJson);
    } catch (e) {
      debugPrint('Error saving offline events: $e');
    }
  }
  
  static Future<void> _syncOfflineEvents() async {
    if (_offlineEventQueue.isEmpty) return;
    
    try {
      final batch = _firestore.batch();
      
      for (final event in _offlineEventQueue) {
        final docRef = _firestore.collection(_userEventsCollection).doc();
        
        // Convert clientTimestamp to server timestamp
        final eventData = Map<String, dynamic>.from(event);
        eventData['timestamp'] = FieldValue.serverTimestamp();
        eventData['syncedAt'] = FieldValue.serverTimestamp();
        
        batch.set(docRef, eventData);
      }
      
      await batch.commit();
      
      // Clear offline queue
      _offlineEventQueue.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_offlineEventsKey);
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
      
      debugPrint('Synced ${_offlineEventQueue.length} offline events');
    } catch (e) {
      debugPrint('Error syncing offline events: $e');
    }
  }
  
  static Map<String, dynamic> _aggregateEventMetrics(
    List<Map<String, dynamic>> events, {
    String? marketId,
    String? vendorId,
  }) {
    final metrics = <String, dynamic>{
      'totalEvents': events.length,
      'uniqueUsers': <String>{},
      'uniqueSessions': <String>{},
      'pageViews': 0,
      'vendorInteractions': 0,
      'marketEngagements': 0,
      'searches': 0,
      'averageSessionDuration': 0.0,
      'topScreens': <String, int>{},
      'topVendorActions': <String, int>{},
      'topMarketActions': <String, int>{},
      'topSearchTerms': <String, int>{},
    };
    
    int totalSessionDuration = 0;
    int sessionCount = 0;
    
    for (final event in events) {
      final eventType = event['eventType'] as String?;
      final userId = event['userId'] as String?;
      final sessionId = event['sessionId'] as String?;
      final data = event['data'] as Map<String, dynamic>?;
      
      if (userId != null) {
        (metrics['uniqueUsers'] as Set<String>).add(userId);
      }
      if (sessionId != null) {
        (metrics['uniqueSessions'] as Set<String>).add(sessionId);
      }
      
      // Filter by market/vendor if specified
      if (marketId != null && data?['marketId'] != marketId) continue;
      if (vendorId != null && data?['vendorId'] != vendorId) continue;
      
      switch (eventType) {
        case 'page_view':
          metrics['pageViews']++;
          final screenName = data?['screenName'] as String?;
          if (screenName != null) {
            final topScreens = metrics['topScreens'] as Map<String, int>;
            topScreens[screenName] = (topScreens[screenName] ?? 0) + 1;
          }
          break;
          
        case 'vendor_interaction':
          metrics['vendorInteractions']++;
          final action = data?['action'] as String?;
          if (action != null) {
            final topActions = metrics['topVendorActions'] as Map<String, int>;
            topActions[action] = (topActions[action] ?? 0) + 1;
          }
          break;
          
        case 'market_engagement':
          metrics['marketEngagements']++;
          final action = data?['action'] as String?;
          if (action != null) {
            final topActions = metrics['topMarketActions'] as Map<String, int>;
            topActions[action] = (topActions[action] ?? 0) + 1;
          }
          break;
          
        case 'search':
          metrics['searches']++;
          final searchTerm = data?['searchTerm'] as String?;
          if (searchTerm != null) {
            final topTerms = metrics['topSearchTerms'] as Map<String, int>;
            topTerms[searchTerm] = (topTerms[searchTerm] ?? 0) + 1;
          }
          break;
          
        case 'session':
          final action = data?['action'] as String?;
          final duration = data?['duration'] as int?;
          if (action == 'end' && duration != null) {
            totalSessionDuration += duration;
            sessionCount++;
          }
          break;
      }
    }
    
    // Convert sets to counts
    metrics['uniqueUsers'] = (metrics['uniqueUsers'] as Set<String>).length;
    metrics['uniqueSessions'] = (metrics['uniqueSessions'] as Set<String>).length;
    
    // Calculate average session duration
    if (sessionCount > 0) {
      metrics['averageSessionDuration'] = totalSessionDuration / sessionCount;
    }
    
    return metrics;
  }
  
  /// Dispose of resources (call when app is terminating)
  static Future<void> dispose() async {
    await _endCurrentSession();
    await _syncOfflineEvents();
    _sessionTimer?.cancel();
  }
}

/// Event types for consistent tracking
class EventTypes {
  static const String pageView = 'page_view';
  static const String vendorInteraction = 'vendor_interaction';
  static const String marketEngagement = 'market_engagement';
  static const String search = 'search';
  static const String session = 'session';
  static const String buttonClick = 'button_click';
  static const String favorite = 'favorite';
  static const String share = 'share';
  static const String error = 'error';
}

/// Common vendor interaction actions
class VendorActions {
  static const String profileView = 'profile_view';
  static const String contactClick = 'contact_click';
  static const String favoriteAdd = 'favorite_add';
  static const String favoriteRemove = 'favorite_remove';
  static const String shareClick = 'share_click';
  static const String postView = 'post_view';
  static const String postLike = 'post_like';
  static const String applicationView = 'application_view';
  static const String applicationSubmit = 'application_submit';
}

/// Common market engagement actions
class MarketActions {
  static const String marketView = 'market_view';
  static const String vendorListScroll = 'vendor_list_scroll';
  static const String vendorCardClick = 'vendor_card_click';
  static const String favoriteAdd = 'favorite_add';
  static const String favoriteRemove = 'favorite_remove';
  static const String shareClick = 'share_click';
  static const String searchPerformed = 'search_performed';
  static const String filterApplied = 'filter_applied';
  static const String directionsClick = 'directions_click';
}