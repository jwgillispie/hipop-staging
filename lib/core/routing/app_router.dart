import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../repositories/vendor_posts_repository.dart';
// Auth screens
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/auth_landing_screen.dart';
import '../../features/auth/screens/auth_screen.dart';
import '../../features/auth/screens/change_password_screen.dart';
// Market screens
import '../../features/market/screens/market_detail_screen.dart';
import '../../features/market/screens/market_management_screen.dart';
// Shopper screens
import '../../features/shopper/screens/shopper_home.dart';
import '../../features/shopper/screens/shopper_calendar_screen.dart';
import '../../features/shopper/screens/event_detail_screen.dart';
import '../../features/shopper/screens/post_market_feedback_screen.dart';
import '../../features/shopper/screens/vendor_rating_screen.dart';
import '../../features/shopper/screens/market_rating_screen.dart';
// Vendor screens
import '../../features/vendor/screens/vendor_dashboard.dart';
import '../../features/vendor/screens/vendor_my_popups_screen.dart';
import '../../features/vendor/screens/vendor_profile_screen.dart';
import '../../features/vendor/screens/vendor_post_detail_screen.dart';
import '../../features/vendor/screens/vendor_applications_screen.dart';
import '../../features/vendor/screens/vendor_management_screen.dart';
import '../../features/vendor/screens/vendor_detail_screen.dart';
import '../../features/vendor/screens/vendor_application_status_screen.dart';
import '../../features/vendor/screens/vendor_market_permissions_screen.dart';
import '../../features/vendor/screens/vendor_popup_creation_screen.dart';
import '../../features/vendor/screens/vendor_signup_screen.dart';
import '../../features/vendor/screens/vendor_verification_pending_screen.dart';
import '../../features/vendor/screens/edit_popup_screen.dart';
import '../../features/vendor/screens/vendor_sales_tracker_screen.dart';
import '../../features/vendor/screens/vendor_analytics_screen.dart';
// Organizer screens
import '../../features/organizer/screens/organizer_dashboard.dart';
import '../../features/organizer/screens/organizer_analytics_screen.dart';
import '../../features/organizer/screens/organizer_profile_screen.dart';
import '../../features/organizer/screens/organizer_calendar_screen.dart';
import '../../features/organizer/screens/organizer_onboarding_screen.dart';
import '../../features/organizer/screens/organizer_event_management_screen.dart';
import '../../features/organizer/screens/market_organizer_comprehensive_signup_screen.dart';
// Shared screens
import '../../features/shared/screens/create_popup_screen.dart';
import '../../features/shared/screens/custom_items_screen.dart';
import '../../features/shared/screens/admin_fix_screen.dart';
import '../../features/shared/screens/favorites_screen.dart';
import '../../features/shared/screens/legal_documents_screen.dart';
import '../../features/shared/screens/account_verification_pending_screen.dart';
import '../../features/shared/screens/ceo_verification_dashboard_screen.dart';
// Premium screens
import '../../features/premium/screens/subscription_test_screen.dart';
import '../../features/premium/screens/premium_onboarding_screen.dart';
import '../../features/premium/screens/subscription_success_screen.dart';
import '../../features/premium/screens/subscription_cancel_screen.dart';
import '../../features/premium/widgets/tier_specific_dashboard.dart';
import '../../features/shared/services/user_profile_service.dart';
import '../../features/premium/services/subscription_service.dart';
import '../../features/premium/models/user_subscription.dart';
import '../../features/shared/models/user_profile.dart';
import '../../features/market/models/market.dart';
import '../../features/vendor/models/vendor_post.dart';
import '../../features/shared/models/event.dart';

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
          builder: (context, state) => const VendorVerificationPendingScreen(),
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
              path: 'vendor-detail/:vendorId',
              name: 'vendorDetail',
              builder: (context, state) {
                final vendorId = state.pathParameters['vendorId']!;
                return VendorDetailScreen(vendorId: vendorId);
              },
            ),
            GoRoute(
              path: 'event-detail/:eventId',
              name: 'eventDetail',
              builder: (context, state) {
                final eventId = state.pathParameters['eventId']!;
                final event = state.extra as Event?;
                return EventDetailScreen(eventId: eventId, event: event);
              },
            ),
            GoRoute(
              path: 'feedback/market/:marketId',
              name: 'marketFeedback',
              builder: (context, state) {
                final marketId = state.pathParameters['marketId']!;
                final marketName = state.uri.queryParameters['marketName'];
                final eventId = state.uri.queryParameters['eventId'];
                final visitDateStr = state.uri.queryParameters['visitDate'];
                final visitDate = visitDateStr != null 
                    ? DateTime.tryParse(visitDateStr) ?? DateTime.now()
                    : DateTime.now();
                return PostMarketFeedbackScreen(
                  marketId: marketId,
                  marketName: marketName,
                  eventId: eventId,
                  visitDate: visitDate,
                );
              },
            ),
            GoRoute(
              path: 'feedback/vendor/:vendorId',
              name: 'vendorFeedback',
              builder: (context, state) {
                final vendorId = state.pathParameters['vendorId']!;
                final vendorName = state.uri.queryParameters['vendorName'];
                final marketId = state.uri.queryParameters['marketId'];
                final eventId = state.uri.queryParameters['eventId'];
                final visitDateStr = state.uri.queryParameters['visitDate'];
                final visitDate = visitDateStr != null 
                    ? DateTime.tryParse(visitDateStr) ?? DateTime.now()
                    : DateTime.now();
                return VendorRatingScreen(
                  vendorId: vendorId,
                  vendorName: vendorName,
                  marketId: marketId,
                  eventId: eventId,
                  visitDate: visitDate,
                );
              },
            ),
            GoRoute(
              path: 'rating/market/:marketId',
              name: 'marketRating',
              builder: (context, state) {
                final marketId = state.pathParameters['marketId']!;
                final marketName = state.uri.queryParameters['marketName'];
                final eventId = state.uri.queryParameters['eventId'];
                final visitDateStr = state.uri.queryParameters['visitDate'];
                final visitDate = visitDateStr != null 
                    ? DateTime.tryParse(visitDateStr) ?? DateTime.now()
                    : DateTime.now();
                return MarketRatingScreen(
                  marketId: marketId,
                  marketName: marketName,
                  eventId: eventId,
                  visitDate: visitDate,
                );
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
            GoRoute(
              path: 'edit-popup',
              name: 'editPopup',
              builder: (context, state) {
                final vendorPost = state.extra as VendorPost;
                return EditPopupScreen(vendorPost: vendorPost);
              },
            ),
            GoRoute(
              path: 'sales-tracker',
              name: 'vendorSalesTracker',
              builder: (context, state) => const VendorSalesTrackerScreen(),
            ),
            GoRoute(
              path: 'analytics',
              name: 'vendorAnalytics',
              builder: (context, state) => const VendorAnalyticsScreen(),
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
            if (kDebugMode)
              GoRoute(
                path: 'subscription-test',
                name: 'subscriptionTest',
                builder: (context, state) => const SubscriptionTestScreen(),
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
        
        
        // Premium onboarding route
        GoRoute(
          path: '/premium/onboarding',
          name: 'premiumOnboarding',
          builder: (context, state) {
            final userId = state.uri.queryParameters['userId'] ?? '';
            final userType = state.uri.queryParameters['userType'] ?? 'vendor';
            
            if (userId.isEmpty) {
              return const Scaffold(
                body: Center(
                  child: Text('Error: User ID is required for premium onboarding'),
                ),
              );
            }
            
            return PremiumOnboardingScreen(
              userId: userId,
              userType: userType,
            );
          },
        ),
        
        // Premium dashboard route
        GoRoute(
          path: '/premium/dashboard',
          name: 'premiumDashboard',
          builder: (context, state) {
            // Try to get userId from query params first, then from auth context
            String userId = state.uri.queryParameters['userId'] ?? '';
            
            // If no userId in params, try to get from auth context
            if (userId.isEmpty) {
              final authBloc = context.read<AuthBloc>();
              final authState = authBloc.state;
              if (authState is Authenticated) {
                userId = authState.user.uid;
              }
            }
            
            if (userId.isEmpty) {
              return const Scaffold(
                body: Center(
                  child: Text('Error: User ID is required for premium dashboard'),
                ),
              );
            }
            
            // Fetch real subscription data and validate user type access
            return FutureBuilder<Map<String, dynamic>>(
              future: _getUserSubscriptionDataWithValidation(userId, context),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                
                if (snapshot.hasError || !snapshot.hasData) {
                  return Scaffold(
                    body: Center(
                      child: Text('Error loading subscription data: ${snapshot.error}'),
                    ),
                  );
                }
                
                final data = snapshot.data!;
                final subscription = data['subscription'] as UserSubscription?;
                final userProfile = data['userProfile'] as UserProfile?;
                
                // Validation check: ensure subscription tier matches user type
                if (subscription != null && userProfile != null) {
                  final isValidAccess = _validateUserTypeAccess(userProfile.userType, subscription.tier);
                  if (!isValidAccess) {
                    // Redirect to appropriate user dashboard instead of premium dashboard
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _redirectToUserDashboard(context, userProfile.userType);
                    });
                    return const Scaffold(
                      body: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                }
                
                if (subscription == null) {
                  return const Scaffold(
                    body: Center(
                      child: Text('No active subscription found'),
                    ),
                  );
                }
                
                return TierSpecificDashboard(
                  userId: userId,
                  subscription: subscription,
                );
              },
            );
          },
        ),
        
        // Subscription success route
        GoRoute(
          path: '/subscription/success',
          name: 'subscriptionSuccess',
          builder: (context, state) {
            final sessionId = state.uri.queryParameters['session_id'] ?? '';
            final userId = state.uri.queryParameters['user_id'] ?? '';
            
            debugPrint('');
            debugPrint('✅ ========= SUBSCRIPTION SUCCESS =========');
            debugPrint('🌐 Full URL: ${state.uri}');
            debugPrint('🎯 Session ID: $sessionId');
            debugPrint('👤 User ID: $userId');
            debugPrint('⏰ Timestamp: ${DateTime.now()}');
            debugPrint('✅ ======================================');
            debugPrint('');
            
            if (sessionId.isEmpty || userId.isEmpty) {
              return const Scaffold(
                body: Center(
                  child: Text('Error: Missing subscription parameters'),
                ),
              );
            }
            
            return SubscriptionSuccessScreen(
              sessionId: sessionId,
              userId: userId,
            );
          },
        ),
        
        // Subscription cancel route
        GoRoute(
          path: '/subscription/cancel',
          name: 'subscriptionCancel',
          builder: (context, state) {
            final reason = state.uri.queryParameters['reason'];
            
            debugPrint('');
            debugPrint('❌ ========= SUBSCRIPTION CANCELLED =========');
            debugPrint('🌐 Full URL: ${state.uri}');
            debugPrint('💬 Reason: $reason');
            debugPrint('⏰ Timestamp: ${DateTime.now()}');
            debugPrint('❌ =====================================');
            debugPrint('');
            
            return SubscriptionCancelScreen(reason: reason);
          },
        ),
        
        // Premium upgrade route (handles upgrade flow)
        GoRoute(
          path: '/premium/upgrade',
          name: 'premiumUpgrade',
          builder: (context, state) {
            final targetTier = state.uri.queryParameters['tier'];
            final userId = state.uri.queryParameters['userId'];
            
            debugPrint('');
            debugPrint('⭐ ========= PREMIUM UPGRADE ROUTE =========');
            debugPrint('🌐 Full URL: ${state.uri}');
            debugPrint('🎯 Target tier: $targetTier');
            debugPrint('👤 User ID: $userId');
            debugPrint('⏰ Timestamp: ${DateTime.now()}');
            debugPrint('⭐ ======================================');
            debugPrint('');
            
            // Get userId from query params or auth context
            String? effectiveUserId = userId;
            if (effectiveUserId == null || effectiveUserId.isEmpty) {
              final authBloc = context.read<AuthBloc>();
              final authState = authBloc.state;
              if (authState is Authenticated) {
                effectiveUserId = authState.user.uid;
              }
            }
            
            if (effectiveUserId == null || effectiveUserId.isEmpty) {
              return const Scaffold(
                body: Center(
                  child: Text('Error: User ID is required for premium upgrade'),
                ),
              );
            }
            
            return PremiumOnboardingScreen(
              userId: effectiveUserId,
              userType: targetTier ?? 'shopper',
            );
          },
        ),
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

  /// Fetch user subscription data for premium dashboard
  static Future<Map<String, dynamic>> _getUserSubscriptionData(String userId) async {
    try {
      // Import the services we need
      final userProfileService = UserProfileService();
      
      // Get user profile to determine user type
      final userProfile = await userProfileService.getUserProfile(userId);
      if (userProfile == null) {
        throw Exception('User profile not found');
      }
      
      // Get subscription information using static method
      final subscription = await SubscriptionService.getUserSubscription(userId);
      if (subscription == null) {
        // Create a free tier subscription for display purposes
        final freeSubscription = UserSubscription(
          id: 'free_$userId',
          userId: userId,
          userType: userProfile.userType,
          tier: SubscriptionTier.free,
          status: SubscriptionStatus.active,
          stripeCustomerId: '',
          stripeSubscriptionId: '',
          stripePriceId: '',
          monthlyPrice: 0.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        return {
          'subscription': freeSubscription,
          'userProfile': userProfile,
        };
      }
      
      return {
        'subscription': subscription,
        'userProfile': userProfile,
      };
    } catch (e) {
      debugPrint('❌ Error fetching user subscription data: $e');
      rethrow;
    }
  }

  /// Fetch user subscription data with user type validation
  static Future<Map<String, dynamic>> _getUserSubscriptionDataWithValidation(String userId, BuildContext context) async {
    try {
      // Import the services we need
      final userProfileService = UserProfileService();
      
      // Get user profile to determine user type
      final userProfile = await userProfileService.getUserProfile(userId);
      if (userProfile == null) {
        throw Exception('User profile not found');
      }
      
      // Get subscription information using static method
      final subscription = await SubscriptionService.getUserSubscription(userId);
      if (subscription == null) {
        // Create a free tier subscription for display purposes
        final freeSubscription = UserSubscription(
          id: 'free_$userId',
          userId: userId,
          userType: userProfile.userType,
          tier: SubscriptionTier.free,
          status: SubscriptionStatus.active,
          stripeCustomerId: '',
          stripeSubscriptionId: '',
          stripePriceId: '',
          monthlyPrice: 0.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        return {
          'subscription': freeSubscription,
          'userProfile': userProfile,
        };
      }
      
      return {
        'subscription': subscription,
        'userProfile': userProfile,
      };
    } catch (e) {
      debugPrint('❌ Error fetching user subscription data with validation: $e');
      rethrow;
    }
  }

  /// Validate that user type matches subscription tier
  static bool _validateUserTypeAccess(String userType, SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.shopperPro:
        return userType == 'shopper';
      case SubscriptionTier.vendorPro:
        return userType == 'vendor';
      case SubscriptionTier.marketOrganizerPro:
        return userType == 'market_organizer';
      case SubscriptionTier.enterprise:
        return userType == 'market_organizer'; // Enterprise is for market organizers
      case SubscriptionTier.free:
        return true; // Free tier is available to all user types
    }
  }

  /// Redirect user to appropriate dashboard based on user type
  static void _redirectToUserDashboard(BuildContext context, String userType) {
    switch (userType) {
      case 'vendor':
        context.go('/vendor');
        break;
      case 'market_organizer':
        context.go('/organizer');
        break;
      case 'shopper':
      default:
        context.go('/shopper');
        break;
    }
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(AuthBloc authBloc) {
    authBloc.stream.listen((_) {
      notifyListeners();
    });
  }
}