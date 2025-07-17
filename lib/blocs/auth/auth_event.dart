import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthStarted extends AuthEvent {}

class AuthUserChanged extends AuthEvent {
  final dynamic user;
  
  const AuthUserChanged(this.user);
  
  @override
  List<Object?> get props => [user];
}

class LoginEvent extends AuthEvent {
  final String email;
  final String password;
  
  const LoginEvent({required this.email, required this.password});
  
  @override
  List<Object> get props => [email, password];
}

class SignUpEvent extends AuthEvent {
  final String name;
  final String email;
  final String password;
  final String userType;
  
  const SignUpEvent({
    required this.name,
    required this.email,
    required this.password,
    required this.userType,
  });
  
  @override
  List<Object> get props => [name, email, password, userType];
}

class LogoutEvent extends AuthEvent {}

class ForgotPasswordEvent extends AuthEvent {
  final String email;
  
  const ForgotPasswordEvent({required this.email});
  
  @override
  List<Object> get props => [email];
}

class SendEmailVerificationEvent extends AuthEvent {}

class ReloadUserEvent extends AuthEvent {}