import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../market/models/market.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/hipop_colors.dart';

/// Market selection screen for vendors creating market-associated posts
class SelectMarketScreen extends StatefulWidget {
  const SelectMarketScreen({Key? key}) : super(key: key);

  @override
  State<SelectMarketScreen> createState() => _SelectMarketScreenState();
}

class _SelectMarketScreenState extends State<SelectMarketScreen> {
  String _searchQuery = '';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Your Pop-Up'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Market selection content
          Expanded(
            child: _buildMarketSelection(),
          ),
        ],
      ),
    );
  }
  
  
  Widget _buildMarketSelection() {
    return Column(
      children: [
        // Search and filter bar
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                style: TextStyle(color: HiPopColors.lightTextPrimary),
                decoration: InputDecoration(
                  hintText: 'Search markets by name or location...',
                  hintStyle: TextStyle(color: HiPopColors.lightTextSecondary),
                  prefixIcon: Icon(Icons.search, color: HiPopColors.primaryDeepSage),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: HiPopColors.lightBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: HiPopColors.lightBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: HiPopColors.vendorAccent, width: 2),
                  ),
                  filled: true,
                  fillColor: HiPopColors.surfacePalePink,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
              const SizedBox(height: 12),
              // Date range selector for filtering markets
              InkWell(
                onTap: _selectDateRange,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: HiPopColors.surfacePalePink,
                    border: Border.all(color: HiPopColors.lightBorder),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.date_range, size: 20, color: HiPopColors.primaryDeepSage),
                      const SizedBox(width: 8),
                      Text(
                        'Dates: ${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
                        style: TextStyle(fontSize: 16, color: HiPopColors.lightTextPrimary),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_drop_down, color: HiPopColors.lightTextSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Markets list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('markets')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        // Debug: Log the data received
                        if (snapshot.hasError) {
                          debugPrint('Error loading markets: ${snapshot.error}');
                          return Center(
                            child: Text('Error loading markets: ${snapshot.error}'),
                          );
                        }
                        
                        debugPrint('Markets loaded: ${snapshot.data?.docs.length ?? 0} documents');
                        
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.store_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No markets available',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => _navigateToIndependentPost(),
                        child: const Text('Create an independent pop-up instead'),
                      ),
                    ],
                  ),
                );
              }
              
              // Filter markets
              final markets = snapshot.data!.docs
                  .map((doc) => Market.fromFirestore(doc))
                  .where((market) {
                    // Filter by search query
                    if (_searchQuery.isNotEmpty) {
                      final matchesName = market.name.toLowerCase().contains(_searchQuery);
                      final matchesCity = market.city.toLowerCase().contains(_searchQuery);
                      final matchesAddress = market.address.toLowerCase().contains(_searchQuery);
                      if (!matchesName && !matchesCity && !matchesAddress) {
                        return false;
                      }
                    }
                    
                    // Show all markets (removed date range filter for now)
                    return true; // Temporarily show all markets
                  })
                  .toList();
              
              if (markets.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No markets found for ${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _startDate = DateTime.now();
                            _endDate = DateTime.now().add(const Duration(days: 7));
                          });
                        },
                        child: const Text('Clear filters'),
                      ),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: markets.length,
                itemBuilder: (context, index) {
                  final market = markets[index];
                  return _buildMarketCard(market);
                },
              );
                      },
                    ),
        ),
      ],
    );
  }
  
  Widget _buildMarketCard(Market market) {
    final marketHours = _getMarketHoursForDateRange(market, _startDate, _endDate);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _selectMarketAndProceed(market),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Market logo/image
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: HiPopColors.vendorAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      image: market.imageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(market.imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: market.imageUrl == null
                        ? Icon(
                            Icons.storefront,
                            color: HiPopColors.vendorAccent,
                            size: 30,
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          market.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${market.address}, ${market.city}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Only show hours if they are actual hours (not fallback messages)
              if (marketHours.isNotEmpty && 
                  !marketHours.contains('Contact market') && 
                  !marketHours.contains('No hours')) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: HiPopColors.successGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time, size: 16, color: HiPopColors.successGreen),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          marketHours,
                          style: TextStyle(
                            color: HiPopColors.successGreen,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (market.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  market.description!,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _selectMarketAndProceed(market),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Select This Market'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  
  void _selectMarketAndProceed(Market market) {
    // Navigate to create popup screen with market type and market ID
    context.go('/vendor/create-popup?type=market&marketId=${market.id}');
  }
  
  void _navigateToIndependentPost() {
    context.go('/vendor/create-popup?type=independent');
  }
  
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }
  
  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
  
  
  /// Gets a formatted string of market event information
  String _getMarketHoursForDateRange(Market market, DateTime startDate, DateTime endDate) {
    // Debug: Log market event info
    debugPrint('Market ${market.name} event info: ${market.eventDisplayInfo}');
    
    // Check if event date is within our date range
    if (market.eventDate.isAfter(startDate.subtract(const Duration(days: 1))) && 
        market.eventDate.isBefore(endDate.add(const Duration(days: 1)))) {
      final dayDisplayName = _formatDate(market.eventDate);
      return '$dayDisplayName: ${market.startTime} - ${market.endTime}';
    }
    
    // Event is outside the date range
    return 'Event on ${market.eventDisplayInfo}';
  }
  
}