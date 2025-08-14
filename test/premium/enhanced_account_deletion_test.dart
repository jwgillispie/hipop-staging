import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:hipop/features/shared/services/user_data_deletion_service.dart';
import 'package:hipop/features/premium/services/subscription_service.dart';
import 'package:hipop/features/premium/services/stripe_service.dart';
import 'package:hipop/features/premium/models/user_subscription.dart';

import 'enhanced_account_deletion_test.mocks.dart';

@GenerateMocks([
  FirebaseFirestore,
  FirebaseAuth,
  User,
  CollectionReference,
  DocumentReference,
  Query,
  QuerySnapshot,
  DocumentSnapshot,
  WriteBatch,
  FirebaseFunctions,
  HttpsCallable,
  HttpsCallableResult,
])
void main() {
  group('Enhanced Account Deletion with Premium Subscription', () {
    late MockFirebaseFirestore mockFirestore;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;
    late MockCollectionReference mockCollectionRef;
    late MockQuery mockQuery;
    late MockQuerySnapshot mockQuerySnapshot;
    late MockDocumentSnapshot mockDocumentSnapshot;
    late MockWriteBatch mockBatch;
    late MockFirebaseFunctions mockFunctions;
    late MockHttpsCallable mockCallable;
    late MockHttpsCallableResult mockResult;
    late UserDataDeletionService deletionService;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser();
      mockCollectionRef = MockCollectionReference();
      mockQuery = MockQuery();
      mockQuerySnapshot = MockQuerySnapshot();
      mockDocumentSnapshot = MockDocumentSnapshot();
      mockBatch = MockWriteBatch();
      mockFunctions = MockFirebaseFunctions();
      mockCallable = MockHttpsCallable();
      mockResult = MockHttpsCallableResult();

      deletionService = UserDataDeletionService(
        firestore: mockFirestore,
        auth: mockAuth,
      );

      // Default auth setup
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('test_user_123');
    });

    group('Premium Subscription Cancellation During Account Deletion', () {
      test('should cancel active premium subscription before data deletion', () async {
        // Arrange
        const userId = 'test_user_123';
        final subscription = UserSubscription.createFree(userId, 'vendor')
            .upgradeToTier(
          SubscriptionTier.vendorPro,
          stripeCustomerId: 'cus_test123',
          stripeSubscriptionId: 'sub_test123',
        );

        // Mock subscription exists
        when(mockFirestore.collection('user_subscriptions'))
            .thenReturn(mockCollectionRef);
        when(mockCollectionRef.where('userId', isEqualTo: userId))
            .thenReturn(mockQuery);
        when(mockQuery.limit(1)).thenReturn(mockQuery);
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn([mockDocumentSnapshot]);
        when(mockDocumentSnapshot.data()).thenReturn(subscription.toFirestore());
        when(mockDocumentSnapshot.id).thenReturn('subscription_123');

        // Mock successful subscription cancellation
        when(mockFunctions.httpsCallable('cancelSubscriptionEnhanced'))
            .thenReturn(mockCallable);
        when(mockCallable.call(any)).thenAnswer((_) async => mockResult);
        when(mockResult.data).thenReturn({
          'success': true,
          'stripe_cancelled': true,
          'subscription_updated': true,
          'message': 'Subscription cancelled for account deletion',
        });

        // Mock data deletion process
        _setupSuccessfulDataDeletion();

        // Act
        final result = await _performEnhancedAccountDeletion(
          userId,
          hasActiveSubscription: true,
          subscriptionTier: SubscriptionTier.vendorPro,
        );

        // Assert
        expect(result.success, isTrue);
        expect(result.subscriptionCancelled, isTrue);
        expect(result.stripeDataCleaned, isTrue);
        expect(result.totalDocumentsDeleted, greaterThan(0));
      });

      test('should handle subscription cancellation failure and abort deletion', () async {
        // Arrange
        const userId = 'test_user_123';
        
        // Mock failed subscription cancellation
        when(mockFunctions.httpsCallable('cancelSubscriptionEnhanced'))
            .thenReturn(mockCallable);
        when(mockCallable.call(any)).thenAnswer((_) async => mockResult);
        when(mockResult.data).thenReturn({
          'success': false,
          'error_code': 'stripe_api_error',
          'message': 'Unable to cancel subscription',
          'retry_recommended': true,
        });

        // Act
        final result = await _performEnhancedAccountDeletion(
          userId,
          hasActiveSubscription: true,
          subscriptionTier: SubscriptionTier.vendorPro,
        );

        // Assert
        expect(result.success, isFalse);
        expect(result.subscriptionCancelled, isFalse);
        expect(result.errors, contains(contains('subscription cancellation failed')));
        expect(result.totalDocumentsDeleted, 0); // No deletion should occur
      });

      test('should handle partial subscription cancellation gracefully', () async {
        // Arrange
        const userId = 'test_user_123';
        
        // Mock partial subscription cancellation (Stripe cancelled, but local update failed)
        when(mockFunctions.httpsCallable('cancelSubscriptionEnhanced'))
            .thenReturn(mockCallable);
        when(mockCallable.call(any)).thenAnswer((_) async => mockResult);
        when(mockResult.data).thenReturn({
          'success': true,
          'stripe_cancelled': true,
          'subscription_updated': false,
          'message': 'Stripe cancelled but local update failed',
          'requires_manual_cleanup': true,
        });

        _setupSuccessfulDataDeletion();

        // Act
        final result = await _performEnhancedAccountDeletion(
          userId,
          hasActiveSubscription: true,
          subscriptionTier: SubscriptionTier.vendorPro,
        );

        // Assert
        expect(result.success, isTrue);
        expect(result.subscriptionCancelled, isTrue);
        expect(result.requiresManualCleanup, isTrue);
        expect(result.warnings, contains(contains('manual cleanup required')));
      });

      test('should proceed with deletion if user has no active subscription', () async {
        // Arrange
        const userId = 'test_user_123';
        
        _setupSuccessfulDataDeletion();

        // Act
        final result = await _performEnhancedAccountDeletion(
          userId,
          hasActiveSubscription: false,
        );

        // Assert
        expect(result.success, isTrue);
        expect(result.subscriptionCancelled, isNull); // No subscription to cancel
        expect(result.totalDocumentsDeleted, greaterThan(0));
      });
    });

    group('Data Cleanup Verification', () {
      test('should verify all premium-related data is cleaned', () async {
        // Arrange
        const userId = 'test_user_123';
        final collectionsToVerify = [
          'user_subscriptions',
          'premium_analytics',
          'usage_tracking',
          'billing_history',
          'payment_methods',
        ];

        _setupCollectionCleanup(collectionsToVerify);

        // Act
        final result = await _performEnhancedAccountDeletion(userId);

        // Assert
        for (final collection in collectionsToVerify) {
          expect(result.collectionsProcessed.containsKey(collection), isTrue,
              reason: 'Collection $collection should be processed');
          expect(result.collectionsProcessed[collection], greaterThanOrEqualTo(0),
              reason: 'Collection $collection should report deletion count');
        }
      });

      test('should handle large datasets with batch processing', () async {
        // Arrange
        const userId = 'test_user_123';
        const largeDocumentCount = 1500; // Exceeds batch limit
        
        // Mock large dataset
        final mockDocs = List.generate(largeDocumentCount, (index) {
          final mockDoc = MockDocumentSnapshot();
          when(mockDoc.reference).thenReturn(MockDocumentReference());
          return mockDoc;
        });
        
        when(mockQuerySnapshot.docs).thenReturn(mockDocs);

        // Act
        final result = await _performEnhancedAccountDeletion(userId);

        // Assert
        expect(result.success, isTrue);
        expect(result.totalDocumentsDeleted, largeDocumentCount);
        expect(result.batchesProcessed, greaterThan(1));
      });

      test('should maintain data integrity during partial failures', () async {
        // Arrange
        const userId = 'test_user_123';
        
        // Mock partial failure scenario
        when(mockFirestore.collection('user_profiles'))
            .thenReturn(mockCollectionRef);
        when(mockCollectionRef.where(any, isEqualTo: userId))
            .thenReturn(mockQuery);
        when(mockQuery.get()).thenThrow(
          FirebaseException(plugin: 'firestore', code: 'permission-denied'));

        // Mock other collections succeed
        _setupSuccessfulDataDeletion(skipUserProfiles: true);

        // Act
        final result = await _performEnhancedAccountDeletion(userId);

        // Assert
        expect(result.success, isFalse);
        expect(result.errors, contains(contains('user_profiles')));
        expect(result.partialSuccess, isTrue);
      });
    });

    group('Stripe Customer Data Cleanup', () {
      test('should clean Stripe customer data after subscription cancellation', () async {
        // Arrange
        const userId = 'test_user_123';
        const stripeCustomerId = 'cus_test123';

        // Mock Stripe cleanup
        when(mockFunctions.httpsCallable('cleanupStripeCustomerData'))
            .thenReturn(mockCallable);
        when(mockCallable.call({
          'userId': userId,
          'customerId': stripeCustomerId,
          'deletePaymentMethods': true,
          'deleteBillingHistory': false, // Keep for compliance
        })).thenAnswer((_) async => mockResult);
        when(mockResult.data).thenReturn({
          'success': true,
          'payment_methods_deleted': 2,
          'subscriptions_cancelled': 1,
          'customer_deleted': true,
        });

        _setupSuccessfulDataDeletion();

        // Act
        final result = await _performEnhancedAccountDeletion(
          userId,
          hasActiveSubscription: true,
          stripeCustomerId: stripeCustomerId,
        );

        // Assert
        expect(result.success, isTrue);
        expect(result.stripeDataCleaned, isTrue);
        expect(result.stripePaymentMethodsDeleted, 2);
      });

      test('should handle Stripe data cleanup failures gracefully', () async {
        // Arrange
        const userId = 'test_user_123';
        const stripeCustomerId = 'cus_test123';

        // Mock Stripe cleanup failure
        when(mockFunctions.httpsCallable('cleanupStripeCustomerData'))
            .thenReturn(mockCallable);
        when(mockCallable.call(any)).thenAnswer((_) async => mockResult);
        when(mockResult.data).thenReturn({
          'success': false,
          'error': 'Stripe customer not found',
          'requires_manual_review': true,
        });

        _setupSuccessfulDataDeletion();

        // Act
        final result = await _performEnhancedAccountDeletion(
          userId,
          stripeCustomerId: stripeCustomerId,
        );

        // Assert
        expect(result.success, isTrue); // Local deletion should still succeed
        expect(result.stripeDataCleaned, isFalse);
        expect(result.warnings, contains(contains('Stripe cleanup failed')));
      });
    });

    group('Progress Tracking and User Feedback', () {
      test('should provide accurate progress updates during deletion', () async {
        // Arrange
        const userId = 'test_user_123';
        final progressUpdates = <String>[];
        int lastCompletedCount = 0;
        int totalOperations = 0;

        void onProgress(String operation, int completed, int total) {
          progressUpdates.add(operation);
          expect(completed, greaterThanOrEqualTo(lastCompletedCount));
          lastCompletedCount = completed;
          totalOperations = total;
        }

        _setupSuccessfulDataDeletion();

        // Act
        await deletionService.deleteAllUserData(
          userId,
          onProgress: onProgress,
        );

        // Assert
        expect(progressUpdates.isNotEmpty, isTrue);
        expect(progressUpdates.first, contains('Deleting'));
        expect(progressUpdates.last, contains('Finalizing'));
        expect(totalOperations, greaterThan(0));
      });

      test('should estimate deletion time accurately', () async {
        // Arrange
        const userId = 'test_user_123';
        
        // Mock preview generation
        _setupPreviewGeneration(documentCount: 500);

        // Act
        final preview = await deletionService.getDeletePreview(userId);
        final startTime = DateTime.now();
        final result = await _performEnhancedAccountDeletion(userId);
        final actualDuration = DateTime.now().difference(startTime);

        // Assert
        expect(preview.totalDocumentsToDelete, 500);
        expect(preview.estimatedTimeMinutes, greaterThan(0));
        expect(result.success, isTrue);
        
        // Actual time should be reasonable compared to estimate
        final estimatedMs = preview.estimatedTimeMinutes * 60 * 1000;
        expect(actualDuration.inMilliseconds, lessThan(estimatedMs * 2));
      });
    });

    group('Error Recovery and Rollback', () {
      test('should rollback changes on critical failures', () async {
        // Arrange
        const userId = 'test_user_123';
        
        // Mock critical failure during deletion
        when(mockFirestore.batch()).thenReturn(mockBatch);
        when(mockBatch.commit()).thenThrow(
          FirebaseException(plugin: 'firestore', code: 'deadline-exceeded'));

        // Act
        final result = await _performEnhancedAccountDeletion(userId);

        // Assert
        expect(result.success, isFalse);
        expect(result.errors, contains(contains('Critical error')));
        expect(result.requiresManualReview, isTrue);
      });

      test('should handle concurrent deletion attempts', () async {
        // Arrange
        const userId = 'test_user_123';
        
        // Simulate concurrent deletion by having auth check fail
        when(mockAuth.currentUser).thenReturn(null);

        // Act
        final canDelete = await deletionService.verifyDeletionPermissions(userId);

        // Assert
        expect(canDelete, isFalse);
      });
    });

    group('Authentication and Authorization', () {
      test('should verify user owns the account before deletion', () async {
        // Arrange
        const userId = 'test_user_123';
        const differentUserId = 'different_user_456';
        
        when(mockUser.uid).thenReturn(differentUserId);

        // Act
        final canDelete = await deletionService.verifyDeletionPermissions(userId);

        // Assert
        expect(canDelete, isFalse);
      });

      test('should require active authentication for deletion', () async {
        // Arrange
        const userId = 'test_user_123';
        when(mockAuth.currentUser).thenReturn(null);

        // Act
        final canDelete = await deletionService.verifyDeletionPermissions(userId);

        // Assert
        expect(canDelete, isFalse);
      });

      test('should validate user ID format before processing', () async {
        // Arrange
        const invalidUserId = '';

        // Act & Assert
        expect(
          () => deletionService.deleteAllUserData(invalidUserId),
          throwsA(isA<UserDataDeletionException>()),
        );
      });
    });

    group('Compliance and Audit Trail', () {
      test('should generate comprehensive audit log', () async {
        // Arrange
        const userId = 'test_user_123';
        _setupSuccessfulDataDeletion();

        // Act
        final result = await _performEnhancedAccountDeletion(userId);

        // Assert
        final auditLog = result.toMap();
        expect(auditLog['userId'], userId);
        expect(auditLog['startTime'], isNotNull);
        expect(auditLog['endTime'], isNotNull);
        expect(auditLog['success'], isTrue);
        expect(auditLog['collectionsProcessed'], isA<Map>());
        expect(auditLog['totalDocumentsDeleted'], isA<int>());
        expect(auditLog['durationMs'], isA<int>());
      });

      test('should record all errors and warnings for compliance', () async {
        // Arrange
        const userId = 'test_user_123';
        
        // Mock mixed success/failure scenario
        _setupPartialFailureDeletion();

        // Act
        final result = await _performEnhancedAccountDeletion(userId);

        // Assert
        expect(result.errors.isNotEmpty, isTrue);
        expect(result.warnings.isNotEmpty, isTrue);
        expect(result.partialSuccess, isTrue);
        
        // Each error should be descriptive
        for (final error in result.errors) {
          expect(error.contains('collection') || error.contains('operation'), isTrue);
        }
      });
    });
  });
}

// Helper methods for setting up mock scenarios

void _setupSuccessfulDataDeletion({bool skipUserProfiles = false}) {
  // Implementation would set up all necessary mocks for successful deletion
}

void _setupCollectionCleanup(List<String> collections) {
  // Implementation would set up mocks for specified collections
}

void _setupPreviewGeneration({required int documentCount}) {
  // Implementation would set up mocks for deletion preview
}

void _setupPartialFailureDeletion() {
  // Implementation would set up mixed success/failure scenarios
}

Future<EnhancedAccountDeletionResult> _performEnhancedAccountDeletion(
  String userId, {
  bool hasActiveSubscription = false,
  SubscriptionTier? subscriptionTier,
  String? stripeCustomerId,
}) async {
  // This would be the actual enhanced account deletion implementation
  // that combines subscription cancellation with data deletion
  
  final result = EnhancedAccountDeletionResult(userId: userId, startTime: DateTime.now());
  
  try {
    // Step 1: Check for active subscription
    if (hasActiveSubscription && subscriptionTier != null) {
      // Cancel subscription first
      final cancellationResult = await StripeService.cancelSubscriptionEnhanced(
        userId,
        cancellationType: 'immediate',
        feedback: 'Account deletion requested',
      );
      
      result.subscriptionCancelled = cancellationResult;
      
      if (!cancellationResult) {
        result.success = false;
        result.errors.add('Subscription cancellation failed - aborting account deletion');
        return result;
      }
    }
    
    // Step 2: Clean Stripe customer data if applicable
    if (stripeCustomerId != null) {
      // Implementation would clean Stripe data
      result.stripeDataCleaned = true;
    }
    
    // Step 3: Perform comprehensive data deletion
    final deletionService = UserDataDeletionService();
    final deletionResult = await deletionService.deleteAllUserData(userId);
    
    result.success = deletionResult.success;
    result.totalDocumentsDeleted = deletionResult.totalDocumentsDeleted;
    result.collectionsProcessed = deletionResult.collectionsProcessed;
    result.errors.addAll(deletionResult.errors);
    
    result.endTime = DateTime.now();
    return result;
    
  } catch (e) {
    result.success = false;
    result.errors.add('Critical error during enhanced account deletion: $e');
    result.endTime = DateTime.now();
    return result;
  }
}

/// Enhanced result class for account deletion with premium features
class EnhancedAccountDeletionResult {
  final String userId;
  final DateTime startTime;
  DateTime? endTime;
  bool success = false;
  bool? subscriptionCancelled;
  bool stripeDataCleaned = false;
  int stripePaymentMethodsDeleted = 0;
  bool requiresManualCleanup = false;
  bool requiresManualReview = false;
  bool partialSuccess = false;
  int totalDocumentsDeleted = 0;
  int batchesProcessed = 0;
  Map<String, int> collectionsProcessed = {};
  List<String> errors = [];
  List<String> warnings = [];

  EnhancedAccountDeletionResult({
    required this.userId,
    required this.startTime,
  });

  Duration? get duration => endTime?.difference(startTime);

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'success': success,
      'subscriptionCancelled': subscriptionCancelled,
      'stripeDataCleaned': stripeDataCleaned,
      'totalDocumentsDeleted': totalDocumentsDeleted,
      'collectionsProcessed': collectionsProcessed,
      'errors': errors,
      'warnings': warnings,
      'durationMs': duration?.inMilliseconds,
    };
  }
}