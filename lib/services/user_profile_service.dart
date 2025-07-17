import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';

abstract class IUserProfileService {
  Future<UserProfile?> getUserProfile(String userId);
  Future<UserProfile> createUserProfile({
    required String userId,
    required String userType,
    required String email,
    String? displayName,
  });
  Future<UserProfile> updateUserProfile(UserProfile profile);
  Future<void> deleteUserProfile(String userId);
  Stream<UserProfile?> watchUserProfile(String userId);
}

class UserProfileService implements IUserProfileService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  static const String _collection = 'user_profiles';

  UserProfileService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  @override
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      
      if (doc.exists) {
        return UserProfile.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  @override
  Future<UserProfile> createUserProfile({
    required String userId,
    required String userType,
    required String email,
    String? displayName,
  }) async {
    try {
      final now = DateTime.now();
      final profile = UserProfile(
        userId: userId,
        userType: userType,
        email: email,
        displayName: displayName,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore.collection(_collection).doc(userId).set(profile.toFirestore());
      
      return profile;
    } catch (e) {
      throw UserProfileException('Failed to create user profile: $e');
    }
  }

  @override
  Future<UserProfile> updateUserProfile(UserProfile profile) async {
    try {
      final updatedProfile = profile.copyWith(updatedAt: DateTime.now());
      
      await _firestore
          .collection(_collection)
          .doc(profile.userId)
          .update(updatedProfile.toFirestore());

      // Also update Firebase Auth display name if it changed
      final user = _auth.currentUser;
      if (user != null && 
          user.uid == profile.userId && 
          user.displayName != updatedProfile.displayName) {
        await user.updateDisplayName(updatedProfile.displayName);
        await user.reload();
      }

      return updatedProfile;
    } catch (e) {
      throw UserProfileException('Failed to update user profile: $e');
    }
  }

  @override
  Future<void> deleteUserProfile(String userId) async {
    try {
      await _firestore.collection(_collection).doc(userId).delete();
    } catch (e) {
      throw UserProfileException('Failed to delete user profile: $e');
    }
  }

  @override
  Stream<UserProfile?> watchUserProfile(String userId) {
    return _firestore
        .collection(_collection)
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            return UserProfile.fromFirestore(doc);
          }
          return null;
        });
  }

  // Helper method to create or get profile for current user
  Future<UserProfile> ensureUserProfile({
    required String userType,
    String? displayName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw UserProfileException('No authenticated user');
    }

    // Try to get existing profile
    UserProfile? profile = await getUserProfile(user.uid);
    
    if (profile == null) {
      // Create new profile
      profile = await createUserProfile(
        userId: user.uid,
        userType: userType,
        email: user.email ?? '',
        displayName: displayName ?? user.displayName,
      );
    }

    return profile;
  }

  // Helper method to update only specific fields
  Future<UserProfile> updateUserProfileFields(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final profile = await getUserProfile(userId);
      if (profile == null) {
        throw UserProfileException('User profile not found');
      }

      // Add updatedAt timestamp
      updates['updatedAt'] = Timestamp.fromDate(DateTime.now());

      await _firestore
          .collection(_collection)
          .doc(userId)
          .update(updates);

      // Return updated profile
      final updatedProfile = await getUserProfile(userId);
      if (updatedProfile == null) {
        throw UserProfileException('Failed to retrieve updated profile');
      }

      return updatedProfile;
    } catch (e) {
      throw UserProfileException('Failed to update profile fields: $e');
    }
  }

  // Helper method to check if profile exists
  Future<bool> profileExists(String userId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking profile existence: $e');
      return false;
    }
  }

  // Helper method to get profiles by user type
  Future<List<UserProfile>> getProfilesByUserType(String userType) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userType', isEqualTo: userType)
          .get();

      return querySnapshot.docs
          .map((doc) => UserProfile.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting profiles by user type: $e');
      return [];
    }
  }

  // Helper method to search profiles by display name or business name
  Future<List<UserProfile>> searchProfiles(String searchTerm) async {
    try {
      if (searchTerm.isEmpty) return [];

      final searchLower = searchTerm.toLowerCase();
      
      // Get all profiles and filter client-side since Firestore doesn't support
      // case-insensitive or contains queries natively
      final querySnapshot = await _firestore.collection(_collection).get();
      
      final profiles = querySnapshot.docs
          .map((doc) => UserProfile.fromFirestore(doc))
          .where((profile) {
            final displayName = profile.displayName?.toLowerCase() ?? '';
            final businessName = profile.businessName?.toLowerCase() ?? '';
            final email = profile.email.toLowerCase();
            
            return displayName.contains(searchLower) ||
                   businessName.contains(searchLower) ||
                   email.contains(searchLower);
          })
          .toList();

      return profiles;
    } catch (e) {
      debugPrint('Error searching profiles: $e');
      return [];
    }
  }

  // Helper method to get vendor profiles with categories
  Future<List<UserProfile>> getVendorsByCategory(String category) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userType', isEqualTo: 'vendor')
          .where('categories', arrayContains: category)
          .get();

      return querySnapshot.docs
          .map((doc) => UserProfile.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting vendors by category: $e');
      return [];
    }
  }

  // Helper method to migrate existing user to profile system
  Future<UserProfile?> migrateUserToProfile(User user, String userType) async {
    try {
      // Check if profile already exists
      final existingProfile = await getUserProfile(user.uid);
      if (existingProfile != null) {
        return existingProfile;
      }

      // Create new profile from Firebase Auth user
      return await createUserProfile(
        userId: user.uid,
        userType: userType,
        email: user.email ?? '',
        displayName: user.displayName,
      );
    } catch (e) {
      debugPrint('Error migrating user to profile: $e');
      return null;
    }
  }

  // Administrative function to fix market organizer associations
  Future<void> fixMarketOrganizerAssociations() async {
    try {
      debugPrint('🔧 Starting market organizer association fix...');
      
      // First, check if any markets exist
      final marketsSnapshot = await _firestore.collection('markets').get();
      debugPrint('Found ${marketsSnapshot.docs.length} existing markets');
      
      String marketId;
      
      // Check if user already has a market based on their email/name
      String? existingUserMarketId;
      final user = _auth.currentUser;
      
      if (user != null) {
        // Look for a market that might belong to this user
        for (final marketDoc in marketsSnapshot.docs) {
          final marketData = marketDoc.data();
          final marketName = marketData['name'] as String? ?? '';
          final userEmail = user.email ?? '';
          
          // Check if market name contains user's name or email prefix
          final emailPrefix = userEmail.split('@').first.toLowerCase();
          if (marketName.toLowerCase().contains('jozo') || 
              marketName.toLowerCase().contains(emailPrefix)) {
            existingUserMarketId = marketDoc.id;
            debugPrint('✅ Found existing user market: $marketName with ID: $existingUserMarketId');
            break;
          }
        }
      }
      
      if (existingUserMarketId != null) {
        marketId = existingUserMarketId;
      } else {
        // Create a personalized market for this user
        final user = _auth.currentUser;
        final userEmail = user?.email ?? 'organizer@example.com';
        final emailPrefix = userEmail.split('@').first;
        final marketName = emailPrefix.contains('jozo') ? 'JOZO Market' : '${emailPrefix.toUpperCase()} Market';
        
        debugPrint('📍 Creating personalized market for user: $userEmail');
        
        final marketData = {
          'name': marketName,
          'address': '123 Market Street',
          'city': 'Atlanta',
          'state': 'GA',
          'latitude': 33.7490,
          'longitude': -84.3880,
          'operatingDays': {
            'saturday': '8:00 AM - 2:00 PM',
            'sunday': '10:00 AM - 4:00 PM',
          },
          'description': 'Local farmers market featuring fresh, quality vendors and artisan goods.',
          'isActive': true,
          'createdAt': Timestamp.fromDate(DateTime.now()),
        };
        
        final docRef = await _firestore.collection('markets').add(marketData);
        marketId = docRef.id;
        
        // Update the market with its ID
        await docRef.update({'id': marketId});
        
        debugPrint('✅ Created personalized market: ${marketData['name']} with ID: $marketId');
      }
      
      debugPrint('👤 Looking for market organizer users to update...');
      
      // Find users with userType = 'market_organizer' but no managedMarketIds
      final usersSnapshot = await _firestore
          .collection(_collection)
          .where('userType', isEqualTo: 'market_organizer')
          .get();
      
      debugPrint('Found ${usersSnapshot.docs.length} market organizer users');
      
      int updatedCount = 0;
      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final userId = userDoc.id;
        final displayName = userData['displayName'] ?? userData['organizationName'] ?? 'Unknown User';
        final managedMarketIds = List<String>.from(userData['managedMarketIds'] ?? []);
        
        if (managedMarketIds.isEmpty) {
          debugPrint('🔧 Updating user: $displayName (ID: $userId)');
          
          // Update the user profile to include the market
          await _firestore.collection(_collection).doc(userId).update({
            'managedMarketIds': [marketId],
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
          
          updatedCount++;
          debugPrint('✅ Added market $marketId to user $displayName');
        } else {
          debugPrint('⏭️  User $displayName already has markets: $managedMarketIds');
        }
      }
      
      debugPrint('🎉 Market association fix completed! Updated $updatedCount users.');
    } catch (e) {
      debugPrint('❌ Error fixing market associations: $e');
      throw UserProfileException('Failed to fix market associations: $e');
    }
  }

  // Helper method to get current user ID
  Future<String?> getCurrentUserId() async {
    final user = _auth.currentUser;
    return user?.uid;
  }

  // Helper method to get current user profile
  Future<UserProfile?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    return await getUserProfile(user.uid);
  }

  // Helper method to create missing organizer profile
  Future<UserProfile> createMissingOrganizerProfile(String userId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw UserProfileException('No authenticated user');
      }

      debugPrint('🔧 Creating missing market organizer profile for user: $userId');
      
      return await createUserProfile(
        userId: userId,
        userType: 'market_organizer',
        email: user.email ?? '',
        displayName: user.displayName ?? 'Market Organizer',
      );
    } catch (e) {
      debugPrint('❌ Error creating missing organizer profile: $e');
      throw UserProfileException('Failed to create missing organizer profile: $e');
    }
  }

  // Helper method to fix existing managed vendors with old placeholder IDs
  Future<void> fixExistingManagedVendors() async {
    try {
      debugPrint('🔧 Fixing existing managed vendors with placeholder IDs...');
      
      final user = _auth.currentUser;
      if (user == null) {
        throw UserProfileException('No authenticated user');
      }

      // Get the current user's profile to find their real market ID
      final userProfile = await getUserProfile(user.uid);
      if (userProfile == null || !userProfile.isMarketOrganizer || userProfile.managedMarketIds.isEmpty) {
        debugPrint('❌ User is not a market organizer with managed markets');
        return;
      }

      final realMarketId = userProfile.managedMarketIds.first;
      final realOrganizerId = user.uid;

      debugPrint('📍 Real market ID: $realMarketId');
      debugPrint('👤 Real organizer ID: $realOrganizerId');

      // Find managed vendors with placeholder IDs OR belonging to this user
      final tempMarketVendors = await _firestore
          .collection('managed_vendors')
          .where('marketId', isEqualTo: 'temp_market_id')
          .get();

      final placeholderOrganizerVendors = await _firestore
          .collection('managed_vendors')
          .where('organizerId', isEqualTo: 'current_organizer_id')
          .get();

      final userEmailVendors = await _firestore
          .collection('managed_vendors')
          .where('email', isEqualTo: user.email)
          .get();

      // Combine all potential vendors
      final allVendorDocs = <QueryDocumentSnapshot>[];
      allVendorDocs.addAll(tempMarketVendors.docs);
      allVendorDocs.addAll(placeholderOrganizerVendors.docs);
      allVendorDocs.addAll(userEmailVendors.docs);

      // Remove duplicates
      final uniqueVendorDocs = <String, QueryDocumentSnapshot>{};
      for (final doc in allVendorDocs) {
        uniqueVendorDocs[doc.id] = doc;
      }

      debugPrint('Found ${tempMarketVendors.docs.length} vendors with temp_market_id');
      debugPrint('Found ${placeholderOrganizerVendors.docs.length} vendors with current_organizer_id');
      debugPrint('Found ${userEmailVendors.docs.length} vendors with your email (${user.email})');
      debugPrint('Total unique vendors to fix: ${uniqueVendorDocs.length}');

      int updatedCount = 0;
      for (final vendorDoc in uniqueVendorDocs.values) {
        final vendorData = vendorDoc.data() as Map<String, dynamic>;
        final vendorId = vendorDoc.id;
        final businessName = vendorData['businessName'] ?? 'Unknown Vendor';

        // Check if this vendor belongs to the current user (by organizer ID or email)
        final vendorOrganizerId = vendorData['organizerId'];
        final vendorEmail = vendorData['email'];
        
        if (vendorOrganizerId == 'current_organizer_id' || 
            vendorOrganizerId == realOrganizerId ||
            vendorEmail == user.email) {
          
          debugPrint('🔧 Updating vendor: $businessName (ID: $vendorId)');
          
          // Update the vendor with real IDs
          await _firestore.collection('managed_vendors').doc(vendorId).update({
            'marketId': realMarketId,
            'organizerId': realOrganizerId,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
          
          updatedCount++;
          debugPrint('✅ Updated vendor $businessName with real market and organizer IDs');
        }
      }

      debugPrint('🎉 Fixed $updatedCount existing managed vendors!');
    } catch (e) {
      debugPrint('❌ Error fixing existing managed vendors: $e');
      throw UserProfileException('Failed to fix existing managed vendors: $e');
    }
  }
}

class UserProfileException implements Exception {
  final String message;
  
  UserProfileException(this.message);
  
  @override
  String toString() => 'UserProfileException: $message';
}