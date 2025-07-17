import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class Market extends Equatable {
  final String id;
  final String name;
  final String address;
  final String city;
  final String state;
  final double latitude;
  final double longitude;
  final String? placeId;
  final Map<String, String> operatingDays; // {"saturday": "9AM-2PM", "sunday": "11AM-4PM"} - Legacy format
  final List<String>? scheduleIds; // References to MarketSchedule documents
  final String? description;
  final String? imageUrl;
  final bool isActive;
  final List<String> associatedVendorIds; // IDs of vendors associated with this market
  final DateTime createdAt;

  const Market({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.latitude,
    required this.longitude,
    this.placeId,
    this.operatingDays = const {},
    this.scheduleIds,
    this.description,
    this.imageUrl,
    this.isActive = true,
    this.associatedVendorIds = const [],
    required this.createdAt,
  });

  factory Market.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    try {
      return Market(
        id: doc.id,
        name: data['name'] ?? '',
        address: data['address'] ?? '',
        city: data['city'] ?? '',
        state: data['state'] ?? '',
        latitude: data['latitude']?.toDouble() ?? 0.0,
        longitude: data['longitude']?.toDouble() ?? 0.0,
        placeId: data['placeId'],
        operatingDays: data['operatingDays'] != null 
            ? Map<String, String>.from(data['operatingDays']) 
            : {},
        scheduleIds: data['scheduleIds'] != null
            ? List<String>.from(data['scheduleIds'])
            : null,
        description: data['description'],
        imageUrl: data['imageUrl'],
        isActive: data['isActive'] ?? true,
        associatedVendorIds: data['associatedVendorIds'] != null
            ? List<String>.from(data['associatedVendorIds'])
            : [],
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    } catch (e) {
      // Error parsing Market from Firestore
      rethrow;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'city': city,
      'state': state,
      'latitude': latitude,
      'longitude': longitude,
      'placeId': placeId,
      'operatingDays': operatingDays,
      if (scheduleIds != null) 'scheduleIds': scheduleIds,
      'description': description,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'associatedVendorIds': associatedVendorIds,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Market copyWith({
    String? id,
    String? name,
    String? address,
    String? city,
    String? state,
    double? latitude,
    double? longitude,
    String? placeId,
    Map<String, String>? operatingDays,
    List<String>? scheduleIds,
    String? description,
    String? imageUrl,
    bool? isActive,
    List<String>? associatedVendorIds,
    DateTime? createdAt,
  }) {
    return Market(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeId: placeId ?? this.placeId,
      operatingDays: operatingDays ?? this.operatingDays,
      scheduleIds: scheduleIds ?? this.scheduleIds,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      associatedVendorIds: associatedVendorIds ?? this.associatedVendorIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Helper methods
  String get fullAddress => '$address, $city, $state';
  
  bool get isOpenToday {
    final today = DateTime.now().weekday;
    final dayName = _getDayName(today);
    return operatingDays.containsKey(dayName);
  }
  
  String? get todaysHours {
    final today = DateTime.now().weekday;
    final dayName = _getDayName(today);
    return operatingDays[dayName];
  }
  
  List<String> get operatingDaysList {
    return operatingDays.keys.toList();
  }
  
  DateTime? get nextOperatingDate {
    if (operatingDays.isEmpty) return null;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Check the next 7 days to find the next operating date
    for (int i = 0; i < 7; i++) {
      final checkDate = today.add(Duration(days: i));
      final dayName = _getDayName(checkDate.weekday);
      
      if (operatingDays.containsKey(dayName)) {
        return checkDate;
      }
    }
    
    return null;
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

  @override
  List<Object?> get props => [
        id,
        name,
        address,
        city,
        state,
        latitude,
        longitude,
        placeId,
        operatingDays,
        scheduleIds,
        description,
        imageUrl,
        isActive,
        associatedVendorIds,
        createdAt,
      ];
}