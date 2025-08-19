import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/market.dart';

/// Service for managing vendor recruitment features
/// Provides optimized queries and real-time updates for markets looking for vendors
class VendorRecruitmentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Get all markets actively looking for vendors
  /// Optimized with compound indexes for performance
  static Stream<List<Market>> getMarketsLookingForVendors({
    int limit = 20,
    DateTime? afterDate,
  }) {
    Query query = _firestore
        .collection('markets')
        .where('isLookingForVendors', isEqualTo: true)
        .where('isActive', isEqualTo: true);
    
    // Filter by event date if provided
    if (afterDate != null) {
      query = query.where('eventDate', isGreaterThan: Timestamp.fromDate(afterDate));
    } else {
      // Default to future events only
      query = query.where('eventDate', isGreaterThan: Timestamp.now());
    }
    
    // Order by urgency (application deadline)
    query = query.orderBy('applicationDeadline').limit(limit);
    
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Market.fromFirestore(doc))
          .where((market) => 
              !market.isApplicationDeadlinePassed &&
              market.hasAvailableSpots)
          .toList();
    });
  }
  
  /// Get markets with urgent deadlines (within 3 days)
  static Future<List<Market>> getUrgentRecruitingMarkets() async {
    try {
      final now = DateTime.now();
      final urgentDeadline = now.add(const Duration(days: 3));
      
      final snapshot = await _firestore
          .collection('markets')
          .where('isLookingForVendors', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .where('applicationDeadline', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .where('applicationDeadline', isLessThanOrEqualTo: Timestamp.fromDate(urgentDeadline))
          .orderBy('applicationDeadline')
          .get();
      
      return snapshot.docs
          .map((doc) => Market.fromFirestore(doc))
          .where((market) => market.hasAvailableSpots)
          .toList();
    } catch (e) {
      // Debug print for Firestore index errors
      print('\n🔴 ERROR in getUrgentRecruitingMarkets:');
      print('Error Type: ${e.runtimeType}');
      print('Error Message: $e');
      
      final errorString = e.toString();
      if (errorString.contains('index')) {
        print('\n⚠️ FIRESTORE INDEX REQUIRED for getUrgentRecruitingMarkets!');
        print('Query: markets where isLookingForVendors=true, isActive=true, applicationDeadline range query');
        print('Full error: $errorString');
        
        // Extract URL if present
        final urlPattern = RegExp(r'https://console\.firebase\.google\.com/[^\s]+');
        final match = urlPattern.firstMatch(errorString);
        if (match != null) {
          print('\n🔗 INDEX CREATION LINK:');
          print(match.group(0));
        }
      }
      rethrow; // Re-throw the error
    }
  }
  
  /// Update vendor spots when a vendor is accepted
  static Future<void> updateVendorSpots(
    String marketId, {
    required int spotsToDeduct,
  }) async {
    final marketRef = _firestore.collection('markets').doc(marketId);
    
    await _firestore.runTransaction((transaction) async {
      final marketDoc = await transaction.get(marketRef);
      
      if (!marketDoc.exists) {
        throw Exception('Market not found');
      }
      
      final currentSpots = marketDoc.data()?['vendorSpotsAvailable'] as int? ?? 0;
      final newSpots = (currentSpots - spotsToDeduct).clamp(0, double.infinity).toInt();
      
      transaction.update(marketRef, {
        'vendorSpotsAvailable': newSpots,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // If no spots left, optionally update isLookingForVendors
      if (newSpots == 0) {
        transaction.update(marketRef, {
          'isLookingForVendors': false,
        });
      }
    });
  }
  
  /// Toggle market recruitment status
  static Future<void> toggleRecruitmentStatus(
    String marketId,
    bool isLookingForVendors,
  ) async {
    await _firestore.collection('markets').doc(marketId).update({
      'isLookingForVendors': isLookingForVendors,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  /// Get markets by location with recruitment filter
  static Future<List<Market>> getNearbyRecruitingMarkets({
    required double latitude,
    required double longitude,
    double radiusInMiles = 25,
  }) async {
    // Calculate bounding box for initial query
    const double milesPerDegree = 69.0;
    final double latDelta = radiusInMiles / milesPerDegree;
    
    // Note: Firestore has limitations on range queries
    // We'll do a broad latitude filter and calculate exact distance in memory
    final snapshot = await _firestore
        .collection('markets')
        .where('isLookingForVendors', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .where('latitude', isGreaterThan: latitude - latDelta)
        .where('latitude', isLessThan: latitude + latDelta)
        .get();
    
    // Filter by actual distance and other criteria
    final markets = snapshot.docs
        .map((doc) => Market.fromFirestore(doc))
        .where((market) {
          // Calculate actual distance
          final distance = _calculateDistance(
            latitude,
            longitude,
            market.latitude,
            market.longitude,
          );
          
          return distance <= radiusInMiles &&
                 !market.isApplicationDeadlinePassed &&
                 market.hasAvailableSpots &&
                 market.eventDate.isAfter(DateTime.now());
        })
        .toList();
    
    // Sort by distance
    markets.sort((a, b) {
      final distA = _calculateDistance(latitude, longitude, a.latitude, a.longitude);
      final distB = _calculateDistance(latitude, longitude, b.latitude, b.longitude);
      return distA.compareTo(distB);
    });
    
    return markets;
  }
  
  /// Calculate distance between two coordinates in miles
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 3959; // Earth's radius in miles
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(_toRadians(lat1)) * Math.cos(_toRadians(lat2)) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2);
    
    final double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return earthRadius * c;
  }
  
  static double _toRadians(double degrees) {
    return degrees * (Math.pi / 180);
  }
  
  /// Track vendor application
  static Future<void> trackVendorApplication({
    required String vendorId,
    required String marketId,
    String? applicationUrl,
  }) async {
    await _firestore.collection('vendor_applications').add({
      'vendorId': vendorId,
      'marketId': marketId,
      'applicationUrl': applicationUrl,
      'appliedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
    
    // Also update vendor's application history
    await _firestore
        .collection('users')
        .doc(vendorId)
        .collection('market_applications')
        .doc(marketId)
        .set({
      'marketId': marketId,
      'appliedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }
  
  /// Get vendor's application history
  static Future<List<Map<String, dynamic>>> getVendorApplications(
    String vendorId,
  ) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(vendorId)
        .collection('market_applications')
        .orderBy('appliedAt', descending: true)
        .get();
    
    return snapshot.docs.map((doc) => {
      'id': doc.id,
      ...doc.data(),
    }).toList();
  }
  
  /// Update market recruitment details
  static Future<void> updateRecruitmentDetails(
    String marketId, {
    String? applicationUrl,
    double? applicationFee,
    double? dailyBoothFee,
    int? vendorSpotsTotal,
    int? vendorSpotsAvailable,
    DateTime? applicationDeadline,
    String? vendorRequirements,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    if (applicationUrl != null) updates['applicationUrl'] = applicationUrl;
    if (applicationFee != null) updates['applicationFee'] = applicationFee;
    if (dailyBoothFee != null) updates['dailyBoothFee'] = dailyBoothFee;
    if (vendorSpotsTotal != null) updates['vendorSpotsTotal'] = vendorSpotsTotal;
    if (vendorSpotsAvailable != null) updates['vendorSpotsAvailable'] = vendorSpotsAvailable;
    if (applicationDeadline != null) {
      updates['applicationDeadline'] = Timestamp.fromDate(applicationDeadline);
    }
    if (vendorRequirements != null) updates['vendorRequirements'] = vendorRequirements;
    
    await _firestore.collection('markets').doc(marketId).update(updates);
  }
  
  /// Get recruitment analytics for a market
  static Future<Map<String, dynamic>> getRecruitmentAnalytics(
    String marketId,
  ) async {
    // Get market data
    final marketDoc = await _firestore.collection('markets').doc(marketId).get();
    if (!marketDoc.exists) {
      throw Exception('Market not found');
    }
    
    final marketData = marketDoc.data()!;
    
    // Get application count
    final applicationsSnapshot = await _firestore
        .collection('vendor_applications')
        .where('marketId', isEqualTo: marketId)
        .get();
    
    final totalApplications = applicationsSnapshot.docs.length;
    final pendingApplications = applicationsSnapshot.docs
        .where((doc) => doc.data()['status'] == 'pending')
        .length;
    final acceptedApplications = applicationsSnapshot.docs
        .where((doc) => doc.data()['status'] == 'accepted')
        .length;
    
    return {
      'totalSpots': marketData['vendorSpotsTotal'] ?? 0,
      'availableSpots': marketData['vendorSpotsAvailable'] ?? 0,
      'totalApplications': totalApplications,
      'pendingApplications': pendingApplications,
      'acceptedApplications': acceptedApplications,
      'conversionRate': totalApplications > 0 
          ? (acceptedApplications / totalApplications * 100).toStringAsFixed(1)
          : '0.0',
      'fillRate': marketData['vendorSpotsTotal'] != null && marketData['vendorSpotsTotal'] > 0
          ? ((marketData['vendorSpotsTotal'] - (marketData['vendorSpotsAvailable'] ?? 0)) / 
             marketData['vendorSpotsTotal'] * 100).toStringAsFixed(1)
          : '0.0',
    };
  }
}

/// Helper class for Math functions
class Math {
  static double sin(double x) => math.sin(x);
  static double cos(double x) => math.cos(x);
  static double sqrt(double x) => math.sqrt(x);
  static double atan2(double y, double x) => math.atan2(y, x);
  static const double pi = math.pi;
}