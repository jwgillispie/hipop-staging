# HiPop Testing Guide

## 🔄 **Core Cross-Profile Flows**

### **1. Vendor Application → Market Organizer Approval Flow**
- **Vendor Profile**: Apply to specific markets with requested dates
- **Market Organizer**: Review applications → Approve/Reject/Waitlist
- **System**: Approved vendors become available for market association
- **Test Points**: Application submission, review process, status notifications

### **2. Market Creation → Vendor Association Flow**
- **Market Organizer**: Create new market with Google Places address search
- **System**: Load approved applications + existing managed vendors
- **Market Organizer**: Select vendors to associate with market
- **Result**: Market created with associated vendor roster
- **Test Points**: Vendor selection UI, data persistence, market-vendor relationships

### **3. Shopper Discovery → Favorites Flow**
- **Shopper**: Browse markets/vendors/events with location-based filtering
- **Shopper**: Add items to favorites (cross-device sync via Firebase)
- **System**: Real-time favorites updates across sessions
- **Test Points**: Search functionality, favorites persistence, cross-device sync

### **4. Vendor Management → Market Integration Flow**
- **Market Organizer**: Create managed vendors directly
- **System**: Auto-associate with organizer's markets
- **Market Organizer**: Include in market vendor roster
- **Test Points**: Vendor creation, automatic associations, market updates

## 🎯 **Specific Test Scenarios**

### **Vendor → Market Organizer Interactions**
1. **Application Workflow**:
   ```
   Vendor applies → Organizer reviews → Status changes → Vendor notification
   ```

2. **Market Association**:
   ```
   Approved vendor → Available for selection → Market creation → Vendor roster
   ```

### **Shopper → Content Discovery**
1. **Multi-Type Search**:
   ```
   Location search → Filter by markets/vendors/events → Favorites → Cross-session persistence
   ```

2. **Real-time Updates**:
   ```
   Market changes → Shopper feed updates → Favorites sync
   ```

### **Market Organizer Workflows**
1. **Complete Market Setup**:
   ```
   Create market → Add schedule → Associate vendors → Vendor management
   ```

2. **Vendor Lifecycle Management**:
   ```
   Review applications → Create managed vendors → Market association → Updates
   ```

## 📱 **Cross-Platform Testing Points**

### **Authentication & Profile Management**
- User registration with different profile types (shopper/vendor/organizer)
- Profile completion requirements
- Cross-device login persistence

### **Real-time Data Sync**
- Favorites synchronization across devices
- Market/vendor updates reflected in shopper feeds
- Application status changes

### **Location-Based Features**
- Google Places integration for consistent address data
- Market location search and discovery
- Proximity-based content filtering

## 🔍 **Integration Testing Focus Areas**

### **Data Consistency**
- Market-vendor associations persist correctly
- Favorites sync between local storage (anonymous) and Firestore (authenticated)
- Application status changes reflect across all user types

### **User Experience Flows**
- Seamless transitions between profile types
- Consistent address search experience (shoppers vs. market creation)
- Real-time UI updates without refresh requirements

### **Permission & Access Control**
- Market organizers can only manage their own content
- Vendors can only apply to active markets
- Shoppers have read-only access to public content

## 🧪 **Detailed Test Cases**

### **Test Case 1: Complete Vendor Application Process**
1. **Setup**: Create vendor account and complete profile
2. **Action**: Apply to multiple markets with different dates
3. **Verification**: Applications appear in market organizer dashboard
4. **Action**: Market organizer approves/rejects applications
5. **Verification**: Vendor receives status updates
6. **Expected Result**: Approved vendors available for market association

### **Test Case 2: Market Creation with Vendor Association**
1. **Setup**: Market organizer account with existing approved applications
2. **Action**: Create new market using Google Places address search
3. **Verification**: Address data consistency across shopper search and market creation
4. **Action**: Select approved vendors and managed vendors for association
5. **Verification**: Market created with correct vendor associations
6. **Expected Result**: Market appears in shopper feeds with associated vendors

### **Test Case 3: Cross-Profile Favorites Synchronization**
1. **Setup**: Anonymous shopper browsing markets/vendors/events
2. **Action**: Add items to favorites while anonymous
3. **Action**: Create account and login
4. **Verification**: Anonymous favorites migrate to user account
5. **Action**: Access favorites from different device
6. **Expected Result**: Favorites sync across devices and sessions

### **Test Case 4: Real-time Content Updates**
1. **Setup**: Shopper with active feed, Market organizer with markets
2. **Action**: Market organizer updates market information
3. **Verification**: Changes appear in shopper feed without refresh
4. **Action**: Market organizer associates new vendors
5. **Verification**: Vendor count updates in real-time
6. **Expected Result**: All users see consistent, up-to-date information

### **Test Case 5: Event System Integration**
1. **Setup**: Market organizer and shopper accounts
2. **Action**: Create events associated with markets
3. **Verification**: Events appear in shopper feed filters
4. **Action**: Shopper filters by events only
5. **Verification**: Event filtering works correctly
6. **Action**: Add events to favorites
7. **Expected Result**: Event favorites persist and sync

## 🐛 **Common Issues to Test**

### **Data Persistence Issues**
- Favorites not syncing between anonymous and authenticated states
- Market-vendor associations not persisting after creation
- Address data inconsistency between search and creation

### **UI/UX Issues**
- Loading states during vendor data fetching
- Form validation for required fields
- Error handling for network failures

### **Performance Issues**
- Large vendor lists in market creation form
- Real-time updates causing UI lag
- Image loading and caching

## 📊 **Testing Environment Setup**

### **Required Test Data**
- Multiple user accounts (vendor, market organizer, shopper)
- Sample markets with different locations
- Vendor applications in various states
- Events associated with markets

### **Firebase Collections to Monitor**
- `users` - Profile data and authentication
- `markets` - Market information and associations
- `vendor_applications` - Application workflow
- `managed_vendors` - Organizer-created vendors
- `user_favorites` - Cross-device favorites sync
- `events` - Event system functionality

### **API Integration Points**
- Google Places API for address search
- Firebase Authentication for user management
- Firestore for real-time data sync
- Cloud Storage for image uploads

This comprehensive testing guide covers all major user flows and interaction patterns in the HiPop farmers market application, focusing on cross-profile interactions and real-time data synchronization.