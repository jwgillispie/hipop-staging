# Vendor Directory Feature Plan
## Premium Market Organizer Feature

### Overview
A searchable vendor directory for market organizers to browse, filter, and connect with vendors. This will be a premium-gated feature available to Market Organizer Pro subscribers ($69/month).

### Core Requirements
1. **Search & Filter Vendors** - Similar to shopper search but for organizers
2. **View Vendor Profiles** - Business info, categories, experience, contact details
3. **Direct Contact** - Email, phone, Instagram, website links
4. **Invitation System** - Send market invitations directly from directory
5. **Premium Gating** - Only available to Market Organizer Pro subscribers

### Implementation Plan

#### 1. Data Model
- Use existing `user_profiles` collection (vendors)
- Use existing `vendor_posts` for additional vendor info
- Leverage `vendor_invitations` collection for tracking

#### 2. UI Components

##### A. Main Directory Screen (`/lib/features/organizer/screens/vendor_directory_screen.dart`)
```
- AppBar with "Vendor Directory" title and premium badge
- Search bar at top
- Filter chips (Categories, Location, Experience, Availability)
- Vendor list cards with:
  - Business name
  - Categories
  - Location
  - Rating/experience level
  - Quick contact buttons
  - "Send Invitation" button
```

##### B. Search & Filter Service (`/lib/features/organizer/services/vendor_directory_service.dart`)
```dart
Key Methods:
- searchVendors(query, filters)
- getVendorsByCategory(categories)
- getVendorsByLocation(location, radius)
- getVendorDetails(vendorId)
```

##### C. Integration Points
- Add new tab to Market Organizer Premium Dashboard
- Premium gate check before access
- Track usage analytics

### Technical Architecture

#### Screen Structure:
```
VendorDirectoryScreen
├── Premium Access Check
├── Search Bar
├── Filter Section
│   ├── Category Multi-Select
│   ├── Location Input
│   ├── Experience Level Filter
│   └── Availability Toggle
├── Results List
│   └── VendorCard
│       ├── Business Info
│       ├── Categories Tags
│       ├── Contact Actions
│       └── Invite Button
└── Empty State / Loading States
```

#### Key Features:
1. **Smart Search** - Search by business name, products, categories
2. **Multi-Filter** - Combine multiple filters
3. **Contact Integration** - Launch email/phone/web directly
4. **Invitation Flow** - Quick invite with pre-filled market details
5. **Analytics Tracking** - Track searches, views, invitations

### File Structure:
```
lib/features/organizer/
├── screens/
│   └── vendor_directory_screen.dart
├── services/
│   └── vendor_directory_service.dart
└── widgets/
    └── vendor_directory_card.dart
```

### Premium Gating:
- Check `SubscriptionService.hasFeature(userId, 'vendor_directory')`
- Show upgrade prompt if not premium
- Feature key: `vendor_directory`

### Success Metrics:
- Number of searches performed
- Vendors contacted
- Invitations sent
- Conversion to market applications