import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/blocs/favorites/favorites_bloc.dart';
import 'package:hipop/features/shared/services/places_service.dart';
import 'package:hipop/features/shared/widgets/common/loading_widget.dart';
import 'package:hipop/features/shared/widgets/common/settings_dropdown.dart';
import 'package:hipop/features/shared/widgets/common/favorite_button.dart';
import 'package:hipop/features/shared/widgets/share_button.dart';
import 'package:hipop/features/shared/widgets/common/vendor_items_widget.dart';
import 'package:hipop/features/shared/widgets/common/simple_places_widget.dart';
import 'package:hipop/features/market/services/market_service.dart';
import 'package:hipop/features/shared/services/url_launcher_service.dart';
import 'package:hipop/features/market/models/market.dart';
import 'package:hipop/repositories/vendor_posts_repository.dart';
import 'package:hipop/features/shared/services/event_service.dart';
import 'package:hipop/core/constants/place_utils.dart';
import 'package:hipop/features/vendor/models/vendor_post.dart';
import 'package:hipop/features/shared/models/event.dart';
import 'package:hipop/features/shared/widgets/debug_account_switcher.dart';
import 'package:hipop/features/vendor/widgets/vendor/vendor_follow_button.dart';
import 'package:hipop/features/auth/services/onboarding_service.dart';
import 'package:hipop/features/vendor/services/vendor_market_items_service.dart';

enum FeedFilter { markets, vendors, events, all }

/// Production-ready shopper home screen with location-based discovery
/// Focuses on core market and vendor discovery functionality
class ShopperHome extends StatefulWidget {
  const ShopperHome({super.key});

  @override
  State<ShopperHome> createState() => _ShopperHomeState();
}

class _ShopperHomeState extends State<ShopperHome> with WidgetsBindingObserver {
  String _searchLocation = '';
  PlaceDetails? _selectedSearchPlace;
  String _selectedCity = '';
  FeedFilter _selectedFilter = FeedFilter.all;
  late VendorPostsRepository _vendorPostsRepository;

  @override
  void initState() {
    super.initState();
    _vendorPostsRepository = VendorPostsRepository();
    WidgetsBinding.instance.addObserver(this);
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final shouldShowOnboarding = await OnboardingService.shouldShowShopperOnboarding();
    if (shouldShowOnboarding && mounted) {
      // Navigate to onboarding screen
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
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
                color: isSelected ? color : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
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
            body: LoadingWidget(message: 'Signing you in...'),
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
                _buildFilterSlider(),
                const SizedBox(height: 24),
                // Location search - main feature
                Text(
                  _getSearchHeaderText(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SimplePlacesWidget(
                  initialLocation: _searchLocation,
                  onLocationSelected: _performPlaceSearch,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'or browse all',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300])),
                  ],
                ),
                const SizedBox(height: 8),
                if (_searchLocation.isNotEmpty || _selectedSearchPlace != null) ...[ 
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
                const SizedBox(height: 24),
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
                  return _buildErrorMessage(
                    'Error loading content', 
                    '${marketSnapshot.error ?? ''} ${vendorSnapshot.error ?? ''} ${eventSnapshot.error ?? ''}'.trim()
                  );
                }

                final markets = marketSnapshot.data ?? [];
                final allPosts = vendorSnapshot.data ?? [];
                final posts = _filterCurrentAndFuturePosts(allPosts);
                final allEvents = eventSnapshot.data ?? [];
                final events = EventService.filterCurrentAndUpcomingEvents(allEvents);
                
                // Sort markets by event date (earliest first)
                final sortedMarkets = List<Market>.from(markets);
                sortedMarkets.sort((a, b) {
                  return a.eventDate.compareTo(b.eventDate);
                });
                
                final totalCount = sortedMarkets.length + posts.length + events.length;

                if (totalCount == 0) {
                  return _buildNoResultsMessage();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$totalCount found (${sortedMarkets.length} markets, ${posts.length} vendor pop-ups, ${events.length} events)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Show markets first, sorted by earliest date
                    ...sortedMarkets.map((market) => _buildMarketCard(market)),
                    // Then show events, sorted by start date
                    ...events.map((event) => _buildEventCard(event)),
                    // Then show vendor posts
                    ...posts.map((post) => _buildVendorPostCard(post)),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildErrorMessage(String title, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVendorPostCard(VendorPost post) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: () => _handleVendorPostTap(post),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.store,
                      color: Colors.blue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.vendorName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pop-up • ${_formatPostDateTime(post.popUpStartDateTime)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      ShareButton(
                        onGetShareContent: () async {
                          return _buildVendorPostShareContent(post);
                        },
                        style: ShareButtonStyle.icon,
                        size: ShareButtonSize.small,
                      ),
                      const SizedBox(width: 8),
                      VendorFollowButton(
                        vendorId: post.vendorId,
                        vendorName: post.vendorName,
                        isCompact: true,
                      ),
                      const SizedBox(width: 8),
                      FavoriteButton(
                        itemId: post.id,
                        type: FavoriteType.post,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () => _launchMaps(post.location),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          post.location,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue[700],
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                post.description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // Show Instagram handle if available
              if (post.instagramHandle != null && post.instagramHandle!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.camera_alt, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _launchInstagram(post.instagramHandle!),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '@${post.instagramHandle!}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              // Show vendor items if available
              FutureBuilder<List<String>>(
                future: _getVendorItemsForMarket(post.vendorId, post.marketId),
                builder: (context, snapshot) {
                  final items = snapshot.data ?? [];
                  if (items.isNotEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.local_grocery_store,
                              size: 14,
                              color: Colors.green[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Available items:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        VendorItemsWidget.compact(items: items),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPostDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final postDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    String dateStr;
    if (postDate == today) {
      dateStr = 'Today';
    } else if (postDate == today.add(const Duration(days: 1))) {
      dateStr = 'Tomorrow';
    } else if (postDate.isBefore(today.add(const Duration(days: 7)))) {
      // Within a week - show day name
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      dateStr = days[dateTime.weekday - 1];
    } else {
      dateStr = '${dateTime.month}/${dateTime.day}';
    }
    
    final hour = dateTime.hour == 0 ? 12 : dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    
    return '$dateStr at $hour:${dateTime.minute.toString().padLeft(2, '0')} $period';
  }

  void _handleVendorPostTap(VendorPost post) {
    context.pushNamed('vendorPostDetail', extra: post);
  }

  List<VendorPost> _filterCurrentAndFuturePosts(List<VendorPost> posts) {
    final now = DateTime.now();
    return posts.where((post) => post.popUpEndDateTime.isAfter(now)).toList();
  }

  String _buildVendorPostShareContent(VendorPost post) {
    final buffer = StringBuffer();
    
    buffer.writeln('Pop-up Event Alert!');
    buffer.writeln();
    buffer.writeln('${post.vendorName}');
    
    if (post.description.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(post.description);
    }
    
    buffer.writeln();
    buffer.writeln('Date/Time: ${_formatPostDateTime(post.popUpStartDateTime)} - ${_formatTime(post.popUpEndDateTime)}');
    
    if (post.locationName != null && post.locationName!.isNotEmpty) {
      buffer.writeln('Location: ${post.locationName}');
    }
    
    if (post.instagramHandle != null && post.instagramHandle!.isNotEmpty) {
      buffer.writeln('Instagram: @${post.instagramHandle}');
    }
    
    buffer.writeln();
    buffer.writeln('Don\'t miss out on fresh local products!');
    buffer.writeln('Shared via HiPop');
    
    return buffer.toString();
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour == 0 ? 12 : dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${dateTime.minute.toString().padLeft(2, '0')} $period';
  }

  Future<List<String>> _getVendorItemsForMarket(String vendorId, String? marketId) async {
    if (marketId == null) return [];
    
    try {
      final vendorItems = await VendorMarketItemsService.getVendorMarketItems(vendorId, marketId);
      return vendorItems?.itemList ?? [];
    } catch (e) {
      debugPrint('Error fetching vendor items: $e');
      return [];
    }
  }

  Widget _buildEventCard(Event event) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: () => _handleEventTap(event),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.event,
                      color: Colors.purple,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Event • ${event.formattedDateTime}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  FavoriteButton(
                    itemId: event.id,
                    type: FavoriteType.event,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () => _launchMaps(event.location),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          event.location,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue[700],
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                event.description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (event.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: event.tags.take(3).map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.purple[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _handleEventTap(Event event) {
    context.goNamed(
      'eventDetail',
      pathParameters: {'eventId': event.id},
      extra: event, // Pass the event object for immediate display while loading fresh data
    );
  }
  
  Widget _buildMarketCard(Market market) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: () => _handleMarketTap(market),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.store_mall_directory,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          market.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Market • ${market.eventDisplayInfo}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      ShareButton(
                        onGetShareContent: () async {
                          return _buildMarketShareContent(market);
                        },
                        style: ShareButtonStyle.icon,
                        size: ShareButtonSize.small,
                      ),
                      const SizedBox(width: 8),
                      VendorFollowButton(
                        vendorId: market.id,
                        vendorName: market.name,
                        isCompact: true,
                      ),
                      const SizedBox(width: 8),
                      FavoriteButton(
                        itemId: market.id,
                        type: FavoriteType.market,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () => _launchMaps(market.address),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          market.address,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue[700],
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (market.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  market.description!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
        title = 'No markets found';
        subtitle = _searchLocation.isEmpty
            ? 'Markets will appear here as they join'
            : 'No markets found in $_searchLocation\n\nTry searching for:\n• "Atlanta" or "ATL" for Atlanta area\n• "Decatur" or "DEC" for Decatur area\n• Other Georgia cities';
        buttonText = 'Show All Markets';
        break;
      case FeedFilter.vendors:
        icon = Icons.store;
        title = 'No vendor pop-ups found';
        subtitle = _searchLocation.isEmpty
            ? 'Vendor pop-ups will appear here as they are created'
            : 'No vendor pop-ups found in $_searchLocation\n\nTry searching for nearby areas or check back later for new pop-ups';
        buttonText = 'Show All Vendors';
        break;
      case FeedFilter.events:
        icon = Icons.event;
        title = 'No events found';
        subtitle = _searchLocation.isEmpty
            ? 'Events will appear here as they are created'
            : 'No events found in $_searchLocation\n\nTry searching for nearby areas or check back later for new events';
        buttonText = 'Show All Events';
        break;
      case FeedFilter.all:
        icon = Icons.explore;
        title = 'No markets, vendors, or events found';
        subtitle = _searchLocation.isEmpty
            ? 'Markets, vendor pop-ups, and events will appear here as they join'
            : 'No markets, vendor pop-ups, or events found in $_searchLocation\n\nTry searching for nearby areas or check back later';
        buttonText = 'Show All';
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          if (_searchLocation.isNotEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _clearSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: Text(buttonText),
            ),
          ],
        ],
      ),
    );
  }

  void _handleMarketTap(Market market) {
    context.pushNamed('marketDetail', extra: market);
  }
  
  Future<void> _launchMaps(String address) async {
    try {
      await UrlLauncherService.launchMaps(address);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open maps: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchInstagram(String handle) async {
    try {
      await UrlLauncherService.launchInstagram(handle);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open Instagram: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _buildMarketShareContent(Market market) {
    final buffer = StringBuffer();
    
    buffer.writeln('Market Discovery!');
    buffer.writeln();
    buffer.writeln('${market.name}');
    if (market.description != null && market.description!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(market.description);
    }
    buffer.writeln();
    buffer.writeln('Location: ${market.address}');
    buffer.writeln();
    
    // Add event information if available
    if (market.eventDate != null) {
      buffer.writeln('🗓️ Event Details:');
      buffer.writeln('• Date: ${market.eventDisplayInfo}');
      buffer.writeln('• Hours: ${market.startTime} - ${market.endTime}');
      buffer.writeln();
    }
    
    buffer.writeln('Visit this amazing local market!');
    buffer.writeln();
    
    buffer.writeln('Discovered on HiPop - Find local markets & pop-ups');
    buffer.writeln('Download: https://hipopapp.com');
    buffer.writeln();
    buffer.writeln('#FarmersMarket #LocalMarket #SupportLocal #HiPop');
    
    return buffer.toString();
  }
}