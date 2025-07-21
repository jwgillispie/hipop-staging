# Vendor-Market Relationship & Freemium Model Planning

## Overview
This document outlines the planned features for vendor-market relationships, freemium pricing tiers, and verification systems for the hipop platform.

## 1. Vendor-Market Relationship User Stories (Updated)

### 1.1 Vendor Permission Request (Primary Flow)
**Flow**: Vendor → Market Organizer (Permission-based)
- Vendor submits permission request to join a specific market
- Request includes vendor profile data and intended posting plans
- Market organizer reviews request in applications dashboard
- If approved: vendor is automatically added to market with full profile info
- Vendor can then create pop-ups associated with that market
- **Implementation needs**: Permission request system, approval workflow, profile data transfer

### 1.2 Central Pop-up Creation Screen
**Flow**: Enhanced vendor pop-up creation
- **Vendor Dashboard**: Single "Create Pop-up" action card leads to unified creation screen
- **Creation Screen**: Toggle between Independent vs Market-Associated pop-ups
- **Independent Pop-up**: Vendor creates standalone event (no market association)
- **Market-Associated Pop-up**: Vendor selects from markets they've been approved for
- **Implementation needs**: Dedicated creation screen with unified UI, approved markets filtering

### 1.3 Market Creates Vendor Profile (Email Invitation)
**Flow**: Market → Vendor (Email invitation)
- Market admin adds vendor by email address
- System sends invitation email to vendor
- Email contains account creation link with pre-populated email
- Vendor completes account setup
- Market-provided vendor data is automatically populated
- **Implementation needs**: Email invitation system, account creation flow, data pre-population

### 1.4 Shopper Search by Date & Favorites
**Flow**: Shopper experience enhancement
- Shoppers can filter markets/events by specific dates
- Shoppers can favorite markets that operate on preferred days
- **Implementation needs**: Date filtering, favorites system, user preferences

## Clarified Workflow Details

### Vendor Permission Request vs Application
**Key Distinction**: Instead of "applying to participate in a market event," vendors now "request permission to join a market" which allows them to create pop-ups for that market ongoing.

**Process**:
1. Vendor browses all available markets
2. Vendor submits permission request with profile info
3. Market organizer reviews in applications dashboard (reusing existing UI)
4. If approved: vendor gains ongoing permission to create pop-ups for that market
5. Vendor uses central pop-up widget, selecting from approved markets

### Pop-up Creation Flow
1. **Dashboard Action**: Single "Create Pop-up" card on vendor dashboard
2. **Central Screen**: Dedicated screen with Independent vs Market-Associated toggle
3. **Market Selection**: If market-associated, show only approved markets
4. **Creation**: Standard pop-up creation flow with market context

### Vendor Dashboard Quick Actions
1. **Create Pop-up**: Leads to unified creation screen
2. **My Applications**: View application status
3. **Market Invitations**: Manage market permission requests
4. **Profile**: Edit vendor profile
5. **Calendar**: View pop-up events calendar
6. **Analytics**: Performance metrics (coming soon)

## 2. Freemium Pricing Model

### 2.1 Vendor Tier
**Free Tier**:
- Up to 5 markets per month
- Basic vendor profile
- Standard event posting

**Premium Tier ($5/month)**:
- Unlimited market participation
- Enhanced vendor analytics
- Priority listing in search results

### 2.2 Market Tier
**Free Tier**:
- Market and event posting
- Basic vendor communication
- All vendor relationship features (apply, invite, create)

**Premium Tier ($5/month)**:
- Application management dashboard
- Advanced analytics (vendor performance, shopper engagement)
- Bulk vendor management tools
- Custom market branding

### 2.3 Shopper Tier
**Free Tier**:
- Browse all markets and vendors
- Basic search and filtering
- Event calendar access

**Premium Tier ($5/month)**:
- AI-powered personalized recommendations
- Advanced search filters
- Early access to new market announcements
- Favorite vendor notifications

## 3. Verification System

### 3.1 Vendor Verification
- Email verification (required)
- Business license verification (optional, premium feature)
- Social media profile linking
- Market endorsements/reviews
- Photo verification for pop-up events

### 3.2 Market Verification
- Email verification (required)
- Physical location verification
- Business registration verification
- Social media/website verification
- Community endorsements

### 3.3 Verification Workflow
- Automated email verification
- Manual review queue for premium verifications
- Verification badges/trust indicators
- Appeal process for rejected verifications

## 4. Technical Implementation Priorities

### Phase 1: Core Relationships
1. Vendor application system
2. Basic market-vendor linking
3. Email invitation system
4. Pending/approved status tracking

### Phase 2: User Experience
1. Date-based search and filtering
2. Favorites system
3. Basic notification system
4. User preference management

### Phase 3: Freemium Features
1. Usage tracking and limits
2. Payment processing integration
3. Feature gating based on subscription tier
4. Analytics dashboards

### Phase 4: Verification System
1. Email verification flows
2. Manual verification review system
3. Trust indicators and badges
4. Appeal and dispute resolution

## 5. Database Schema Considerations

### New Tables Needed:
- `vendor_market_relationships` (vendor_id, market_id, status, created_by, created_at)
- `user_subscriptions` (user_id, tier, features, billing_cycle)
- `verification_requests` (user_id, verification_type, status, documents)
- `user_favorites` (user_id, market_id, created_at)
- `usage_tracking` (user_id, action_type, count, month_year)

### Enhanced Tables:
- `users` - add verification_status, subscription_tier
- `markets` - add verification_badges, created_by_market_admin
- `vendors` - add verification_level, monthly_market_count

## 6. API Endpoints to Develop

### Vendor-Market Relationships:
- `POST /api/vendor/apply-to-market`
- `POST /api/market/invite-vendor`
- `PUT /api/market/approve-vendor`
- `GET /api/market/pending-vendors`

### Freemium Management:
- `GET /api/user/subscription-status`
- `POST /api/user/upgrade-subscription`
- `GET /api/user/usage-stats`

### Verification:
- `POST /api/user/request-verification`
- `PUT /api/admin/review-verification`
- `GET /api/user/verification-status`

## Current Implementation Status

### ✅ Already Implemented
- **UserProfile model** with vendor/market_organizer/shopper types
- **Market model** with associatedVendorIds list
- **VendorApplication model** with full application workflow
- **VendorMarket model** for vendor-market relationships
- **VendorApplicationService** with comprehensive application management
- Firebase Firestore backend with collections:
  - `users` (UserProfile)
  - `markets` (Market)
  - `vendor_applications` (VendorApplication)
  - `vendor_markets` (VendorMarket)
  - `managed_vendors` (ManagedVendor)

### 🚧 Partially Implemented
- Vendor application system (exists but needs enhancement for our user stories)
- Market organizer management (basic structure exists)
- Vendor-market associations (exists but needs relationship status enhancement)

### ❌ Not Yet Implemented
- Market invitation system for vendors
- Freemium usage tracking and limits
- Enhanced relationship status management
- Date-based shopper search with favorites
- Verification system beyond basic email
- Payment processing integration

## Implementation Plan - Updated

### Phase 1: Enhanced Vendor-Market Relationships (Current Focus)
**Status: Ready to implement**

1. **Enhance VendorApplication for Permission Requests**
   - Modify existing VendorApplication model to support "permission request" type
   - Add `applicationType` enum: event_application, market_permission
   - Reuse existing approval workflow for permission requests
   
2. **Create VendorMarketRelationship service**
   - Handle approved permission requests → create ongoing market relationships
   - Integration with existing VendorApplicationService
   - Manage vendor's approved markets list

3. **Implement Central Pop-up Creation Widget**
   - Single unified interface for pop-up creation
   - Toggle: Independent vs Market-Associated
   - Filter and display only vendor's approved markets
   - Integrate with existing pop-up creation flow

4. **Market invitation system**
   - Email invitation workflow (Phase 1B)
   - Pre-populated vendor account creation
   - Auto-linking when vendor creates account

### Phase 2: Freemium Implementation
1. **Create subscription models**
   - UserSubscription model
   - UsageTracking model
   - SubscriptionTier enum

2. **Implement usage tracking**
   - Monthly market participation limits for vendors
   - Feature gating based on subscription tier
   - Usage analytics and reporting

### Phase 3: Enhanced User Experience
1. **Shopper date filtering and favorites**
2. **Enhanced verification system**
3. **Analytics dashboards for premium users**

### Phase 4: Advanced Features
1. **Payment processing integration**
2. **Advanced verification workflows**
3. **Bulk management tools**

## Implementation Summary (Phase 1 Complete)

### ✅ Completed Implementation
**Phase 1: Enhanced Vendor-Market Relationships**

1. **Enhanced Models Created**:
   - `VendorMarketRelationship` - Comprehensive relationship tracking with status and source
   - `VendorApplication` - Enhanced with `ApplicationType` enum for permission vs event applications
   - `UserSubscription` - Full freemium tier management with feature gating
   - `UsageTracking` - Monthly usage analytics with aggregation
   - `UserMarketFavorite` - Shopper favorite markets with day preferences

2. **Services Implemented**:
   - `VendorMarketRelationshipService` - Complete relationship lifecycle management
   - `SubscriptionService` - Freemium subscription and feature access control
   - `UsageTrackingService` - Usage tracking with automatic limit enforcement
   - Enhanced `VendorApplicationService` - Handles both event and permission applications

3. **Central Pop-up Creation Widget**:
   - ✅ Single unified interface with Independent vs Market-Associated toggle
   - ✅ Only shows approved markets for vendor selection
   - ✅ Automatic usage tracking for market participation
   - ✅ Permission request flow integration
   - ✅ Enhanced UX with permission status indicators

4. **Permission Request Workflow**:
   - ✅ Vendors can request permission to join markets
   - ✅ Market organizers review in existing applications dashboard
   - ✅ Auto-creation of vendor-market relationships upon approval
   - ✅ Seamless integration with existing application system

### 🚧 Ready for Phase 2
**Next Implementation Steps**:

1. **Market Invitation System** (Phase 1B):
   - Email invitation workflow
   - Pre-populated vendor account creation
   - Token-based invitation acceptance

2. **Enhanced UI Components**:
   - Market permission request screen
   - Freemium upgrade prompts
   - Usage limit notifications
   - Admin analytics dashboards

3. **Freemium Integration**:
   - Payment processing setup
   - Subscription upgrade flows
   - Feature gating enforcement in UI

### 📊 Database Collections Created
- `vendor_market_relationships` - Core relationship management
- `user_subscriptions` - Freemium subscription tracking
- `usage_tracking` - Monthly usage analytics
- `user_market_favorites` - Shopper preferences (future)

### 🔄 API Patterns Established
- Permission-based vendor-market access control
- Usage tracking with automatic limit enforcement
- Subscription tier feature gating
- Relationship status lifecycle management

## Next Steps
1. ✅ ~~Implement Phase 1 enhanced vendor-market relationships~~
2. ✅ ~~Create market permission request screen~~
3. ✅ ~~Update vendor dashboard with central pop-up creation widget~~
4. ✅ ~~Add routing for new vendor market permissions screen~~
5. ✅ ~~Implement market organizer permission approval UI~~
6. ✅ ~~Test complete permission workflow in staging app~~
7. ✅ ~~Debug and fix vendor management integration~~
8. ✅ ~~Update debug tools for production testing~~
9. 🚧 **READY FOR NEXT PHASE**: Implement Phase 1B: Market invitation system (email invitations)
10. Add freemium upgrade prompts and enforcement
11. Set up payment processing infrastructure
12. Implement shopper date filtering and favorites system

## Implementation Summary (COMPLETED ✅)

### ✅ SUCCESSFULLY COMPLETED Phase 1 Implementation

**Enhanced Vendor-Market Relationships with Central Pop-up Creation**:

1. **Core Models & Services** (✅ COMPLETED):
   - `VendorMarketRelationship` model with comprehensive status tracking
   - `VendorApplication` enhanced with `ApplicationType` enum
   - `UserSubscription` and `UsageTracking` models for freemium features
   - Complete service layer for relationship management

2. **UI Components & Integration** (✅ COMPLETED):
   - ✅ `CentralPopupCreationWidget` - Unified pop-up creation interface
   - ✅ `VendorDashboard` - Correct action cards: Create Pop-up, Applications, Market Invitations, Profile, Calendar, Analytics
   - ✅ `VendorPopupCreationScreen` - Dedicated screen for central pop-up creation widget
   - ✅ `VendorMarketPermissionsScreen` - 3-tab interface for permission management
   - ✅ Complete routing for all screens (`/vendor/popup-creation`, `/vendor/market-permissions`)

3. **Key Features Working** (✅ FULLY FUNCTIONAL):
   - Central pop-up creation with Independent vs Market-Associated toggle
   - Only shows approved markets for vendor selection
   - Permission request workflow with message and referral source
   - Real-time permission status tracking
   - Automatic usage tracking for freemium limits
   - Enhanced UX with permission status indicators

### ✅ COMPLETE Permission Pipeline Implementation (TESTED & WORKING)

**Phase 1A: Enhanced Vendor-Market Relationships** (✅ PRODUCTION READY):
- **Vendor Side**: Central pop-up creation with permission-based market filtering
- **Permission Requests**: Vendors can request ongoing permission to create pop-ups at markets
- **Market Organizer Side**: Enhanced applications screen with permission request approval
- **Automatic Relationships**: Approving permission requests creates vendor-market relationships
- **Vendor Management Integration**: Approved vendors automatically appear in management UI

**Key Features Completed & Tested** (✅ ALL WORKING):
1. **Vendor Dashboard**: Proper action cards with central pop-up creation ✅
2. **Permission Request System**: 3-tab interface for browsing, requesting, and tracking ✅
3. **Market Organizer Approval**: Enhanced applications screen distinguishes permission requests from event applications ✅
4. **Automatic Integration**: Approved permissions automatically grant vendor access to create market pop-ups ✅
5. **Visual Indicators**: Clear labeling of permission requests vs event applications ✅
6. **Relationship Creation**: Approved permissions create `VendorMarketRelationship` records ✅
7. **Vendor Management Display**: Approved vendors appear with "Permission-Based" badges ✅
8. **Debug Tools**: Updated account switcher and database cleaner for testing ✅

**Complete User Flow** (✅ END-TO-END TESTED):
1. **Vendor** → Browse markets → Request permission → Wait for approval ✅
2. **Market Organizer** → Review permission requests → Approve/Deny → Automatic relationship creation ✅
3. **Approved Vendor** → Appears in Vendor Management with "Permission-Based" badge ✅
4. **Vendor** → Create pop-ups for approved markets → Automatic usage tracking ✅

**Enhanced Vendor Management** (✅ FULLY IMPLEMENTED):
- Approved permission vendors automatically appear in Vendor Management screen ✅
- Visual "Permission-Based" purple badge distinguishes them from event-application vendors ✅
- Full vendor management capabilities (activate/deactivate, feature, edit, delete) ✅
- Metadata tracking for permission vs event-based vendor origins ✅
- Real-time updates when permissions are approved ✅

**Debug Infrastructure** (✅ PRODUCTION READY):
- Account switcher with correct test emails (jozo@gmail.com, vendorjozo@gmail.com, marketjozo@gmail.com) ✅
- Database cleaner with comprehensive collection cleanup ✅
- Debug logging for troubleshooting permission workflows ✅

🎉 **THE COMPLETE Phase 1A PERMISSION-BASED VENDOR-MARKET RELATIONSHIP SYSTEM IS NOW FULLY IMPLEMENTED, TESTED, AND PRODUCTION READY!** 🎉