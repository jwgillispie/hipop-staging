import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter/foundation.dart';
import 'core/config/firebase_options.dart';
import 'core/theme/hipop_theme.dart';
import 'repositories/auth_repository.dart';
import 'repositories/vendor_posts_repository.dart';
import 'repositories/favorites_repository.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_event.dart';
import 'blocs/auth/auth_state.dart';
import 'blocs/favorites/favorites_bloc.dart';
import 'blocs/subscription/subscription_bloc.dart';
import 'core/routing/app_router.dart';
import 'features/shared/services/remote_config_service.dart';
import 'features/shared/services/real_time_analytics_service.dart';
import 'features/premium/services/revenuecat_service.dart';
import 'features/premium/services/subscription_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await _initializeApp();
    runApp(const HiPopApp());
  } catch (e) {
    runApp(ErrorApp(error: e.toString()));
  }
}

Future<void> _initializeApp() async {
  try {
    // Load environment variables
    await dotenv.load(fileName: ".env");
    
    // Initialize Firebase
    await _initializeFirebase();
    
    // Initialize Remote Config BEFORE Stripe
    // This ensures config values are available for Stripe initialization
    try {
      await RemoteConfigService.instance;
      debugPrint('✅ Remote Config initialized successfully during app startup');
      
      // In debug mode, run configuration test
      if (kDebugMode) {
        await RemoteConfigService.debugConfiguration();
      }
    } catch (e) {
      debugPrint('⚠️ Remote Config initialization failed during startup: $e');
      // Continue with app startup, fallback to .env values will be used
    }
    
    // Initialize Stripe AFTER Remote Config
    await _initializeStripe();
    
    // Initialize RevenueCat for mobile subscriptions
    await _initializeRevenueCat();
    
    // Initialize Analytics with consent
    await _initializeAnalytics();
  } catch (e) {
    debugPrint('WARNING: Initialization warning: $e');
    // Continue with app startup even if some services fail
  }
}

Future<void> _initializeStripe() async {
  try {
    // Try to get key from Remote Config first (following the pattern of other working functions)
    String publishableKey = await RemoteConfigService.getStripePublishableKey();
    
    // If Remote Config fails or returns empty, use platform-specific fallbacks
    if (publishableKey.isEmpty) {
      if (kIsWeb) {
        // Fallback for web - only if Remote Config fails
        // This is your live publishable key - safe to expose
        publishableKey = 'pk_live_51RsQNrC8FCSHt0iKEEfaV2Kd98wwFHAw0d6rcvLR7kxGzvfWuOxhaOvYOD2GRvODOR5eAQnFC7p622ech7BDGddy00IP3xtXun';
        debugPrint('⚠️ Using hardcoded fallback key for web (Remote Config failed)');
      } else {
        // For mobile, try to load from .env
        publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
        debugPrint('⚠️ Using .env fallback key for mobile (Remote Config failed)');
      }
    } else {
      debugPrint('✅ Using Stripe key from Remote Config');
    }
    
    if (publishableKey.isNotEmpty) {
      Stripe.publishableKey = publishableKey;
      
      // Set merchant identifier for Apple Pay (iOS only) - skip on web
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        Stripe.merchantIdentifier = dotenv.env['STRIPE_MERCHANT_IDENTIFIER'] ?? 'merchant.com.hipop';
        // Return URL will be set in Payment Sheet parameters
      }
      
      debugPrint('SUCCESS: Stripe initialized successfully for ${kIsWeb ? 'web' : 'mobile'}');
    } else {
      debugPrint('WARNING: Stripe publishable key not found');
    }
  } catch (e) {
    debugPrint('ERROR: Failed to initialize Stripe: $e');
    // Continue without Stripe rather than crash the app
  }
}

Future<void> _initializeRevenueCat() async {
  try {
    // Only initialize on mobile platforms
    if (kIsWeb) {
      debugPrint('⚠️ RevenueCat skipped - Web platform detected');
      return;
    }
    
    // Skip on unsupported platforms (desktop)
    // Use defaultTargetPlatform to avoid Platform calls on web
    if (defaultTargetPlatform != TargetPlatform.iOS && 
        defaultTargetPlatform != TargetPlatform.android) {
      debugPrint('⚠️ RevenueCat skipped - Unsupported platform');
      return;
    }
    
    // Initialize RevenueCat service
    await RevenueCatService().initialize();
    debugPrint('✅ RevenueCat initialized successfully');
    
    // Start listening to subscription changes
    SubscriptionSyncService.startListeningToSubscriptionChanges();
    
    // Check current subscription status
    await SubscriptionSyncService.checkAndSyncSubscriptionStatus();
  } catch (e) {
    debugPrint('⚠️ RevenueCat initialization failed: $e');
    // Continue without RevenueCat - Stripe will be used as fallback
  }
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      // Firebase already initialized, which is fine
      return;
    }
    rethrow;
  }
}

Future<void> _initializeAnalytics() async {
  try {
    // Initialize analytics service and request consent
    await RealTimeAnalyticsService.initialize();
    await RealTimeAnalyticsService.requestTrackingConsent();
    debugPrint('SUCCESS: Analytics initialized with consent');
  } catch (e) {
    debugPrint('WARNING: Analytics initialization failed: $e');
    // Continue without analytics rather than crash the app
  }
}

class HiPopApp extends StatelessWidget {
  const HiPopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<IAuthRepository>(
          create: (context) => AuthRepository(),
        ),
        RepositoryProvider<IVendorPostsRepository>(
          create: (context) => VendorPostsRepository(),
        ),
        RepositoryProvider<FavoritesRepository>(
          create: (context) => FavoritesRepository(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(
              authRepository: context.read<IAuthRepository>(),
            )..add(AuthStarted()),
          ),
          BlocProvider<FavoritesBloc>(
            create: (context) => FavoritesBloc(
              favoritesRepository: context.read<FavoritesRepository>(),
            ),
          ),
          BlocProvider<SubscriptionBloc>(
            create: (context) => SubscriptionBloc(),
          ),
        ],
        child: Builder(
          builder: (context) {
            final authBloc = context.read<AuthBloc>();
            return BlocListener<AuthBloc, AuthState>(
              listener: (context, state) {
                // Automatically reload favorites when auth state changes
                if (state is Authenticated) {
                  context.read<FavoritesBloc>().add(LoadFavorites(userId: state.user.uid));
                } else if (state is Unauthenticated) {
                  context.read<FavoritesBloc>().add(const LoadFavorites());
                }
              },
              child: MaterialApp.router(
                title: 'HiPop',
                debugShowCheckedModeBanner: false,
                theme: HiPopTheme.lightTheme,
                darkTheme: HiPopTheme.darkTheme,
                themeMode: ThemeMode.system,
                // builder: (context, child) {
                //   return Banner(
                //     message: 'STAGING',
                //     location: BannerLocation.topStart,
                //     color: Colors.pink,
                //     textStyle: const TextStyle(
                //       color: Colors.white,
                //       fontSize: 12,
                //       fontWeight: FontWeight.bold,
                //     ),
                //     child: child!,
                //   );
                // },
                routerConfig: AppRouter.createRouter(authBloc),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HiPop - Error',
      home: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.red, Colors.redAccent],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Initialization Error',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to initialize the app: $error',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      main();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}