// Demo file showing how to use the Strava-style photo widgets
// This file demonstrates the usage of VendorPhotoPreview and VendorPhotoCarousel
// 
// USAGE EXAMPLES:
// 
// 1. VendorPhotoPreview - For feed cards (Strava-style split view)
// VendorPhotoPreview(
//   latitude: 33.7490,
//   longitude: -84.3880,
//   location: "Atlanta, GA",
//   photoUrls: ["url1", "url2", "url3"],
//   onPhotoTap: () => navigateToDetail(),
//   height: 200, // Optional, defaults to 200
//   borderRadius: 12, // Optional, defaults to 12
// )
// 
// 2. VendorPhotoCarousel - For detail screens (full-width swipeable)
// VendorPhotoCarousel(
//   photoUrls: ["url1", "url2", "url3"],
//   height: 300, // Optional, defaults to 300
//   borderRadius: 0, // Optional, defaults to 0
// )
// 
// FEATURES:
// - VendorPhotoPreview:
//   * Left side: Google Maps Static API with dark theme
//   * Right side: First photo with "+N" indicator if multiple
//   * 4px gap between map and photo
//   * Clickable map opens Google Maps app
//   * Clickable photo navigates to detail
// 
// - VendorPhotoCarousel:
//   * Swipeable PageView for all photos
//   * Dot indicators at bottom
//   * Photo counter badge (1/3 format)
//   * Navigation arrows on desktop/web
//   * Full-screen gallery on tap
//   * Pinch-to-zoom in full-screen mode
// 
// INTEGRATION POINTS:
// - shopper_home.dart: VendorPhotoPreview in vendor post cards
// - vendor_detail_screen.dart: VendorPhotoCarousel at top
// - vendor_post_detail_screen.dart: VendorPhotoCarousel at top
// 
// PERFORMANCE:
// - Uses cached_network_image for efficient loading
// - Lazy loads Google Maps Static API images
// - Handles missing photos/coordinates gracefully
// 
// DESIGN SYSTEM:
// - Follows HiPopColors theme
// - Material Design 3 principles
// - Dark mode optimized
// - Responsive for mobile/tablet/web
// 
import 'package:flutter/material.dart';
import 'vendor_photo_preview.dart';
import 'vendor_photo_carousel.dart';

class VendorPhotoWidgetsDemo extends StatelessWidget {
  const VendorPhotoWidgetsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample data for demonstration
    final samplePhotoUrls = [
      'https://via.placeholder.com/400x300/FF6366F1/FFFFFF?text=Photo+1',
      'https://via.placeholder.com/400x300/FF4CAF50/FFFFFF?text=Photo+2',
      'https://via.placeholder.com/400x300/FFFF9800/FFFFFF?text=Photo+3',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Photo Widgets Demo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VendorPhotoPreview (Feed Card Style)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            // Demo of VendorPhotoPreview
            VendorPhotoPreview(
              latitude: 33.7490,
              longitude: -84.3880,
              location: "Atlanta, GA",
              photoUrls: samplePhotoUrls,
              onPhotoTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Photo tapped - navigate to detail')),
                );
              },
            ),
            
            const SizedBox(height: 32),
            
            Text(
              'VendorPhotoCarousel (Detail Screen Style)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            // Demo of VendorPhotoCarousel
            VendorPhotoCarousel(
              photoUrls: samplePhotoUrls,
              height: 300,
              borderRadius: 12,
            ),
            
            const SizedBox(height: 32),
            
            // Usage instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Implementation Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text('✅ VendorPhotoPreview integrated in shopper_home.dart'),
                    const Text('✅ VendorPhotoCarousel integrated in vendor_detail_screen.dart'),
                    const Text('✅ VendorPhotoCarousel integrated in vendor_post_detail_screen.dart'),
                    const Text('✅ Google Maps Static API with dark theme'),
                    const Text('✅ Cached network images for performance'),
                    const Text('✅ Full-screen gallery viewer'),
                    const Text('✅ Responsive design for all screen sizes'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}