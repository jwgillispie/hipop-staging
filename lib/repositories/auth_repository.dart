import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class IAuthRepository {
  Stream<User?> get authStateChanges;
  User? get currentUser;
  Future<UserCredential> signInWithEmailAndPassword(String email, String password);
  Future<UserCredential> createUserWithEmailAndPassword(String email, String password);
  Future<void> signOut();
  Future<void> sendPasswordResetEmail(String email);
  Future<void> sendEmailVerification();
  Future<void> reloadUser();
  Future<void> updateDisplayName(String displayName);
}

class AuthRepository implements IAuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  @override
  User? get currentUser => _firebaseAuth.currentUser;

  @override
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update last login timestamp (following govvy pattern)
      if (userCredential.user != null) {
        await updateLastLogin(userCredential.user!.uid);
      }
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      throw AuthException('An unexpected error occurred. Please try again.');
    }
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      throw AuthException('An unexpected error occurred. Please try again.');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw AuthException('Failed to sign out. Please try again.');
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      throw AuthException('Failed to send password reset email. Please try again.');
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      throw AuthException('Failed to send verification email. Please try again.');
    }
  }

  @override
  Future<void> reloadUser() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.reload();
      }
    } catch (e) {
      throw AuthException('Failed to reload user. Please try again.');
    }
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName);
        await user.reload();
      }
    } catch (e) {
      throw AuthException('Failed to update display name. Please try again.');
    }
  }

  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String email,
    required String userType,
  }) async {
    try {
      print('DEBUG: Attempting to create user profile for UID: $uid');
      print('DEBUG: Name: $name, Email: $email, UserType: $userType');
      
      // Always use set() to create/update user profile (following govvy pattern)
      await _firestore.collection('users').doc(uid).set({
        'name': name,
        'email': email,
        'userType': userType,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });
      
      print('DEBUG: User profile created/updated successfully in Firestore');
    } catch (e) {
      print('DEBUG: Error creating user profile: $e');
      print('DEBUG: Error type: ${e.runtimeType}');
      if (e is FirebaseException) {
        print('DEBUG: Firebase error code: ${e.code}');
        print('DEBUG: Firebase error message: ${e.message}');
        throw AuthException('Firebase error: ${e.message ?? 'Unknown Firebase error'}');
      }
      throw AuthException('Failed to create user profile: $e');
    }
  }
  
  Future<void> updateLastLogin(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silently handle errors when updating last login
      print('DEBUG: Error updating last login: $e');
    }
  }

  AuthException _mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return AuthException('No user found with this email address.');
      case 'wrong-password':
        return AuthException('Incorrect password. Please try again.');
      case 'email-already-in-use':
        return AuthException('An account already exists with this email address.');
      case 'weak-password':
        return AuthException('Password is too weak. Please choose a stronger password.');
      case 'invalid-email':
        return AuthException('Please enter a valid email address.');
      case 'user-disabled':
        return AuthException('This account has been disabled. Please contact support.');
      case 'too-many-requests':
        return AuthException('Too many failed attempts. Please try again later.');
      case 'network-request-failed':
        return AuthException('Network error. Please check your connection and try again.');
      case 'invalid-credential':
        return AuthException('Invalid email or password. Please try again.');
      default:
        return AuthException('Authentication failed: ${e.message}');
    }
  }
}

class AuthException implements Exception {
  final String message;
  
  AuthException(this.message);
  
  @override
  String toString() => message;
}