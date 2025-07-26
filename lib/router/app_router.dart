import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../repositories/vendor_posts_repository.dart';
import '../screens/onboarding_screen.dart';
import '../screens/auth_landing_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/market_detail_screen.dart';
import '../screens/shopper_home.dart';
import '../screens/vendor_dashboard.dart';
import '../screens/create_popup_screen.dart';
import '../screens/vendor_my_popups_screen.dart';
import '../screens/vendor_profile_screen.dart';
import '../screens/change_password_screen.dart';
import '../screens/vendor_post_detail_screen.dart';
import '../screens/organizer_dashboard.dart';
import '../screens/vendor_applications_screen.dart';
import '../screens/custom_items_screen.dart';
import '../screens/organizer_analytics_screen.dart';
import '../screens/organizer_profile_screen.dart';
import '../screens/vendor_management_screen.dart';
import '../screens/admin_fix_screen.dart';
import '../screens/market_management_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/organizer_calendar_screen.dart';
import '../screens/shopper_recipes_screen.dart';
import '../screens/recipe_detail_screen.dart';
import '../screens/vendor_detail_screen.dart';
import '../screens/shopper_calendar_screen.dart';
import '../screens/organizer_onboarding_screen.dart';
import '../screens/vendor_application_status_screen.dart';
import '../screens/vendor_market_permissions_screen.dart';
import '../screens/vendor_popup_creation_screen.dart';
import '../screens/legal_documents_screen.dart';
import '../screens/organizer_event_management_screen.dart';
import '../screens/vendor_signup_screen.dart';
import '../screens/market_organizer_comprehensive_signup_screen.dart';
import '../screens/account_verification_pending_screen.dart';
import '../screens/ceo_verification_dashboard_screen.dart';
import '../models/market.dart';
import '../models/vendor_post.dart';

class AppRouter {
  static GoRouter createRouter(AuthBloc authBloc) {
    return GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          name: 'onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/auth',
          name: 'auth',
          builder: (context, state) => const AuthLandingScreen(),
        ),
        GoRoute(
          path: '/legal',
          name: 'legal',
          builder: (context, state) => const LegalDocumentsScreen(),
        ),
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) {
            final userType = state.uri.queryParameters['type'] ?? 'shopper';
            return AuthScreen(userType: userType, isLogin: true);
          },
        ),
        GoRoute(
          path: '/signup',
          name: 'signup',
          builder: (context, state) {
            final userType = state.uri.queryParameters['type'] ?? 'shopper';
            if (userType == 'market_organizer') {
              return const MarketOrganizerComprehensiveSignupScreen();
            } else if (userType == 'vendor') {
              return const VendorSignupScreen();
            }
            return AuthScreen(userType: userType, isLogin: false);
          },
        ),
        GoRoute(
          path: '/account-verification-pending',
          name: 'accountVerificationPending',
          builder: (context, state) => const AccountVerificationPendingScreen(),
        ),
        GoRoute(
          path: '/vendor-verification-pending',
          name: 'vendorVerificationPending',
          builder: (context, state) => const AccountVerificationPendingScreen(),
        ),
        GoRoute(
          path: '/organizer-verification-pending',
          name: 'organizerVerificationPending',
          builder: (context, state) => const AccountVerificationPendingScreen(),
        ),
        GoRoute(
          path: '/ceo-verification-dashboard',
          name: 'ceoVerificationDashboard',
          builder: (context, state) => const CeoVerificationDashboardScreen(),
        ),
        GoRoute(
          path: '/shopper',
          name: 'shopper',
          builder: (context, state) => const ShopperHome(),
          routes: [
            GoRoute(
              path: 'market-detail',
              name: 'marketDetail',
              builder: (context, state) {
                final market = state.extra as Market;
                return MarketDetailScreen(market: market);
              },
            ),
            GoRoute(
              path: 'vendor-post-detail',
              name: 'vendorPostDetail',
              builder: (context, state) {
                final vendorPost = state.extra as VendorPost;
                return VendorPostDetailScreen(vendorPost: vendorPost);
              },
            ),
            GoRoute(
              path: 'favorites',
              name: 'favorites',
              builder: (context, state) => const FavoritesScreen(),
            ),
            GoRoute(
              path: 'calendar',
              name: 'shopperCalendar',
              builder: (context, state) => const ShopperCalendarScreen(),
            ),
            GoRoute(
              path: 'recipes',
              name: 'shopperRecipes',
              builder: (context, state) => const ShopperRecipesScreen(),
            ),
            GoRoute(
              path: 'recipe-detail/:recipeId',
              name: 'recipeDetail',
              builder: (context, state) {
                final recipeId = state.pathParameters['recipeId']!;
                return RecipeDetailScreen(recipeId: recipeId);
              },
            ),
            GoRoute(
              path: 'vendor-detail/:vendorId',
              name: 'vendorDetail',
              builder: (context, state) {
                final vendorId = state.pathParameters['vendorId']!;
                return VendorDetailScreen(vendorId: vendorId);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/vendor',
          name: 'vendor',
          builder: (context, state) => const VendorDashboard(),
          routes: [
            GoRoute(
              path: 'create-popup',
              name: 'createPopup',
              builder: (context, state) => CreatePopUpScreen(
                postsRepository: context.read<IVendorPostsRepository>(),
              ),
            ),
            GoRoute(
              path: 'my-popups',
              name: 'myPopups',
              builder: (context, state) => const VendorMyPopupsScreen(),
            ),
            GoRoute(
              path: 'profile',
              name: 'vendorProfile',
              builder: (context, state) => const VendorProfileScreen(),
            ),
            GoRoute(
              path: 'change-password',
              name: 'changePassword',
              builder: (context, state) => const ChangePasswordScreen(),
            ),
            GoRoute(
              path: 'applications',
              name: 'vendorApplicationStatus',
              builder: (context, state) => const VendorApplicationStatusScreen(),
            ),
            GoRoute(
              path: 'market-permissions',
              name: 'vendorMarketPermissions',
              builder: (context, state) => const VendorMarketPermissionsScreen(),
            ),
            GoRoute(
              path: 'popup-creation',
              name: 'vendorPopupCreation',
              builder: (context, state) => const VendorPopupCreationScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/organizer',
          name: 'organizer',
          builder: (context, state) => const OrganizerDashboard(),
          routes: [
            GoRoute(
              path: 'market-management',
              name: 'marketManagement',
              builder: (context, state) => const MarketManagementScreen(),
            ),
            GoRoute(
              path: 'vendor-management',
              name: 'vendorManagement',
              builder: (context, state) => const VendorManagementScreen(),
            ),
            GoRoute(
              path: 'vendor-applications',
              name: 'vendorApplications',
              builder: (context, state) => const VendorApplicationsScreen(),
            ),
            GoRoute(
              path: 'event-management',
              name: 'eventManagement',
              builder: (context, state) => const OrganizerEventManagementScreen(),
            ),
            GoRoute(
              path: 'custom-items',
              name: 'customItems',
              builder: (context, state) => const CustomItemsScreen(),
            ),
            GoRoute(
              path: 'analytics',
              name: 'analytics',
              builder: (context, state) => const OrganizerAnalyticsScreen(),
            ),
            GoRoute(
              path: 'profile',
              name: 'organizerProfile',
              builder: (context, state) => const OrganizerProfileScreen(),
            ),
            GoRoute(
              path: 'change-password',
              name: 'organizerChangePassword',
              builder: (context, state) => const ChangePasswordScreen(),
            ),
            GoRoute(
              path: 'calendar',
              name: 'organizerCalendar',
              builder: (context, state) => const OrganizerCalendarScreen(),
            ),
            GoRoute(
              path: 'onboarding',
              name: 'organizerOnboarding',
              builder: (context, state) => const OrganizerOnboardingScreen(),
            ),
            if (kDebugMode)
              GoRoute(
                path: 'admin-fix',
                name: 'adminFix',
                builder: (context, state) => const AdminFixScreen(),
              ),
          ],
        ),
        // TEMPORARILY HIDDEN: Public vendor application form (only showing permissions for now)
        // GoRoute(
        //   path: '/apply/:marketId',
        //   name: 'vendorApplication',
        //   builder: (context, state) {
        //     final marketId = state.pathParameters['marketId']!;
        //     return VendorApplicationForm(
        //       marketId: marketId,
        //     );
        //   },
        // ),
      ],
      redirect: (BuildContext context, GoRouterState state) {
        final authState = authBloc.state;
        
        // If authenticated, redirect based on user type and verification status
        if (authState is Authenticated) {
          final userProfile = authState.userProfile;
          
          // Allow access to CEO dashboard for anyone (it has its own access control)
          if (state.matchedLocation == '/ceo-verification-dashboard') {
            return null;
          }
          
          // Check verification status for vendors and market organizers
          if (userProfile != null && (userProfile.userType == 'vendor' || userProfile.userType == 'market_organizer')) {
            final verificationPendingRoutes = [
              '/account-verification-pending',
              '/vendor-verification-pending', 
              '/organizer-verification-pending'
            ];
            
            if (!userProfile.isVerified && !verificationPendingRoutes.contains(state.matchedLocation)) {
              // Redirect unverified users to pending screen, unless they're already there
              return '/account-verification-pending';
            }
            
            if (userProfile.isVerified && verificationPendingRoutes.contains(state.matchedLocation)) {
              // Redirect verified users away from pending screen
              switch (userProfile.userType) {
                case 'vendor':
                  return '/vendor';
                case 'market_organizer':
                  return '/organizer';
                default:
                  return '/shopper';
              }
            }
          }
          
          final isAuthRoute = ['/auth', '/login', '/signup'].contains(state.matchedLocation);
          if (isAuthRoute) {
            switch (authState.userType) {
              case 'vendor':
                return '/vendor';
              case 'market_organizer':
                return '/organizer';
              default:
                return '/shopper';
            }
          }
          
          // Skip onboarding for vendors, organizers, and shoppers - they go straight to dashboard
          if ((authState.userType == 'vendor' || authState.userType == 'market_organizer' || authState.userType == 'shopper') && 
              state.matchedLocation == '/onboarding') {
            switch (authState.userType) {
              case 'vendor':
                return '/vendor';
              case 'market_organizer':
                return '/organizer';
              case 'shopper':
                return '/shopper';
              default:
                return '/shopper';
            }
          }
          
          // Prevent wrong user type from accessing wrong routes
          if (authState.userType == 'vendor' && 
              (state.matchedLocation.startsWith('/shopper') || state.matchedLocation.startsWith('/organizer'))) {
            return '/vendor';
          }
          if (authState.userType == 'market_organizer' && 
              (state.matchedLocation.startsWith('/shopper') || state.matchedLocation.startsWith('/vendor'))) {
            return '/organizer';
          }
          if (authState.userType == 'shopper' && 
              (state.matchedLocation.startsWith('/vendor') || state.matchedLocation.startsWith('/organizer'))) {
            return '/shopper';
          }
        }
        
        // If email verification required, redirect to auth screen
        if (authState is EmailVerificationRequired) {
          return '/auth';
        }
        
        // If unauthenticated and not on auth routes or public routes, go to auth landing
        if (authState is Unauthenticated) {
          final publicRoutes = [
            '/auth', 
            '/login', 
            '/signup', 
            '/onboarding', 
            '/legal',
            '/account-verification-pending',
            '/vendor-verification-pending',
            '/organizer-verification-pending',
            '/ceo-verification-dashboard'
          ];
          final isVendorApplication = state.matchedLocation.startsWith('/apply/');
          
          if (!publicRoutes.contains(state.matchedLocation) && !isVendorApplication) {
            return '/auth';
          }
        }
        
        return null;
      },
      refreshListenable: GoRouterRefreshStream(authBloc),
    );
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(AuthBloc authBloc) {
    authBloc.stream.listen((_) {
      notifyListeners();
    });
  }
}