# Vendor-Market System Redesign - Complete Implementation Guide for Claude Code

## Overview
Transform the vendor-market system from a two-step permission model to a unified post-with-approval model where the vendor post IS the market application.

## Core Change
**OLD:** Vendor requests permission → Market approves → Vendor creates post → Shows on market  
**NEW:** Vendor creates post (selects market) → Market reviews actual post → Approve/Deny → Shows on market

## 1. DATABASE SCHEMA UPDATES

### Update vendor_posts collection with these new fields:

```javascript
// Add these fields to vendor_posts documents
{
  // NEW FIELDS - Post Type
  "postType": "market", // or "independent" - REQUIRED enum field
  "associatedMarketId": "market_123", // null for independent posts
  "associatedMarketName": "Community Farmers Market", // denormalized for performance
  "associatedMarketLogo": "https://...", // market logo URL
  
  // NEW FIELDS - Approval System
  "approvalStatus": "pending", // "pending" | "approved" | "denied" | null
  "approvalRequestedAt": Timestamp,
  "approvalDecidedAt": Timestamp,
  "approvedBy": "organizer_uid", // who approved/denied
  "approvalNote": "Reason for denial", // optional feedback
  "approvalExpiresAt": Timestamp, // auto-deny if not acted upon
  
  // NEW FIELDS - Tracking
  "monthlyPostNumber": 2, // This is vendor's Nth post this month
  "countsTowardLimit": true, // for accurate limit tracking
  "version": 2 // schema version for migration
}
```

### Create NEW collection: market_approval_queue

```javascript
// NEW COLLECTION: market_approval_queue
{
  "id": "approval_123",
  "marketId": "market_123",
  "organizerId": "org_789", // for efficient queries
  "vendorPostId": "post_abc123",
  "vendorName": "John's Fresh Produce",
  "vendorId": "vendor_456",
  "eventDate": Timestamp, // when the popup/market is
  "requestedAt": Timestamp,
  "priority": "urgent", // "urgent" if < 48hrs, "high" if < 72hrs, "normal" otherwise
  "status": "pending", // "pending" | "approved" | "denied" | "expired"
  "preview": {
    "description": "First 100 chars...",
    "productCount": 15,
    "photoCount": 3
  }
}
```

### Create NEW collection: vendor_monthly_tracking

```javascript
// NEW COLLECTION: vendor_monthly_tracking
// Document ID format: vendorId_YYYY_MM (e.g., "vendor123_2024_01")
{
  "vendorId": "vendor_123",
  "yearMonth": "2024-01",
  "posts": {
    "total": 2,
    "independent": 1,
    "market": 1,
    "denied": 0 // don't count toward limit
  },
  "postIds": ["post1", "post2"],
  "lastPostDate": Timestamp,
  "subscriptionTier": "free" // or "premium"
}
```

### Firestore Indexes Required:

```json
// firestore.indexes.json - ADD THESE INDEXES
{
  "indexes": [
    {
      "collectionGroup": "vendor_posts",
      "fields": [
        {"fieldPath": "associatedMarketId", "order": "ASCENDING"},
        {"fieldPath": "approvalStatus", "order": "ASCENDING"},
        {"fieldPath": "popUpStartDateTime", "order": "ASCENDING"}
      ]
    },
    {
      "collectionGroup": "market_approval_queue",
      "fields": [
        {"fieldPath": "organizerId", "order": "ASCENDING"},
        {"fieldPath": "status", "order": "ASCENDING"},
        {"fieldPath": "priority", "order": "DESCENDING"}
      ]
    }
  ]
}
```

## 2. BACKEND SERVICE UPDATES

### File: lib/features/vendor/services/vendor_post_service.dart

```dart
// COMPLETE REPLACEMENT for createVendorPost method
class VendorPostService {
  static Future<VendorPost> createVendorPost({
    required VendorPostData postData,
    required PostType postType, // NEW PARAMETER
    Market? selectedMarket,      // NEW PARAMETER
  }) async {
    final vendorId = FirebaseAuth.instance.currentUser!.uid;
    final db = FirebaseFirestore.instance;
    
    // 1. Check monthly limits (3 for free tier)
    final canCreate = await _checkCanCreatePost(vendorId);
    if (!canCreate) {
      throw PostLimitException('Monthly limit reached. Upgrade to Premium for unlimited posts.');
    }
    
    // 2. Get vendor profile for embedded data
    final vendor = await UserProfileService.getUserProfile(vendorId);
    
    // 3. Prepare post document with new fields
    final postId = db.collection('vendor_posts').doc().id;
    final now = DateTime.now();
    
    final postDoc = {
      // Existing fields
      'id': postId,
      'vendorId': vendorId,
      'vendorName': vendor.businessName,
      'vendorProfileImage': vendor.profileImageUrl,
      ...postData.toMap(),
      
      // NEW FIELDS
      'postType': postType == PostType.MARKET ? 'market' : 'independent',
      'associatedMarketId': selectedMarket?.id,
      'associatedMarketName': selectedMarket?.name,
      'associatedMarketLogo': selectedMarket?.logoUrl,
      
      // Approval workflow
      'approvalStatus': selectedMarket != null ? 'pending' : null,
      'approvalRequestedAt': selectedMarket != null ? now : null,
      'approvalExpiresAt': selectedMarket != null 
          ? postData.popUpStartDateTime.subtract(Duration(days: 1)) 
          : null,
      
      // Tracking
      'monthlyPostNumber': await _getMonthlyPostCount(vendorId) + 1,
      'countsTowardLimit': true,
      'version': 2,
      
      // Metadata
      'createdAt': now,
      'updatedAt': now,
      'status': selectedMarket != null ? 'pending_approval' : 'active',
    };
    
    // 4. Execute in transaction
    await db.runTransaction((transaction) async {
      // Create the post
      transaction.set(db.collection('vendor_posts').doc(postId), postDoc);
      
      // If market post, add to approval queue
      if (selectedMarket != null) {
        final queueDoc = db.collection('market_approval_queue').doc();
        transaction.set(queueDoc, {
          'marketId': selectedMarket.id,
          'organizerId': selectedMarket.organizerId,
          'vendorPostId': postId,
          'vendorName': vendor.businessName,
          'vendorId': vendorId,
          'eventDate': postData.popUpStartDateTime,
          'requestedAt': now,
          'priority': _calculatePriority(postData.popUpStartDateTime),
          'status': 'pending',
          'preview': {
            'description': postData.description.substring(0, min(100, postData.description.length)),
            'productCount': postData.products.length,
            'photoCount': postData.photos.length,
          },
        });
      }
      
      // Update monthly tracking
      final trackingId = '${vendorId}_${now.year}_${now.month}';
      transaction.set(
        db.collection('vendor_monthly_tracking').doc(trackingId),
        {
          'vendorId': vendorId,
          'yearMonth': '${now.year}-${now.month.toString().padLeft(2, '0')}',
          'posts': {
            'total': FieldValue.increment(1),
            postType == PostType.INDEPENDENT ? 'independent' : 'market': FieldValue.increment(1),
          },
          'postIds': FieldValue.arrayUnion([postId]),
          'lastPostDate': now,
          'subscriptionTier': vendor.subscriptionTier ?? 'free',
        },
        SetOptions(merge: true),
      );
    });
    
    // 5. Send notification if market post
    if (selectedMarket != null) {
      await NotificationService.sendNotification(
        to: selectedMarket.organizerId,
        title: 'New Vendor Request',
        body: '${vendor.businessName} wants to join your market',
        data: {'type': 'vendor_request', 'postId': postId},
      );
    }
    
    return VendorPost.fromMap(postDoc);
  }
  
  // Helper: Check if vendor can create more posts
  static Future<bool> _checkCanCreatePost(String vendorId) async {
    final subscription = await SubscriptionService.getUserSubscription(vendorId);
    if (subscription?.isPremium == true) return true;
    
    final now = DateTime.now();
    final trackingId = '${vendorId}_${now.year}_${now.month}';
    final tracking = await FirebaseFirestore.instance
        .collection('vendor_monthly_tracking')
        .doc(trackingId)
        .get();
    
    final currentCount = tracking.exists ? (tracking.data()?['posts']?['total'] ?? 0) : 0;
    return currentCount < 3; // Free tier limit
  }
  
  // Helper: Calculate priority
  static String _calculatePriority(DateTime eventDate) {
    final hoursUntil = eventDate.difference(DateTime.now()).inHours;
    if (hoursUntil <= 48) return 'urgent';
    if (hoursUntil <= 72) return 'high';
    return 'normal';
  }
  
  // NEW METHOD: Get approved vendors for a market
  static Stream<List<VendorPost>> getApprovedMarketVendors(String marketId, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(Duration(days: 1));
    
    return FirebaseFirestore.instance
        .collection('vendor_posts')
        .where('associatedMarketId', isEqualTo: marketId)
        .where('approvalStatus', isEqualTo: 'approved')
        .where('popUpStartDateTime', isGreaterThanOrEqualTo: startOfDay)
        .where('popUpStartDateTime', isLessThan: endOfDay)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VendorPost.fromFirestore(doc))
            .toList());
  }
}

// Add PostType enum
enum PostType { INDEPENDENT, MARKET }
```

### NEW FILE: lib/features/organizer/services/market_approval_service.dart

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MarketApprovalService {
  static final _db = FirebaseFirestore.instance;
  
  // Get pending approvals for market organizer
  static Stream<List<ApprovalRequest>> getPendingApprovals(String organizerId) {
    return _db
        .collection('market_approval_queue')
        .where('organizerId', isEqualTo: organizerId)
        .where('status', isEqualTo: 'pending')
        .orderBy('priority', descending: true)
        .orderBy('requestedAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ApprovalRequest.fromFirestore(doc))
            .toList());
  }
  
  // Approve vendor post
  static Future<void> approveVendorPost({
    required String queueId,
    required String postId,
    required String approverId,
  }) async {
    await _db.runTransaction((transaction) async {
      final now = FieldValue.serverTimestamp();
      
      // Update vendor post
      transaction.update(_db.collection('vendor_posts').doc(postId), {
        'approvalStatus': 'approved',
        'approvalDecidedAt': now,
        'approvedBy': approverId,
        'status': 'active',
        'updatedAt': now,
      });
      
      // Update queue
      transaction.update(_db.collection('market_approval_queue').doc(queueId), {
        'status': 'approved',
        'decidedAt': now,
      });
    });
    
    // Send notification to vendor
    final post = await _db.collection('vendor_posts').doc(postId).get();
    await NotificationService.sendNotification(
      to: post.data()?['vendorId'],
      title: '✅ Market Approved!',
      body: 'You\'re approved for ${post.data()?['associatedMarketName']}',
      data: {'type': 'approval', 'postId': postId},
    );
  }
  
  // Deny vendor post
  static Future<void> denyVendorPost({
    required String queueId,
    required String postId,
    required String approverId,
    required String reason,
  }) async {
    await _db.runTransaction((transaction) async {
      final now = FieldValue.serverTimestamp();
      
      // Update vendor post
      transaction.update(_db.collection('vendor_posts').doc(postId), {
        'approvalStatus': 'denied',
        'approvalDecidedAt': now,
        'approvedBy': approverId,
        'approvalNote': reason,
        'status': 'denied',
        'updatedAt': now,
      });
      
      // Update queue
      transaction.update(_db.collection('market_approval_queue').doc(queueId), {
        'status': 'denied',
        'decidedAt': now,
        'denialReason': reason,
      });
      
      // Refund monthly count since denied
      final post = await _db.collection('vendor_posts').doc(postId).get();
      final vendorId = post.data()?['vendorId'];
      final now = DateTime.now();
      final trackingId = '${vendorId}_${now.year}_${now.month}';
      
      transaction.update(_db.collection('vendor_monthly_tracking').doc(trackingId), {
        'posts.total': FieldValue.increment(-1),
        'posts.denied': FieldValue.increment(1),
      });
    });
    
    // Send notification
    final post = await _db.collection('vendor_posts').doc(postId).get();
    await NotificationService.sendNotification(
      to: post.data()?['vendorId'],
      title: 'Market Application Update',
      body: 'Tap to see feedback from the organizer',
      data: {'type': 'denial', 'postId': postId, 'reason': reason},
    );
  }
}

// ApprovalRequest model
class ApprovalRequest {
  final String queueId;
  final String postId;
  final String marketId;
  final String vendorName;
  final String vendorId;
  final DateTime eventDate;
  final DateTime requestedAt;
  final String priority;
  final Map<String, dynamic> preview;
  
  ApprovalRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    queueId = doc.id;
    postId = data['vendorPostId'];
    marketId = data['marketId'];
    vendorName = data['vendorName'];
    vendorId = data['vendorId'];
    eventDate = (data['eventDate'] as Timestamp).toDate();
    requestedAt = (data['requestedAt'] as Timestamp).toDate();
    priority = data['priority'];
    preview = data['preview'];
  }
}
```

### REMOVE/DEPRECATE these methods:

```dart
// Mark as @deprecated and remove after migration:
// - VendorPermissionService (entire class)
// - MarketVendorManagementService (entire class)
// - requestVendorPermission()
// - approveVendorPermission()
// - getMarketVendors()
// - addVendorToMarket()
```

## 3. FRONTEND UI UPDATES

### File: lib/features/shared/screens/create_popup_screen.dart

```dart
// ADD these to CreatePopUpScreen state
class _CreatePopUpScreenState extends State<CreatePopUpScreen> {
  // NEW: Post type selection
  PostType _postType = PostType.INDEPENDENT;
  Market? _selectedMarket;
  
  // MODIFY the build method to include:
  
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        child: ListView(
          children: [
            // NEW: Add post type selector
            _buildPostTypeSelector(),
            
            // NEW: Add market selector if market type selected
            if (_postType == PostType.MARKET)
              _buildMarketSelector(),
            
            // ... existing form fields ...
            
            // MODIFY: Update submit button
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }
  
  // NEW: Post type selector widget
  Widget _buildPostTypeSelector() {
    return Card(
      margin: EdgeInsets.all(16),
      child: Column(
        children: [
          ListTile(
            title: Text('Post Type', style: TextStyle(fontWeight: FontWeight.bold)),
            leading: Icon(Icons.category),
          ),
          RadioListTile<PostType>(
            title: Text('Independent Popup'),
            subtitle: Text('Your own event at any location'),
            value: PostType.INDEPENDENT,
            groupValue: _postType,
            onChanged: (value) {
              setState(() {
                _postType = value!;
                _selectedMarket = null;
              });
            },
          ),
          RadioListTile<PostType>(
            title: Text('Market Vendor'),
            subtitle: Text('Join an organized market event'),
            value: PostType.MARKET,
            groupValue: _postType,
            onChanged: (value) {
              setState(() {
                _postType = value!;
              });
            },
          ),
        ],
      ),
    );
  }
  
  // NEW: Market selector widget
  Widget _buildMarketSelector() {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Market', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            
            // Market search/dropdown
            TypeAheadField<Market>(
              textFieldConfiguration: TextFieldConfiguration(
                decoration: InputDecoration(
                  hintText: 'Search for a market...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              suggestionsCallback: (pattern) async {
                return await MarketService.searchMarkets(pattern);
              },
              itemBuilder: (context, Market market) {
                return ListTile(
                  title: Text(market.name),
                  subtitle: Text(market.location),
                );
              },
              onSuggestionSelected: (Market market) {
                setState(() {
                  _selectedMarket = market;
                  // Auto-fill location from market
                  _locationController.text = market.location;
                  _latitude = market.latitude;
                  _longitude = market.longitude;
                });
              },
            ),
            
            // Selected market display
            if (_selectedMarket != null)
              Container(
                margin: EdgeInsets.only(top: 12),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_selectedMarket!.name}\nYour post will be sent for approval',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // MODIFY: Update submit button
  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _submitPost,
      child: Text(
        _postType == PostType.MARKET 
            ? 'Submit for Approval' 
            : 'Create Post',
      ),
    );
  }
  
  // MODIFY: Update submit method
  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;
    
    try {
      final post = await VendorPostService.createVendorPost(
        postData: VendorPostData(
          // ... existing fields ...
        ),
        postType: _postType,  // NEW
        selectedMarket: _selectedMarket,  // NEW
      );
      
      // Show appropriate success message
      if (_postType == PostType.MARKET) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Post submitted for market approval!')),
        );
      }
      
      Navigator.pop(context, post);
    } catch (e) {
      // Handle errors
    }
  }
}
```

### NEW FILE: lib/features/organizer/screens/approval_dashboard.dart

```dart
import 'package:flutter/material.dart';

class ApprovalDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final organizerId = FirebaseAuth.instance.currentUser!.uid;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Vendor Approvals'),
      ),
      body: StreamBuilder<List<ApprovalRequest>>(
        stream: MarketApprovalService.getPendingApprovals(organizerId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          
          final requests = snapshot.data!;
          if (requests.isEmpty) {
            return Center(
              child: Text('No pending vendor requests'),
            );
          }
          
          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return ApprovalCard(request: request);
            },
          );
        },
      ),
    );
  }
}

class ApprovalCard extends StatelessWidget {
  final ApprovalRequest request;
  
  const ApprovalCard({required this.request});
  
  @override
  Widget build(BuildContext context) {
    final isUrgent = request.priority == 'urgent';
    
    return Card(
      margin: EdgeInsets.all(8),
      elevation: isUrgent ? 4 : 2,
      color: isUrgent ? Colors.orange.shade50 : null,
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              child: Text(request.vendorName[0]),
            ),
            title: Text(request.vendorName),
            subtitle: Text('For ${DateFormat('MMM d, h:mm a').format(request.eventDate)}'),
            trailing: isUrgent 
                ? Chip(
                    label: Text('URGENT'),
                    backgroundColor: Colors.orange,
                  )
                : null,
          ),
          
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              request.preview['description'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _showDenyDialog(context),
                icon: Icon(Icons.close, color: Colors.red),
                label: Text('Deny', style: TextStyle(color: Colors.red)),
              ),
              Spacer(),
              ElevatedButton.icon(
                onPressed: () => _approveVendor(context),
                icon: Icon(Icons.check),
                label: Text('Approve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Future<void> _approveVendor(BuildContext context) async {
    await MarketApprovalService.approveVendorPost(
      queueId: request.queueId,
      postId: request.postId,
      approverId: FirebaseAuth.instance.currentUser!.uid,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Vendor approved!')),
    );
  }
  
  Future<void> _showDenyDialog(BuildContext context) async {
    final reasonController = TextEditingController();
    
    final denied = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Deny Vendor'),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(
            labelText: 'Reason for denial',
            hintText: 'Provide feedback to vendor...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Deny'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
    
    if (denied == true && reasonController.text.isNotEmpty) {
      await MarketApprovalService.denyVendorPost(
        queueId: request.queueId,
        postId: request.postId,
        approverId: FirebaseAuth.instance.currentUser!.uid,
        reason: reasonController.text,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vendor denied with feedback')),
      );
    }
  }
}
```

## 4. MIGRATION SCRIPT

### Create and run: scripts/migrate_vendor_market_system.dart

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> migrateVendorMarketSystem() async {
  final db = FirebaseFirestore.instance;
  print('Starting migration...');
  
  // 1. Update existing vendor_posts
  final posts = await db.collection('vendor_posts').get();
  final batch = db.batch();
  int count = 0;
  
  for (final doc in posts.docs) {
    final data = doc.data();
    final updates = <String, dynamic>{};
    
    // Add new fields if missing
    if (!data.containsKey('postType')) {
      updates['postType'] = data['marketId'] != null ? 'market' : 'independent';
    }
    
    if (!data.containsKey('approvalStatus') && data['marketId'] != null) {
      updates['approvalStatus'] = 'approved'; // Assume existing are approved
      updates['associatedMarketId'] = data['marketId'];
    }
    
    if (!data.containsKey('monthlyPostNumber')) {
      updates['monthlyPostNumber'] = 0;
    }
    
    if (!data.containsKey('countsTowardLimit')) {
      updates['countsTowardLimit'] = true;
    }
    
    if (!data.containsKey('version')) {
      updates['version'] = 2;
    }
    
    if (updates.isNotEmpty) {
      batch.update(doc.reference, updates);
      count++;
      
      if (count % 400 == 0) {
        await batch.commit();
        print('Updated $count posts...');
      }
    }
  }
  
  if (count > 0) {
    await batch.commit();
  }
  
  print('Migration complete! Updated $count posts');
  
  // 2. Create monthly tracking documents
  final vendors = <String>{};
  for (final doc in posts.docs) {
    vendors.add(doc.data()['vendorId']);
  }
  
  final now = DateTime.now();
  for (final vendorId in vendors) {
    final monthlyPosts = await db
        .collection('vendor_posts')
        .where('vendorId', isEqualTo: vendorId)
        .where('createdAt', isGreaterThanOrEqualTo: DateTime(now.year, now.month, 1))
        .get();
    
    await db.collection('vendor_monthly_tracking')
        .doc('${vendorId}_${now.year}_${now.month}')
        .set({
      'vendorId': vendorId,
      'yearMonth': '${now.year}-${now.month.toString().padLeft(2, '0')}',
      'posts': {
        'total': monthlyPosts.size,
      },
      'postIds': monthlyPosts.docs.map((d) => d.id).toList(),
    });
  }
  
  print('Created tracking for ${vendors.length} vendors');
}
```

## 5. TESTING CHECKLIST

### Critical Paths to Test:

1. Vendor creates independent post → Shows on vendor profile only
2. Vendor creates market post → Goes to pending → Organizer approves → Shows on market
3. Vendor creates market post → Organizer denies with reason → Vendor sees feedback
4. Free vendor hits 3 post limit → Gets upgrade prompt
5. Denied posts don't count toward monthly limit
6. Approval expires after 24 hours before event

### Test Data Validation:

- All existing posts have new fields
- No orphaned permissions remain
- Monthly tracking is accurate
- Approval queue works correctly

## 6. ROLLBACK PLAN

If issues arise, use feature flags:

```dart
// lib/core/feature_flags.dart
class FeatureFlags {
  static bool useNewVendorSystem = true; // Set to false to rollback
  
  static bool shouldUseNewSystem() {
    return useNewVendorSystem;
  }
}

// In VendorPostService
if (FeatureFlags.shouldUseNewSystem()) {
  // New system
} else {
  // Old system
}
```

## Discussion Points

1. **UX Improvement**: This approach significantly improves the user experience by reducing friction from a 2-step to 1-step process
2. **Data Integrity**: The approach maintains referential integrity and provides proper audit trails
3. **Scalability**: The approval queue system allows for efficient batch processing and prioritization
4. **Migration Strategy**: The versioned approach allows for safe rollback and gradual migration
5. **Performance**: Denormalized data (market name/logo in posts) reduces query complexity

## Potential Concerns

1. **Complexity**: This is a significant structural change that touches many parts of the system
2. **Migration Risk**: Existing data needs careful migration with proper validation
3. **Edge Cases**: Need to handle expired approvals, market deletions, etc.
4. **Testing**: Requires comprehensive testing of all interaction patterns

## Next Steps

1. Review and validate the approach
2. Plan migration strategy and timeline
3. Implement feature flags for safe rollout
4. Create comprehensive test plan
5. Execute migration in stages (backend → frontend → cleanup)