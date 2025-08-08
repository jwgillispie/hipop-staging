import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class VendorMarket extends Equatable {
  final String id;
  final String vendorId;
  final String vendorName; // Vendor display name
  final String marketId;
  final List<String> schedule; // ["saturday", "sunday"]
  final String? boothNumber;
  final bool isActive;
  final bool isApproved; // For manual verification
  final DateTime joinedDate;

  const VendorMarket({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.marketId,
    this.schedule = const [],
    this.boothNumber,
    this.isActive = true,
    this.isApproved = false,
    required this.joinedDate,
  });

  factory VendorMarket.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    try {
      return VendorMarket(
        id: doc.id,
        vendorId: data['vendorId'] ?? '',
        vendorName: data['vendorName'] ?? 'Unknown Vendor',
        marketId: data['marketId'] ?? '',
        schedule: data['schedule'] != null 
            ? List<String>.from(data['schedule']) 
            : [],
        boothNumber: data['boothNumber'],
        isActive: data['isActive'] ?? true,
        isApproved: data['isApproved'] ?? false,
        joinedDate: (data['joinedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    } catch (e) {
      print('Error parsing VendorMarket from Firestore: $e');
      print('Document data: $data');
      rethrow;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'vendorId': vendorId,
      'vendorName': vendorName,
      'marketId': marketId,
      'schedule': schedule,
      'boothNumber': boothNumber,
      'isActive': isActive,
      'isApproved': isApproved,
      'joinedDate': Timestamp.fromDate(joinedDate),
    };
  }

  VendorMarket copyWith({
    String? id,
    String? vendorId,
    String? vendorName,
    String? marketId,
    List<String>? schedule,
    String? boothNumber,
    bool? isActive,
    bool? isApproved,
    DateTime? joinedDate,
  }) {
    return VendorMarket(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      marketId: marketId ?? this.marketId,
      schedule: schedule ?? this.schedule,
      boothNumber: boothNumber ?? this.boothNumber,
      isActive: isActive ?? this.isActive,
      isApproved: isApproved ?? this.isApproved,
      joinedDate: joinedDate ?? this.joinedDate,
    );
  }

  // Helper methods
  bool get isActiveAndApproved => isActive && isApproved;
  
  bool isScheduledForDay(String dayName) {
    return schedule.contains(dayName.toLowerCase());
  }
  
  bool get isScheduledToday {
    final today = DateTime.now().weekday;
    final dayName = _getDayName(today);
    return isScheduledForDay(dayName);
  }
  
  String get scheduleDisplay {
    if (schedule.isEmpty) return 'No schedule set';
    return schedule.map(_capitalizeDay).join(', ');
  }
  
  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'monday';
      case 2: return 'tuesday';
      case 3: return 'wednesday';
      case 4: return 'thursday';
      case 5: return 'friday';
      case 6: return 'saturday';
      case 7: return 'sunday';
      default: return '';
    }
  }
  
  String _capitalizeDay(String day) {
    if (day.isEmpty) return day;
    return day[0].toUpperCase() + day.substring(1);
  }

  @override
  List<Object?> get props => [
        id,
        vendorId,
        vendorName,
        marketId,
        schedule,
        boothNumber,
        isActive,
        isApproved,
        joinedDate,
      ];
}