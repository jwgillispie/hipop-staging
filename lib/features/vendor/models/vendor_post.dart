import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../../shared/models/user_profile.dart';
import '../services/vendor_contact_service.dart';

class VendorPost extends Equatable {
  final String id;
  final String vendorId;
  final String vendorName;
  final String description;
  final String location;
  final List<String> locationKeywords;
  final double? latitude;
  final double? longitude;
  final String? placeId;
  final String? locationName;
  final String? marketId; // New field for market relationship
  final DateTime popUpStartDateTime;
  final DateTime popUpEndDateTime;
  /// @deprecated Use getVendorContactInfo() instead. This field will be removed in future versions.
  /// Contact information should come from the vendor's UserProfile.
  final String? instagramHandle;
  final List<String> photoUrls;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  const VendorPost({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.description,
    required this.location,
    this.locationKeywords = const [],
    this.latitude,
    this.longitude,
    this.placeId,
    this.locationName,
    this.marketId,
    required this.popUpStartDateTime,
    required this.popUpEndDateTime,
    this.instagramHandle,
    this.photoUrls = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  factory VendorPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    try {
      return VendorPost(
        id: doc.id,
        vendorId: data['vendorId'] ?? '',
        vendorName: data['vendorName'] ?? '',
        description: data['description'] ?? '',
        location: data['location'] ?? '',
        locationKeywords: data['locationKeywords'] != null 
            ? List<String>.from(data['locationKeywords']) 
            : VendorPost.generateLocationKeywords(data['location'] ?? ''),
        latitude: data['latitude']?.toDouble(),
        longitude: data['longitude']?.toDouble(),
        placeId: data['placeId'],
        locationName: data['locationName'],
        marketId: data['marketId'],
        popUpStartDateTime: data['popUpStartDateTime'] != null 
            ? (data['popUpStartDateTime'] as Timestamp).toDate()
            : (data['popUpDateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
        popUpEndDateTime: data['popUpEndDateTime'] != null 
            ? (data['popUpEndDateTime'] as Timestamp).toDate()
            : (data['popUpDateTime'] as Timestamp?)?.toDate().add(const Duration(hours: 4)) ?? DateTime.now().add(const Duration(hours: 4)),
        instagramHandle: data['instagramHandle'],
        photoUrls: data['photoUrls'] != null 
            ? List<String>.from(data['photoUrls']) 
            : [],
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        isActive: data['isActive'] ?? true,
      );
    } catch (e) {
      rethrow;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'vendorId': vendorId,
      'vendorName': vendorName,
      'description': description,
      'location': location,
      'locationKeywords': locationKeywords,
      'latitude': latitude,
      'longitude': longitude,
      'placeId': placeId,
      'locationName': locationName,
      'marketId': marketId,
      'popUpStartDateTime': Timestamp.fromDate(popUpStartDateTime),
      'popUpEndDateTime': Timestamp.fromDate(popUpEndDateTime),
      'instagramHandle': instagramHandle,
      'photoUrls': photoUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  VendorPost copyWith({
    String? id,
    String? vendorId,
    String? vendorName,
    String? description,
    String? location,
    List<String>? locationKeywords,
    double? latitude,
    double? longitude,
    String? placeId,
    String? locationName,
    String? marketId,
    DateTime? popUpStartDateTime,
    DateTime? popUpEndDateTime,
    String? instagramHandle,
    List<String>? photoUrls,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return VendorPost(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      description: description ?? this.description,
      location: location ?? this.location,
      locationKeywords: locationKeywords ?? this.locationKeywords,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeId: placeId ?? this.placeId,
      locationName: locationName ?? this.locationName,
      marketId: marketId ?? this.marketId,
      popUpStartDateTime: popUpStartDateTime ?? this.popUpStartDateTime,
      popUpEndDateTime: popUpEndDateTime ?? this.popUpEndDateTime,
      instagramHandle: instagramHandle ?? this.instagramHandle,
      photoUrls: photoUrls ?? this.photoUrls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  bool get isUpcoming => popUpStartDateTime.isAfter(DateTime.now());
  bool get isHappening {
    final now = DateTime.now();
    return now.isAfter(popUpStartDateTime) && now.isBefore(popUpEndDateTime);
  }
  bool get isPast => DateTime.now().isAfter(popUpEndDateTime);

  String get formattedDateTime {
    final now = DateTime.now();
    
    if (isHappening) {
      return 'Happening now!';
    } else if (isPast) {
      return 'Past event';
    } else {
      final difference = popUpStartDateTime.difference(now);
      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} from now';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} from now';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} from now';
      } else {
        return 'Starting soon';
      }
    }
  }
  
  String get formattedTimeRange {
    final startTime = _formatTime(popUpStartDateTime);
    final endTime = _formatTime(popUpEndDateTime);
    final isSameDay = popUpStartDateTime.day == popUpEndDateTime.day &&
                      popUpStartDateTime.month == popUpEndDateTime.month &&
                      popUpStartDateTime.year == popUpEndDateTime.year;
    
    if (isSameDay) {
      return '$startTime - $endTime';
    } else {
      return '${_formatDate(popUpStartDateTime)} $startTime - ${_formatDate(popUpEndDateTime)} $endTime';
    }
  }
  
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour == 0 ? 12 : dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
  
  String _formatDate(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
  }

  static List<String> generateLocationKeywords(String location) {
    final keywords = <String>{};
    final normalizedLocation = location.toLowerCase().trim();
    
    keywords.add(normalizedLocation);
    
    final words = normalizedLocation.split(RegExp(r'[,\s]+'));
    for (final word in words) {
      if (word.isNotEmpty) {
        keywords.add(word);
        for (int i = 1; i <= word.length; i++) {
          keywords.add(word.substring(0, i));
        }
      }
    }
    
    final commonSynonyms = {
      'atlanta': ['atl', 'hotlanta'],
      'midtown': ['mid', 'midtown atlanta'],
      'buckhead': ['bhead'],
      'decatur': ['decatur ga'],
      'alpharetta': ['alpharetta ga', 'alph'],
      'virginia-highland': ['vahi', 'virginia highland'],
      'little five points': ['l5p', 'little 5 points'],
      'old fourth ward': ['o4w', 'old 4th ward'],
    };
    
    for (final entry in commonSynonyms.entries) {
      if (normalizedLocation.contains(entry.key)) {
        keywords.addAll(entry.value);
      }
    }
    
    return keywords.toList();
  }

  /// Get vendor contact information from UserProfile (single source of truth)
  /// This replaces the deprecated instagramHandle field
  Future<VendorContactInfo?> getVendorContactInfo() async {
    final contactService = VendorContactService();
    return await contactService.getVendorContactInfo(vendorId);
  }

  /// Check if vendor has contact information available
  /// This method provides a way to check contact availability without loading the profile
  static Future<bool> hasVendorContactInfo(String vendorId) async {
    final contactService = VendorContactService();
    final contactInfo = await contactService.getVendorContactInfo(vendorId);
    return VendorContactService.hasContactInfo(contactInfo);
  }

  @override
  List<Object?> get props => [
        id,
        vendorId,
        vendorName,
        description,
        location,
        locationKeywords,
        latitude,
        longitude,
        placeId,
        locationName,
        marketId,
        popUpStartDateTime,
        popUpEndDateTime,
        instagramHandle,
        photoUrls,
        createdAt,
        updatedAt,
        isActive,
      ];
}