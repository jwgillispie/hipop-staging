import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class MarketAnalytics extends Equatable {
  final String marketId;
  final String organizerId;
  final DateTime date;
  
  // Vendor metrics
  final int totalVendors;
  final int activeVendors;
  final int newVendorApplications;
  final int approvedApplications;
  final int rejectedApplications;
  
  // Event metrics
  final int totalEvents;
  final int publishedEvents;
  final int completedEvents;
  final int upcomingEvents;
  final double averageEventOccupancy;
  
  
  // Favorites metrics
  final int totalMarketFavorites;
  final int totalVendorFavorites;
  final int newMarketFavoritesToday;
  final int newVendorFavoritesToday;
  
  // Engagement metrics
  final int totalViews;
  final int uniqueVisitors;
  final double averageSessionDuration;
  final int totalSearches;
  
  // Revenue metrics (if applicable)
  final double totalRevenue;
  final double averageOrderValue;
  final int totalOrders;
  
  const MarketAnalytics({
    required this.marketId,
    required this.organizerId,
    required this.date,
    this.totalVendors = 0,
    this.activeVendors = 0,
    this.newVendorApplications = 0,
    this.approvedApplications = 0,
    this.rejectedApplications = 0,
    this.totalEvents = 0,
    this.publishedEvents = 0,
    this.completedEvents = 0,
    this.upcomingEvents = 0,
    this.averageEventOccupancy = 0.0,
    this.totalMarketFavorites = 0,
    this.totalVendorFavorites = 0,
    this.newMarketFavoritesToday = 0,
    this.newVendorFavoritesToday = 0,
    this.totalViews = 0,
    this.uniqueVisitors = 0,
    this.averageSessionDuration = 0.0,
    this.totalSearches = 0,
    this.totalRevenue = 0.0,
    this.averageOrderValue = 0.0,
    this.totalOrders = 0,
  });

  factory MarketAnalytics.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return MarketAnalytics(
      marketId: data['marketId'] ?? '',
      organizerId: data['organizerId'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalVendors: data['totalVendors'] ?? 0,
      activeVendors: data['activeVendors'] ?? 0,
      newVendorApplications: data['newVendorApplications'] ?? 0,
      approvedApplications: data['approvedApplications'] ?? 0,
      rejectedApplications: data['rejectedApplications'] ?? 0,
      totalEvents: data['totalEvents'] ?? 0,
      publishedEvents: data['publishedEvents'] ?? 0,
      completedEvents: data['completedEvents'] ?? 0,
      upcomingEvents: data['upcomingEvents'] ?? 0,
      averageEventOccupancy: (data['averageEventOccupancy'] ?? 0.0).toDouble(),
      totalMarketFavorites: data['totalMarketFavorites'] ?? 0,
      totalVendorFavorites: data['totalVendorFavorites'] ?? 0,
      newMarketFavoritesToday: data['newMarketFavoritesToday'] ?? 0,
      newVendorFavoritesToday: data['newVendorFavoritesToday'] ?? 0,
      totalViews: data['totalViews'] ?? 0,
      uniqueVisitors: data['uniqueVisitors'] ?? 0,
      averageSessionDuration: (data['averageSessionDuration'] ?? 0.0).toDouble(),
      totalSearches: data['totalSearches'] ?? 0,
      totalRevenue: (data['totalRevenue'] ?? 0.0).toDouble(),
      averageOrderValue: (data['averageOrderValue'] ?? 0.0).toDouble(),
      totalOrders: data['totalOrders'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'marketId': marketId,
      'organizerId': organizerId,
      'date': Timestamp.fromDate(date),
      'totalVendors': totalVendors,
      'activeVendors': activeVendors,
      'newVendorApplications': newVendorApplications,
      'approvedApplications': approvedApplications,
      'rejectedApplications': rejectedApplications,
      'totalEvents': totalEvents,
      'publishedEvents': publishedEvents,
      'completedEvents': completedEvents,
      'upcomingEvents': upcomingEvents,
      'averageEventOccupancy': averageEventOccupancy,
      'totalMarketFavorites': totalMarketFavorites,
      'totalVendorFavorites': totalVendorFavorites,
      'newMarketFavoritesToday': newMarketFavoritesToday,
      'newVendorFavoritesToday': newVendorFavoritesToday,
      'totalViews': totalViews,
      'uniqueVisitors': uniqueVisitors,
      'averageSessionDuration': averageSessionDuration,
      'totalSearches': totalSearches,
      'totalRevenue': totalRevenue,
      'averageOrderValue': averageOrderValue,
      'totalOrders': totalOrders,
    };
  }

  @override
  List<Object?> get props => [
        marketId,
        organizerId,
        date,
        totalVendors,
        activeVendors,
        newVendorApplications,
        approvedApplications,
        rejectedApplications,
        totalEvents,
        publishedEvents,
        completedEvents,
        upcomingEvents,
        averageEventOccupancy,
        totalMarketFavorites,
        totalVendorFavorites,
        newMarketFavoritesToday,
        newVendorFavoritesToday,
        totalViews,
        uniqueVisitors,
        averageSessionDuration,
        totalSearches,
        totalRevenue,
        averageOrderValue,
        totalOrders,
      ];
}

class AnalyticsSummary extends Equatable {
  final int totalVendors;
  final int totalEvents;
  final double totalRevenue;
  final int totalViews;
  final double growthRate;
  final Map<String, int> vendorApplicationsByStatus;
  final Map<String, int> eventsByStatus;
  final int totalFavorites;
  final Map<String, int> favoritesByType;
  final List<MarketAnalytics> dailyData;

  const AnalyticsSummary({
    this.totalVendors = 0,
    this.totalEvents = 0,
    this.totalRevenue = 0.0,
    this.totalViews = 0,
    this.growthRate = 0.0,
    this.vendorApplicationsByStatus = const {},
    this.eventsByStatus = const {},
    this.totalFavorites = 0,
    this.favoritesByType = const {},
    this.dailyData = const [],
  });

  @override
  List<Object?> get props => [
        totalVendors,
        totalEvents,
        totalRevenue,
        totalViews,
        growthRate,
        vendorApplicationsByStatus,
        eventsByStatus,
        totalFavorites,
        favoritesByType,
        dailyData,
      ];
}

enum AnalyticsTimeRange {
  week,
  month,
  quarter,
  year,
}

extension AnalyticsTimeRangeExtension on AnalyticsTimeRange {
  String get displayName {
    switch (this) {
      case AnalyticsTimeRange.week:
        return '7 Days';
      case AnalyticsTimeRange.month:
        return '30 Days';
      case AnalyticsTimeRange.quarter:
        return '3 Months';
      case AnalyticsTimeRange.year:
        return '1 Year';
    }
  }

  int get days {
    switch (this) {
      case AnalyticsTimeRange.week:
        return 7;
      case AnalyticsTimeRange.month:
        return 30;
      case AnalyticsTimeRange.quarter:
        return 90;
      case AnalyticsTimeRange.year:
        return 365;
    }
  }
}