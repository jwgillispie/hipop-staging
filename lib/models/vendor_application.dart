import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum ApplicationStatus {
  pending,
  approved,
  rejected,
  waitlisted,
}

class VendorApplication extends Equatable {
  final String id;
  final String marketId;
  final String vendorId; // User ID of the vendor applicant
  final List<String> operatingDays; // Legacy: Days they want to attend this market (kept for backward compatibility)
  final List<DateTime> requestedDates; // Specific dates they want to attend this market
  final String? specialMessage; // Optional message to market organizer
  final String? howDidYouHear; // How they heard about the market
  final ApplicationStatus status;
  final String? reviewNotes; // Organizer notes
  final String? reviewedBy; // Market organizer who reviewed
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata; // Flexible field for additional data

  const VendorApplication({
    required this.id,
    required this.marketId,
    required this.vendorId,
    this.operatingDays = const [],
    this.requestedDates = const [],
    this.specialMessage,
    this.howDidYouHear,
    this.status = ApplicationStatus.pending,
    this.reviewNotes,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
    this.metadata = const {},
  });

  factory VendorApplication.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return VendorApplication(
      id: doc.id,
      marketId: data['marketId'] ?? '',
      vendorId: data['vendorId'] ?? '',
      operatingDays: List<String>.from(data['operatingDays'] ?? []),
      requestedDates: (data['requestedDates'] as List<dynamic>?)?.map((e) => (e as Timestamp).toDate()).toList() ?? [],
      specialMessage: data['specialMessage'],
      howDidYouHear: data['howDidYouHear'],
      status: ApplicationStatus.values.firstWhere(
        (status) => status.name == data['status'],
        orElse: () => ApplicationStatus.pending,
      ),
      reviewNotes: data['reviewNotes'],
      reviewedBy: data['reviewedBy'],
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'marketId': marketId,
      'vendorId': vendorId,
      'operatingDays': operatingDays,
      'requestedDates': requestedDates.map((date) => Timestamp.fromDate(date)).toList(),
      'specialMessage': specialMessage,
      'howDidYouHear': howDidYouHear,
      'status': status.name,
      'reviewNotes': reviewNotes,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'metadata': metadata,
    };
  }

  VendorApplication copyWith({
    String? id,
    String? marketId,
    String? vendorId,
    List<String>? operatingDays,
    List<DateTime>? requestedDates,
    String? specialMessage,
    String? howDidYouHear,
    ApplicationStatus? status,
    String? reviewNotes,
    String? reviewedBy,
    DateTime? reviewedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return VendorApplication(
      id: id ?? this.id,
      marketId: marketId ?? this.marketId,
      vendorId: vendorId ?? this.vendorId,
      operatingDays: operatingDays ?? this.operatingDays,
      requestedDates: requestedDates ?? this.requestedDates,
      specialMessage: specialMessage ?? this.specialMessage,
      howDidYouHear: howDidYouHear ?? this.howDidYouHear,
      status: status ?? this.status,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  // Helper methods
  bool get isPending => status == ApplicationStatus.pending;
  bool get isApproved => status == ApplicationStatus.approved;
  bool get isRejected => status == ApplicationStatus.rejected;
  bool get isWaitlisted => status == ApplicationStatus.waitlisted;
  bool get hasBeenReviewed => reviewedAt != null;

  String get statusDisplayName {
    switch (status) {
      case ApplicationStatus.pending:
        return 'Pending Review';
      case ApplicationStatus.approved:
        return 'Approved';
      case ApplicationStatus.rejected:
        return 'Rejected';
      case ApplicationStatus.waitlisted:
        return 'Waitlisted';
    }
  }

  // Get vendor business name from metadata or fallback
  String get vendorBusinessName {
    final profileSnapshot = metadata['profileSnapshot'] as Map<String, dynamic>?;
    if (profileSnapshot != null) {
      return profileSnapshot['businessName'] as String? ?? 
             profileSnapshot['displayName'] as String? ?? 
             'Unknown Business';
    }
    return 'Unknown Business';
  }

  // Get vendor display name from metadata or fallback
  String get vendorDisplayName {
    final profileSnapshot = metadata['profileSnapshot'] as Map<String, dynamic>?;
    if (profileSnapshot != null) {
      return profileSnapshot['displayName'] as String? ?? 
             profileSnapshot['email'] as String? ?? 
             'Unknown Vendor';
    }
    return 'Unknown Vendor';
  }

  // Get vendor email from metadata
  String? get vendorEmail {
    final profileSnapshot = metadata['profileSnapshot'] as Map<String, dynamic>?;
    return profileSnapshot?['email'] as String?;
  }

  // Get vendor categories from metadata
  List<String> get vendorCategories {
    final profileSnapshot = metadata['profileSnapshot'] as Map<String, dynamic>?;
    if (profileSnapshot != null && profileSnapshot['categories'] != null) {
      return List<String>.from(profileSnapshot['categories'] as List? ?? []);
    }
    return [];
  }

  // Approve the application
  VendorApplication approve(String reviewerId, {String? notes}) {
    return copyWith(
      status: ApplicationStatus.approved,
      reviewedBy: reviewerId,
      reviewedAt: DateTime.now(),
      reviewNotes: notes,
      updatedAt: DateTime.now(),
    );
  }

  // Reject the application
  VendorApplication reject(String reviewerId, {String? notes}) {
    return copyWith(
      status: ApplicationStatus.rejected,
      reviewedBy: reviewerId,
      reviewedAt: DateTime.now(),
      reviewNotes: notes,
      updatedAt: DateTime.now(),
    );
  }

  // Waitlist the application
  VendorApplication waitlist(String reviewerId, {String? notes}) {
    return copyWith(
      status: ApplicationStatus.waitlisted,
      reviewedBy: reviewerId,
      reviewedAt: DateTime.now(),
      reviewNotes: notes,
      updatedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        marketId,
        vendorId,
        operatingDays,
        requestedDates,
        specialMessage,
        howDidYouHear,
        status,
        reviewNotes,
        reviewedBy,
        reviewedAt,
        createdAt,
        updatedAt,
        metadata,
      ];

  // Helper methods for requested dates
  bool get hasRequestedDates => requestedDates.isNotEmpty;
  
  List<DateTime> get sortedRequestedDates {
    final dates = List<DateTime>.from(requestedDates);
    dates.sort();
    return dates;
  }
  
  String get requestedDatesDisplayString {
    if (requestedDates.isEmpty) return 'No dates selected';
    
    final sortedDates = sortedRequestedDates;
    if (sortedDates.length == 1) {
      return '${sortedDates.first.month}/${sortedDates.first.day}/${sortedDates.first.year}';
    } else if (sortedDates.length <= 3) {
      return sortedDates.map((date) => '${date.month}/${date.day}').join(', ');
    } else {
      return '${sortedDates.first.month}/${sortedDates.first.day} - ${sortedDates.last.month}/${sortedDates.last.day} (${sortedDates.length} dates)';
    }
  }

  @override
  String toString() {
    return 'VendorApplication(id: $id, marketId: $marketId, vendorId: $vendorId, requestedDates: ${requestedDates.length}, status: $status)';
  }
}