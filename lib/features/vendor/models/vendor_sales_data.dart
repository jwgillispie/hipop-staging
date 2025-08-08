import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a vendor's sales data for a specific date
/// 
/// This model captures comprehensive sales information including:
/// - Total revenue and transaction counts
/// - Individual product performance
/// - Commission and fee tracking
/// - Photo uploads for record keeping
class VendorSalesData {
  final String id;
  final String vendorId;
  final String marketId;
  final DateTime date;
  final double revenue;
  final int transactions;
  final List<ProductSaleData> products;
  final double commissionPaid;
  final double marketFee;
  final List<String> photoUrls;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final VendorSalesStatus status;

  const VendorSalesData({
    required this.id,
    required this.vendorId,
    required this.marketId,
    required this.date,
    required this.revenue,
    required this.transactions,
    required this.products,
    required this.commissionPaid,
    required this.marketFee,
    required this.photoUrls,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.status = VendorSalesStatus.draft,
  });

  /// Create from Firestore document
  factory VendorSalesData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return VendorSalesData(
      id: doc.id,
      vendorId: data['vendorId'] ?? '',
      marketId: data['marketId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      revenue: (data['revenue'] ?? 0).toDouble(),
      transactions: data['transactions'] ?? 0,
      products: (data['products'] as List<dynamic>?)
          ?.map((p) => ProductSaleData.fromMap(p as Map<String, dynamic>))
          .toList() ?? [],
      commissionPaid: (data['commissionPaid'] ?? 0).toDouble(),
      marketFee: (data['marketFee'] ?? 0).toDouble(),
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      status: VendorSalesStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => VendorSalesStatus.draft,
      ),
    );
  }

  /// Convert to Firestore document data
  Map<String, dynamic> toFirestore() {
    return {
      'vendorId': vendorId,
      'marketId': marketId,
      'date': Timestamp.fromDate(date),
      'revenue': revenue,
      'transactions': transactions,
      'products': products.map((p) => p.toMap()).toList(),
      'commissionPaid': commissionPaid,
      'marketFee': marketFee,
      'photoUrls': photoUrls,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'status': status.name,
    };
  }

  /// Create a copy with updated fields
  VendorSalesData copyWith({
    String? id,
    String? vendorId,
    String? marketId,
    DateTime? date,
    double? revenue,
    int? transactions,
    List<ProductSaleData>? products,
    double? commissionPaid,
    double? marketFee,
    List<String>? photoUrls,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    VendorSalesStatus? status,
  }) {
    return VendorSalesData(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      marketId: marketId ?? this.marketId,
      date: date ?? this.date,
      revenue: revenue ?? this.revenue,
      transactions: transactions ?? this.transactions,
      products: products ?? this.products,
      commissionPaid: commissionPaid ?? this.commissionPaid,
      marketFee: marketFee ?? this.marketFee,
      photoUrls: photoUrls ?? this.photoUrls,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
    );
  }

  /// Calculate net profit (revenue minus commission and fees)
  double get netProfit => revenue - commissionPaid - marketFee;

  /// Calculate average transaction value
  double get averageTransactionValue => transactions > 0 ? revenue / transactions : 0.0;

  /// Get total units sold across all products
  int get totalUnitsSold => products.fold(0, (total, product) => total + product.quantitySold);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VendorSalesData &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Model representing individual product sales performance
class ProductSaleData {
  final String name;
  final String category;
  final int quantitySold;
  final double unitPrice;
  final double totalRevenue;
  final double costPrice;
  final String? sku;
  final String? description;

  const ProductSaleData({
    required this.name,
    required this.category,
    required this.quantitySold,
    required this.unitPrice,
    required this.totalRevenue,
    required this.costPrice,
    this.sku,
    this.description,
  });

  /// Create from map (for Firestore)
  factory ProductSaleData.fromMap(Map<String, dynamic> map) {
    return ProductSaleData(
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      quantitySold: map['quantitySold'] ?? 0,
      unitPrice: (map['unitPrice'] ?? 0).toDouble(),
      totalRevenue: (map['totalRevenue'] ?? 0).toDouble(),
      costPrice: (map['costPrice'] ?? 0).toDouble(),
      sku: map['sku'],
      description: map['description'],
    );
  }

  /// Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'quantitySold': quantitySold,
      'unitPrice': unitPrice,
      'totalRevenue': totalRevenue,
      'costPrice': costPrice,
      'sku': sku,
      'description': description,
    };
  }

  /// Calculate profit margin percentage
  double get profitMargin {
    if (totalRevenue <= 0) return 0.0;
    final profit = totalRevenue - (costPrice * quantitySold);
    return (profit / totalRevenue) * 100;
  }

  /// Calculate total profit for this product
  double get totalProfit => totalRevenue - (costPrice * quantitySold);

  /// Create a copy with updated fields
  ProductSaleData copyWith({
    String? name,
    String? category,
    int? quantitySold,
    double? unitPrice,
    double? totalRevenue,
    double? costPrice,
    String? sku,
    String? description,
  }) {
    return ProductSaleData(
      name: name ?? this.name,
      category: category ?? this.category,
      quantitySold: quantitySold ?? this.quantitySold,
      unitPrice: unitPrice ?? this.unitPrice,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      costPrice: costPrice ?? this.costPrice,
      sku: sku ?? this.sku,
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductSaleData &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          sku == other.sku;

  @override
  int get hashCode => Object.hash(name, sku);
}

/// Model for tracking commission and fee calculations
class CommissionData {
  final String id;
  final String vendorId;
  final String marketId;
  final String organizerId;
  final DateTime date;
  final double vendorRevenue;
  final double commissionRate;
  final double commissionAmount;
  final double marketFee;
  final double processingFee;
  final CommissionStatus status;
  final DateTime? paidDate;
  final String? transactionId;
  final String? notes;

  const CommissionData({
    required this.id,
    required this.vendorId,
    required this.marketId,
    required this.organizerId,
    required this.date,
    required this.vendorRevenue,
    required this.commissionRate,
    required this.commissionAmount,
    required this.marketFee,
    required this.processingFee,
    this.status = CommissionStatus.pending,
    this.paidDate,
    this.transactionId,
    this.notes,
  });

  /// Create from Firestore document
  factory CommissionData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return CommissionData(
      id: doc.id,
      vendorId: data['vendorId'] ?? '',
      marketId: data['marketId'] ?? '',
      organizerId: data['organizerId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      vendorRevenue: (data['vendorRevenue'] ?? 0).toDouble(),
      commissionRate: (data['commissionRate'] ?? 0).toDouble(),
      commissionAmount: (data['commissionAmount'] ?? 0).toDouble(),
      marketFee: (data['marketFee'] ?? 0).toDouble(),
      processingFee: (data['processingFee'] ?? 0).toDouble(),
      status: CommissionStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => CommissionStatus.pending,
      ),
      paidDate: data['paidDate'] != null ? (data['paidDate'] as Timestamp).toDate() : null,
      transactionId: data['transactionId'],
      notes: data['notes'],
    );
  }

  /// Convert to Firestore document data
  Map<String, dynamic> toFirestore() {
    return {
      'vendorId': vendorId,
      'marketId': marketId,
      'organizerId': organizerId,
      'date': Timestamp.fromDate(date),
      'vendorRevenue': vendorRevenue,
      'commissionRate': commissionRate,
      'commissionAmount': commissionAmount,
      'marketFee': marketFee,
      'processingFee': processingFee,
      'status': status.name,
      'paidDate': paidDate != null ? Timestamp.fromDate(paidDate!) : null,
      'transactionId': transactionId,
      'notes': notes,
    };
  }

  /// Calculate total amount owed to market organizer
  double get totalAmount => commissionAmount + marketFee + processingFee;

  /// Calculate vendor's net earnings
  double get vendorNetEarnings => vendorRevenue - totalAmount;
}

/// Model for market financial data aggregation
class MarketFinancialData {
  final String id;
  final String marketId;
  final String organizerId;
  final DateTime date;
  final int vendorCount;
  final double totalVendorFees;
  final double totalCommissionsCollected;
  final double totalMarketRevenue;
  final double operationalCosts;
  final double netProfit;
  final int totalTransactions;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MarketFinancialData({
    required this.id,
    required this.marketId,
    required this.organizerId,
    required this.date,
    required this.vendorCount,
    required this.totalVendorFees,
    required this.totalCommissionsCollected,
    required this.totalMarketRevenue,
    required this.operationalCosts,
    required this.netProfit,
    required this.totalTransactions,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Firestore document
  factory MarketFinancialData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return MarketFinancialData(
      id: doc.id,
      marketId: data['marketId'] ?? '',
      organizerId: data['organizerId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      vendorCount: data['vendorCount'] ?? 0,
      totalVendorFees: (data['totalVendorFees'] ?? 0).toDouble(),
      totalCommissionsCollected: (data['totalCommissionsCollected'] ?? 0).toDouble(),
      totalMarketRevenue: (data['totalMarketRevenue'] ?? 0).toDouble(),
      operationalCosts: (data['operationalCosts'] ?? 0).toDouble(),
      netProfit: (data['netProfit'] ?? 0).toDouble(),
      totalTransactions: data['totalTransactions'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Convert to Firestore document data
  Map<String, dynamic> toFirestore() {
    return {
      'marketId': marketId,
      'organizerId': organizerId,
      'date': Timestamp.fromDate(date),
      'vendorCount': vendorCount,
      'totalVendorFees': totalVendorFees,
      'totalCommissionsCollected': totalCommissionsCollected,
      'totalMarketRevenue': totalMarketRevenue,
      'operationalCosts': operationalCosts,
      'netProfit': netProfit,
      'totalTransactions': totalTransactions,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Calculate profit margin percentage
  double get profitMarginPercentage {
    if (totalMarketRevenue <= 0) return 0.0;
    return (netProfit / totalMarketRevenue) * 100;
  }

  /// Calculate average revenue per vendor
  double get averageRevenuePerVendor {
    if (vendorCount <= 0) return 0.0;
    return totalMarketRevenue / vendorCount;
  }

  /// Calculate average transaction value
  double get averageTransactionValue {
    if (totalTransactions <= 0) return 0.0;
    return totalMarketRevenue / totalTransactions;
  }
}

/// Status enum for vendor sales data
enum VendorSalesStatus {
  draft,
  submitted,
  approved,
  disputed,
}

extension VendorSalesStatusExtension on VendorSalesStatus {
  String get displayName {
    switch (this) {
      case VendorSalesStatus.draft:
        return 'Draft';
      case VendorSalesStatus.submitted:
        return 'Submitted';
      case VendorSalesStatus.approved:
        return 'Approved';
      case VendorSalesStatus.disputed:
        return 'Disputed';
    }
  }

  /// Get appropriate color for UI display
  String get colorHex {
    switch (this) {
      case VendorSalesStatus.draft:
        return '#9E9E9E'; // Grey
      case VendorSalesStatus.submitted:
        return '#FF9800'; // Orange
      case VendorSalesStatus.approved:
        return '#4CAF50'; // Green
      case VendorSalesStatus.disputed:
        return '#F44336'; // Red
    }
  }
}

/// Status enum for commission tracking
enum CommissionStatus {
  pending,
  calculated,
  paid,
  disputed,
  refunded,
}

extension CommissionStatusExtension on CommissionStatus {
  String get displayName {
    switch (this) {
      case CommissionStatus.pending:
        return 'Pending';
      case CommissionStatus.calculated:
        return 'Calculated';
      case CommissionStatus.paid:
        return 'Paid';
      case CommissionStatus.disputed:
        return 'Disputed';
      case CommissionStatus.refunded:
        return 'Refunded';
    }
  }

  String get colorHex {
    switch (this) {
      case CommissionStatus.pending:
        return '#9E9E9E'; // Grey
      case CommissionStatus.calculated:
        return '#FF9800'; // Orange
      case CommissionStatus.paid:
        return '#4CAF50'; // Green
      case CommissionStatus.disputed:
        return '#F44336'; // Red
      case CommissionStatus.refunded:
        return '#9C27B0'; // Purple
    }
  }
}

/// Revenue breakdown model for detailed analytics
class RevenueBreakdown {
  final Map<String, double> byProduct;
  final Map<String, double> byCategory;
  final Map<String, double> byTimeOfDay;
  final Map<String, double> byMarket;
  final Map<String, int> transactionsByHour;

  const RevenueBreakdown({
    required this.byProduct,
    required this.byCategory,
    required this.byTimeOfDay,
    required this.byMarket,
    required this.transactionsByHour,
  });

  /// Create empty breakdown
  factory RevenueBreakdown.empty() {
    return const RevenueBreakdown(
      byProduct: {},
      byCategory: {},
      byTimeOfDay: {},
      byMarket: {},
      transactionsByHour: {},
    );
  }

  /// Get top performing product
  MapEntry<String, double>? get topProduct {
    if (byProduct.isEmpty) return null;
    return byProduct.entries.reduce((a, b) => a.value > b.value ? a : b);
  }

  /// Get top performing category
  MapEntry<String, double>? get topCategory {
    if (byCategory.isEmpty) return null;
    return byCategory.entries.reduce((a, b) => a.value > b.value ? a : b);
  }

  /// Get peak sales hour
  MapEntry<String, int>? get peakHour {
    if (transactionsByHour.isEmpty) return null;
    return transactionsByHour.entries.reduce((a, b) => a.value > b.value ? a : b);
  }
}