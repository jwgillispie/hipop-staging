import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter/foundation.dart';
import 'core/config/firebase_options.dart';
import 'repositories/auth_repository.dart';
import 'repositories/vendor_posts_repository.dart';
import 'repositories/favorites_repository.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_event.dart';
import 'blocs/auth/auth_state.dart';
import 'blocs/favorites/favorites_bloc.dart';
import 'core/routing/app_router.dart';
import 'features/shared/services/remote_config_service.dart';

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
    
    // Initialize Stripe (skip on web for now)
    if (!kIsWeb) {
      await _initializeStripe();
    }
    
    // Initialize Remote Config in background - don't block app startup
    RemoteConfigService.instance.catchError((e) => null);
  } catch (e) {
    debugPrint('⚠️ Initialization warning: $e');
    // Continue with app startup even if some services fail
  }
}

Future<void> _initializeStripe() async {
  final publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'];
  if (publishableKey != null && publishableKey.isNotEmpty) {
    Stripe.publishableKey = publishableKey;
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
                title: 'HiPop - STAGING',
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
                  useMaterial3: true,
                ),
                builder: (context, child) {
                  return Banner(
                    message: 'STAGING',
                    location: BannerLocation.topStart,
                    color: Colors.pink,
                    textStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    child: child!,
                  );
                },
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