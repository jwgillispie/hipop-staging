import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../repositories/auth_repository.dart';
import '../../features/shared/services/user_profile_service.dart';
import '../../features/shared/services/favorites_migration_service.dart';
import '../../features/auth/services/onboarding_service.dart';
import '../../features/shared/models/user_profile.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../../core/constants/validation_utils.dart';

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
    
    // Phone Authentication Handlers
    on<PhoneSignInRequestedEvent>(_onPhoneSignInRequested);
    on<PhoneCodeSentEvent>(_onPhoneCodeSent);
    on<PhoneVerificationCompletedEvent>(_onPhoneVerificationCompleted);
    on<PhoneVerificationFailedEvent>(_onPhoneVerificationFailed);
    on<VerifyPhoneCodeEvent>(_onVerifyPhoneCode);
    on<ResendPhoneCodeEvent>(_onResendPhoneCode);
    on<LinkPhoneNumberEvent>(_onLinkPhoneNumber);
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
    print('🔐 DEBUG: AuthUserChanged - user is ${user != null ? "not null" : "null"}');
    
    if (user != null) {
      try {
        // Check email verification status
        print('DEBUG: Email verified: ${user.emailVerified}');
        if (!user.emailVerified) {
          print('DEBUG: User email not verified - proceeding anyway for staging environment');
          // For staging, we'll proceed even with unverified email
          // In production, you should require verification:
          // emit(EmailVerificationRequired(user: user));
          // return;
        }
        
        // Force token refresh before any Firestore calls
        try {
          await user.getIdToken(true);
        } catch (e) {
          print('DEBUG: Error refreshing token: $e');
        }
        
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
          print('DEBUG: Failed to load user profile: $e');
          // If user profile doesn't exist, create a new one with default type
          try {
            print('DEBUG: Creating missing user profile for user: ${user.uid}');
            // Default to 'shopper' for new users without profiles
            const defaultUserType = 'shopper';
            userProfile = await _userProfileService.createUserProfile(
              userId: user.uid,
              userType: defaultUserType,
              email: user.email ?? '',
              displayName: user.displayName ?? 'User',
            );
            
            if (userProfile != null) {
              emit(Authenticated(user: user, userType: userProfile.userType, userProfile: userProfile));
              return;
            }
          } catch (createError) {
            print('DEBUG: Failed to create missing user profile: $createError');
            // If profile creation fails, emit authenticated with default type
            emit(Authenticated(user: user, userType: 'shopper', userProfile: null));
            return;
          }
        }
      } catch (e) {
        emit(Authenticated(user: user, userType: 'shopper', userProfile: null));
      }
    } else {
      print('🔐 DEBUG: Emitting Unauthenticated state');
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
        
        // Mark first-time signup for shoppers to trigger onboarding
        if (event.userType == 'shopper') {
          await OnboardingService.markShopperFirstTimeSignup();
        }
        
        // Emit authenticated state directly to avoid race condition
        emit(Authenticated(user: userCredential.user!, userType: event.userType, userProfile: userProfile));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onLogoutEvent(LogoutEvent event, Emitter<AuthState> emit) async {
    print('🔐 DEBUG: LogoutEvent triggered');
    emit(const AuthLoading(message: 'Signing out...'));
    
    try {
      print('🔐 DEBUG: Calling _authRepository.signOut()');
      await _authRepository.signOut();
      print('🔐 DEBUG: Sign out completed, waiting for AuthUserChanged event');
      // State will be updated via AuthUserChanged event
    } catch (e) {
      print('🔐 DEBUG: Error during logout: $e');
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


  // Phone Authentication Handlers
  Future<void> _onPhoneSignInRequested(
    PhoneSignInRequestedEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const PhoneAuthInProgress(message: 'Sending verification code...'));
    
    try {
      await (_authRepository as AuthRepository).verifyPhoneNumber(
        phoneNumber: event.phoneNumber,
        codeSent: (String verificationId, int? resendToken) {
          add(PhoneCodeSentEvent(
            verificationId: verificationId,
            resendToken: resendToken,
          ));
        },
        verificationCompleted: (PhoneAuthCredential credential) {
          add(PhoneVerificationCompletedEvent(credential: credential));
        },
        verificationFailed: (FirebaseAuthException e) {
          add(PhoneVerificationFailedEvent(
            error: _getPhoneAuthErrorMessage(e),
          ));
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          emit(PhoneAuthTimeout(verificationId: verificationId));
        },
      );
    } catch (e) {
      emit(PhoneAuthError(message: e.toString()));
    }
  }

  Future<void> _onPhoneCodeSent(
    PhoneCodeSentEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(PhoneAuthCodeSent(
      verificationId: event.verificationId,
      resendToken: event.resendToken,
      phoneNumber: '', // Pass the phone number from previous state
    ));
  }

  Future<void> _onPhoneVerificationCompleted(
    PhoneVerificationCompletedEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const PhoneAuthInProgress(message: 'Verifying...'));
    
    try {
      final userCredential = await (_authRepository as AuthRepository)
          .signInWithPhoneCredential(event.credential);
      
      if (userCredential.user != null) {
        add(AuthUserChanged(userCredential.user));
      }
    } catch (e) {
      emit(PhoneAuthError(message: e.toString()));
    }
  }

  Future<void> _onPhoneVerificationFailed(
    PhoneVerificationFailedEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(PhoneAuthError(message: event.error));
  }

  Future<void> _onVerifyPhoneCode(
    VerifyPhoneCodeEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const PhoneAuthInProgress(message: 'Verifying code...'));
    
    try {
      // Create credential from verification ID and SMS code
      final credential = PhoneAuthProvider.credential(
        verificationId: event.verificationId,
        smsCode: event.smsCode,
      );
      
      final userCredential = await (_authRepository as AuthRepository)
          .signInWithPhoneCredential(credential);
      
      if (userCredential.user != null) {
        // Check if this is a new user
        if (userCredential.additionalUserInfo?.isNewUser == true &&
            event.userType != null) {
          // Create user profile for new phone auth users
          await (_authRepository as AuthRepository).createUserProfile(
            uid: userCredential.user!.uid,
            name: event.displayName ?? 'Phone User',
            email: '', // Phone users might not have email
            userType: event.userType!,
          );
          
          // Update display name if provided
          if (event.displayName != null) {
            await _authRepository.updateDisplayName(event.displayName!);
          }
        }
        
        add(AuthUserChanged(userCredential.user));
      }
    } catch (e) {
      emit(PhoneAuthError(message: e.toString()));
    }
  }

  Future<void> _onResendPhoneCode(
    ResendPhoneCodeEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const PhoneAuthInProgress(message: 'Resending code...'));
    
    try {
      await (_authRepository as AuthRepository).verifyPhoneNumber(
        phoneNumber: event.phoneNumber,
        resendToken: event.resendToken,
        codeSent: (String verificationId, int? resendToken) {
          add(PhoneCodeSentEvent(
            verificationId: verificationId,
            resendToken: resendToken,
          ));
        },
        verificationCompleted: (PhoneAuthCredential credential) {
          add(PhoneVerificationCompletedEvent(credential: credential));
        },
        verificationFailed: (FirebaseAuthException e) {
          add(PhoneVerificationFailedEvent(
            error: _getPhoneAuthErrorMessage(e),
          ));
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          emit(PhoneAuthTimeout(verificationId: verificationId));
        },
      );
    } catch (e) {
      emit(PhoneAuthError(message: e.toString()));
    }
  }

  Future<void> _onLinkPhoneNumber(
    LinkPhoneNumberEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const PhoneAuthInProgress(message: 'Linking phone number...'));
    
    try {
      // Start phone verification for linking
      await (_authRepository as AuthRepository).verifyPhoneNumber(
        phoneNumber: event.phoneNumber,
        codeSent: (String verificationId, int? resendToken) {
          emit(PhoneAuthCodeSent(
            verificationId: verificationId,
            resendToken: resendToken,
            phoneNumber: event.phoneNumber,
          ));
        },
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-link if verification completes
          try {
            await (_authRepository as AuthRepository).linkPhoneNumber(credential);
            emit(const AuthSuccess(message: 'Phone number linked successfully'));
          } catch (e) {
            emit(PhoneAuthError(message: e.toString()));
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          emit(PhoneAuthError(message: _getPhoneAuthErrorMessage(e)));
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          emit(PhoneAuthTimeout(verificationId: verificationId));
        },
      );
    } catch (e) {
      emit(PhoneAuthError(message: e.toString()));
    }
  }

  String _getPhoneAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'The phone number is invalid. Please check and try again.';
      case 'missing-phone-number':
        return 'Please enter a phone number.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'operation-not-allowed':
        return 'Phone authentication is not enabled. Please contact support.';
      case 'invalid-verification-code':
        return 'Invalid verification code. Please try again.';
      case 'invalid-verification-id':
        return 'Invalid verification ID. Please request a new code.';
      case 'session-expired':
        return 'Verification session expired. Please request a new code.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      default:
        return 'Phone authentication failed: ${e.message}';
    }
  }

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }
}