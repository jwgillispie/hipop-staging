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
  final DateTime eventDate; // Single specific date for this market event
  final String startTime; // e.g., "9:00 AM"
  final String endTime; // e.g., "2:00 PM"
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
    required this.eventDate,
    required this.startTime,
    required this.endTime,
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
        eventDate: (data['eventDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        startTime: data['startTime'] ?? '9:00 AM',
        endTime: data['endTime'] ?? '2:00 PM',
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
      'eventDate': Timestamp.fromDate(eventDate),
      'startTime': startTime,
      'endTime': endTime,
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
    DateTime? eventDate,
    String? startTime,
    String? endTime,
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
      eventDate: eventDate ?? this.eventDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      associatedVendorIds: associatedVendorIds ?? this.associatedVendorIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Helper methods
  String get fullAddress => '$address, $city, $state';
  
  /// Whether this market event is happening today
  bool get isHappeningToday {
    final today = DateTime.now();
    return eventDate.year == today.year &&
           eventDate.month == today.month &&
           eventDate.day == today.day;
  }
  
  /// Whether this market event is in the future
  bool get isFutureEvent {
    return eventDate.isAfter(DateTime.now());
  }
  
  /// Whether this market event is in the past
  bool get isPastEvent {
    return eventDate.isBefore(DateTime.now());
  }
  
  /// Time range as a formatted string
  String get timeRange => '$startTime - $endTime';
  
  /// Combined date and time information for display
  String get eventDisplayInfo {
    final dateStr = '${eventDate.month}/${eventDate.day}/${eventDate.year}';
    return '$dateStr • $timeRange';
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
        eventDate,
        startTime,
        endTime,
        description,
        imageUrl,
        isActive,
        associatedVendorIds,
        createdAt,
      ];
}