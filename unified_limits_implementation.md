# Unified Monthly Limits Implementation

## Architecture Decision: Single Tracking System

### Problem Solved
- **Before**: Vendors used `user_stats` collection, organizers used `SubscriptionService.getRemainingVendorPosts()`
- **After**: Both user types use unified `user_stats` collection with consistent logic

### Key Changes Made

#### 1. VendorPostsRepository (`lib/repositories/vendor_posts_repository.dart`)
- ✅ Renamed `vendor_stats` → `user_stats` collection 
- ✅ Updated method signatures: `_updateVendorPostCount(String userId)`
- ✅ Unified tracking for all user types
- ✅ Same monthly reset logic for vendors and organizers

#### 2. CreatePopUpScreen (`lib/features/shared/screens/create_popup_screen.dart`)  
- ✅ Market organizers now use same limit logic as vendors
- ✅ Same 3 posts per month limit for free users
- ✅ Premium bypass works for both user types
- ✅ Unified `_getCurrentMonthlyPostCount()` method
- ✅ Dynamic error messages based on user type

#### 3. Visual Consistency
- ✅ Same limit indicators show for both user types
- ✅ Consistent upgrade prompts (Vendor Pro vs Organizer Pro)
- ✅ Real-time count updates after post creation

## Business Logic (Unified)

```
Free Users (Vendors & Organizers): 3 posts per month total
Premium Users: Unlimited posts
Count Tracking: All posts counted on creation
Monthly Reset: Automatic based on month change
Collection: user_stats (unified for all user types)
```

## Technical Benefits

1. **Single Source of Truth**: One collection tracks all user limits
2. **Consistent Logic**: Same validation and reset patterns
3. **Maintainability**: No duplicate tracking systems
4. **Real-time Updates**: Firestore streams provide instant UI feedback
5. **Scalability**: Easy to extend limits per user type in future

## Database Schema (Updated)

### user_stats Collection
```javascript
{
  userId: "string",           // Works for vendors and organizers
  monthlyPostCount: number,   // Current month's post count
  currentCountMonth: "YYYY-MM", // Month tracking key
  lastPostCreatedAt: timestamp,
  createdAt: timestamp
}
```

## Test Scenarios

### Vendor Flow
1. Free vendor creates 3 posts → Success, count = 3
2. Free vendor tries 4th post → Blocked with "Upgrade to Vendor Pro"
3. Premium vendor creates unlimited → Success, no counting

### Organizer Flow  
1. Free organizer creates 3 vendor recruitment posts → Success, count = 3
2. Free organizer tries 4th post → Blocked with "Upgrade to Organizer Pro"
3. Premium organizer creates unlimited → Success, no counting

### Cross-Type Consistency
1. Both user types see same UI patterns
2. Both use same monthly reset logic
3. Both tracked in same database collection

## Migration Notes
- Existing `vendor_stats` documents should be migrated to `user_stats`
- `SubscriptionService.getRemainingVendorPosts()` can be deprecated
- All future limit features use unified system

## Success Metrics
✅ Code compiles without errors
✅ Consistent UI between user types  
✅ Single tracking system reduces complexity
✅ Real-time updates work for all users
✅ Enterprise-grade error handling and validation