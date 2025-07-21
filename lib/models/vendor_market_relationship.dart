import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum RelationshipStatus {
  pending,
  approved,
  active,
  inactive,
  rejected,
}

enum RelationshipSource {
  vendorApplication,
  marketInvitation,
  vendorSelfAssignment,
}

class VendorMarketRelationship extends Equatable {
  final String id;
  final String vendorId;
  final String marketId;
  final RelationshipStatus status;
  final RelationshipSource source;
  final String? invitationToken;
  final String? invitationEmail;
  final String createdBy;
  final String? approvedBy;
  final DateTime? approvedAt;
  final List<String> operatingDays;
  final String? boothNumber;
  final String? notes;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VendorMarketRelationship({
    required this.id,
    required this.vendorId,
    required this.marketId,
    required this.status,
    required this.source,
    this.invitationToken,
    this.invitationEmail,
    required this.createdBy,
    this.approvedBy,
    this.approvedAt,
    this.operatingDays = const [],
    this.boothNumber,
    this.notes,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory VendorMarketRelationship.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return VendorMarketRelationship(
      id: doc.id,
      vendorId: data['vendorId'] ?? '',
      marketId: data['marketId'] ?? '',
      status: RelationshipStatus.values.firstWhere(
        (status) => status.name == data['status'],
        orElse: () => RelationshipStatus.pending,
      ),
      source: RelationshipSource.values.firstWhere(
        (source) => source.name == data['source'],
        orElse: () => RelationshipSource.vendorApplication,
      ),
      invitationToken: data['invitationToken'],
      invitationEmail: data['invitationEmail'],
      createdBy: data['createdBy'] ?? '',
      approvedBy: data['approvedBy'],
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      operatingDays: List<String>.from(data['operatingDays'] ?? []),
      boothNumber: data['boothNumber'],
      notes: data['notes'],
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'vendorId': vendorId,
      'marketId': marketId,
      'status': status.name,
      'source': source.name,
      'invitationToken': invitationToken,
      'invitationEmail': invitationEmail,
      'createdBy': createdBy,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'operatingDays': operatingDays,
      'boothNumber': boothNumber,
      'notes': notes,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  VendorMarketRelationship copyWith({
    String? id,
    String? vendorId,
    String? marketId,
    RelationshipStatus? status,
    RelationshipSource? source,
    String? invitationToken,
    String? invitationEmail,
    String? createdBy,
    String? approvedBy,
    DateTime? approvedAt,
    List<String>? operatingDays,
    String? boothNumber,
    String? notes,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VendorMarketRelationship(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      marketId: marketId ?? this.marketId,
      status: status ?? this.status,
      source: source ?? this.source,
      invitationToken: invitationToken ?? this.invitationToken,
      invitationEmail: invitationEmail ?? this.invitationEmail,
      createdBy: createdBy ?? this.createdBy,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      operatingDays: operatingDays ?? this.operatingDays,
      boothNumber: boothNumber ?? this.boothNumber,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isPending => status == RelationshipStatus.pending;
  bool get isApproved => status == RelationshipStatus.approved;
  bool get isActive => status == RelationshipStatus.active;
  bool get isInactive => status == RelationshipStatus.inactive;
  bool get isRejected => status == RelationshipStatus.rejected;
  
  bool get isFromInvitation => source == RelationshipSource.marketInvitation;
  bool get isFromApplication => source == RelationshipSource.vendorApplication;
  bool get isFromSelfAssignment => source == RelationshipSource.vendorSelfAssignment;
  
  bool get hasInvitationToken => invitationToken != null && invitationToken!.isNotEmpty;
  bool get needsApproval => isPending && (isFromSelfAssignment || isFromInvitation);

  String get statusDisplayName {
    switch (status) {
      case RelationshipStatus.pending:
        return 'Pending Approval';
      case RelationshipStatus.approved:
        return 'Approved';
      case RelationshipStatus.active:
        return 'Active';
      case RelationshipStatus.inactive:
        return 'Inactive';
      case RelationshipStatus.rejected:
        return 'Rejected';
    }
  }

  String get sourceDisplayName {
    switch (source) {
      case RelationshipSource.vendorApplication:
        return 'Vendor Application';
      case RelationshipSource.marketInvitation:
        return 'Market Invitation';
      case RelationshipSource.vendorSelfAssignment:
        return 'Vendor Self-Assignment';
    }
  }

  VendorMarketRelationship approve(String approverId, {String? notes}) {
    return copyWith(
      status: RelationshipStatus.approved,
      approvedBy: approverId,
      approvedAt: DateTime.now(),
      notes: notes,
      updatedAt: DateTime.now(),
    );
  }

  VendorMarketRelationship reject(String approverId, {String? notes}) {
    return copyWith(
      status: RelationshipStatus.rejected,
      approvedBy: approverId,
      approvedAt: DateTime.now(),
      notes: notes,
      updatedAt: DateTime.now(),
    );
  }

  VendorMarketRelationship activate() {
    return copyWith(
      status: RelationshipStatus.active,
      updatedAt: DateTime.now(),
    );
  }

  VendorMarketRelationship deactivate() {
    return copyWith(
      status: RelationshipStatus.inactive,
      updatedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        vendorId,
        marketId,
        status,
        source,
        invitationToken,
        invitationEmail,
        createdBy,
        approvedBy,
        approvedAt,
        operatingDays,
        boothNumber,
        notes,
        metadata,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() {
    return 'VendorMarketRelationship(id: $id, vendorId: $vendorId, marketId: $marketId, status: ${status.name}, source: ${source.name})';
  }
}