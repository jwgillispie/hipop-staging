import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:hipop/features/vendor/models/vendor_post.dart';
import 'package:hipop/repositories/vendor_posts_repository.dart';
import 'package:hipop/features/shared/services/user_profile_service.dart';

// Events
abstract class VendorDashboardEvent extends Equatable {
  const VendorDashboardEvent();

  @override
  List<Object?> get props => [];
}

class LoadVendorDashboard extends VendorDashboardEvent {
  final String userId;
  const LoadVendorDashboard(this.userId);
  
  @override
  List<Object?> get props => [userId];
}

class CheckPremiumAccess extends VendorDashboardEvent {
  final String userId;
  const CheckPremiumAccess(this.userId);
  
  @override
  List<Object?> get props => [userId];
}

class UpdatePremiumAccess extends VendorDashboardEvent {
  final bool hasPremiumAccess;
  const UpdatePremiumAccess(this.hasPremiumAccess);
  
  @override
  List<Object?> get props => [hasPremiumAccess];
}

// States
abstract class VendorDashboardState extends Equatable {
  const VendorDashboardState();
  
  @override
  List<Object?> get props => [];
}

class VendorDashboardInitial extends VendorDashboardState {}

class VendorDashboardLoading extends VendorDashboardState {}

class VendorDashboardLoaded extends VendorDashboardState {
  final String userId;
  final bool hasPremiumAccess;
  final bool isCheckingPremium;
  final List<VendorPost> vendorPosts;
  
  const VendorDashboardLoaded({
    required this.userId,
    this.hasPremiumAccess = false,
    this.isCheckingPremium = false,
    this.vendorPosts = const [],
  });
  
  VendorDashboardLoaded copyWith({
    String? userId,
    bool? hasPremiumAccess,
    bool? isCheckingPremium,
    List<VendorPost>? vendorPosts,
  }) {
    return VendorDashboardLoaded(
      userId: userId ?? this.userId,
      hasPremiumAccess: hasPremiumAccess ?? this.hasPremiumAccess,
      isCheckingPremium: isCheckingPremium ?? this.isCheckingPremium,
      vendorPosts: vendorPosts ?? this.vendorPosts,
    );
  }
  
  @override
  List<Object?> get props => [userId, hasPremiumAccess, isCheckingPremium, vendorPosts];
}

class VendorDashboardError extends VendorDashboardState {
  final String message;
  
  const VendorDashboardError(this.message);
  
  @override
  List<Object?> get props => [message];
}

// BLoC
class VendorDashboardBloc extends Bloc<VendorDashboardEvent, VendorDashboardState> {
  final VendorPostsRepository _vendorPostsRepository;
  final UserProfileService _userProfileService;
  
  VendorDashboardBloc({
    VendorPostsRepository? vendorPostsRepository,
    UserProfileService? userProfileService,
  }) : _vendorPostsRepository = vendorPostsRepository ?? VendorPostsRepository(),
       _userProfileService = userProfileService ?? UserProfileService(),
       super(VendorDashboardInitial()) {
    on<LoadVendorDashboard>(_onLoadVendorDashboard);
    on<CheckPremiumAccess>(_onCheckPremiumAccess);
    on<UpdatePremiumAccess>(_onUpdatePremiumAccess);
  }
  
  Future<void> _onLoadVendorDashboard(
    LoadVendorDashboard event,
    Emitter<VendorDashboardState> emit,
  ) async {
    emit(VendorDashboardLoading());
    
    try {
      // Start checking premium access
      emit(VendorDashboardLoaded(
        userId: event.userId,
        isCheckingPremium: true,
      ));
      
      // Check premium access
      final userProfile = await _userProfileService.getUserProfile(event.userId);
      final hasPremiumAccess = userProfile?.isPremium == true;
      
      // Load vendor posts
      final postsStream = _vendorPostsRepository.getVendorPosts(event.userId);
      
      await emit.forEach<List<VendorPost>>(
        postsStream,
        onData: (posts) {
          final currentState = state;
          if (currentState is VendorDashboardLoaded) {
            return currentState.copyWith(
              vendorPosts: posts,
              hasPremiumAccess: hasPremiumAccess,
              isCheckingPremium: false,
            );
          } else {
            return VendorDashboardLoaded(
              userId: event.userId,
              vendorPosts: posts,
              hasPremiumAccess: hasPremiumAccess,
              isCheckingPremium: false,
            );
          }
        },
        onError: (error, stackTrace) => VendorDashboardError(error.toString()),
      );
    } catch (e) {
      emit(VendorDashboardError(e.toString()));
    }
  }
  
  Future<void> _onCheckPremiumAccess(
    CheckPremiumAccess event,
    Emitter<VendorDashboardState> emit,
  ) async {
    final currentState = state;
    if (currentState is! VendorDashboardLoaded) return;
    
    emit(currentState.copyWith(isCheckingPremium: true));
    
    try {
      final userProfile = await _userProfileService.getUserProfile(event.userId);
      final hasPremiumAccess = userProfile?.isPremium == true;
      
      emit(currentState.copyWith(
        hasPremiumAccess: hasPremiumAccess,
        isCheckingPremium: false,
      ));
    } catch (e) {
      emit(currentState.copyWith(isCheckingPremium: false));
    }
  }
  
  Future<void> _onUpdatePremiumAccess(
    UpdatePremiumAccess event,
    Emitter<VendorDashboardState> emit,
  ) async {
    final currentState = state;
    if (currentState is! VendorDashboardLoaded) return;
    
    emit(currentState.copyWith(hasPremiumAccess: event.hasPremiumAccess));
  }
}