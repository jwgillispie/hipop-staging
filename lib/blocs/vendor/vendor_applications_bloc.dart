import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hipop/features/vendor/models/vendor_application.dart';
import 'package:hipop/features/vendor/services/vendor_application_service.dart';

// Events
abstract class VendorApplicationsEvent extends Equatable {
  const VendorApplicationsEvent();

  @override
  List<Object?> get props => [];
}

class LoadApplications extends VendorApplicationsEvent {
  final String marketId;
  final ApplicationStatus? filterStatus;
  
  const LoadApplications({
    required this.marketId,
    this.filterStatus,
  });
  
  @override
  List<Object?> get props => [marketId, filterStatus];
}

class LoadMoreApplications extends VendorApplicationsEvent {
  final String marketId;
  final ApplicationStatus? filterStatus;
  
  const LoadMoreApplications({
    required this.marketId,
    this.filterStatus,
  });
  
  @override
  List<Object?> get props => [marketId, filterStatus];
}

class RefreshApplications extends VendorApplicationsEvent {
  final String marketId;
  final ApplicationStatus? filterStatus;
  
  const RefreshApplications({
    required this.marketId,
    this.filterStatus,
  });
  
  @override
  List<Object?> get props => [marketId, filterStatus];
}

class UpdateApplicationStatus extends VendorApplicationsEvent {
  final String applicationId;
  final ApplicationStatus newStatus;
  final String organizerId;
  final String? reviewNotes;
  
  const UpdateApplicationStatus({
    required this.applicationId,
    required this.newStatus,
    required this.organizerId,
    this.reviewNotes,
  });
  
  @override
  List<Object?> get props => [applicationId, newStatus, organizerId, reviewNotes];
}

// States
abstract class VendorApplicationsState extends Equatable {
  const VendorApplicationsState();
  
  @override
  List<Object?> get props => [];
}

class ApplicationsInitial extends VendorApplicationsState {}

class ApplicationsLoading extends VendorApplicationsState {}

class ApplicationsLoaded extends VendorApplicationsState {
  final List<VendorApplication> applications;
  final bool hasReachedEnd;
  final bool isLoadingMore;
  final DocumentSnapshot? lastDocument;
  final String marketId;
  final ApplicationStatus? filterStatus;
  
  const ApplicationsLoaded({
    required this.applications,
    required this.hasReachedEnd,
    required this.marketId,
    this.isLoadingMore = false,
    this.lastDocument,
    this.filterStatus,
  });
  
  ApplicationsLoaded copyWith({
    List<VendorApplication>? applications,
    bool? hasReachedEnd,
    bool? isLoadingMore,
    DocumentSnapshot? lastDocument,
    String? marketId,
    ApplicationStatus? filterStatus,
  }) {
    return ApplicationsLoaded(
      applications: applications ?? this.applications,
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      lastDocument: lastDocument ?? this.lastDocument,
      marketId: marketId ?? this.marketId,
      filterStatus: filterStatus ?? this.filterStatus,
    );
  }
  
  @override
  List<Object?> get props => [
    applications, 
    hasReachedEnd, 
    isLoadingMore, 
    lastDocument,
    marketId,
    filterStatus,
  ];
}

class ApplicationsError extends VendorApplicationsState {
  final String message;
  
  const ApplicationsError(this.message);
  
  @override
  List<Object?> get props => [message];
}

// BLoC
class VendorApplicationsBloc extends Bloc<VendorApplicationsEvent, VendorApplicationsState> {
  static const int _pageSize = 20;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  VendorApplicationsBloc() : super(ApplicationsInitial()) {
    on<LoadApplications>(_onLoadApplications);
    on<LoadMoreApplications>(_onLoadMoreApplications);
    on<RefreshApplications>(_onRefreshApplications);
    on<UpdateApplicationStatus>(_onUpdateApplicationStatus);
  }
  
  Future<void> _onLoadApplications(
    LoadApplications event,
    Emitter<VendorApplicationsState> emit,
  ) async {
    emit(ApplicationsLoading());
    
    try {
      Query query = _firestore
          .collection('vendor_applications')
          .where('marketId', isEqualTo: event.marketId)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);
      
      if (event.filterStatus != null) {
        query = query.where('status', isEqualTo: event.filterStatus!.name);
      }
      
      final snapshot = await query.get();
      
      final applications = snapshot.docs
          .map((doc) => VendorApplication.fromFirestore(doc))
          .toList();
      
      emit(ApplicationsLoaded(
        applications: applications,
        hasReachedEnd: snapshot.docs.length < _pageSize,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        marketId: event.marketId,
        filterStatus: event.filterStatus,
      ));
    } catch (e) {
      emit(ApplicationsError(e.toString()));
    }
  }
  
  Future<void> _onLoadMoreApplications(
    LoadMoreApplications event,
    Emitter<VendorApplicationsState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ApplicationsLoaded || 
        currentState.hasReachedEnd || 
        currentState.isLoadingMore ||
        currentState.lastDocument == null) {
      return;
    }
    
    emit(currentState.copyWith(isLoadingMore: true));
    
    try {
      Query query = _firestore
          .collection('vendor_applications')
          .where('marketId', isEqualTo: event.marketId)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(currentState.lastDocument!)
          .limit(_pageSize);
      
      if (event.filterStatus != null) {
        query = query.where('status', isEqualTo: event.filterStatus!.name);
      }
      
      final snapshot = await query.get();
      
      final newApplications = snapshot.docs
          .map((doc) => VendorApplication.fromFirestore(doc))
          .toList();
      
      emit(currentState.copyWith(
        applications: [...currentState.applications, ...newApplications],
        hasReachedEnd: snapshot.docs.length < _pageSize,
        isLoadingMore: false,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : currentState.lastDocument,
      ));
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }
  
  Future<void> _onRefreshApplications(
    RefreshApplications event,
    Emitter<VendorApplicationsState> emit,
  ) async {
    // Reset and reload
    emit(ApplicationsInitial());
    add(LoadApplications(marketId: event.marketId, filterStatus: event.filterStatus));
  }
  
  Future<void> _onUpdateApplicationStatus(
    UpdateApplicationStatus event,
    Emitter<VendorApplicationsState> emit,
  ) async {
    try {
      if (event.newStatus == ApplicationStatus.approved) {
        await VendorApplicationService.approveApplication(
          event.applicationId,
          event.organizerId,
          notes: event.reviewNotes,
        );
      } else {
        await VendorApplicationService.updateApplicationStatus(
          event.applicationId,
          event.newStatus,
          event.organizerId,
          reviewNotes: event.reviewNotes,
        );
      }
      
      // Refresh the list
      final currentState = state;
      if (currentState is ApplicationsLoaded) {
        add(RefreshApplications(
          marketId: currentState.marketId,
          filterStatus: currentState.filterStatus,
        ));
      }
    } catch (e) {
      emit(ApplicationsError(e.toString()));
    }
  }
}