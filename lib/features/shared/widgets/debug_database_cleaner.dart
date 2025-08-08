import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class DebugDatabaseCleaner extends StatefulWidget {
  const DebugDatabaseCleaner({super.key});

  @override
  State<DebugDatabaseCleaner> createState() => _DebugDatabaseCleanerState();
}

class _DebugDatabaseCleanerState extends State<DebugDatabaseCleaner> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String _result = '';
  
  // Protected users - these will NOT be deleted
  final List<String> _protectedEmails = [
    'jozo@gmail.com',
    'vendorjozo@gmail.com',
    'marketjozo@gmail.com',
  ];

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.red.shade50,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  'DEBUG: Database Cleaner',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ WARNING: This will delete ALL data except:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Your 3 test accounts (jozo@gmail.com, vendorjozo@gmail.com, marketjozo@gmail.com)',
                    style: TextStyle(color: Colors.orange.shade700),
                  ),
                  Text(
                    '• Any account with "maria" in the email',
                    style: TextStyle(color: Colors.orange.shade700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Everything else will be PERMANENTLY DELETED:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                  Text(
                    '• All other user profiles',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                  Text(
                    '• All markets and schedules',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                  Text(
                    '• All vendor applications',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                  Text(
                    '• All managed vendors',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                  Text(
                    '• All vendor-market relationships',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                  Text(
                    '• All user subscriptions',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                  Text(
                    '• All usage tracking data',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                  Text(
                    '• All vendor posts',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                  Text(
                    '• All favorites',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _showConfirmationDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: _isLoading
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Clearing Database...'),
                      ],
                    )
                  : const Text('🗑️ CLEAR DATABASE'),
            ),
            const SizedBox(height: 16),
            if (_result.isNotEmpty) ...[
              const Text(
                'Result:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
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

  Future<void> _showConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ DANGER: Database Wipe'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This action will PERMANENTLY DELETE all data except:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('✅ jozo@gmail.com'),
              Text('✅ vendorjozo@gmail.com'),
              Text('✅ marketjozo@gmail.com'),
              Text('✅ Any email containing "maria"'),
              SizedBox(height: 16),
              Text(
                'Are you absolutely sure you want to proceed?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'This cannot be undone!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Delete Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _clearDatabase();
    }
  }

  Future<void> _clearDatabase() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      String log = '🗑️ STARTING DATABASE CLEANUP\n\n';
      
      // Step 1: Identify protected users
      log += '👤 IDENTIFYING PROTECTED USERS:\n';
      final protectedUserIds = <String>{};
      
      // Get all user profiles to identify protected users
      final userProfilesSnapshot = await _firestore.collection('user_profiles').get();
      for (final doc in userProfilesSnapshot.docs) {
        final data = doc.data();
        final email = data['email'] as String? ?? '';
        
        if (_protectedEmails.contains(email) || email.toLowerCase().contains('maria')) {
          protectedUserIds.add(doc.id);
          log += '✅ Protected user: $email (ID: ${doc.id})\n';
        }
      }
      
      // Note: We're identifying protected users based on user_profiles collection
      // Firebase Auth users will be preserved if they match the protected emails
      
      log += '\nProtected ${protectedUserIds.length} users total\n\n';
      
      setState(() {
        _result = log;
      });
      
      // Step 2: Clear user_profiles (except protected)
      log += '🗑️ CLEARING USER PROFILES:\n';
      final userProfilesToDelete = userProfilesSnapshot.docs
          .where((doc) => !protectedUserIds.contains(doc.id))
          .toList();
      
      for (final doc in userProfilesToDelete) {
        final data = doc.data();
        final email = data['email'] ?? 'unknown';
        await doc.reference.delete();
        log += '❌ Deleted user profile: $email\n';
      }
      log += 'Deleted ${userProfilesToDelete.length} user profiles\n\n';
      
      setState(() {
        _result = log;
      });
      
      // Step 3: Clear all markets
      log += '🗑️ CLEARING MARKETS:\n';
      final marketsSnapshot = await _firestore.collection('markets').get();
      for (final doc in marketsSnapshot.docs) {
        final data = doc.data();
        final name = data['name'] ?? 'Unknown Market';
        await doc.reference.delete();
        log += '❌ Deleted market: $name\n';
      }
      log += 'Deleted ${marketsSnapshot.docs.length} markets\n\n';
      
      setState(() {
        _result = log;
      });
      
      // Step 4: Clear all market schedules
      log += '🗑️ CLEARING MARKET SCHEDULES:\n';
      final schedulesSnapshot = await _firestore.collection('market_schedules').get();
      for (final doc in schedulesSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${schedulesSnapshot.docs.length} market schedules\n\n';
      
      setState(() {
        _result = log;
      });
      
      // Step 5: Clear all vendor applications
      log += '🗑️ CLEARING VENDOR APPLICATIONS:\n';
      final applicationsSnapshot = await _firestore.collection('vendor_applications').get();
      for (final doc in applicationsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${applicationsSnapshot.docs.length} vendor applications\n\n';
      
      setState(() {
        _result = log;
      });
      
      // Step 6: Clear all managed vendors
      log += '🗑️ CLEARING MANAGED VENDORS:\n';
      final managedVendorsSnapshot = await _firestore.collection('managed_vendors').get();
      for (final doc in managedVendorsSnapshot.docs) {
        final data = doc.data();
        final businessName = data['businessName'] ?? 'Unknown Business';
        await doc.reference.delete();
        log += '❌ Deleted managed vendor: $businessName\n';
      }
      log += 'Deleted ${managedVendorsSnapshot.docs.length} managed vendors\n\n';
      
      setState(() {
        _result = log;
      });
      
      // Step 7: Clear all vendor markets
      log += '🗑️ CLEARING VENDOR MARKETS:\n';
      final vendorMarketsSnapshot = await _firestore.collection('vendor_markets').get();
      for (final doc in vendorMarketsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${vendorMarketsSnapshot.docs.length} vendor markets\n\n';
      
      setState(() {
        _result = log;
      });
      
      // Step 8: Clear all vendor posts
      log += '🗑️ CLEARING VENDOR POSTS:\n';
      final vendorPostsSnapshot = await _firestore.collection('vendor_posts').get();
      for (final doc in vendorPostsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${vendorPostsSnapshot.docs.length} vendor posts\n\n';
      
      setState(() {
        _result = log;
      });
      
      // Step 9: Clear all user favorites
      log += '🗑️ CLEARING USER FAVORITES:\n';
      final favoritesSnapshot = await _firestore.collection('user_favorites').get();
      for (final doc in favoritesSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${favoritesSnapshot.docs.length} user favorites\n\n';
      
      setState(() {
        _result = log;
      });
      
      
      setState(() {
        _result = log;
      });
      
      // Step 11: Clear vendor-market relationships
      log += '🗑️ CLEARING VENDOR-MARKET RELATIONSHIPS:\n';
      final relationshipsSnapshot = await _firestore.collection('vendor_market_relationships').get();
      for (final doc in relationshipsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${relationshipsSnapshot.docs.length} vendor-market relationships\n\n';
      
      setState(() {
        _result = log;
      });
      
      // Step 12: Clear user subscriptions
      log += '🗑️ CLEARING USER SUBSCRIPTIONS:\n';
      final subscriptionsSnapshot = await _firestore.collection('user_subscriptions').get();
      for (final doc in subscriptionsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${subscriptionsSnapshot.docs.length} user subscriptions\n\n';
      
      setState(() {
        _result = log;
      });
      
      // Step 13: Clear usage tracking
      log += '🗑️ CLEARING USAGE TRACKING:\n';
      final usageTrackingSnapshot = await _firestore.collection('usage_tracking').get();
      for (final doc in usageTrackingSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${usageTrackingSnapshot.docs.length} usage tracking records\n\n';
      
      setState(() {
        _result = log;
      });
      
      // Step 14: Clear user market favorites
      log += '🗑️ CLEARING USER MARKET FAVORITES:\n';
      final marketFavoritesSnapshot = await _firestore.collection('user_market_favorites').get();
      for (final doc in marketFavoritesSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${marketFavoritesSnapshot.docs.length} user market favorites\n\n';
      
      setState(() {
        _result = log;
      });
      
      // Step 15: Clear legacy users collection (except protected)
      log += '🗑️ CLEARING LEGACY USERS:\n';
      final legacyUsersSnapshot = await _firestore.collection('users').get();
      int deletedLegacyUsers = 0;
      for (final doc in legacyUsersSnapshot.docs) {
        final data = doc.data();
        final email = data['email'] as String? ?? '';
        
        if (!_protectedEmails.contains(email) && !email.toLowerCase().contains('maria')) {
          await doc.reference.delete();
          log += '❌ Deleted legacy user: $email\n';
          deletedLegacyUsers++;
        } else {
          log += '✅ Preserved legacy user: $email\n';
        }
      }
      log += 'Deleted $deletedLegacyUsers legacy users\n\n';
      
      setState(() {
        _result = log;
      });
      
      // Final summary
      log += '✅ DATABASE CLEANUP COMPLETED!\n\n';
      log += '📊 SUMMARY:\n';
      log += '• Protected ${protectedUserIds.length} users\n';
      log += '• Deleted ${userProfilesToDelete.length} user profiles\n';
      log += '• Deleted ${marketsSnapshot.docs.length} markets\n';
      log += '• Deleted ${schedulesSnapshot.docs.length} market schedules\n';
      log += '• Deleted ${applicationsSnapshot.docs.length} vendor applications\n';
      log += '• Deleted ${managedVendorsSnapshot.docs.length} managed vendors\n';
      log += '• Deleted ${vendorMarketsSnapshot.docs.length} vendor markets\n';
      log += '• Deleted ${relationshipsSnapshot.docs.length} vendor-market relationships\n';
      log += '• Deleted ${subscriptionsSnapshot.docs.length} user subscriptions\n';
      log += '• Deleted ${usageTrackingSnapshot.docs.length} usage tracking records\n';
      log += '• Deleted ${marketFavoritesSnapshot.docs.length} user market favorites\n';
      log += '• Deleted ${vendorPostsSnapshot.docs.length} vendor posts\n';
      log += '• Deleted ${favoritesSnapshot.docs.length} user favorites\n';
      log += '• Deleted $deletedLegacyUsers legacy users\n\n';
      log += '🎉 Database is now clean and ready for fresh data!\n';
      log += '🔒 All protected users remain intact.';
      
      setState(() {
        _result = log;
      });
      
      // Show success dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('✅ Database Cleared Successfully'),
            content: Text(
              'Database has been cleared while preserving ${protectedUserIds.length} protected users.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      
    } catch (e) {
      setState(() {
        _result += '\n\n❌ ERROR DURING CLEANUP:\n$e';
      });
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('❌ Error'),
            content: Text('Database cleanup failed: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}