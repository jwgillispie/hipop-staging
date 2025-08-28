import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/vendor_sales_data.dart';

/// Service for managing vendor sales data
/// 
/// Provides comprehensive sales tracking functionality including:
/// - CRUD operations for sales data
/// - Photo upload and management
/// - Revenue analytics and reporting  
/// - Commission calculations
/// - Export functionality for business reporting
class VendorSalesService {
  static const String _salesCollection = 'vendor_sales';
  static const String _commissionsCollection = 'vendor_commissions';
  static const String _marketFinancialsCollection = 'market_financials';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Create new sales data entry
  Future<String> createSalesData(VendorSalesData salesData) async {
    try {
      final docRef = await _firestore.collection(_salesCollection).add(salesData.toFirestore());
      
      // Update market financials
      await _updateMarketFinancials(salesData);
      
      // Create commission record if applicable
      if (salesData.commissionPaid > 0) {
        await _createCommissionRecord(salesData);
      }
      
      debugPrint('Sales data created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating sales data: $e');
      throw Exception('Failed to create sales data: $e');
    }
  }
  
  /// Update existing sales data
  Future<void> updateSalesData(VendorSalesData salesData) async {
    try {
      await _firestore
          .collection(_salesCollection)
          .doc(salesData.id)
          .update(salesData.toFirestore());
      
      // Update market financials
      await _updateMarketFinancials(salesData);
      
      // Update commission record
      if (salesData.commissionPaid > 0) {
        await _updateCommissionRecord(salesData);
      }
      
      debugPrint('Sales data updated: ${salesData.id}');
    } catch (e) {
      debugPrint('Error updating sales data: $e');
      throw Exception('Failed to update sales data: $e');
    }
  }
  
  /// Get sales data for a specific date
  /// 
  /// If marketId is provided, looks for sales at that specific market.
  /// If marketId is null, looks for any sales on that date.
  /// If venueDetails is provided, looks for sales matching that venue.
  Future<VendorSalesData?> getSalesDataForDate({
    required String vendorId,
    String? marketId,
    required DateTime date,
    VenueDetails? venueDetails,
  }) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      Query query = _firestore
          .collection(_salesCollection)
          .where('vendorId', isEqualTo: vendorId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay));
      
      // Add market filter if specified
      if (marketId != null) {
        query = query.where('marketId', isEqualTo: marketId);
      }
      
      final snapshot = await query.limit(1).get();
      
      if (snapshot.docs.isNotEmpty) {
        // If venue details specified, filter by venue
        if (venueDetails != null) {
          for (final doc in snapshot.docs) {
            final salesData = VendorSalesData.fromFirestore(doc);
            if (_venueMatches(salesData.venueDetails, venueDetails)) {
              return salesData;
            }
          }
          return null; // No matching venue found
        }
        
        return VendorSalesData.fromFirestore(snapshot.docs.first);
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting sales data for date: $e');
      throw Exception('Failed to get sales data: $e');
    }
  }
  
  /// Check if two venue details match (for duplicate detection)
  bool _venueMatches(VenueDetails venue1, VenueDetails venue2) {
    return venue1.type == venue2.type && 
           venue1.name.toLowerCase() == venue2.name.toLowerCase();
  }
  
  /// Get sales data for a date range
  Future<List<VendorSalesData>> getSalesDataForRange({
    required String vendorId,
    String? marketId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      Query query = _firestore
          .collection(_salesCollection)
          .where('vendorId', isEqualTo: vendorId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      
      if (marketId != null) {
        query = query.where('marketId', isEqualTo: marketId);
      }
      
      final snapshot = await query.orderBy('date', descending: true).get();
      
      return snapshot.docs.map((doc) => VendorSalesData.fromFirestore(doc)).toList();
    } catch (e) {
      // Check for Firestore index errors
      final errorString = e.toString();
      if (errorString.contains('index')) {
        // Firestore index required for vendor_sales range query
        debugPrint('Firestore index required: vendor_sales where vendorId=X, date range, orderBy date desc');
        
        // Extract URL if present
        final urlPattern = RegExp(r'https://console\.firebase\.google\.com/[^\s]+');
        final match = urlPattern.firstMatch(errorString);
        if (match != null) {
          debugPrint('Index creation link: ${match.group(0)}');
        }
      }
      
      debugPrint('Error getting sales data for range: $e');
      throw Exception('Failed to get sales data range: $e');
    }
  }
  
  /// Get aggregated sales analytics
  Future<Map<String, dynamic>> getSalesAnalytics({
    required String vendorId,
    String? marketId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final salesData = await getSalesDataForRange(
        vendorId: vendorId,
        marketId: marketId,
        startDate: startDate,
        endDate: endDate,
      );
      
      if (salesData.isEmpty) {
        return _getEmptyAnalytics();
      }
      
      final totalRevenue = salesData.fold(0.0, (total, sale) => total + sale.revenue);
      final totalTransactions = salesData.fold(0, (total, sale) => total + sale.transactions);
      final totalCommissions = salesData.fold(0.0, (total, sale) => total + sale.commissionPaid);
      final totalFees = salesData.fold(0.0, (total, sale) => total + sale.marketFee);
      final netRevenue = totalRevenue - totalCommissions - totalFees;
      
      // Calculate daily averages
      final daysWithSales = salesData.length;
      final avgDailyRevenue = daysWithSales > 0 ? totalRevenue / daysWithSales : 0.0;
      final avgDailyTransactions = daysWithSales > 0 ? totalTransactions / daysWithSales : 0.0;
      
      // Product performance analysis
      final productPerformance = _analyzeProductPerformance(salesData);
      
      // Revenue trends
      final dailyRevenue = salesData.map((sale) => {
        'date': sale.date,
        'revenue': sale.revenue,
        'transactions': sale.transactions,
        'netRevenue': sale.netProfit,
      }).toList();
      
      // Growth calculation
      final growthRate = _calculateGrowthRate(dailyRevenue);
      
      return {
        'totalRevenue': totalRevenue,
        'totalTransactions': totalTransactions,
        'totalCommissions': totalCommissions,
        'totalFees': totalFees,
        'netRevenue': netRevenue,
        'averageDailyRevenue': avgDailyRevenue,
        'averageDailyTransactions': avgDailyTransactions,
        'averageTransactionValue': totalTransactions > 0 ? totalRevenue / totalTransactions : 0.0,
        'profitMargin': totalRevenue > 0 ? (netRevenue / totalRevenue) * 100 : 0.0,
        'daysWithSales': daysWithSales,
        'productPerformance': productPerformance,
        'dailyRevenue': dailyRevenue,
        'revenueGrowth': growthRate,
        'topProducts': _getTopProducts(productPerformance),
        'topMarkets': await _getTopMarketsByRevenue(vendorId, startDate, endDate),
      };
    } catch (e) {
      debugPrint('Error getting sales analytics: $e');
      return _getEmptyAnalytics();
    }
  }
  
  /// Upload sales photos (placeholder - implement when image_picker is available)
  Future<List<String>> uploadSalesPhotos(List<dynamic> images) async {
    try {
      final List<String> downloadUrls = [];
      
      // TODO: Implement when image_picker is available
      // for (final image in images) {
      //   final fileName = 'sales_photos/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      //   final ref = _storage.ref().child(fileName);
      //   
      //   final uploadTask = await ref.putFile(File(image.path));
      //   final downloadUrl = await uploadTask.ref.getDownloadURL();
      //   
      //   downloadUrls.add(downloadUrl);
      // }
      
      debugPrint('Uploaded ${downloadUrls.length} sales photos');
      return downloadUrls;
    } catch (e) {
      debugPrint('Error uploading sales photos: $e');
      throw Exception('Failed to upload photos: $e');
    }
  }
  
  /// Delete sales data
  Future<void> deleteSalesData(String salesId) async {
    try {
      // Get the sales data before deleting to update market financials
      final doc = await _firestore.collection(_salesCollection).doc(salesId).get();
      
      if (doc.exists) {
        final salesData = VendorSalesData.fromFirestore(doc);
        
        // Delete the sales record
        await _firestore.collection(_salesCollection).doc(salesId).delete();
        
        // Update market financials (subtract deleted amounts)
        await _updateMarketFinancials(salesData, isDelete: true);
        
        // Delete associated commission record
        await _deleteCommissionRecord(salesData);
        
        debugPrint('Sales data deleted: $salesId');
      }
    } catch (e) {
      debugPrint('Error deleting sales data: $e');
      throw Exception('Failed to delete sales data: $e');
    }
  }
  
  /// Export sales data to CSV format
  Future<String> exportSalesDataToCsv({
    required String vendorId,
    String? marketId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final salesData = await getSalesDataForRange(
        vendorId: vendorId,
        marketId: marketId,
        startDate: startDate,
        endDate: endDate,
      );
      
      final csv = StringBuffer();
      
      // CSV Header
      csv.writeln('Date,Market ID,Revenue,Transactions,Commission Paid,Market Fee,Net Profit,Products Count,Notes');
      
      // Data rows
      for (final sale in salesData) {
        csv.writeln([
          sale.date.toIso8601String().split('T')[0],
          sale.marketId,
          sale.revenue.toStringAsFixed(2),
          sale.transactions,
          sale.commissionPaid.toStringAsFixed(2),
          sale.marketFee.toStringAsFixed(2),
          sale.netProfit.toStringAsFixed(2),
          sale.products.length,
          sale.notes?.replaceAll(',', ';') ?? '', // Replace commas to avoid CSV issues
        ].join(','));
      }
      
      return csv.toString();
    } catch (e) {
      debugPrint('Error exporting sales data: $e');
      throw Exception('Failed to export sales data: $e');
    }
  }
  
  /// Export product performance to CSV
  Future<String> exportProductPerformanceToCsv({
    required String vendorId,
    String? marketId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final salesData = await getSalesDataForRange(
        vendorId: vendorId,
        marketId: marketId,
        startDate: startDate,
        endDate: endDate,
      );
      
      final productMap = <String, Map<String, dynamic>>{};
      
      // Aggregate product data
      for (final sale in salesData) {
        for (final product in sale.products) {
          final key = '${product.name}_${product.category}';
          
          if (productMap.containsKey(key)) {
            productMap[key]!['totalQuantity'] += product.quantitySold;
            productMap[key]!['totalRevenue'] += product.totalRevenue;
            productMap[key]!['totalCost'] += product.costPrice * product.quantitySold;
          } else {
            productMap[key] = {
              'name': product.name,
              'category': product.category,
              'totalQuantity': product.quantitySold,
              'totalRevenue': product.totalRevenue,
              'totalCost': product.costPrice * product.quantitySold,
              'avgUnitPrice': product.unitPrice,
            };
          }
        }
      }
      
      final csv = StringBuffer();
      
      // CSV Header
      csv.writeln('Product Name,Category,Total Quantity,Total Revenue,Total Cost,Total Profit,Avg Unit Price,Profit Margin %');
      
      // Data rows
      for (final productData in productMap.values) {
        final totalRevenue = productData['totalRevenue'] as double;
        final totalCost = productData['totalCost'] as double;
        final totalProfit = totalRevenue - totalCost;
        final profitMargin = totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0.0;
        
        csv.writeln([
          productData['name'],
          productData['category'],
          productData['totalQuantity'],
          totalRevenue.toStringAsFixed(2),
          totalCost.toStringAsFixed(2),
          totalProfit.toStringAsFixed(2),
          productData['avgUnitPrice'].toStringAsFixed(2),
          profitMargin.toStringAsFixed(2),
        ].join(','));
      }
      
      return csv.toString();
    } catch (e) {
      debugPrint('Error exporting product performance: $e');
      throw Exception('Failed to export product performance: $e');
    }
  }
  
  // Private helper methods
  
  Future<void> _updateMarketFinancials(VendorSalesData salesData, {bool isDelete = false}) async {
    try {
      // Only update market financials if this is a formal market sale
      final marketId = salesData.marketId;
      if (marketId == null || marketId.isEmpty) {
        debugPrint('Skipping market financials update - not a formal market sale');
        return;
      }
      
      final dateKey = salesData.date.toIso8601String().split('T')[0];
      final docId = '${marketId}_$dateKey';
      
      final docRef = _firestore.collection(_marketFinancialsCollection).doc(docId);
      
      if (isDelete) {
        // Subtract deleted amounts
        await docRef.update({
          'totalMarketRevenue': FieldValue.increment(-salesData.revenue),
          'totalCommissionsCollected': FieldValue.increment(-salesData.commissionPaid),
          'totalVendorFees': FieldValue.increment(-salesData.marketFee),
          'totalTransactions': FieldValue.increment(-salesData.transactions),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Add or update amounts
        await docRef.set({
          'marketId': marketId,
          'date': Timestamp.fromDate(salesData.date),
          'totalMarketRevenue': FieldValue.increment(salesData.revenue),
          'totalCommissionsCollected': FieldValue.increment(salesData.commissionPaid),
          'totalVendorFees': FieldValue.increment(salesData.marketFee),
          'totalTransactions': FieldValue.increment(salesData.transactions),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error updating market financials: $e');
      // Don't throw - this is a background operation
    }
  }
  
  Future<void> _createCommissionRecord(VendorSalesData salesData) async {
    try {
      // Only create commission records for formal market sales
      final marketId = salesData.marketId;
      if (marketId == null || marketId.isEmpty) {
        debugPrint('Skipping commission record - not a formal market sale');
        return;
      }
      
      final commissionData = CommissionData(
        id: '',
        vendorId: salesData.vendorId,
        marketId: marketId,
        organizerId: '', // TODO: Get organizer ID from market data
        date: salesData.date,
        vendorRevenue: salesData.revenue,
        commissionRate: salesData.commissionPaid / salesData.revenue * 100,
        commissionAmount: salesData.commissionPaid,
        marketFee: salesData.marketFee,
        processingFee: 0.0,
        status: CommissionStatus.calculated,
      );
      
      await _firestore.collection(_commissionsCollection).add(commissionData.toFirestore());
    } catch (e) {
      debugPrint('Error creating commission record: $e');
      // Don't throw - this is a background operation
    }
  }
  
  Future<void> _updateCommissionRecord(VendorSalesData salesData) async {
    try {
      // Only update commission records for formal market sales
      final marketId = salesData.marketId;
      if (marketId == null || marketId.isEmpty) {
        debugPrint('Skipping commission record update - not a formal market sale');
        return;
      }
      
      // Find existing commission record for this vendor/market/date
      final snapshot = await _firestore
          .collection(_commissionsCollection)
          .where('vendorId', isEqualTo: salesData.vendorId)
          .where('marketId', isEqualTo: marketId)
          .where('date', isEqualTo: Timestamp.fromDate(salesData.date))
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        await doc.reference.update({
          'vendorRevenue': salesData.revenue,
          'commissionRate': salesData.commissionPaid / salesData.revenue * 100,
          'commissionAmount': salesData.commissionPaid,
          'marketFee': salesData.marketFee,
        });
      } else {
        // Create new record if none exists
        await _createCommissionRecord(salesData);
      }
    } catch (e) {
      debugPrint('Error updating commission record: $e');
      // Don't throw - this is a background operation
    }
  }
  
  Future<void> _deleteCommissionRecord(VendorSalesData salesData) async {
    try {
      // Only delete commission records for formal market sales
      final marketId = salesData.marketId;
      if (marketId == null || marketId.isEmpty) {
        debugPrint('Skipping commission record deletion - not a formal market sale');
        return;
      }
      
      final snapshot = await _firestore
          .collection(_commissionsCollection)
          .where('vendorId', isEqualTo: salesData.vendorId)
          .where('marketId', isEqualTo: marketId)
          .where('date', isEqualTo: Timestamp.fromDate(salesData.date))
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.delete();
      }
    } catch (e) {
      debugPrint('Error deleting commission record: $e');
      // Don't throw - this is a background operation
    }
  }
  
  Map<String, dynamic> _getEmptyAnalytics() {
    return {
      'totalRevenue': 0.0,
      'totalTransactions': 0,
      'totalCommissions': 0.0,
      'totalFees': 0.0,
      'netRevenue': 0.0,
      'averageDailyRevenue': 0.0,
      'averageDailyTransactions': 0.0,
      'averageTransactionValue': 0.0,
      'profitMargin': 0.0,
      'daysWithSales': 0,
      'productPerformance': <String, dynamic>{},
      'dailyRevenue': <Map<String, dynamic>>[],
      'revenueGrowth': 0.0,
      'topProducts': <Map<String, dynamic>>[],
      'topMarkets': <Map<String, dynamic>>[],
    };
  }
  
  Map<String, dynamic> _analyzeProductPerformance(List<VendorSalesData> salesData) {
    final productMap = <String, Map<String, dynamic>>{};
    
    for (final sale in salesData) {
      for (final product in sale.products) {
        final key = product.name;
        
        if (productMap.containsKey(key)) {
          productMap[key]!['quantity'] += product.quantitySold;
          productMap[key]!['revenue'] += product.totalRevenue;
          productMap[key]!['profit'] += product.totalProfit;
        } else {
          productMap[key] = {
            'name': product.name,
            'category': product.category,
            'quantity': product.quantitySold,
            'revenue': product.totalRevenue,
            'profit': product.totalProfit,
            'avgPrice': product.unitPrice,
          };
        }
      }
    }
    
    return productMap;
  }
  
  double _calculateGrowthRate(List<Map<String, dynamic>> dailyRevenue) {
    if (dailyRevenue.length < 7) return 0.0;
    
    final recentWeek = dailyRevenue.take(7).fold(0.0, (total, day) => total + (day['revenue'] as double));
    final previousWeek = dailyRevenue.skip(7).take(7).fold(0.0, (total, day) => total + (day['revenue'] as double));
    
    if (previousWeek <= 0) return 0.0;
    
    return ((recentWeek - previousWeek) / previousWeek) * 100;
  }
  
  List<Map<String, dynamic>> _getTopProducts(Map<String, dynamic> productPerformance) {
    final products = productPerformance.values.cast<Map<String, dynamic>>().toList();
    products.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
    return products.take(5).toList();
  }
  
  Future<List<Map<String, dynamic>>> _getTopMarketsByRevenue(
    String vendorId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final salesData = await getSalesDataForRange(
        vendorId: vendorId,
        startDate: startDate,
        endDate: endDate,
      );
      
      final marketMap = <String, double>{};
      
      for (final sale in salesData) {
        // Only include sales with marketId (formal market sales)
        final marketId = sale.marketId;
        if (marketId != null && marketId.isNotEmpty) {
          marketMap[marketId] = (marketMap[marketId] ?? 0.0) + sale.revenue;
        }
      }
      
      final marketList = marketMap.entries
          .map((entry) => {'marketId': entry.key, 'revenue': entry.value})
          .toList();
      
      marketList.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
      
      return marketList.take(3).toList();
    } catch (e) {
      debugPrint('Error getting top markets: $e');
      return [];
    }
  }
  
  /// Get sales analytics broken down by venue type
  Future<Map<String, dynamic>> getSalesAnalyticsByVenueType({
    required String vendorId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final salesData = await getSalesDataForRange(
        vendorId: vendorId,
        startDate: startDate,
        endDate: endDate,
      );
      
      final venueTypeBreakdown = <String, Map<String, dynamic>>{};
      
      for (final sale in salesData) {
        final venueTypeName = sale.venueDetails.type.displayName;
        
        if (venueTypeBreakdown.containsKey(venueTypeName)) {
          venueTypeBreakdown[venueTypeName]!['revenue'] += sale.revenue;
          venueTypeBreakdown[venueTypeName]!['transactions'] += sale.transactions;
          venueTypeBreakdown[venueTypeName]!['count'] += 1;
          venueTypeBreakdown[venueTypeName]!['netProfit'] += sale.netProfit;
        } else {
          venueTypeBreakdown[venueTypeName] = {
            'revenue': sale.revenue,
            'transactions': sale.transactions,
            'count': 1,
            'netProfit': sale.netProfit,
            'type': sale.venueDetails.type.name,
          };
        }
      }
      
      // Calculate additional metrics for each venue type
      for (final data in venueTypeBreakdown.values) {
        final revenue = data['revenue'] as double;
        final transactions = data['transactions'] as int;
        final count = data['count'] as int;
        
        data['averageTransactionValue'] = transactions > 0 ? revenue / transactions : 0.0;
        data['averageRevenuePerEvent'] = count > 0 ? revenue / count : 0.0;
      }
      
      return {
        'venueTypeBreakdown': venueTypeBreakdown,
        'totalVenueTypes': venueTypeBreakdown.length,
        'topVenueType': _getTopVenueType(venueTypeBreakdown),
      };
    } catch (e) {
      debugPrint('Error getting venue type analytics: $e');
      return {
        'venueTypeBreakdown': <String, Map<String, dynamic>>{},
        'totalVenueTypes': 0,
        'topVenueType': null,
      };
    }
  }
  
  Map<String, dynamic>? _getTopVenueType(Map<String, Map<String, dynamic>> breakdown) {
    if (breakdown.isEmpty) return null;
    
    var topEntry = breakdown.entries.first;
    for (final entry in breakdown.entries) {
      if ((entry.value['revenue'] as double) > (topEntry.value['revenue'] as double)) {
        topEntry = entry;
      }
    }
    
    return {
      'name': topEntry.key,
      'revenue': topEntry.value['revenue'],
      'transactions': topEntry.value['transactions'],
      'count': topEntry.value['count'],
    };
  }
}