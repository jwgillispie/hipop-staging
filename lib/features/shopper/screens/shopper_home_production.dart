import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/blocs/favorites/favorites_bloc.dart';
import 'package:hipop/core/constants/place_utils.dart';
import 'package:hipop/features/market/models/market.dart';
import 'package:hipop/features/market/services/market_service.dart';
import 'package:hipop/features/premium/services/subscription_service.dart';
import 'package:hipop/features/premium/widgets/premium_feed_enhancements.dart';
import 'package:hipop/features/premium/widgets/premium_search_widget.dart';
import 'package:hipop/features/shared/models/event.dart';
import 'package:hipop/features/shared/services/event_service.dart';
import 'package:hipop/features/shared/services/places_service.dart';
import 'package:hipop/features/shared/widgets/common/favorite_button.dart';
import 'package:hipop/features/shared/widgets/common/loading_widget.dart';
import 'package:hipop/features/shared/widgets/common/settings_dropdown.dart';
import 'package:hipop/features/shared/widgets/common/simple_places_widget.dart';
import 'package:hipop/features/shared/widgets/debug_account_switcher.dart';
import 'package:hipop/features/vendor/models/vendor_post.dart';
import 'package:hipop/features/vendor/widgets/vendor/vendor_follow_button.dart';
import 'package:hipop/repositories/vendor_posts_repository.dart' show VendorPostsRepository;


enum FeedFilter { markets, vendors, events, all }

/// Production-ready shopper home screen with integrated premium features
/// instead of demo screens and test buttons
class ShopperHome extends StatefulWidget {
  const ShopperHome({super.key});

  @override
  State<ShopperHome> createState() => _ShopperHomeState();
}

class _ShopperHomeState extends State<ShopperHome> {
  String _searchLocation = '';
  PlaceDetails? _selectedSearchPlace;
  String _selectedCity = '';
  FeedFilter _selectedFilter = FeedFilter.all;
  late VendorPostsRepository _vendorPostsRepository;
  bool _hasPremiumAccess = false;
  bool _isCheckingPremium = true;

  @override
  void initState() {
    super.initState();
    _vendorPostsRepository = VendorPostsRepository();
    _checkPremiumAccess();
  }

  Future<void> _checkPremiumAccess() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      final hasAccess = await SubscriptionService.hasFeature(
        authState.user.uid,
        'vendor_following_system',
      );
      if (mounted) {
        setState(() {
          _hasPremiumAccess = hasAccess;
          _isCheckingPremium = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isCheckingPremium = false;
        });
      }
    }
  }

  void _clearSearch() {
    setState(() {
      _searchLocation = '';
      _selectedSearchPlace = null;
      _selectedCity = '';
    });
  }
  
  void _performPlaceSearch(PlaceDetails? placeDetails) {
    if (placeDetails == null) {
      _clearSearch();
      return;
    }
    
    setState(() {
      _searchLocation = placeDetails.formattedAddress;
      _selectedSearchPlace = placeDetails;
      
      // Extract city from place details for market search using better logic
      _selectedCity = PlaceUtils.extractCityFromPlace(placeDetails);
    });
  }

  String _getSearchHeaderText() {
    switch (_selectedFilter) {
      case FeedFilter.markets:
        return 'Find Markets Near You';
      case FeedFilter.vendors:
        return 'Find Vendor Pop-ups Near You';
      case FeedFilter.events:
        return 'Find Events Near You';
      case FeedFilter.all:
        return 'Find Markets, Vendors & Events Near You';
    }
  }

  String _getResultsHeaderText() {
    if (_searchLocation.isEmpty) {
      switch (_selectedFilter) {
        case FeedFilter.markets:
          return 'All Markets';
        case FeedFilter.vendors:
          return 'All Vendor Pop-ups';
        case FeedFilter.events:
          return 'All Events';
        case FeedFilter.all:
          return 'All Markets, Vendors & Events';
      }
    } else {
      switch (_selectedFilter) {
        case FeedFilter.markets:
          return 'Markets in $_searchLocation';
        case FeedFilter.vendors:
          return 'Vendor Pop-ups in $_searchLocation';
        case FeedFilter.events:
          return 'Events in $_searchLocation';
        case FeedFilter.all:
          return 'Markets, Vendors & Events in $_searchLocation';
      }
    }
  }

  Widget _buildFilterSlider() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Show me:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildFilterOption(
                    FeedFilter.markets,
                    'Markets',
                    Icons.store_mall_directory,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildFilterOption(
                    FeedFilter.vendors,
                    'Vendors',
                    Icons.store,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildFilterOption(
                    FeedFilter.events,
                    'Events',
                    Icons.event,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildFilterOption(
                    FeedFilter.all,
                    'All',
                    Icons.explore,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(FeedFilter filter, String label, IconData icon, Color color) {
    final isSelected = _selectedFilter == filter;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey.shade700,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('HiPop Markets'),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            actions: [
              BlocBuilder<FavoritesBloc, FavoritesState>(
                builder: (context, favoritesState) {
                  final totalFavorites = favoritesState.totalFavorites;
                  return Stack(
                    children: [
                      IconButton(
                        onPressed: () => context.pushNamed('favorites'),
                        icon: const Icon(Icons.favorite),
                        tooltip: 'My Favorites',
                      ),
                      if (totalFavorites > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '$totalFavorites',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              IconButton(
                onPressed: () => context.pushNamed('shopperCalendar'),
                icon: const Icon(Icons.calendar_today),
                tooltip: 'Market Calendar',
              ),
              const SettingsDropdown(),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Debug Account Switcher
                const DebugAccountSwitcher(),
                
                // Welcome Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Colors.orange,
                              child: Icon(Icons.shopping_bag, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Find Local Markets & Vendors',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  Text(
                                    'Discover markets and vendor pop-ups near you',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Filter Options
                _buildFilterSlider(),
                
                const SizedBox(height: 24),
                
                // Premium Features Integration - replaces demo buttons
                const PremiumFeedEnhancements(),
                
                const SizedBox(height: 24),
                
                // Premium Search Widget - replaces simple search
                PremiumSearchWidget(
                  onSearchResults: (results) {
                    // Handle search results in the main feed
                    debugPrint('Premium search returned ${results.length} results');
                  },
                  initialLocation: _selectedCity,
                ),
                
                const SizedBox(height: 24),
                
                // Traditional location search fallback
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getSearchHeaderText(),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SimplePlacesWidget(
                          initialLocation: _searchLocation,
                          onLocationSelected: _performPlaceSearch,
                        ),
                        if (_searchLocation.isNotEmpty || _selectedSearchPlace != null) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _clearSearch,
                                  icon: const Icon(Icons.clear, size: 16),
                                  label: const Text('Show All'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orange,
                                    side: const BorderSide(color: Colors.orange),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Results Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getResultsHeaderText(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_searchLocation.isNotEmpty && _selectedCity != _searchLocation) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Searching for: $_selectedCity',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Content Stream
                _buildContentStream(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContentStream() {
    if (_selectedFilter == FeedFilter.markets) {
      return _buildMarketsOnlyStream();
    } else if (_selectedFilter == FeedFilter.vendors) {
      return _buildVendorPostsOnlyStream();
    } else if (_selectedFilter == FeedFilter.events) {
      return _buildEventsOnlyStream();
    } else {
      return _buildMixedContentStream();
    }
  }

  Widget _buildMarketsOnlyStream() {
    return StreamBuilder<List<Market>>(
      stream: _selectedCity.isEmpty 
          ? MarketService.getAllActiveMarketsStream()
          : MarketService.getMarketsByCityStream(_selectedCity),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget(message: 'Loading markets...');
        }

        if (snapshot.hasError) {
          return _buildErrorMessage('Error loading markets', snapshot.error.toString());
        }

        final markets = snapshot.data ?? [];

        if (markets.isEmpty) {
          return _buildNoResultsMessage();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${markets.length} found',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: markets.length,
              itemBuilder: (context, index) {
                final market = markets[index];
                return _buildMarketCard(market);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildVendorPostsOnlyStream() {
    return StreamBuilder<List<VendorPost>>(
      stream: _selectedCity.isEmpty 
          ? _vendorPostsRepository.getAllActivePosts()
          : _vendorPostsRepository.searchPostsByLocation(_selectedCity),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget(message: 'Loading vendor pop-ups...');
        }

        if (snapshot.hasError) {
          return _buildErrorMessage('Error loading vendor pop-ups', snapshot.error.toString());
        }

        final allPosts = snapshot.data ?? [];
        final posts = _filterCurrentAndFuturePosts(allPosts);

        if (posts.isEmpty) {
          return _buildNoResultsMessage();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${posts.length} found',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return _buildVendorPostCard(post);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildEventsOnlyStream() {
    return StreamBuilder<List<Event>>(
      stream: _selectedCity.isEmpty 
          ? EventService.getAllActiveEventsStream()
          : EventService.getEventsByCityStream(_selectedCity),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget(message: 'Loading events...');
        }

        if (snapshot.hasError) {
          return _buildErrorMessage('Error loading events', snapshot.error.toString());
        }

        final allEvents = snapshot.data ?? [];
        final events = EventService.filterCurrentAndUpcomingEvents(allEvents);

        if (events.isEmpty) {
          return _buildNoResultsMessage();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${events.length} found',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return _buildEventCard(event);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildMixedContentStream() {
    return StreamBuilder<List<Market>>(
      stream: _selectedCity.isEmpty 
          ? MarketService.getAllActiveMarketsStream()
          : MarketService.getMarketsByCityStream(_selectedCity),
      builder: (context, marketSnapshot) {
        return StreamBuilder<List<VendorPost>>(
          stream: _selectedCity.isEmpty 
              ? _vendorPostsRepository.getAllActivePosts()
              : _vendorPostsRepository.searchPostsByLocation(_selectedCity),
          builder: (context, vendorSnapshot) {
            return StreamBuilder<List<Event>>(
              stream: _selectedCity.isEmpty 
                  ? EventService.getAllActiveEventsStream()
                  : EventService.getEventsByCityStream(_selectedCity),
              builder: (context, eventSnapshot) {
                if (marketSnapshot.connectionState == ConnectionState.waiting ||
                    vendorSnapshot.connectionState == ConnectionState.waiting ||
                    eventSnapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingWidget(message: 'Loading markets, vendors, and events...');
                }

                if (marketSnapshot.hasError || vendorSnapshot.hasError || eventSnapshot.hasError) {
                  return _buildErrorMessage('Error loading content', 'Please try again later');
                }

                final markets = marketSnapshot.data ?? [];
                final allPosts = vendorSnapshot.data ?? [];
                final posts = _filterCurrentAndFuturePosts(allPosts);
                final allEvents = eventSnapshot.data ?? [];
                final events = EventService.filterCurrentAndUpcomingEvents(allEvents);

                final totalResults = markets.length + posts.length + events.length;

                if (totalResults == 0) {
                  return _buildNoResultsMessage();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$totalResults found (${markets.length} markets, ${posts.length} vendors, ${events.length} events)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Markets Section
                    if (markets.isNotEmpty) ...[
                      _buildSectionHeader('Markets (${markets.length})', Icons.store_mall_directory, Colors.green),
                      ...markets.take(3).map((market) => _buildMarketCard(market)),
                      if (markets.length > 3) _buildViewMoreCard('markets', markets.length - 3),
                      const SizedBox(height: 16),
                    ],
                    
                    // Vendor Posts Section  
                    if (posts.isNotEmpty) ...[
                      _buildSectionHeader('Vendor Pop-ups (${posts.length})', Icons.store, Colors.blue),
                      ...posts.take(3).map((post) => _buildVendorPostCard(post)),
                      if (posts.length > 3) _buildViewMoreCard('vendors', posts.length - 3),
                      const SizedBox(height: 16),
                    ],
                    
                    // Events Section
                    if (events.isNotEmpty) ...[
                      _buildSectionHeader('Events (${events.length})', Icons.event, Colors.purple),
                      ...events.take(3).map((event) => _buildEventCard(event)),
                      if (events.length > 3) _buildViewMoreCard('events', events.length - 3),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewMoreCard(String type, int remainingCount) {
    return Card(
      child: InkWell(
        onTap: () {
          // Switch to specific filter
          setState(() {
            switch (type) {
              case 'markets':
                _selectedFilter = FeedFilter.markets;
                break;
              case 'vendors':
                _selectedFilter = FeedFilter.vendors;
                break;
              case 'events':
                _selectedFilter = FeedFilter.events;
                break;
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'View $remainingCount more $type',
                style: TextStyle(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward,
                color: Colors.orange[700],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarketCard(Market market) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.pushNamed('marketDetail', extra: market),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    child: Icon(Icons.store_mall_directory, color: Colors.green.shade700),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          market.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (market.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            market.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  FavoriteButton(
                    itemId: market.id,
                    type: FavoriteType.market,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${market.address}, ${market.city}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (market.operatingDays.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.grey[600], size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        market.operatingDays.entries.map((e) => '${e.key}: ${e.value}').join(', '),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVendorPostCard(VendorPost post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.pushNamed('vendorPostDetail', extra: post),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Icon(Icons.store, color: Colors.blue.shade700),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.vendorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (post.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            post.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      FavoriteButton(
                        itemId: post.id,
                        type: FavoriteType.post,
                      ),
                      if (_hasPremiumAccess) ...[
                        const SizedBox(height: 8),
                        VendorFollowButton(
                          vendorId: post.vendorId,
                          vendorName: post.vendorName,
                          isCompact: true,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      post.location,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.schedule, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${post.popUpStartDateTime.month}/${post.popUpStartDateTime.day}/${post.popUpStartDateTime.year} - ${post.popUpEndDateTime.month}/${post.popUpEndDateTime.day}/${post.popUpEndDateTime.year}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(Event event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          context.goNamed(
            'eventDetail',
            pathParameters: {'eventId': event.id},
            extra: event, // Pass the event object for immediate display while loading fresh data
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.purple.shade100,
                    child: Icon(Icons.event, color: Colors.purple.shade700),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (event.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            event.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  FavoriteButton(
                    itemId: event.id,
                    type: FavoriteType.event,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.location,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.schedule, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${event.startDateTime.month}/${event.startDateTime.day}/${event.startDateTime.year} - ${event.endDateTime.month}/${event.endDateTime.day}/${event.endDateTime.year}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsMessage() {
    IconData icon;
    String title;
    String subtitle;
    String buttonText;

    switch (_selectedFilter) {
      case FeedFilter.markets:
        icon = Icons.store_mall_directory;
        title = 'No Markets Found';
        subtitle = _searchLocation.isEmpty
            ? 'There are no active markets at the moment.'
            : 'No markets found in $_searchLocation.';
        buttonText = 'Show All Markets';
        break;
      case FeedFilter.vendors:
        icon = Icons.store;
        title = 'No Vendor Pop-ups Found';
        subtitle = _searchLocation.isEmpty
            ? 'There are no active vendor pop-ups at the moment.'
            : 'No vendor pop-ups found in $_searchLocation.';
        buttonText = 'Show All Vendors';
        break;
      case FeedFilter.events:
        icon = Icons.event;
        title = 'No Events Found';
        subtitle = _searchLocation.isEmpty
            ? 'There are no upcoming events at the moment.'
            : 'No events found in $_searchLocation.';
        buttonText = 'Show All Events';
        break;
      case FeedFilter.all:
        icon = Icons.search_off;
        title = 'No Results Found';
        subtitle = _searchLocation.isEmpty
            ? 'There are no active markets, vendors, or events at the moment.'
            : 'Nothing found in $_searchLocation. Try a broader search.';
        buttonText = 'Show Everything';
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchLocation.isNotEmpty) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _clearSearch,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                ),
                child: Text(buttonText),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage(String title, String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.red[700],
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: Colors.red[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (mounted) {
                  setState(() {
                    // Trigger rebuild to retry
                  });
                }
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  List<VendorPost> _filterCurrentAndFuturePosts(List<VendorPost> posts) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return posts.where((post) {
      final postEndDate = DateTime(post.popUpEndDateTime.year, post.popUpEndDateTime.month, post.popUpEndDateTime.day);
      return postEndDate.isAtSameMomentAs(today) || postEndDate.isAfter(today);
    }).toList();
  }
}