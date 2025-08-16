import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/features/shared/models/user_profile.dart';
import 'package:hipop/features/market/screens/market_management_screen.dart';

// Mock classes
@GenerateMocks([AuthBloc])
import 'market_management_widget_test.mocks.dart';

void main() {
  group('Market Management Widget Tests', () {
    late MockAuthBloc mockAuthBloc;

    setUp(() {
      mockAuthBloc = MockAuthBloc();
    });

    testWidgets('should show usage summary card for free tier organizer', (WidgetTester tester) async {
      // Setup mock auth state with free tier organizer
      final userProfile = UserProfile(
        userId: 'test_organizer',
        displayName: 'Test Organizer',
        email: 'test@example.com',
        isMarketOrganizer: true,
        managedMarketIds: ['market1'], // Has 1 market
        userType: 'market_organizer',
      );

      when(mockAuthBloc.state).thenReturn(Authenticated(userProfile: userProfile));
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.value(Authenticated(userProfile: userProfile)));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: mockAuthBloc,
            child: const MarketManagementScreen(),
          ),
        ),
      );

      await tester.pump(); // Allow initial load
      await tester.pump(const Duration(seconds: 1)); // Allow for async operations

      // Should show usage summary card
      expect(find.text('Market Usage'), findsOneWidget);
      expect(find.text('1 of 2 markets used'), findsOneWidget);
      
      // Should show progress indicator
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('should show premium account indicator for premium organizer', (WidgetTester tester) async {
      // Setup mock auth state with premium tier organizer
      final userProfile = UserProfile(
        userId: 'premium_organizer',
        displayName: 'Premium Organizer',
        email: 'premium@example.com',
        isMarketOrganizer: true,
        managedMarketIds: ['market1', 'market2', 'market3'], // Has 3 markets (premium)
        userType: 'market_organizer',
      );

      when(mockAuthBloc.state).thenReturn(Authenticated(userProfile: userProfile));
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.value(Authenticated(userProfile: userProfile)));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: mockAuthBloc,
            child: const MarketManagementScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Should show premium account indicator
      expect(find.text('Premium Account'), findsOneWidget);
      expect(find.text('Unlimited markets available'), findsOneWidget);
    });

    testWidgets('should disable create button when at limit', (WidgetTester tester) async {
      // Setup mock auth state with organizer at limit
      final userProfile = UserProfile(
        userId: 'at_limit_organizer',
        displayName: 'At Limit Organizer',
        email: 'limit@example.com',
        isMarketOrganizer: true,
        managedMarketIds: ['market1', 'market2'], // Has 2 markets (at limit)
        userType: 'market_organizer',
      );

      when(mockAuthBloc.state).thenReturn(Authenticated(userProfile: userProfile));
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.value(Authenticated(userProfile: userProfile)));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: mockAuthBloc,
            child: const MarketManagementScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Should show disabled create button
      final createButton = find.byType(FloatingActionButton);
      expect(createButton, findsOneWidget);
      
      // Button should be disabled (grey color) and show lock icon
      final FloatingActionButton button = tester.widget(createButton);
      expect(button.backgroundColor, equals(Colors.grey));
      expect(find.byIcon(Icons.lock), findsOneWidget);
      expect(find.text('Limit Reached'), findsOneWidget);
    });

    testWidgets('should show upgrade dialog when tapping disabled button', (WidgetTester tester) async {
      // Setup mock auth state with organizer at limit
      final userProfile = UserProfile(
        userId: 'at_limit_organizer',
        displayName: 'At Limit Organizer',
        email: 'limit@example.com',
        isMarketOrganizer: true,
        managedMarketIds: ['market1', 'market2'], // Has 2 markets (at limit)
        userType: 'market_organizer',
      );

      when(mockAuthBloc.state).thenReturn(Authenticated(userProfile: userProfile));
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.value(Authenticated(userProfile: userProfile)));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: mockAuthBloc,
            child: const MarketManagementScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Tap the disabled create button
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      // Should show upgrade dialog
      expect(find.text('Market Limit Reached'), findsOneWidget);
      expect(find.text('You have reached your free tier limit of 2 markets.'), findsOneWidget);
      expect(find.text('Current Usage: 2 of 2 markets'), findsOneWidget);
      expect(find.text('Upgrade to Market Organizer Pro for unlimited markets!'), findsOneWidget);
      
      // Should show pro benefits
      expect(find.text('Pro Benefits:'), findsOneWidget);
      expect(find.text('• Unlimited markets'), findsOneWidget);
      expect(find.text('• Advanced analytics'), findsOneWidget);
      expect(find.text('• Vendor recruitment tools'), findsOneWidget);
      expect(find.text('• Priority support'), findsOneWidget);
      
      // Should show upgrade button
      expect(find.text('Upgrade'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('should enable create button when under limit', (WidgetTester tester) async {
      // Setup mock auth state with organizer under limit
      final userProfile = UserProfile(
        userId: 'under_limit_organizer',
        displayName: 'Under Limit Organizer',
        email: 'under@example.com',
        isMarketOrganizer: true,
        managedMarketIds: ['market1'], // Has 1 market (under limit)
        userType: 'market_organizer',
      );

      when(mockAuthBloc.state).thenReturn(Authenticated(userProfile: userProfile));
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.value(Authenticated(userProfile: userProfile)));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: mockAuthBloc,
            child: const MarketManagementScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Should show enabled create button
      final createButton = find.byType(FloatingActionButton);
      expect(createButton, findsOneWidget);
      
      // Button should be enabled (teal color) and show add icon
      final FloatingActionButton button = tester.widget(createButton);
      expect(button.backgroundColor, equals(Colors.teal));
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.text('Create Market'), findsOneWidget);
    });

    testWidgets('should show correct progress bar value', (WidgetTester tester) async {
      // Setup mock auth state with organizer with 1 market
      final userProfile = UserProfile(
        userId: 'progress_test_organizer',
        displayName: 'Progress Test Organizer',
        email: 'progress@example.com',
        isMarketOrganizer: true,
        managedMarketIds: ['market1'], // Has 1 market out of 2
        userType: 'market_organizer',
      );

      when(mockAuthBloc.state).thenReturn(Authenticated(userProfile: userProfile));
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.value(Authenticated(userProfile: userProfile)));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: mockAuthBloc,
            child: const MarketManagementScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Should show progress bar with 50% progress (1/2)
      final progressIndicator = find.byType(LinearProgressIndicator);
      expect(progressIndicator, findsOneWidget);
      
      final LinearProgressIndicator progress = tester.widget(progressIndicator);
      expect(progress.value, equals(0.5)); // 1/2 = 0.5
    });

    testWidgets('should handle non-organizer users gracefully', (WidgetTester tester) async {
      // Setup mock auth state with non-organizer user
      final userProfile = UserProfile(
        userId: 'vendor_user',
        displayName: 'Vendor User',
        email: 'vendor@example.com',
        isMarketOrganizer: false,
        managedMarketIds: [],
        userType: 'vendor',
      );

      when(mockAuthBloc.state).thenReturn(Authenticated(userProfile: userProfile));
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.value(Authenticated(userProfile: userProfile)));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: mockAuthBloc,
            child: const MarketManagementScreen(),
          ),
        ),
      );

      await tester.pump();

      // Should show access denied message
      expect(find.text('Only market organizers can access this feature'), findsOneWidget);
    });

    testWidgets('should handle unauthenticated users gracefully', (WidgetTester tester) async {
      // Setup mock auth state as unauthenticated
      when(mockAuthBloc.state).thenReturn(Unauthenticated());
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.value(Unauthenticated()));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: mockAuthBloc,
            child: const MarketManagementScreen(),
          ),
        ),
      );

      await tester.pump();

      // Should show sign in message
      expect(find.text('Please sign in to access market management'), findsOneWidget);
    });

    testWidgets('should show upgrade button in usage summary when at limit', (WidgetTester tester) async {
      // Setup mock auth state with organizer at limit
      final userProfile = UserProfile(
        userId: 'at_limit_organizer',
        displayName: 'At Limit Organizer',
        email: 'limit@example.com',
        isMarketOrganizer: true,
        managedMarketIds: ['market1', 'market2'], // Has 2 markets (at limit)
        userType: 'market_organizer',
      );

      when(mockAuthBloc.state).thenReturn(Authenticated(userProfile: userProfile));
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.value(Authenticated(userProfile: userProfile)));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: mockAuthBloc,
            child: const MarketManagementScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Should show upgrade button in usage summary
      expect(find.text('Upgrade'), findsWidgets); // May appear in multiple places
      expect(find.text('Upgrade to create unlimited markets'), findsOneWidget);
    });
  });
}