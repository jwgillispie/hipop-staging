import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/market.dart';
import '../models/market_schedule.dart';
import '../models/managed_vendor.dart';
import '../services/market_service.dart';
import '../services/managed_vendor_service.dart';

class DebugMarketCreator extends StatefulWidget {
  const DebugMarketCreator({super.key});

  @override
  State<DebugMarketCreator> createState() => _DebugMarketCreatorState();
}

class _DebugMarketCreatorState extends State<DebugMarketCreator> {
  bool _isLoading = false;
  String _result = '';

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.green.shade50,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_business, color: Colors.green.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  'DEBUG: Create Demo Markets',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Create realistic markets with vendors for demos:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            
            // Mini Vegan Market Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _createMiniVeganMarket(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                          Text('🌱 Mini Vegan Market'),
                          Text(
                            'Little 5 Points • Sunday 1-5 PM • 6 vendors',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Cathedral Market Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _createCathedralMarket(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Column(
                  children: [
                    Text('🏛️ Cathedral Farmers Market'),
                    Text(
                      'Peachtree Rd • Saturday 8:30 AM-12 PM • 10 vendors',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Dunwoody Market Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _createDunwoodyMarket(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Column(
                  children: [
                    Text('🧺 Dunwoody Farmers Market'),
                    Text(
                      'Dunwoody, GA • Weekends • 38+ amazing vendors',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Oakhurst Market Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _createOakhurstMarket(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Column(
                  children: [
                    Text('🍺 Oakhurst Farmers Market'),
                    Text(
                      'Front of Sceptre Beer • Saturday 9 AM-1 PM • Next 4 weeks',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            if (_result.isNotEmpty) ...[
              Container(
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

  Future<void> _createMiniVeganMarket() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      String log = '🌱 CREATING MINI VEGAN MARKET\n\n';

      // Create the market
      final market = Market(
        id: '',
        name: 'Mini Vegan Market by Bien Vegano ATL',
        address: 'Liminal Space ATL (next to Sevananda), Little Five Points',
        city: 'Atlanta',
        state: 'GA',
        latitude: 33.7679,
        longitude: -84.3513,
        operatingDays: {
          'sunday': '1:00 PM - 5:00 PM',
        },
        description: 'A curated pop-up full of flavor, art, and all things vegan right in the heart of Little 5 Points. Come vibe with us for an afternoon of community, creativity, and plant-based joy! 🌿',
        createdAt: DateTime.now(),
      );

      final marketId = await MarketService.createMarket(market);
      log += '✅ Created market: ${market.name}\n';
      log += '📍 Market ID: $marketId\n\n';

      // Create market schedule for Sunday, July 13th, 2025
      final schedule = MarketSchedule.specificDates(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        marketId: marketId,
        startTime: '1:00 PM',
        endTime: '5:00 PM',
        dates: [DateTime(2025, 7, 13)],
      );

      final scheduleId = await MarketService.createMarketSchedule(schedule);
      
      // Update market with schedule ID
      await MarketService.updateMarket(marketId, {
        'scheduleIds': [scheduleId]
      });
      
      log += '✅ Added schedule for Sunday, July 13th, 2025\n\n';

      setState(() {
        _result = log;
      });

      // Create vendors
      final vendors = [
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Mucho Amor Vegan',
          contactName: 'Mucho Amor Team',
          description: 'Irresistible vegan street tacos with bold, authentic flavor. Our plant-based tacos bring all the taste and soul of traditional Mexican street food.',
          categories: [VendorCategory.prepared_foods],
          email: 'hello@muchoamor.vegan',
          phoneNumber: '+1-404-555-0001',
          instagramHandle: 'muchoamor.vegan',
          products: ['Vegan Street Tacos', 'Jackfruit Carnitas', 'Mushroom Al Pastor', 'Cashew Crema', 'Salsa Verde'],
          isFeatured: true,
          operatingDays: ['sunday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'The Creamy Spot',
          contactName: 'Creamy Spot Team',
          description: 'Small-batch, dairy-free ice cream made with love. We craft premium plant-based frozen treats using only the finest natural ingredients.',
          categories: [VendorCategory.other],
          email: 'hello@thecreamyspot.com',
          phoneNumber: '+1-404-555-0002',
          instagramHandle: 'thecreamyspot',
          products: ['Vanilla Bean Ice Cream', 'Chocolate Fudge', 'Strawberry Coconut', 'Mint Chip', 'Salted Caramel'],
          isFeatured: true,
          operatingDays: ['sunday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Pecan Milk',
          contactName: 'Pecan Milk Team',
          description: 'Creamy, refreshing plant-based milks made with clean, nourishing ingredients. Our locally-made nut milks are fresh, organic, and delicious.',
          categories: [VendorCategory.beverages],
          email: 'hello@pecanmilk.com',
          phoneNumber: '+1-404-555-0003',
          instagramHandle: 'pecanmilk',
          products: ['Fresh Pecan Milk', 'Almond Milk', 'Oat Milk', 'Cashew Milk', 'Vanilla Pecan Milk'],
          isFeatured: false,
          operatingDays: ['sunday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Terra Nohpalli',
          contactName: 'Terra Artisan',
          description: 'Beautiful Mexican handmade jewelry & accessories full of culture and soul. Each piece tells a story and celebrates traditional craftsmanship.',
          categories: [VendorCategory.jewelry, VendorCategory.crafts],
          email: 'hello@terra.nohpalli',
          phoneNumber: '+1-404-555-0004',
          instagramHandle: 'terra.nohpalli',
          products: ['Silver Jewelry', 'Handmade Earrings', 'Cultural Accessories', 'Traditional Bracelets', 'Artisan Necklaces'],
          isFeatured: false,
          operatingDays: ['sunday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Snoodie Bath Essentials',
          contactName: 'Snoodie Team',
          description: 'Luxe, cruelty-free bath & body goods for the perfect self-care moment. Our products are made with natural ingredients and lots of love.',
          categories: [VendorCategory.skincare],
          email: 'hello@snoodiebath.com',
          phoneNumber: '+1-404-555-0005',
          instagramHandle: 'snoodiebathessentials',
          products: ['Bath Bombs', 'Body Scrubs', 'Moisturizing Soap', 'Essential Oil Blends', 'Shower Steamers'],
          isFeatured: false,
          operatingDays: ['sunday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: "Let's Talk Food",
          contactName: 'Food Education Team',
          description: 'Inspiring vegan cookbooks & meal plans to elevate your kitchen game. We make plant-based cooking accessible, delicious, and fun for everyone.',
          categories: [VendorCategory.other],
          email: 'hello@letstalkfood.com',
          phoneNumber: '+1-404-555-0006',
          instagramHandle: 'lets.talkfood',
          products: ['Vegan Cookbooks', 'Meal Planning Guides', 'Recipe Cards', 'Cooking Classes', 'Nutrition Guides'],
          isFeatured: false,
          operatingDays: ['sunday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      for (final vendor in vendors) {
        await ManagedVendorService.createVendor(vendor);
        log += '✅ Added vendor: ${vendor.businessName}\n';
        setState(() {
          _result = log;
        });
      }

      log += '\n🎉 MINI VEGAN MARKET CREATED!\n';
      log += '📍 Little Five Points, Atlanta\n';
      log += '📅 Sunday, July 13th, 2025\n';
      log += '🕐 1:00 PM - 5:00 PM\n';
      log += '🌿 ${vendors.length} vegan vendors ready to go!\n';
      
      setState(() {
        _result = log;
      });

    } catch (e) {
      setState(() {
        _result += '\n❌ ERROR: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createCathedralMarket() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      String log = '🏛️ CREATING CATHEDRAL FARMERS MARKET\n\n';

      // Create the market
      final market = Market(
        id: '',
        name: 'Cathedral of St. Philip Farmers Market',
        address: '2744 Peachtree Rd',
        city: 'Atlanta',
        state: 'GA',
        latitude: 33.8224,
        longitude: -84.3789,
        operatingDays: {
          'saturday': '8:30 AM - 12:00 PM',
        },
        description: 'Join us Saturday from 8:30am - 12pm! Shop over 70 local vendors, enjoy live music, children\'s area, playground and more. Story time by the Alliance Theatre at the music tent at 9:30am & 10:30am! SNAP/EBT is accepted and we will double your benefits on fresh fruits and vegetables.',
        createdAt: DateTime.now(),
      );

      final marketId = await MarketService.createMarket(market);
      log += '✅ Created market: ${market.name}\n';
      log += '📍 Market ID: $marketId\n\n';

      // Create recurring schedule for Saturdays
      final schedule = MarketSchedule.recurring(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        marketId: marketId,
        startTime: '8:30 AM',
        endTime: '12:00 PM',
        pattern: RecurrencePattern.weekly,
        daysOfWeek: [6], // Saturday
        startDate: DateTime.now(),
      );

      final scheduleId = await MarketService.createMarketSchedule(schedule);
      
      // Update market with schedule ID
      await MarketService.updateMarket(marketId, {
        'scheduleIds': [scheduleId]
      });
      
      log += '✅ Added recurring Saturday schedule\n\n';

      setState(() {
        _result = log;
      });

      // Create sample vendors (representing the 70+ vendors)
      final vendors = [
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Roshambo Restaurant (Chef Pop Up)',
          contactName: 'Chef Kevin Leveille',
          description: 'This week\'s Chef Pop Up featuring Breakfast Burrito, Fried Bologna Sandwich, Mini Caramel Pecan Monkey Bread, and Dom\'s Sweet Tea Drink. Look for the Big Green Egg Tent!',
          categories: [VendorCategory.prepared_foods],
          email: 'chef@roshambo.com',
          phoneNumber: '+1-404-555-1001',
          products: ['Breakfast Burrito', 'Fried Bologna Sandwich', 'Mini Caramel Pecan Monkey Bread', 'Dom\'s Sweet Tea Drink'],
          isFeatured: true,
          operatingDays: ['saturday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Buckhead Produce',
          contactName: 'Farm Fresh Team',
          description: 'Fresh, locally-sourced produce direct from Georgia farms. SNAP/EBT accepted with double benefits on fresh fruits and vegetables.',
          categories: [VendorCategory.produce],
          email: 'info@buckheadproduce.com',
          phoneNumber: '+1-404-555-1002',
          products: ['Seasonal Vegetables', 'Fresh Fruits', 'Organic Greens', 'Root Vegetables', 'Herbs'],
          isFeatured: true,
          operatingDays: ['saturday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Alliance Theatre Children\'s Programs',
          contactName: 'Theatre Education Team',
          description: 'Story time by the Alliance Theatre at the music tent at 9:30am & 10:30am! Interactive children\'s programming and educational activities.',
          categories: [VendorCategory.other],
          email: 'education@alliancetheatre.org',
          phoneNumber: '+1-404-555-1003',
          products: ['Story Time Sessions', 'Children\'s Activities', 'Educational Programs', 'Interactive Entertainment'],
          isFeatured: false,
          operatingDays: ['saturday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Atlanta Honey Company',
          contactName: 'Local Beekeeper',
          description: 'Pure, raw honey and bee products from Atlanta-area apiaries. Taste the difference that local flowers make in our artisanal honey.',
          categories: [VendorCategory.honey],
          email: 'buzz@atlantahoney.com',
          phoneNumber: '+1-404-555-1004',
          products: ['Wildflower Honey', 'Clover Honey', 'Beeswax Candles', 'Honey Soap', 'Pollen'],
          isFeatured: false,
          operatingDays: ['saturday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Peachtree Pastries',
          contactName: 'Master Baker',
          description: 'Fresh-baked breads, pastries, and treats made daily. European-style bakery bringing traditional techniques to Atlanta.',
          categories: [VendorCategory.bakery],
          email: 'orders@peachtreepastries.com',
          phoneNumber: '+1-404-555-1005',
          products: ['Artisan Breads', 'Croissants', 'Seasonal Pastries', 'Custom Cakes', 'Gluten-Free Options'],
          isFeatured: false,
          operatingDays: ['saturday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Georgia Mountain Meats',
          contactName: 'Farm Direct Team',
          description: 'Grass-fed beef, pasture-raised pork, and free-range poultry from Georgia mountain farms. Sustainable, humane, and delicious.',
          categories: [VendorCategory.meat],
          email: 'farm@georgimountainmeats.com',
          phoneNumber: '+1-404-555-1006',
          products: ['Grass-Fed Beef', 'Pasture-Raised Pork', 'Free-Range Chicken', 'Farm Eggs', 'Artisan Sausages'],
          isFeatured: false,
          operatingDays: ['saturday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Artisan Pottery Studio',
          contactName: 'Local Potter',
          description: 'Handmade pottery, ceramics, and home goods crafted by local Atlanta artisans. Each piece is unique and functional art for your home.',
          categories: [VendorCategory.crafts, VendorCategory.art],
          email: 'studio@artisanpottery.com',
          phoneNumber: '+1-404-555-1007',
          products: ['Handmade Pottery', 'Ceramic Bowls', 'Coffee Mugs', 'Plant Pots', 'Decorative Pieces'],
          isFeatured: false,
          operatingDays: ['saturday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Southern Pickles & Preserves',
          contactName: 'Preservation Expert',
          description: 'Traditional Southern pickles, jams, and preserves made with time-honored recipes and locally-sourced ingredients.',
          categories: [VendorCategory.preserves],
          email: 'pickle@southernpreserves.com',
          phoneNumber: '+1-404-555-1008',
          products: ['Dill Pickles', 'Peach Preserves', 'Pepper Jelly', 'Pickled Okra', 'Seasonal Jams'],
          isFeatured: false,
          operatingDays: ['saturday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Fresh Cut Flowers',
          contactName: 'Local Florist',
          description: 'Seasonal cut flowers and plants grown locally. Bring the beauty of Georgia gardens to your home with our fresh arrangements.',
          categories: [VendorCategory.flowers],
          email: 'bloom@freshcutflowers.com',
          phoneNumber: '+1-404-555-1009',
          products: ['Seasonal Bouquets', 'Potted Plants', 'Herb Gardens', 'Cut Flowers', 'Seasonal Arrangements'],
          isFeatured: false,
          operatingDays: ['saturday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Live Music Collective',
          contactName: 'Music Coordinator',
          description: 'Live music performances throughout the market day. Local musicians providing the soundtrack to your Saturday morning shopping experience.',
          categories: [VendorCategory.other],
          email: 'music@livemarket.com',
          phoneNumber: '+1-404-555-1010',
          products: ['Live Performances', 'Local Musicians', 'Background Music', 'Interactive Performances'],
          isFeatured: false,
          operatingDays: ['saturday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      for (final vendor in vendors) {
        await ManagedVendorService.createVendor(vendor);
        log += '✅ Added vendor: ${vendor.businessName}\n';
        setState(() {
          _result = log;
        });
      }

      log += '\n🎉 CATHEDRAL FARMERS MARKET CREATED!\n';
      log += '📍 2744 Peachtree Rd, Atlanta\n';
      log += '📅 Every Saturday\n';
      log += '🕐 8:30 AM - 12:00 PM\n';
      log += '🎪 ${vendors.length} vendors (representing 70+ vendors)\n';
      log += '🎵 Live music & children\'s activities included!\n';
      
      setState(() {
        _result = log;
      });

    } catch (e) {
      setState(() {
        _result += '\n❌ ERROR: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createDunwoodyMarket() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      String log = '🧺 CREATING DUNWOODY FARMERS MARKET\n\n';

      // Create the market
      final market = Market(
        id: '',
        name: 'Dunwoody Farmers Market',
        address: 'Dunwoody Village Shopping Center',
        city: 'Dunwoody',
        state: 'GA',
        latitude: 33.9487,
        longitude: -84.3347,
        operatingDays: {
          'saturday': '9:00 AM - 1:00 PM',
          'sunday': '10:00 AM - 2:00 PM',
        },
        description: 'Shop over 38 amazing local vendors! Perfect for stocking up on your favorites, discovering something new, and enjoying the best of what our local makers and growers have to offer! Come out, support local, and soak up a beautiful day at the market. 🧺🍅🌻',
        createdAt: DateTime.now(),
      );

      final marketId = await MarketService.createMarket(market);
      log += '✅ Created market: ${market.name}\n';
      log += '📍 Market ID: $marketId\n\n';

      // Create recurring schedule for weekends
      final schedules = [
        MarketSchedule.recurring(
          id: '${DateTime.now().millisecondsSinceEpoch}1',
          marketId: marketId,
          startTime: '9:00 AM',
          endTime: '1:00 PM',
          pattern: RecurrencePattern.weekly,
          daysOfWeek: [6], // Saturday
          startDate: DateTime.now(),
        ),
        MarketSchedule.recurring(
          id: '${DateTime.now().millisecondsSinceEpoch}2',
          marketId: marketId,
          startTime: '10:00 AM',
          endTime: '2:00 PM',
          pattern: RecurrencePattern.weekly,
          daysOfWeek: [7], // Sunday
          startDate: DateTime.now(),
        ),
      ];

      final scheduleIds = <String>[];
      for (final schedule in schedules) {
        final scheduleId = await MarketService.createMarketSchedule(schedule);
        scheduleIds.add(scheduleId);
      }
      
      // Update market with schedule IDs
      await MarketService.updateMarket(marketId, {
        'scheduleIds': scheduleIds
      });
      
      log += '✅ Added weekend recurring schedules\n\n';

      setState(() {
        _result = log;
      });

      // Create vendors from the Instagram post
      final vendors = [
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Weld ATL',
          contactName: 'Weld Jewelry Team',
          description: 'Beautiful handcrafted jewelry made with precision and passion. Each piece is unique and designed to make a statement.',
          categories: [VendorCategory.jewelry],
          email: 'hello@weldatl.com',
          phoneNumber: '+1-404-555-2001',
          instagramHandle: 'weld_atl',
          products: ['Handcrafted Necklaces', 'Statement Earrings', 'Custom Rings', 'Artisan Bracelets'],
          isFeatured: true,
          operatingDays: ['saturday', 'sunday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Joi Pet Treats',
          contactName: 'Pet Treat Specialist',
          description: 'Single ingredient pet treats made with love. Pure, natural, and healthy treats your pets will go crazy for!',
          categories: [VendorCategory.other],
          email: 'treats@joipet.com',
          phoneNumber: '+1-404-555-2002',
          instagramHandle: 'joipettreats',
          products: ['Single Ingredient Treats', 'Natural Dog Chews', 'Healthy Cat Treats', 'Training Rewards'],
          isFeatured: false,
          operatingDays: ['saturday', 'sunday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Bee Wild Buzz',
          contactName: 'Local Beekeeper',
          description: 'Local raw honey straight from our Georgia hives. Pure, unfiltered, and packed with natural goodness and local pollen.',
          categories: [VendorCategory.honey],
          email: 'buzz@beewildbuzz.com',
          phoneNumber: '+1-404-555-2003',
          instagramHandle: 'beewildbuzz',
          products: ['Raw Wildflower Honey', 'Clover Honey', 'Local Pollen', 'Beeswax Products'],
          isFeatured: true,
          operatingDays: ['saturday', 'sunday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Summit Coffee Dunwoody',
          contactName: 'Coffee Roaster',
          description: 'Freshly roasted coffee beans and expertly crafted coffee drinks. Start your market day with the perfect cup!',
          categories: [VendorCategory.beverages],
          email: 'brew@summitcoffee.com',
          phoneNumber: '+1-404-555-2004',
          instagramHandle: 'summitcoffeedunwoody',
          products: ['Freshly Roasted Beans', 'Cold Brew', 'Espresso Drinks', 'Specialty Blends'],
          isFeatured: true,
          operatingDays: ['saturday', 'sunday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Georgia Proud Provisions',
          contactName: 'Georgia Fruit Grower',
          description: 'Local Georgia fruit including fresh peaches, strawberries, blueberries, and pecans. Taste the sunshine of Georgia!',
          categories: [VendorCategory.produce],
          email: 'fruit@georgiaproud.com',
          phoneNumber: '+1-404-555-2005',
          instagramHandle: 'georgiaproudprovisions',
          products: ['Georgia Peaches', 'Fresh Strawberries', 'Blueberries', 'Georgia Pecans', 'Seasonal Fruit'],
          isFeatured: true,
          operatingDays: ['saturday', 'sunday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Blended Together Juice',
          contactName: 'Juice Master',
          description: 'Cold pressed juices made fresh daily. Packed with nutrients and flavor to fuel your healthy lifestyle.',
          categories: [VendorCategory.beverages],
          email: 'fresh@blendedtogether.com',
          phoneNumber: '+1-404-555-2006',
          instagramHandle: 'blendedtogetherjuice',
          products: ['Cold Pressed Green Juice', 'Fruit Blends', 'Immunity Shots', 'Detox Blends'],
          isFeatured: false,
          operatingDays: ['saturday', 'sunday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Cupcake on the Rocks ATL',
          contactName: 'Cupcake Artist',
          description: 'Gourmet cupcakes served in beautiful mason jars. Perfect for treating yourself or gifting to someone special!',
          categories: [VendorCategory.bakery],
          email: 'sweet@cupcakeontherocks.com',
          phoneNumber: '+1-404-555-2007',
          instagramHandle: 'cupcakeontherocksatl',
          products: ['Mason Jar Cupcakes', 'Gourmet Flavors', 'Custom Orders', 'Seasonal Specials'],
          isFeatured: false,
          operatingDays: ['saturday', 'sunday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Simply Done Donuts',
          contactName: 'Donut Food Truck',
          description: 'Fresh donuts made to order from our food truck! Warm, fluffy, and simply irresistible.',
          categories: [VendorCategory.bakery],
          email: 'donuts@simplydone.com',
          phoneNumber: '+1-404-555-2008',
          instagramHandle: 'simplydonedonuts',
          products: ['Fresh Glazed Donuts', 'Filled Donuts', 'Specialty Toppings', 'Coffee Pairings'],
          isFeatured: false,
          operatingDays: ['saturday', 'sunday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Stone Mountain Cattle',
          contactName: 'Local Rancher',
          description: 'Local organic meat including chicken, pork, and beef. Grass-fed, pasture-raised, and ethically sourced from Georgia farms.',
          categories: [VendorCategory.meat],
          email: 'ranch@stonemountaincattle.com',
          phoneNumber: '+1-404-555-2009',
          instagramHandle: 'stonemountaincattle',
          products: ['Grass-Fed Beef', 'Pasture-Raised Chicken', 'Heritage Pork', 'Farm Fresh Eggs'],
          isFeatured: true,
          operatingDays: ['saturday', 'sunday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Dancing Sourdough',
          contactName: 'Sourdough Baker',
          description: 'Artisanal sourdough bread and baked goods. Traditional fermentation methods create incredible flavor and health benefits.',
          categories: [VendorCategory.bakery],
          email: 'bread@dancingsourdough.com',
          phoneNumber: '+1-404-555-2010',
          instagramHandle: 'dancingsourdough',
          products: ['Sourdough Bread', 'Sourdough Pizza Dough', 'Fermented Pastries', 'Starter Kits'],
          isFeatured: false,
          operatingDays: ['saturday', 'sunday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'The Curated Olive',
          contactName: 'Olive Oil Specialist',
          description: 'Premium flavored and herb-infused olive oils. Elevate your cooking with our carefully curated selection of gourmet oils.',
          categories: [VendorCategory.spices],
          email: 'oil@curatedolive.com',
          phoneNumber: '+1-404-555-2011',
          instagramHandle: 'thecuratedolive',
          products: ['Herb Infused Olive Oil', 'Flavored Oils', 'Balsamic Vinegars', 'Gourmet Seasonings'],
          isFeatured: false,
          operatingDays: ['saturday', 'sunday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Fidelas Street Kitchen',
          contactName: 'Street Food Chef',
          description: 'Authentic tacos, empanadas, and refreshing agua fresca. Bold flavors and traditional recipes bring the street food experience to you!',
          categories: [VendorCategory.prepared_foods],
          email: 'chef@fidelasstreet.com',
          phoneNumber: '+1-404-555-2012',
          instagramHandle: 'fidelasstreetkitchen',
          products: ['Street Tacos', 'Fresh Empanadas', 'Agua Fresca', 'Salsa Verde'],
          isFeatured: true,
          operatingDays: ['saturday', 'sunday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Pasta Milani',
          contactName: 'Pasta Artisan',
          description: 'Fresh pasta and authentic sauces made daily. Bring the taste of Italy home with our handmade pasta and signature sauces.',
          categories: [VendorCategory.prepared_foods],
          email: 'pasta@milani.com',
          phoneNumber: '+1-404-555-2013',
          instagramHandle: 'pastamilani',
          products: ['Fresh Pasta', 'Signature Sauces', 'Gnocchi', 'Ravioli'],
          isFeatured: false,
          operatingDays: ['saturday', 'sunday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Grow with the Flow LLC',
          contactName: 'Organic Farmer',
          description: 'Fresh organic vegetables grown with sustainable farming practices. From soil to table, we grow with nature\'s flow.',
          categories: [VendorCategory.produce],
          email: 'grow@withtheflow.com',
          phoneNumber: '+1-404-555-2014',
          instagramHandle: 'growwiththeflowllc',
          products: ['Organic Vegetables', 'Leafy Greens', 'Root Vegetables', 'Seasonal Produce'],
          isFeatured: true,
          operatingDays: ['saturday', 'sunday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Hot Nutz Food Truck',
          contactName: 'Peanut Specialist',
          description: 'Hot boiled peanuts made fresh! A Southern tradition served hot and salty, perfect for snacking at the market.',
          categories: [VendorCategory.prepared_foods],
          email: 'nuts@hotnutz.com',
          phoneNumber: '+1-404-555-2015',
          instagramHandle: 'hotnutzfoodtruck',
          products: ['Hot Boiled Peanuts', 'Cajun Spiced', 'Traditional Southern', 'Salt & Pepper'],
          isFeatured: false,
          operatingDays: ['saturday', 'sunday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      for (final vendor in vendors) {
        await ManagedVendorService.createVendor(vendor);
        log += '✅ Added vendor: ${vendor.businessName}\n';
        setState(() {
          _result = log;
        });
      }

      log += '\n🎉 DUNWOODY FARMERS MARKET CREATED!\n';
      log += '📍 Dunwoody Village Shopping Center\n';
      log += '📅 Every Weekend\n';
      log += '🕐 Saturday 9 AM-1 PM, Sunday 10 AM-2 PM\n';
      log += '🧺 ${vendors.length} amazing vendors (representing 38+ vendors)\n';
      log += '🍅 Fresh produce, artisan goods, and local treats!\n';
      
      setState(() {
        _result = log;
      });

    } catch (e) {
      setState(() {
        _result += '\n❌ ERROR: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createOakhurstMarket() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      String log = '🍺 CREATING OAKHURST FARMERS MARKET\n\n';

      // Create the market
      final market = Market(
        id: '',
        name: 'Oakhurst Farmers Market',
        address: 'Front of Sceptre Brewing, Oakhurst, Atlanta, GA',
        city: 'Atlanta',
        state: 'GA',
        latitude: 33.7490,
        longitude: -84.3880,
        operatingDays: {
          'saturday': '9:00 AM - 1:00 PM',
        },
        description: 'Shop local at the Oakhurst Farmers Market every Saturday from 9am to 1pm in front of Sceptre Beer. Supporting local makers, growers, and artisans in the heart of Oakhurst.',
        createdAt: DateTime.now(),
      );

      final marketId = await MarketService.createMarket(market);
      log += '✅ Created market: ${market.name}\n';
      log += '📍 Market ID: $marketId\n\n';

      // Create market schedule for the next 4 Saturdays
      final now = DateTime.now();
      final nextSaturdays = <DateTime>[];
      
      // Find the next Saturday
      var nextSaturday = now;
      while (nextSaturday.weekday != DateTime.saturday) {
        nextSaturday = nextSaturday.add(const Duration(days: 1));
      }
      
      // Add next 4 Saturdays
      for (int i = 0; i < 4; i++) {
        nextSaturdays.add(nextSaturday.add(Duration(days: i * 7)));
      }

      final schedule = MarketSchedule.specificDates(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        marketId: marketId,
        startTime: '9:00 AM',
        endTime: '1:00 PM',
        dates: nextSaturdays,
      );

      final scheduleId = await MarketService.createMarketSchedule(schedule);
      
      // Update market with schedule ID
      await MarketService.updateMarket(marketId, {
        'scheduleIds': [scheduleId]
      });
      
      log += '✅ Added schedule for next 4 Saturdays\n';
      log += '📅 Dates: ${nextSaturdays.map((d) => '${d.month}/${d.day}').join(', ')}\n\n';

      setState(() {
        _result = log;
      });

      // Create vendors from the Instagram post
      final vendors = [
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Bee Wild Buzz',
          contactName: 'Bee Wild Buzz Team',
          description: 'Local honey producers offering pure, raw honey and bee products from our Atlanta-area hives.',
          categories: [VendorCategory.honey],
          email: 'hello@beewildbuzz.com',
          phoneNumber: '+1-404-555-0001',
          instagramHandle: 'beewildbuzz',
          products: ['Raw Honey', 'Honeycomb', 'Beeswax Products', 'Honey Sticks'],
          isFeatured: true,
          operatingDays: ['saturday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Floribunda Flower Farm',
          contactName: 'Floribunda Team',
          description: 'Local flower farm specializing in seasonal cut flowers and beautiful arrangements.',
          categories: [VendorCategory.flowers],
          email: 'hello@floribundaflowerfarm.com',
          phoneNumber: '+1-404-555-0002',
          instagramHandle: 'floribundaflowerfarm',
          products: ['Seasonal Cut Flowers', 'Bouquets', 'Dried Flowers', 'Flower Arrangements'],
          isFeatured: true,
          operatingDays: ['saturday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Georgia Peach Truck',
          contactName: 'Georgia Peach Team',
          description: 'Fresh Georgia peaches and seasonal fruit direct from local farms.',
          categories: [VendorCategory.produce],
          email: 'hello@georgiapeachtruck.com',
          phoneNumber: '+1-404-555-0003',
          instagramHandle: 'georgiapeachtruck',
          products: ['Georgia Peaches', 'Seasonal Fruit', 'Preserves', 'Peach Products'],
          isFeatured: true,
          operatingDays: ['saturday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Little Tart Bakeshop',
          contactName: 'Little Tart Team',
          description: 'Artisanal bakery offering fresh baked goods, pastries, and specialty items.',
          categories: [VendorCategory.bakery],
          email: 'hello@littletartbakeshop.com',
          phoneNumber: '+1-404-555-0004',
          instagramHandle: 'littletartbakeshop',
          products: ['Artisan Bread', 'Pastries', 'Croissants', 'Seasonal Treats'],
          isFeatured: false,
          operatingDays: ['saturday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Rebel Farm',
          contactName: 'Rebel Farm Team',
          description: 'Sustainable farm offering organic vegetables, herbs, and farm-fresh produce.',
          categories: [VendorCategory.produce, VendorCategory.spices],
          email: 'hello@rebelfarm.com',
          phoneNumber: '+1-404-555-0005',
          instagramHandle: 'rebelfarm',
          products: ['Organic Vegetables', 'Fresh Herbs', 'Microgreens', 'Seasonal Produce'],
          isFeatured: false,
          operatingDays: ['saturday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Spotted Trotter',
          contactName: 'Spotted Trotter Team',
          description: 'Farm-to-table charcuterie and prepared foods featuring locally sourced ingredients.',
          categories: [VendorCategory.prepared_foods, VendorCategory.meat],
          email: 'hello@spottedtrotter.com',
          phoneNumber: '+1-404-555-0006',
          instagramHandle: 'spottedtrotter',
          products: ['Charcuterie', 'Prepared Foods', 'Local Meats', 'Artisan Sausages'],
          isFeatured: false,
          operatingDays: ['saturday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      log += '🏪 CREATING VENDORS:\n';
      for (final vendor in vendors) {
        try {
          await ManagedVendorService.createVendor(vendor);
          log += '✅ ${vendor.businessName}\n';
          setState(() {
            _result = log;
          });
        } catch (e) {
          log += '❌ ${vendor.businessName}: $e\n';
          setState(() {
            _result = log;
          });
        }
      }

      log += '\n🎉 OAKHURST FARMERS MARKET COMPLETE!\n';
      log += '📍 Market created with ${vendors.length} vendors\n';
      log += '📅 Scheduled for next 4 Saturdays\n';
      log += '🍺 Located at Sceptre Brewing in Oakhurst\n';

      setState(() {
        _result = log;
      });

    } catch (e) {
      setState(() {
        _result += '\n❌ ERROR: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}