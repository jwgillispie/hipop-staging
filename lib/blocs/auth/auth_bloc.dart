import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../repositories/auth_repository.dart';
import '../../services/user_profile_service.dart';
import '../../services/favorites_migration_service.dart';
import '../../models/user_profile.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../../utils/validation_utils.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final IAuthRepository _authRepository;
  final FirebaseFirestore _firestore;
  final UserProfileService _userProfileService;
  StreamSubscription<User?>? _authStateSubscription;

  AuthBloc({
    required IAuthRepository authRepository,
    FirebaseFirestore? firestore,
    UserProfileService? userProfileService,
  })  : _authRepository = authRepository,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _userProfileService = userProfileService ?? UserProfileService(),
        super(AuthInitial()) {
    
    on<AuthStarted>(_onAuthStarted);
    on<AuthUserChanged>(_onAuthUserChanged);
    on<LoginEvent>(_onLoginEvent);
    on<SignUpEvent>(_onSignUpEvent);
    on<LogoutEvent>(_onLogoutEvent);
    on<ForgotPasswordEvent>(_onForgotPasswordEvent);
    on<SendEmailVerificationEvent>(_onSendEmailVerificationEvent);
    on<ReloadUserEvent>(_onReloadUserEvent);
  }

  Future<void> _onAuthStarted(AuthStarted event, Emitter<AuthState> emit) async {
    emit(const AuthLoading(message: 'Initializing...'));
    
    await _authStateSubscription?.cancel();
    _authStateSubscription = _authRepository.authStateChanges.listen(
      (user) => add(AuthUserChanged(user)),
    );
  }

  Future<void> _onAuthUserChanged(AuthUserChanged event, Emitter<AuthState> emit) async {
    final user = event.user as User?;
    
    if (user != null) {
      try {
        // FIRST: Try to load user profile from user_profiles collection (new system)
        UserProfile? userProfile;
        try {
          userProfile = await _userProfileService.getUserProfile(user.uid);
          
          if (userProfile != null) {
            // Use the user profile data as primary source
            emit(Authenticated(user: user, userType: userProfile.userType, userProfile: userProfile));
            
            // Migrate local favorites to user account for shoppers
            if (userProfile.userType == 'shopper' && await FavoritesMigrationService.hasLocalFavorites()) {
              try {
                await FavoritesMigrationService.migrateLocalFavoritesToUser(user.uid);
                await FavoritesMigrationService.clearLocalFavoritesAfterMigration();
              } catch (e) {
                // Handle migration error silently
              }
            }
            return; // Exit early if we have a user profile
          }
        } catch (e) {
          // Failed to load user profile, continue with fallback
        }
        
        // FALLBACK: Check old users collection if no user profile exists
        DocumentSnapshot userDoc;
        int retries = 0;
        const maxRetries = 5;
        
        do {
          userDoc = await _firestore.collection('users').doc(user.uid).get();
          
          if (!userDoc.exists && retries < maxRetries) {
            await Future.delayed(Duration(milliseconds: 1000 * (retries + 1)));
            retries++;
          } else {
            break;
          }
        } while (retries <= maxRetries);
        
        if (userDoc.exists) {
          final userData = userDoc.data()! as Map<String, dynamic>;
          final userType = userData['userType'] as String?;
          
          
          if (userType != null && userType.isNotEmpty) {
            emit(Authenticated(user: user, userType: userType, userProfile: null));
            
            // Migrate local favorites to user account for shoppers
            if (userType == 'shopper' && await FavoritesMigrationService.hasLocalFavorites()) {
              try {
                await FavoritesMigrationService.migrateLocalFavoritesToUser(user.uid);
                await FavoritesMigrationService.clearLocalFavoritesAfterMigration();
              } catch (e) {
                // Handle migration error silently
              }
            }
          } else {
            // For existing users with missing userType, check if they have vendor-specific data
            final hasVendorData = userData.containsKey('businessName') || 
                                userData.containsKey('vendorProfile') ||
                                userData.containsKey('popups');
            final inferredType = hasVendorData ? 'vendor' : 'shopper';
            emit(Authenticated(user: user, userType: inferredType, userProfile: null));
          }
        } else {
          
          // For returning users, try to check if they have any vendor collections
          try {
            final vendorPostsQuery = await _firestore
                .collection('vendor_posts')
                .where('vendorId', isEqualTo: user.uid)
                .limit(1)
                .get();
            
            if (vendorPostsQuery.docs.isNotEmpty) {
              emit(Authenticated(user: user, userType: 'vendor', userProfile: null));
            } else {
              emit(Authenticated(user: user, userType: 'shopper', userProfile: null));
              
              // Migrate local favorites for shopper users
              if (await FavoritesMigrationService.hasLocalFavorites()) {
                try {
                  await FavoritesMigrationService.migrateLocalFavoritesToUser(user.uid);
                  await FavoritesMigrationService.clearLocalFavoritesAfterMigration();
                } catch (e) {
                  // Handle migration error silently
                }
              }
            }
          } catch (e) {
            emit(Authenticated(user: user, userType: 'shopper', userProfile: null));
          }
        }
      } catch (e) {
        emit(Authenticated(user: user, userType: 'shopper', userProfile: null));
      }
    } else {
      emit(Unauthenticated());
    }
  }

  Future<void> _onLoginEvent(LoginEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading(message: 'Signing in...'));
    
    try {
      // Validate inputs
      if (event.email.trim().isEmpty || event.password.trim().isEmpty) {
        emit(const AuthError(message: 'Please fill in all fields'));
        return;
      }

      if (!ValidationUtils.isValidEmail(event.email.trim())) {
        emit(const AuthError(message: 'Please enter a valid email address'));
        return;
      }

      final userCredential = await _authRepository.signInWithEmailAndPassword(
        event.email.trim(),
        event.password.trim(),
      );
      
      // Manually trigger auth state update immediately after login
      if (userCredential.user != null) {
        add(AuthUserChanged(userCredential.user));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onSignUpEvent(SignUpEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading(message: 'Creating account...'));
    
    try {
      // Validate inputs
      if (event.name.trim().isEmpty || 
          event.email.trim().isEmpty || 
          event.password.trim().isEmpty) {
        emit(const AuthError(message: 'Please fill in all fields'));
        return;
      }

      if (!ValidationUtils.isValidEmail(event.email.trim())) {
        emit(const AuthError(message: 'Please enter a valid email address'));
        return;
      }

      if (event.password.trim().length < 6) {
        emit(const AuthError(message: 'Password must be at least 6 characters'));
        return;
      }

      if (event.name.trim().length < 2) {
        emit(const AuthError(message: 'Please enter your full name'));
        return;
      }

      // Create user account
      final userCredential = await _authRepository.createUserWithEmailAndPassword(
        event.email.trim(),
        event.password.trim(),
      );

      if (userCredential.user != null) {
        // Create user profile in Firestore FIRST (following govvy pattern)
        await (_authRepository as AuthRepository).createUserProfile(
          uid: userCredential.user!.uid,
          name: event.name.trim(),
          email: event.email.trim(),
          userType: event.userType,
        );
        
        // THEN update display name in Firebase Auth
        await _authRepository.updateDisplayName(event.name.trim());
        
        // Reload user to ensure we have the latest data
        await _authRepository.reloadUser();
        
        // Try to load the created user profile
        UserProfile? userProfile;
        try {
          userProfile = await _userProfileService.getUserProfile(userCredential.user!.uid);  
        } catch (e) {
          // Failed to load user profile after creation, continue without it
        }
        
        // Emit authenticated state directly to avoid race condition
        emit(Authenticated(user: userCredential.user!, userType: event.userType, userProfile: userProfile));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onLogoutEvent(LogoutEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading(message: 'Signing out...'));
    
    try {
      await _authRepository.signOut();
      // State will be updated via AuthUserChanged event
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onForgotPasswordEvent(ForgotPasswordEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading(message: 'Sending password reset email...'));
    
    try {
      if (event.email.trim().isEmpty) {
        emit(const AuthError(message: 'Please enter your email address'));
        return;
      }

      if (!ValidationUtils.isValidEmail(event.email.trim())) {
        emit(const AuthError(message: 'Please enter a valid email address'));
        return;
      }

      await _authRepository.sendPasswordResetEmail(event.email.trim());
      emit(PasswordResetSent(email: event.email.trim()));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onSendEmailVerificationEvent(SendEmailVerificationEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading(message: 'Sending verification email...'));
    
    try {
      await _authRepository.sendEmailVerification();
      emit(EmailVerificationSent());
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onReloadUserEvent(ReloadUserEvent event, Emitter<AuthState> emit) async {
    try {
      await _authRepository.reloadUser();
      // Force a user state update
      final user = _authRepository.currentUser;
      add(AuthUserChanged(user));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }


  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }
}