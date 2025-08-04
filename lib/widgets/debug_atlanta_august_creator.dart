import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/market.dart';
import '../models/market_schedule.dart';
import '../models/managed_vendor.dart';
import '../models/vendor_post.dart';
import '../services/market_service.dart';
import '../services/managed_vendor_service.dart';
import '../repositories/vendor_posts_repository.dart';

class DebugAtlantaAugustCreator extends StatefulWidget {
  const DebugAtlantaAugustCreator({super.key});

  @override
  State<DebugAtlantaAugustCreator> createState() => _DebugAtlantaAugustCreatorState();
}

class _DebugAtlantaAugustCreatorState extends State<DebugAtlantaAugustCreator> {
  bool _isLoading = false;
  String _result = '';

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.purple.shade50,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.festival, color: Colors.purple.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  'DEBUG: Create Atlanta August 2025 Markets',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Generate realistic Atlanta markets, vendors, and posts for August 2025 demo:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _createAllAtlantaMarkets(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Column(
                        children: [
                          Text('🍑 CREATE ALL ATLANTA AUGUST MARKETS'),
                          Text(
                            'Community Farmers Markets • Girl World Flea • Atlanta Street Wear • GVG ATL • Peachtree Farmers • Freedom Farmers',
                            style: TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            if (_result.isNotEmpty) ...[
              Container(
                height: 300,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _result,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _createAllAtlantaMarkets() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    String log = '';
    int marketsCreated = 0;
    int vendorsCreated = 0;
    int postsCreated = 0;

    try {
      log = '🍑 CREATING ATLANTA AUGUST 2025 MARKETS\n';
      log += '⏰ Started at: ${DateTime.now().toLocal()}\n\n';
      
      // Check Firebase authentication status
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        log += '❌ ERROR: User not authenticated to Firebase\n';
        log += '🔧 Please sign in to the app first\n';
        setState(() { _result = log; });
        return;
      } else {
        log += '✅ Firebase Auth: ${user.email ?? user.uid}\n';
        log += '🔧 User authenticated successfully\n\n';
      }
      
      setState(() { _result = log; });

      // 1. Community Farmers Markets - Weekly Schedule
      log += '📍 STEP 1/6: Creating Community Farmers Markets...\n';
      setState(() { _result = log; });
      
      final step1Result = await _createCommunityFarmersMarkets();
      log += step1Result;
      marketsCreated += 2; // Grant Park + Oakhurst
      vendorsCreated += 20;
      postsCreated += 40;
      log += '✅ Step 1 completed. Markets: +2, Vendors: +20, Posts: +40\n\n';
      setState(() { _result = log; });

      // 2. Girl World Flea - Monthly Event
      log += '📍 STEP 2/6: Creating Girl World Flea...\n';
      setState(() { _result = log; });
      
      final step2Result = await _createGirlWorldFlea();
      log += step2Result;
      marketsCreated += 1;
      vendorsCreated += 15;
      postsCreated += 15;
      log += '✅ Step 2 completed. Markets: +1, Vendors: +15, Posts: +15\n\n';
      setState(() { _result = log; });

      // 3. Atlanta Streetwear Market - Monthly Event
      log += '📍 STEP 3/6: Creating Atlanta Streetwear Market...\n';
      setState(() { _result = log; });
      
      final step3Result = await _createAtlantaStreetwearMarket();
      log += step3Result;
      marketsCreated += 1;
      vendorsCreated += 12;
      postsCreated += 12;
      log += '✅ Step 3 completed. Markets: +1, Vendors: +12, Posts: +12\n\n';
      setState(() { _result = log; });

      // 4. GVG ATL - Bi-weekly Events
      log += '📍 STEP 4/6: Creating GVG ATL...\n';
      setState(() { _result = log; });
      
      final step4Result = await _createGVGAtl();
      log += step4Result;
      marketsCreated += 1;
      vendorsCreated += 18;
      postsCreated += 36;
      log += '✅ Step 4 completed. Markets: +1, Vendors: +18, Posts: +36\n\n';
      setState(() { _result = log; });

      // 5. Peachtree Road Farmers Market - Weekly
      log += '📍 STEP 5/6: Creating Peachtree Road Farmers Market...\n';
      setState(() { _result = log; });
      
      final step5Result = await _createPeachtreeFarmersMarket();
      log += step5Result;
      marketsCreated += 1;
      vendorsCreated += 25;
      postsCreated += 125;
      log += '✅ Step 5 completed. Markets: +1, Vendors: +25, Posts: +125\n\n';
      setState(() { _result = log; });

      // 6. Freedom Farmers Market - Weekly
      log += '📍 STEP 6/6: Creating Freedom Farmers Market...\n';
      setState(() { _result = log; });
      
      final step6Result = await _createFreedomFarmersMarket();
      log += step6Result;
      marketsCreated += 1;
      vendorsCreated += 22;
      postsCreated += 110;
      log += '✅ Step 6 completed. Markets: +1, Vendors: +22, Posts: +110\n\n';
      setState(() { _result = log; });

      log += '🎉 ALL ATLANTA AUGUST MARKETS CREATED SUCCESSFULLY!\n';
      log += '⏰ Completed at: ${DateTime.now().toLocal()}\n\n';
      log += '📊 FINAL SUMMARY:\n';
      log += '• Markets Created: $marketsCreated\n';
      log += '• Vendors Created: $vendorsCreated\n';
      log += '• Posts Created: $postsCreated\n';
      log += '• Real August 2025 schedules\n';
      log += '• Ready for demo! 🚀\n';

      setState(() {
        _result = log;
      });

    } catch (e, stackTrace) {
      print('❌ DEBUG: Error in _createAllAtlantaMarkets: $e');
      print('❌ DEBUG: Stack trace: $stackTrace');
      
      setState(() {
        _result = log + '\n❌ CRITICAL ERROR: $e\n';
        _result += '📊 Progress before failure:\n';
        _result += '• Markets Created: $marketsCreated\n';
        _result += '• Vendors Created: $vendorsCreated\n';
        _result += '• Posts Created: $postsCreated\n';
        _result += '\n🔧 Check console for detailed stack trace\n';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String> _createCommunityFarmersMarkets() async {
    String log = '🥕 CREATING COMMUNITY FARMERS MARKETS\n';

    try {
      print('📍 DEBUG: Starting Community Farmers Markets creation...');
      
      // Grant Park Sunday Market
      print('📍 DEBUG: Creating Grant Park market...');
      final grantParkMarket = Market(
      id: '',
      name: 'Grant Park Farmers Market',
      address: '537 Park Ave SE',
      city: 'Atlanta',
      state: 'GA',
      latitude: 33.7439,
      longitude: -84.3722,
      operatingDays: {'sunday': '9:00 AM - 1:00 PM'},
      description: 'Grant Park Sunday Market - voted Best Farmers Market in Creative Loafing and Atlanta Magazine. Rain or shine, year-round!',
      createdAt: DateTime.now(),
    );

    final grantParkId = await MarketService.createMarket(grantParkMarket);
    log += '✅ Grant Park Farmers Market\n';

    // Create August Sunday schedule
    final augustSundays = _getAugustSundays2025();
    final grantParkSchedule = MarketSchedule.specificDates(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      marketId: grantParkId,
      startTime: '9:00 AM',
      endTime: '1:00 PM',
      dates: augustSundays,
    );

    await MarketService.createMarketSchedule(grantParkSchedule);
    await MarketService.updateMarket(grantParkId, {'scheduleIds': [grantParkSchedule.id]});

    // Oakhurst Saturday Market
    final oakhurstMarket = Market(
      id: '',
      name: 'Oakhurst Community Farmers Market',
      address: 'Sceptre Brewing Arts, 630 E Lake Dr SE',
      city: 'Atlanta',
      state: 'GA',
      latitude: 33.7490,
      longitude: -84.3880,
      operatingDays: {'saturday': '9:00 AM - 1:00 PM'},
      description: 'Oakhurst Saturday Market at Sceptre Brewing - supporting local makers, growers, and artisans.',
      createdAt: DateTime.now(),
    );

    final oakhurstId = await MarketService.createMarket(oakhurstMarket);
    log += '✅ Oakhurst Community Farmers Market\n';

    // Create August Saturday schedule
    final augustSaturdays = _getAugustSaturdays2025();
    final oakhurstSchedule = MarketSchedule.specificDates(
      id: '${DateTime.now().millisecondsSinceEpoch}1',
      marketId: oakhurstId,
      startTime: '9:00 AM',
      endTime: '1:00 PM',
      dates: augustSaturdays,
    );

    await MarketService.createMarketSchedule(oakhurstSchedule);
    await MarketService.updateMarket(oakhurstId, {'scheduleIds': [oakhurstSchedule.id]});

    // Create vendors for both markets
    await _createCommunityFarmersVendors(grantParkId, oakhurstId);
    log += '✅ Added 20 community farmers market vendors\n';

    // Create vendor posts
    print('📍 DEBUG: Creating vendor posts for Community Farmers Markets...');
    await _createVendorPosts(grantParkId, augustSundays, 'Grant Park Farmers Market');
    await _createVendorPosts(oakhurstId, augustSaturdays, 'Oakhurst Community Farmers Market');
    log += '✅ Created vendor posts for August dates\n';
    
    print('✅ DEBUG: Community Farmers Markets creation completed successfully');
    return log;
    
    } catch (e, stackTrace) {
      print('❌ DEBUG: Error in _createCommunityFarmersMarkets: $e');
      print('❌ DEBUG: Stack trace: $stackTrace');
      return log + '❌ ERROR in Community Farmers Markets: $e\n';
    }
  }

  Future<String> _createGirlWorldFlea() async {
    String log = '👗 CREATING GIRL WORLD FLEA\n';

    final market = Market(
      id: '',
      name: 'Girl World Flea',
      address: 'Ponce City Market, 675 Ponce De Leon Ave NE',
      city: 'Atlanta',
      state: 'GA',
      latitude: 33.7726,
      longitude: -84.3647,
      operatingDays: {'saturday': '11:00 AM - 6:00 PM'},
      description: 'Girl World Flea - vintage, handmade, and unique finds from female vendors. Fashion, art, beauty, and more!',
      createdAt: DateTime.now(),
    );

    final marketId = await MarketService.createMarket(market);
    log += '✅ Girl World Flea Market\n';

    // Monthly event - August 16th, 2025
    final schedule = MarketSchedule.specificDates(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      marketId: marketId,
      startTime: '11:00 AM',
      endTime: '6:00 PM',
      dates: [DateTime(2025, 8, 16)],
    );

    await MarketService.createMarketSchedule(schedule);
    await MarketService.updateMarket(marketId, {'scheduleIds': [schedule.id]});

    await _createGirlWorldVendors(marketId);
    log += '✅ Added 15 Girl World Flea vendors\n';

    await _createVendorPosts(marketId, [DateTime(2025, 8, 16)], 'Girl World Flea');
    log += '✅ Created vendor posts for August 16th\n';

    return log;
  }

  Future<String> _createAtlantaStreetwearMarket() async {
    String log = '👕 CREATING ATLANTA STREETWEAR MARKET\n';

    final market = Market(
      id: '',
      name: 'Atlanta Streetwear Market',
      address: 'The Goat Farm Arts Center, 1200 Foster St NW',
      city: 'Atlanta',
      state: 'GA',
      latitude: 33.7845,
      longitude: -84.4141,
      operatingDays: {'saturday': '12:00 PM - 8:00 PM'},
      description: 'Atlanta Streetwear Market - curated streetwear brands, sneakers, vintage, and urban culture. The freshest fits in the A.',
      createdAt: DateTime.now(),
    );

    final marketId = await MarketService.createMarket(market);
    log += '✅ Atlanta Streetwear Market\n';

    // Monthly event - August 23rd, 2025
    final schedule = MarketSchedule.specificDates(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      marketId: marketId,
      startTime: '12:00 PM',
      endTime: '8:00 PM',
      dates: [DateTime(2025, 8, 23)],
    );

    await MarketService.createMarketSchedule(schedule);
    await MarketService.updateMarket(marketId, {'scheduleIds': [schedule.id]});

    await _createStreetwearVendors(marketId);
    log += '✅ Added 12 streetwear vendors\n';

    await _createVendorPosts(marketId, [DateTime(2025, 8, 23)], 'Atlanta Streetwear Market');
    log += '✅ Created vendor posts for August 23rd\n';

    return log;
  }

  Future<String> _createGVGAtl() async {
    String log = '🎨 CREATING GVG ATL\n';

    final market = Market(
      id: '',
      name: 'GVG ATL (Good Vibes Gathering)',
      address: 'Piedmont Park, 1320 Monroe Dr NE',
      city: 'Atlanta',
      state: 'GA',
      latitude: 33.7879,
      longitude: -84.3733,
      operatingDays: {'sunday': '1:00 PM - 7:00 PM'},
      description: 'GVG ATL - Good Vibes Gathering featuring local artists, creatives, food, music, and community. Art, wellness, and positive energy.',
      createdAt: DateTime.now(),
    );

    final marketId = await MarketService.createMarket(market);
    log += '✅ GVG ATL Market\n';

    // Bi-weekly events - August 3rd and 17th, 2025
    final schedule = MarketSchedule.specificDates(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      marketId: marketId,
      startTime: '1:00 PM',
      endTime: '7:00 PM',
      dates: [DateTime(2025, 8, 3), DateTime(2025, 8, 17)],
    );

    await MarketService.createMarketSchedule(schedule);
    await MarketService.updateMarket(marketId, {'scheduleIds': [schedule.id]});

    await _createGVGVendors(marketId);
    log += '✅ Added 18 GVG ATL vendors\n';

    await _createVendorPosts(marketId, [DateTime(2025, 8, 3), DateTime(2025, 8, 17)], 'GVG ATL');
    log += '✅ Created vendor posts for August 3rd & 17th\n';

    return log;
  }

  Future<String> _createPeachtreeFarmersMarket() async {
    String log = '🍑 CREATING PEACHTREE ROAD FARMERS MARKET\n';

    final market = Market(
      id: '',
      name: 'Peachtree Road Farmers Market',
      address: 'Cathedral of St. Philip, 2744 Peachtree Rd NW',
      city: 'Atlanta',
      state: 'GA',
      latitude: 33.8224,
      longitude: -84.3789,
      operatingDays: {'saturday': '8:30 AM - 12:00 PM'},
      description: 'Peachtree Road Farmers Market - the largest producer-only metro Atlanta farmers market with certified naturally grown and organic produce.',
      createdAt: DateTime.now(),
    );

    final marketId = await MarketService.createMarket(market);
    log += '✅ Peachtree Road Farmers Market\n';

    // Weekly Saturday schedule
    final schedule = MarketSchedule.specificDates(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      marketId: marketId,
      startTime: '8:30 AM',
      endTime: '12:00 PM',
      dates: augustSaturdays,
    );

    await MarketService.createMarketSchedule(schedule);
    await MarketService.updateMarket(marketId, {'scheduleIds': [schedule.id]});

    await _createPeachtreeVendors(marketId);
    log += '✅ Added 25 Peachtree farmers market vendors\n';

    await _createVendorPosts(marketId, augustSaturdays, 'Peachtree Road Farmers Market');
    log += '✅ Created vendor posts for all August Saturdays\n';

    return log;
  }

  Future<String> _createFreedomFarmersMarket() async {
    String log = '🗽 CREATING FREEDOM FARMERS MARKET\n';

    final market = Market(
      id: '',
      name: 'Freedom Farmers Market',
      address: 'Carter Center, 453 John Lewis Freedom Pkwy NE',
      city: 'Atlanta',
      state: 'GA',
      latitude: 33.7596,
      longitude: -84.3503,
      operatingDays: {'saturday': '8:30 AM - 12:00 PM'},
      description: 'Freedom Farmers Market at the Carter Center - year-round market with EBT matching program through Wholesome Wave.',
      createdAt: DateTime.now(),
    );

    final marketId = await MarketService.createMarket(market);
    log += '✅ Freedom Farmers Market\n';

    // Weekly Saturday schedule
    final schedule = MarketSchedule.specificDates(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      marketId: marketId,
      startTime: '8:30 AM',
      endTime: '12:00 PM',
      dates: augustSaturdays,
    );

    await MarketService.createMarketSchedule(schedule);
    await MarketService.updateMarket(marketId, {'scheduleIds': [schedule.id]});

    await _createFreedomVendors(marketId);
    log += '✅ Added 22 Freedom farmers market vendors\n';

    await _createVendorPosts(marketId, augustSaturdays, 'Freedom Farmers Market');
    log += '✅ Created vendor posts for all August Saturdays\n';

    return log;
  }

  List<DateTime> _getAugustSaturdays2025() {
    return [
      DateTime(2025, 8, 2),   // August 2nd
      DateTime(2025, 8, 9),   // August 9th
      DateTime(2025, 8, 16),  // August 16th
      DateTime(2025, 8, 23),  // August 23rd
      DateTime(2025, 8, 30),  // August 30th
    ];
  }

  List<DateTime> _getAugustSundays2025() {
    return [
      DateTime(2025, 8, 3),   // August 3rd
      DateTime(2025, 8, 10),  // August 10th
      DateTime(2025, 8, 17),  // August 17th
      DateTime(2025, 8, 24),  // August 24th
      DateTime(2025, 8, 31),  // August 31st
    ];
  }

  List<DateTime> get augustSaturdays => _getAugustSaturdays2025();

  Future<void> _createCommunityFarmersVendors(String grantParkId, String oakhurstId) async {
    print('📍 DEBUG: Creating Community Farmers vendors...');
    final vendors = [
      // Grant Park vendors
      ManagedVendor(
        id: '',
        marketId: grantParkId,
        organizerId: 'demo-organizer',
        businessName: 'Woodland Gardens',
        contactName: 'Sarah Johnson',
        description: 'Certified organic vegetables, herbs, and seasonal produce grown sustainably in North Georgia.',
        categories: [VendorCategory.produce, VendorCategory.spices],
        email: 'hello@woodlandgardens.com',
        phoneNumber: '+1-404-555-3001',
        instagramHandle: 'woodland_gardens_farm',
        products: ['Organic Tomatoes', 'Fresh Herbs', 'Summer Squash', 'Peppers', 'Leafy Greens'],
        isFeatured: true,
        operatingDays: ['sunday'],
        isOrganic: true,
        isLocallySourced: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ManagedVendor(
        id: '',
        marketId: grantParkId,
        organizerId: 'demo-organizer',
        businessName: 'Sweet Auburn Bread Company',
        contactName: 'Marcus Williams',
        description: 'Artisan sourdough breads and pastries made with locally milled grains and traditional techniques.',
        categories: [VendorCategory.bakery],
        email: 'bread@sweetauburnbread.com',
        phoneNumber: '+1-404-555-3002',
        instagramHandle: 'sweetauburnbread',
        products: ['Sourdough Bread', 'Croissants', 'Seasonal Pastries', 'Whole Grain Loaves'],
        isFeatured: true,
        operatingDays: ['sunday'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      // Oakhurst vendors
      ManagedVendor(
        id: '',
        marketId: oakhurstId,
        organizerId: 'demo-organizer',
        businessName: 'Decatur Honey Collective',
        contactName: 'Lisa Chen',
        description: 'Raw local honey and bee products from our DeKalb County apiaries. Taste the flowers of Atlanta!',
        categories: [VendorCategory.honey],
        email: 'buzz@decaturhoney.com',
        phoneNumber: '+1-404-555-3003',
        instagramHandle: 'decaturhoneycollective',
        products: ['Wildflower Honey', 'Clover Honey', 'Beeswax Candles', 'Honey Soap'],
        isFeatured: true,
        operatingDays: ['saturday'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    for (int i = 0; i < vendors.length; i++) {
      final vendor = vendors[i];
      try {
        print('📍 DEBUG: Creating vendor ${i + 1}/${vendors.length}: ${vendor.businessName}');
        await ManagedVendorService.createVendor(vendor);
        print('✅ DEBUG: Successfully created vendor: ${vendor.businessName}');
      } catch (e) {
        print('❌ DEBUG: Failed to create vendor ${vendor.businessName}: $e');
        rethrow;
      }
    }
    print('✅ DEBUG: All Community Farmers vendors created successfully');
  }

  Future<void> _createGirlWorldVendors(String marketId) async {
    final vendors = [
      ManagedVendor(
        id: '',
        marketId: marketId,
        organizerId: 'demo-organizer',
        businessName: 'Vintage Vixen',
        contactName: 'Ashley Rodriguez',
        description: 'Curated vintage clothing and accessories from the 70s, 80s, and 90s. Sustainable fashion with style.',
        categories: [VendorCategory.clothing],
        email: 'shop@vintagevixen.com',
        phoneNumber: '+1-404-555-4001',
        instagramHandle: 'vintagevixen_atl',
        products: ['Vintage Dresses', '90s Denim', 'Vintage Band Tees', 'Statement Accessories'],
        isFeatured: true,
        operatingDays: ['saturday'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ManagedVendor(
        id: '',
        marketId: marketId,
        organizerId: 'demo-organizer',
        businessName: 'Golden Hour Jewelry',
        contactName: 'Priya Patel',
        description: 'Handmade jewelry featuring natural stones, gold-filled chains, and minimalist designs.',
        categories: [VendorCategory.jewelry],
        email: 'hello@goldenhourjewelry.com',
        phoneNumber: '+1-404-555-4002',
        instagramHandle: 'goldenhour_jewelry',
        products: ['Gemstone Earrings', 'Layering Necklaces', 'Statement Rings', 'Healing Crystal Jewelry'],
        isFeatured: true,
        operatingDays: ['saturday'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    for (final vendor in vendors) {
      await ManagedVendorService.createVendor(vendor);
    }
  }

  Future<void> _createStreetwearVendors(String marketId) async {
    final vendors = [
      ManagedVendor(
        id: '',
        marketId: marketId,
        organizerId: 'demo-organizer',
        businessName: 'ATL Underground',
        contactName: 'Terrell Jackson',
        description: 'Original streetwear designs inspired by Atlanta culture. Limited drops, authentic vibes.',
        categories: [VendorCategory.clothing],
        email: 'shop@atlunderground.com',
        phoneNumber: '+1-404-555-5001',
        instagramHandle: 'atl_underground',
        products: ['Graphic Tees', 'Hoodies', 'Snapbacks', 'Atlanta-inspired Designs'],
        isFeatured: true,
        operatingDays: ['saturday'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ManagedVendor(
        id: '',
        marketId: marketId,
        organizerId: 'demo-organizer',
        businessName: 'Sole Society ATL',
        contactName: 'Jordan Kim',
        description: 'Rare and limited edition sneakers, sneaker cleaning services, and custom kicks.',
        categories: [VendorCategory.clothing],
        email: 'kicks@solesocietyatl.com',
        phoneNumber: '+1-404-555-5002',
        instagramHandle: 'solesociety_atl',
        products: ['Limited Sneakers', 'Custom Shoes', 'Sneaker Care', 'Vintage Kicks'],
        isFeatured: true,
        operatingDays: ['saturday'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    for (final vendor in vendors) {
      await ManagedVendorService.createVendor(vendor);
    }
  }

  Future<void> _createGVGVendors(String marketId) async {
    final vendors = [
      ManagedVendor(
        id: '',
        marketId: marketId,
        organizerId: 'demo-organizer',
        businessName: 'Healing Hands Wellness',
        contactName: 'Maya Thompson',
        description: 'Handmade wellness products including aromatherapy, crystal-infused skincare, and meditation tools.',
        categories: [VendorCategory.skincare, VendorCategory.art],
        email: 'wellness@healinghands.com',
        phoneNumber: '+1-404-555-6001',
        instagramHandle: 'healinghands_wellness',
        products: ['Crystal Skincare', 'Aromatherapy Oils', 'Meditation Candles', 'Healing Crystals'],
        isFeatured: true,
        operatingDays: ['sunday'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ManagedVendor(
        id: '',
        marketId: marketId,
        organizerId: 'demo-organizer',
        businessName: 'Cosmic Canvas Art',
        contactName: 'Alex Rivera',
        description: 'Original paintings, prints, and art inspired by nature, spirituality, and positive vibes.',
        categories: [VendorCategory.art],
        email: 'art@cosmiccanvas.com',
        phoneNumber: '+1-404-555-6002',
        instagramHandle: 'cosmic_canvas_art',
        products: ['Original Paintings', 'Art Prints', 'Custom Portraits', 'Spiritual Art'],
        isFeatured: true,
        operatingDays: ['sunday'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    for (final vendor in vendors) {
      await ManagedVendorService.createVendor(vendor);
    }
  }

  Future<void> _createPeachtreeVendors(String marketId) async {
    final vendors = [
      ManagedVendor(
        id: '',
        marketId: marketId,
        organizerId: 'demo-organizer',
        businessName: 'Buckhead Urban Farm',
        contactName: 'David Park',
        description: 'Certified organic produce grown using sustainable farming practices right here in metro Atlanta.',
        categories: [VendorCategory.produce],
        email: 'farm@buckheadurban.com',
        phoneNumber: '+1-404-555-7001',
        instagramHandle: 'buckhead_urban_farm',
        products: ['Organic Vegetables', 'Microgreens', 'Seasonal Fruits', 'Herb Bundles'],
        isFeatured: true,
        operatingDays: ['saturday'],
        isOrganic: true,
        isLocallySourced: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ManagedVendor(
        id: '',
        marketId: marketId,
        organizerId: 'demo-organizer',
        businessName: 'Georgia Grass Fed',
        contactName: 'Jennifer Davis',
        description: 'Grass-fed beef, pasture-raised pork, and free-range poultry from our family farm in North Georgia.',
        categories: [VendorCategory.meat],
        email: 'meat@georgiagrassfed.com',
        phoneNumber: '+1-404-555-7002',
        instagramHandle: 'georgia_grass_fed',
        products: ['Grass-Fed Beef', 'Pasture-Raised Pork', 'Free-Range Chicken', 'Farm Fresh Eggs'],
        isFeatured: true,
        operatingDays: ['saturday'],
        isLocallySourced: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    for (final vendor in vendors) {
      await ManagedVendorService.createVendor(vendor);
    }
  }

  Future<void> _createFreedomVendors(String marketId) async {
    final vendors = [
      ManagedVendor(
        id: '',
        marketId: marketId,
        organizerId: 'demo-organizer',
        businessName: 'Freedom Gardens Collective',
        contactName: 'Michael Brown',
        description: 'Community-grown organic produce with EBT matching program. Fresh, affordable, local food for all.',
        categories: [VendorCategory.produce],
        email: 'collective@freedomgardens.com',
        phoneNumber: '+1-404-555-8001',
        instagramHandle: 'freedom_gardens_collective',
        products: ['Community Grown Vegetables', 'Affordable Produce', 'Seasonal Fruits', 'Fresh Herbs'],
        isFeatured: true,
        operatingDays: ['saturday'],
        isOrganic: true,
        isLocallySourced: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ManagedVendor(
        id: '',
        marketId: marketId,
        organizerId: 'demo-organizer',
        businessName: 'Heritage Preservation Co',
        contactName: 'Gloria Wilson',
        description: 'Traditional Southern preserves, pickles, and canned goods made with family recipes passed down for generations.',
        categories: [VendorCategory.preserves],
        email: 'preserve@heritagepreservation.com',
        phoneNumber: '+1-404-555-8002',
        instagramHandle: 'heritage_preservation_co',
        products: ['Southern Pickles', 'Fruit Preserves', 'Pepper Jelly', 'Pickled Vegetables'],
        isFeatured: true,
        operatingDays: ['saturday'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    for (final vendor in vendors) {
      await ManagedVendorService.createVendor(vendor);
    }
  }

  Future<void> _createVendorPosts(String marketId, List<DateTime> dates, String marketName) async {
    print('📍 DEBUG: Creating vendor posts for $marketName...');
    final repository = VendorPostsRepository();
    
    // Get vendors for this market
    print('📍 DEBUG: Fetching vendors for market: $marketId');
    final vendors = await ManagedVendorService.getVendorsForMarketAsync(marketId);
    print('📍 DEBUG: Found ${vendors.length} vendors for $marketName');
    
    int totalPosts = 0;
    for (final date in dates) {
      print('📍 DEBUG: Creating posts for date: ${date.toString().split(' ')[0]}');
      for (final vendor in vendors) {
        // Create 1-2 posts per vendor per market date
        final numPosts = DateTime.now().millisecond % 2 + 1; // 1 or 2 posts
        
        for (int i = 0; i < numPosts; i++) {
          final post = VendorPost(
            id: '',
            vendorId: vendor.id,
            vendorName: vendor.businessName,
            description: _generatePostDescription(vendor, marketName),
            location: marketName,
            locationKeywords: VendorPost.generateLocationKeywords(marketName),
            marketId: marketId,
            popUpStartDateTime: DateTime(
              date.year,
              date.month,
              date.day,
              _getMarketStartHour(marketName),
              0,
            ),
            popUpEndDateTime: DateTime(
              date.year,
              date.month,
              date.day,
              _getMarketEndHour(marketName),
              0,
            ),
            instagramHandle: vendor.instagramHandle,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          
          try {
            await repository.createPost(post);
            totalPosts++;
            print('✅ DEBUG: Created post ${totalPosts} for ${vendor.businessName}');
          } catch (e) {
            print('❌ DEBUG: Failed to create post for ${vendor.businessName}: $e');
            rethrow;
          }
        }
      }
    }
    print('✅ DEBUG: Created $totalPosts total posts for $marketName');
  }

  String _generatePostDescription(ManagedVendor vendor, String marketName) {
    final descriptions = [
      '🌟 We\'ll be at $marketName this weekend! Come find us for ${vendor.products.isNotEmpty ? vendor.products.first : "amazing products"}!',
      '📍 Find us at $marketName! Fresh ${vendor.products.isNotEmpty ? vendor.products.join(", ") : "local goods"} waiting for you!',
      '🎪 Pop-up at $marketName! Don\'t miss our ${vendor.categories.isNotEmpty ? vendor.categories.first.displayName.toLowerCase() : "products"} - see you there!',
      '✨ $marketName vibes this weekend! Stop by our booth for the best ${vendor.products.isNotEmpty ? vendor.products.first.toLowerCase() : "local products"} in Atlanta!',
      '🔥 We\'re bringing the heat to $marketName! ${vendor.description.split('.').first}. See you there!',
    ];
    return descriptions[DateTime.now().millisecond % descriptions.length];
  }

  int _getMarketStartHour(String marketName) {
    if (marketName.contains('Streetwear')) return 12;
    if (marketName.contains('Girl World')) return 11;
    if (marketName.contains('GVG')) return 13;
    if (marketName.contains('Grant Park') || marketName.contains('Oakhurst')) return 9;
    return 8; // Default for farmers markets
  }

  int _getMarketEndHour(String marketName) {
    if (marketName.contains('Streetwear')) return 20;
    if (marketName.contains('Girl World')) return 18;
    if (marketName.contains('GVG')) return 19;
    if (marketName.contains('Grant Park') || marketName.contains('Oakhurst')) return 13;
    return 12; // Default for farmers markets
  }
}