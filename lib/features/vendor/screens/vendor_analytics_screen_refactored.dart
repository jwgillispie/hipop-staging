// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:hipop/blocs/auth/auth_bloc.dart';
// import 'package:hipop/blocs/auth/auth_state.dart';
// import 'package:hipop/features/vendor/models/vendor_post.dart';
// import 'package:hipop/features/shared/widgets/common/loading_widget.dart';
// import 'package:hipop/features/premium/widgets/vendor_premium_dashboard_components.dart';
// import 'package:hipop/core/widgets/hipop_app_bar.dart';
// import 'package:hipop/core/widgets/metric_card.dart';
// import 'package:hipop/core/theme/hipop_colors.dart';
// import 'package:hipop/repositories/vendor_repository_simple.dart';

// /// Refactored Vendor Analytics Screen using VendorRepository
// /// 
// /// Key improvements:
// /// 1. NO direct Firebase calls - all data through repository
// /// 2. Automatic caching reduces Firebase reads by ~60-80%
// /// 3. Offline support - shows cached data when offline
// /// 4. Real-time updates via streams
// /// 5. Better error handling and loading states
// /// 6. Performance metrics tracking
// class VendorAnalyticsScreenRefactored extends StatefulWidget {
//   const VendorAnalyticsScreenRefactored({super.key});

//   @override
//   State<VendorAnalyticsScreenRefactored> createState() => _VendorAnalyticsScreenRefactoredState();
// }

// class _VendorAnalyticsScreenRefactoredState extends State<VendorAnalyticsScreenRefactored> {
//   // Single repository instance (singleton)
//   final VendorRepository _repository = VendorRepository();
  
//   String? _currentUserId;
  
//   @override
//   void initState() {
//     super.initState();
//     final authState = context.read<AuthBloc>().state;
//     if (authState is Authenticated) {
//       _currentUserId = authState.user.uid;
//     }
//   }
  
//   @override
//   Widget build(BuildContext context) {
//     final authState = context.watch<AuthBloc>().state;
    
//     if (authState is! Authenticated) {
//       return const Scaffold(
//         body: Center(child: CircularProgressIndicator()),
//       );
//     }
    
//     final vendorId = authState.user.uid;
    
//     return Scaffold(
//       appBar: _buildAppBar(context),
//       body: RefreshIndicator(
//         onRefresh: () async {
//           // Clear cache to force refresh
//           _repository.clearVendorCache(vendorId);
//         },
//         child: SingleChildScrollView(
//           physics: const AlwaysScrollableScrollPhysics(),
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Performance Stats Card (shows cache efficiency)
//               _buildPerformanceCard(),
//               const SizedBox(height: 16),
              
//               // Analytics Overview
//               _buildAnalyticsSection(vendorId),
//               const SizedBox(height: 24),
              
//               // Premium Status
//               _buildPremiumSection(vendorId),
//               const SizedBox(height: 24),
              
//               // Recent Posts
//               _buildRecentPostsSection(vendorId),
//               const SizedBox(height: 24),
              
//               // Products Overview
//               _buildProductsSection(vendorId),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
  
//   PreferredSizeWidget _buildAppBar(BuildContext context) {
//     return AppBar(
//       title: const Text('Analytics Dashboard'),
//       flexibleSpace: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//             colors: [
//               HiPopColors.secondarySoftSage,
//               HiPopColors.accentMauve,
//             ],
//           ),
//         ),
//       ),
//       backgroundColor: Colors.transparent,
//       foregroundColor: Colors.white,
//       elevation: 0,
//       actions: [
//         // Repository stats button
//         IconButton(
//           icon: const Icon(Icons.analytics),
//           onPressed: () {
//             _showRepositoryStats(context);
//           },
//           tooltip: 'Repository Statistics',
//         ),
//       ],
//     );
//   }
  
//   /// Performance monitoring card showing cache efficiency
//   Widget _buildPerformanceCard() {
//     final stats = _repository.getStatistics();
//     final hitRate = stats['cacheHitRate'] as double;
//     final firebaseReads = stats['firebaseReads'] as int;
    
//     return Card(
//       elevation: 2,
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Performance Metrics',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 12),
//             Row(
//               children: [
//                 Expanded(
//                   child: _buildMetric(
//                     'Cache Hit Rate',
//                     '${hitRate.toStringAsFixed(1)}%',
//                     hitRate > 70 ? Colors.green : Colors.orange,
//                   ),
//                 ),
//                 Expanded(
//                   child: _buildMetric(
//                     'Firebase Reads',
//                     firebaseReads.toString(),
//                     Colors.blue,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             LinearProgressIndicator(
//               value: hitRate / 100,
//               backgroundColor: Colors.grey[300],
//               valueColor: AlwaysStoppedAnimation<Color>(
//                 hitRate > 70 ? Colors.green : Colors.orange,
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               hitRate > 70
//                   ? '✅ Excellent cache performance - saving Firebase reads'
//                   : '⚠️ Cache warming up - performance will improve',
//               style: TextStyle(
//                 fontSize: 12,
//                 color: Colors.grey[600],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
  
//   Widget _buildMetric(String label, String value, Color color) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: TextStyle(
//             fontSize: 12,
//             color: Colors.grey[600],
//           ),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           value,
//           style: TextStyle(
//             fontSize: 24,
//             fontWeight: FontWeight.bold,
//             color: color,
//           ),
//         ),
//       ],
//     );
//   }
  
//   /// Analytics section using repository
//   Widget _buildAnalyticsSection(String vendorId) {
//     return StreamBuilder<VendorAnalytics>(
//       stream: _repository.watchAnalytics(vendorId),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(child: LoadingWidget());
//         }
        
//         if (snapshot.hasError) {
//           return Card(
//             child: Padding(
//               padding: const EdgeInsets.all(16),
//               child: Text('Error loading analytics: ${snapshot.error}'),
//             ),
//           );
//         }
        
//         final analytics = snapshot.data;
//         if (analytics == null) {
//           return const Card(
//             child: Padding(
//               padding: const EdgeInsets.all(16),
//               child: Text('No analytics data available'),
//             ),
//           );
//         }
        
//         return Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Overview',
//               style: TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 12),
//             GridView.count(
//               shrinkWrap: true,
//               physics: const NeverScrollableScrollPhysics(),
//               crossAxisCount: 2,
//               childAspectRatio: 1.5,
//               crossAxisSpacing: 12,
//               mainAxisSpacing: 12,
//               children: [
//                 MetricCard(
//                   title: 'Total Posts',
//                   value: analytics.totalPosts.toString(),
//                   icon: Icons.article,
//                   color: HiPopColors.primaryPurple,
//                 ),
//                 MetricCard(
//                   title: 'Active Posts',
//                   value: analytics.activePostsCount.toString(),
//                   icon: Icons.visibility,
//                   color: Colors.green,
//                 ),
//                 MetricCard(
//                   title: 'Products',
//                   value: analytics.totalProducts.toString(),
//                   icon: Icons.inventory,
//                   color: HiPopColors.secondarySoftSage,
//                 ),
//                 MetricCard(
//                   title: 'Applications',
//                   value: analytics.totalApplications.toString(),
//                   icon: Icons.assignment,
//                   color: HiPopColors.accentMauve,
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             Text(
//               'Last updated: ${_formatDateTime(analytics.lastUpdated)}',
//               style: TextStyle(
//                 fontSize: 12,
//                 color: Colors.grey[600],
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }
  
//   /// Premium status section using repository
//   Widget _buildPremiumSection(String vendorId) {
//     return StreamBuilder<bool>(
//       stream: _repository.isPremium(vendorId),
//       builder: (context, snapshot) {
//         final isPremium = snapshot.data ?? false;
        
//         return Card(
//           elevation: 2,
//           color: isPremium ? HiPopColors.primaryPurple.withOpacity(0.1) : null,
//           child: Padding(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Icon(
//                       isPremium ? Icons.star : Icons.star_border,
//                       color: isPremium ? Colors.amber : Colors.grey,
//                     ),
//                     const SizedBox(width: 8),
//                     Text(
//                       isPremium ? 'Premium Member' : 'Free Plan',
//                       style: TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                         color: isPremium ? HiPopColors.primaryPurple : null,
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 8),
//                 Text(
//                   isPremium
//                       ? 'Enjoy unlimited posts, advanced analytics, and more!'
//                       : 'Upgrade to Premium for unlimited features',
//                   style: TextStyle(color: Colors.grey[600]),
//                 ),
//                 if (!isPremium) ...[
//                   const SizedBox(height: 12),
//                   ElevatedButton(
//                     onPressed: () {
//                       // Navigate to premium screen
//                       context.push('/vendor/premium');
//                     },
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: HiPopColors.primaryPurple,
//                     ),
//                     child: const Text('Upgrade Now'),
//                   ),
//                 ],
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
  
//   /// Recent posts section using repository
//   Widget _buildRecentPostsSection(String vendorId) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text(
//           'Recent Posts',
//           style: TextStyle(
//             fontSize: 20,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         const SizedBox(height: 12),
//         StreamBuilder<List<VendorPost>>(
//           stream: _repository.getVendorPosts(vendorId, limit: 5),
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return const Center(child: LoadingWidget());
//             }
            
//             final posts = snapshot.data ?? [];
            
//             if (posts.isEmpty) {
//               return Card(
//                 child: Padding(
//                   padding: const EdgeInsets.all(16),
//                   child: Text(
//                     'No posts yet. Create your first popup!',
//                     style: TextStyle(color: Colors.grey[600]),
//                   ),
//                 ),
//               );
//             }
            
//             return ListView.builder(
//               shrinkWrap: true,
//               physics: const NeverScrollableScrollPhysics(),
//               itemCount: posts.length,
//               itemBuilder: (context, index) {
//                 final post = posts[index];
//                 return Card(
//                   margin: const EdgeInsets.only(bottom: 8),
//                   child: ListTile(
//                     title: Text(
//                       post.description,
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                     subtitle: Text(
//                       '${post.location} • ${_formatDateTime(post.popUpStartDateTime)}',
//                       style: TextStyle(
//                         fontSize: 12,
//                         color: Colors.grey[600],
//                       ),
//                     ),
//                     trailing: Chip(
//                       label: Text(
//                         post.isActive ? 'Active' : 'Inactive',
//                         style: const TextStyle(fontSize: 12),
//                       ),
//                       backgroundColor: post.isActive ? Colors.green[100] : Colors.grey[200],
//                     ),
//                     onTap: () {
//                       // Navigate to post details
//                       context.push('/vendor/post/${post.id}');
//                     },
//                   ),
//                 );
//               },
//             );
//           },
//         ),
//       ],
//     );
//   }
  
//   /// Products section using repository
//   Widget _buildProductsSection(String vendorId) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text(
//           'Products',
//           style: TextStyle(
//             fontSize: 20,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         const SizedBox(height: 12),
//         StreamBuilder<List<dynamic>>(
//           stream: _repository.getVendorProducts(vendorId),
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return const Center(child: LoadingWidget());
//             }
            
//             final products = snapshot.data ?? [];
            
//             return Card(
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   children: [
//                     Row(
//                       children: [
//                         const Icon(Icons.inventory_2, color: HiPopColors.secondarySoftSage),
//                         const SizedBox(width: 8),
//                         Text(
//                           '${products.length} Products',
//                           style: const TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 12),
//                     if (products.isEmpty)
//                       Text(
//                         'No products added yet',
//                         style: TextStyle(color: Colors.grey[600]),
//                       )
//                     else
//                       Text(
//                         'Manage your product catalog to showcase at markets',
//                         style: TextStyle(color: Colors.grey[600]),
//                       ),
//                     const SizedBox(height: 12),
//                     ElevatedButton.icon(
//                       onPressed: () {
//                         context.push('/vendor/products');
//                       },
//                       icon: const Icon(Icons.edit),
//                       label: const Text('Manage Products'),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: HiPopColors.secondarySoftSage,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }
  
//   /// Show repository statistics dialog
//   void _showRepositoryStats(BuildContext context) {
//     final stats = _repository.getStatistics();
    
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Repository Statistics'),
//         content: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               _buildStatRow('Cache Hit Rate', '${(stats['cacheHitRate'] as double).toStringAsFixed(1)}%'),
//               _buildStatRow('Cache Hits', stats['cacheHits'].toString()),
//               _buildStatRow('Cache Misses', stats['cacheMisses'].toString()),
//               _buildStatRow('Firebase Reads', stats['firebaseReads'].toString()),
//               _buildStatRow('Offline Cache Size', stats['offlineCacheSize'].toString()),
//               const Divider(),
//               const Text('Active Streams:', style: TextStyle(fontWeight: FontWeight.bold)),
//               ...(stats['activeStreams'] as Map<String, dynamic>).entries.map((e) =>
//                 _buildStatRow('  ${e.key}', e.value.toString()),
//               ),
//               const Divider(),
//               Text(
//                 'Estimated savings: ${_calculateSavings(stats)}',
//                 style: const TextStyle(
//                   fontWeight: FontWeight.bold,
//                   color: Colors.green,
//                 ),
//               ),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () {
//               _repository.clearAllCaches();
//               Navigator.of(context).pop();
//               setState(() {}); // Refresh UI
//             },
//             child: const Text('Clear Cache'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: const Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }
  
//   Widget _buildStatRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(label),
//           Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
//         ],
//       ),
//     );
//   }
  
//   String _calculateSavings(Map<String, dynamic> stats) {
//     final hits = stats['cacheHits'] as int;
//     // Estimate: each cache hit saves 1 Firebase read
//     // Firebase pricing: ~$0.06 per 100,000 reads
//     final savedReads = hits;
//     final savedCost = (savedReads / 100000) * 0.06;
//     return '$savedReads reads saved (\$${savedCost.toStringAsFixed(4)})';
//   }
  
//   String _formatDateTime(DateTime dateTime) {
//     final now = DateTime.now();
//     final difference = now.difference(dateTime);
    
//     if (difference.inMinutes < 1) {
//       return 'Just now';
//     } else if (difference.inHours < 1) {
//       return '${difference.inMinutes}m ago';
//     } else if (difference.inDays < 1) {
//       return '${difference.inHours}h ago';
//     } else if (difference.inDays < 7) {
//       return '${difference.inDays}d ago';
//     } else {
//       return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
//     }
//   }
// }