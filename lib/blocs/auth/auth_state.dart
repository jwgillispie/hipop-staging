import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_profile.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {
  final String? message;
  
  const AuthLoading({this.message});
  
  @override
  List<Object?> get props => [message];
}

class Authenticated extends AuthState {
  final User user;
  final String userType;
  final UserProfile? userProfile;
  
  const Authenticated({
    required this.user, 
    required this.userType,
    this.userProfile,
  });
  
  @override
  List<Object?> get props => [user, userType, userProfile];
}

class Unauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  final String? errorCode;
  
  const AuthError({required this.message, this.errorCode});
  
  @override
  List<Object?> get props => [message, errorCode];
}

class PasswordResetSent extends AuthState {
  final String email;
  
  const PasswordResetSent({required this.email});
  
  @override
  List<Object> get props => [email];
}

class EmailVerificationSent extends AuthState {}