# HiPOP Bugs and Improvements Log
*Last Updated: January 14, 2025*

## 🐛 Active Bugs
*Organized by Priority: High → Medium → Low*

## 🔥 HIGH PRIORITY BUGS

### 1. Market Vendor Connection Issue
**Description:** When a market organizer accepts a vendor for Market 1, they cannot add that same vendor when creating Market 2.
**Expected Behavior:** Markets should be able to create posts with any vendors they've previously accepted across all their markets.
**Current Behavior:** Vendors are siloed to individual markets and cannot be reused.
**Priority:** High
**Affected Users:** Market Organizers

### 2. Premium Upgrade Flow Placeholder
**Description:** When vendors exceed their free product count threshold and click "Upgrade to Premium", they see a dummy placeholder message.
**Current Behavior:** Shows "premium flow upgrade would happen here" after pressing "Upgrade Now"
**Expected Behavior:** Should redirect to actual Stripe payment flow
**Priority:** High
**Affected Users:** Vendors

### 5. Assign Products to Markets Non-Functional
**Description:** The "Assign Products to Markets" feature shows placeholder text instead of working functionality.
**Current Behavior:** Displays "Coming Soon" message
**Expected Behavior:** Should allow vendors to assign their products to specific markets
**Priority:** High
**Affected Users:** Vendors

### 7. Missing Event Favorites
**Description:** Users can only favorite markets and vendors, but cannot favorite specific events.
**Current Behavior:** Favorites only include markets and vendors
**Expected Behavior:** Should allow users to favorite events and see them in their favorites list
**Priority:** High
**Affected Users:** Shoppers
**Feature Gap:** Yes

### 10. Subscription Management Buttons Non-Functional
**Description:** The "Upgrade for Unlimited" and "Choose Plan" buttons on the Manage Subscription page don't work.
**Current Behavior:** Buttons are displayed but have no functionality
**Expected Behavior:** Should redirect to premium upgrade flow with appropriate tier
**Priority:** High
**Affected Users:** Free tier vendors who want to upgrade
**Feature Gap:** Yes

### 12. Vendor Card Links Should Open Apps Directly
**Description:** When shoppers press on vendor cards, they see "Save Location" or "Instagram Info" but have to manually copy/paste instead of direct app integration.
**Current Behavior:** Shows copyable text for location and Instagram information
**Expected Behavior:** "Save Location" should open Maps app directly, "Instagram Info" should open Instagram app
**Priority:** High
**Affected Users:** Shoppers trying to interact with vendor information
**UX Issue:** Yes

### 16. Market Creation Should Use Progressive Flow
**Description:** The current market creation flow tries to fit too much information in one modal, making it overwhelming on mobile.
**Current Behavior:** Single large modal with all fields at once
**Expected Behavior:** Should use a sliding/progressive step-by-step flow (Step 1: Basic Info, Step 2: Location, Step 3: Schedule, etc.)
**Priority:** High
**Affected Users:** Market Organizers creating markets on mobile
**Platform:** iOS (likely all mobile)
**UI/UX Issue:** Yes

### 17. Shoppers Cannot See Items in Vendor Pop-ups
**Description:** When shoppers view vendor pop-ups in their feed, they cannot see the actual items/products that vendors have added to those pop-ups.
**Current Behavior:** Vendor pop-ups show basic vendor info but not the specific items they're bringing
**Expected Behavior:** Should display the item list that vendors added to their pop-ups, allowing shoppers to see what will be available
**Priority:** High
**Affected Users:** Shoppers trying to see what vendors are bringing to markets
**Feature Gap:** Yes

## ⚠️ MEDIUM PRIORITY BUGS

### 3. Free Tier Pop-up Counter Not Decrementing
**Description:** The number of remaining pop-ups for free tier users does not decrease when they create new pop-ups.
**Current Behavior:** Counter stays static regardless of pop-up creation
**Expected Behavior:** Should decrement with each new pop-up created
**Priority:** Medium
**Affected Users:** Free tier Vendors

### 4. Shopper Favorites Loading Issue
**Description:** User favorites for shoppers don't load on initial page load.
**Current Behavior:** Requires manual page refresh to display favorites
**Expected Behavior:** Should load automatically on first visit
**Priority:** Medium
**Affected Users:** Shoppers

### 6. Filter by Product UI is Clunky
**Description:** The current "Filter by Product" interface is difficult to use and visually inconsistent.
**Current Behavior:** Current filter implementation is clunky and hard to navigate
**Expected Behavior:** Should be a dropdown menu or sliding interface with uniform shape/design
**Priority:** Medium
**Affected Users:** Shoppers, Vendors (anyone using product filtering)
**UI/UX Issue:** Yes

### 8. Favorites Calendar Refresh Issues
**Description:** The favorites calendar doesn't refresh properly when opened and lacks auto-refresh capability.
**Current Behavior:** Calendar data may be stale when opened
**Expected Behavior:** Should refresh automatically when opened or have a manual refresh option
**Priority:** Medium
**Affected Users:** Shoppers with favorited items
**UI/UX Issue:** Yes

### 11. Vendor Subscription UI Showing on Shopper Page
**Description:** The subscription management interface (showing "free tier usage") appears on shopper pages when it should only be for vendor upgrades.
**Current Behavior:** Vendor subscription UI visible to shoppers
**Expected Behavior:** Subscription management should only show to vendors, or show appropriate tier for each user type
**Priority:** Medium
**Affected Users:** Shoppers (seeing irrelevant UI)
**User Role Issue:** Yes

### 13. Mobile Market Edit Modal is Ugly and Cramped
**Description:** The "Edit Market" modal on iOS is visually unappealing and doesn't fit mobile screen constraints well.
**Current Behavior:** Large modal with cramped form fields, poor spacing, and awkward layout
**Expected Behavior:** Should be redesigned for mobile with better spacing, cleaner layout, or slide-up design
**Priority:** Medium
**Affected Users:** Market Organizers on mobile
**Platform:** iOS
**UI/UX Issue:** Yes

### 14. Market Calendar Date Selection is Awkward
**Description:** The calendar interface in the market edit modal is difficult to use on mobile with poor touch targets and cramped layout.
**Current Behavior:** Small calendar with difficult-to-tap dates and cluttered "Selected Dates" section
**Expected Behavior:** Larger touch targets, better spacing, cleaner date selection UI
**Priority:** Medium
**Affected Users:** Market Organizers scheduling events on mobile
**Platform:** iOS
**UI/UX Issue:** Yes

### 15. Vendor Management Screen is Visually Poor
**Description:** The Vendor Management screen has poor visual hierarchy, cramped layout, and unclear information architecture.
**Current Behavior:** Cluttered search/filter area, poor vendor card design, cramped bottom action bar
**Expected Behavior:** Cleaner search interface, better vendor card design, improved layout for mobile
**Priority:** Medium
**Affected Users:** Market Organizers managing vendors on mobile
**Platform:** iOS
**UI/UX Issue:** Yes

## 📝 LOW PRIORITY BUGS

### 9. Favorites Refresh Mechanism
**Description:** Favorites currently use a button for refresh instead of modern pull-to-refresh gesture.
**Current Behavior:** Manual refresh button
**Expected Behavior:** Should use slide-down/pull-to-refresh mechanism for better UX
**Priority:** Low
**Affected Users:** All users with favorites
**UI/UX Issue:** Yes

## 📝 Notes

### Testing Environment
- Platform: Web (Staging)
- URL: https://hipop-markets-staging.web.app
- Date: January 14, 2025

### Additional Context
- These issues were discovered during live testing of the premium subscription flow
- All issues are reproducible in the current staging environment

## 🔧 Suggested Fixes

### For Bug #1 (Vendor Connection)
- Implement a global vendor acceptance system
- Create a `accepted_vendors` collection at the organizer level rather than market level
- Allow organizers to select from their pool of accepted vendors when creating any market

### For Bug #2 (Premium Upgrade)
- Connect the upgrade button to the existing StripePaymentForm
- Route should go to `/premium/upgrade?tier=vendor&userId={userId}`
- Remove placeholder dialog

### For Bug #3 (Pop-up Counter)
- Check the decrement logic in the popup creation flow
- Ensure Firestore transaction is updating the usage counter
- Verify the UI is reading from the correct field

### For Bug #4 (Favorites Loading)
- Add proper initialization in the FavoritesBloc
- Ensure favorites are fetched on widget mount
- Check if there's a race condition with auth state

### For Bug #5 (Product Assignment)
- Implement the actual product-to-market assignment logic
- Create UI for multi-select markets
- Update Firestore structure to support product-market relationships

### For Bug #6 (Filter UI)
- Replace current filter with dropdown or modal overlay
- Design consistent filter chips/buttons with uniform sizing
- Consider slide-out filter panel for mobile
- Ensure smooth animations and intuitive UX

### For Bug #7 (Event Favorites)
- Add event favoriting capability to event cards/details
- Update FavoritesBloc to handle event favorites
- Create event favorites section in favorites screen
- Update Firestore structure to support event favorites

### For Bug #8 (Calendar Refresh)
- Add auto-refresh when favorites calendar is opened
- Implement proper data fetching lifecycle
- Add manual refresh option as backup
- Ensure calendar updates when favorites change

### For Bug #9 (Pull-to-Refresh)
- Replace refresh button with RefreshIndicator widget
- Implement proper pull-to-refresh gesture
- Add loading animation during refresh
- Ensure consistent refresh UX across all favorites sections

### For Bug #10 (Subscription Buttons)
- Wire "Upgrade for Unlimited" button to `/premium/upgrade?tier=vendor&userId={userId}`
- Wire "Choose Plan" button to premium onboarding flow
- Ensure proper navigation from subscription management page
- Test that Stripe checkout loads correctly from these entry points

### For Bug #11 (User Role UI)
- Add user role checking in subscription management components
- Hide vendor-specific UI from shoppers
- Show appropriate subscription options for each user type
- Ensure proper conditional rendering based on user.userType

### For Bug #12 (Direct App Integration)
- Replace "Save Location" with direct Maps app launch using url_launcher
- Replace "Instagram Info" with direct Instagram app/web launch
- Use deep linking: `maps://` or `https://maps.apple.com/` for location
- Use Instagram deep linking: `instagram://user?username=` or fallback to web
- Add proper error handling if apps not installed

## 🚀 Next Steps
1. Prioritize fixes based on user impact
2. Create individual tasks for each bug
3. Test fixes in staging before production deployment

## 📊 Bug Status Tracker

### 🔥 High Priority (8 bugs)
| Bug # | Status | Assigned | Target Fix Date |
|-------|--------|----------|-----------------|
| 1 | Open | - | TBD |
| 2 | Open | - | TBD |
| 5 | Open | - | TBD |
| 7 | Open | - | TBD |
| 10 | Open | - | TBD |
| 12 | Open | - | TBD |
| 16 | Open | - | TBD |
| 17 | Open | - | TBD |

### ⚠️ Medium Priority (8 bugs)
| Bug # | Status | Assigned | Target Fix Date |
|-------|--------|----------|-----------------|
| 3 | Open | - | TBD |
| 4 | Open | - | TBD |
| 6 | Open | - | TBD |
| 8 | Open | - | TBD |
| 11 | Open | - | TBD |
| 13 | Open | - | TBD |
| 14 | Open | - | TBD |
| 15 | Open | - | TBD |

### 📝 Low Priority (1 bug)
| Bug # | Status | Assigned | Target Fix Date |
|-------|--------|----------|-----------------|
| 9 | Open | - | TBD |

## 📱 iOS Issues Section

### 13. Mobile Market Edit Modal is Ugly and Cramped
**Description:** The "Edit Market" modal on iOS is visually unappealing and doesn't fit mobile screen constraints well.
**Current Behavior:** Large modal with cramped form fields, poor spacing, and awkward layout
**Expected Behavior:** Should be redesigned for mobile with better spacing, cleaner layout, or slide-up design
**Priority:** Medium
**Affected Users:** Market Organizers on mobile
**Platform:** iOS
**UI/UX Issue:** Yes

### 14. Market Calendar Date Selection is Awkward
**Description:** The calendar interface in the market edit modal is difficult to use on mobile with poor touch targets and cramped layout.
**Current Behavior:** Small calendar with difficult-to-tap dates and cluttered "Selected Dates" section
**Expected Behavior:** Larger touch targets, better spacing, cleaner date selection UI
**Priority:** Medium
**Affected Users:** Market Organizers scheduling events on mobile
**Platform:** iOS
**UI/UX Issue:** Yes

### 15. Vendor Management Screen is Visually Poor
**Description:** The Vendor Management screen has poor visual hierarchy, cramped layout, and unclear information architecture.
**Current Behavior:** Cluttered search/filter area, poor vendor card design, cramped bottom action bar
**Expected Behavior:** Cleaner search interface, better vendor card design, improved layout for mobile
**Priority:** Medium
**Affected Users:** Market Organizers managing vendors on mobile
**Platform:** iOS
**UI/UX Issue:** Yes

### 16. Market Creation Should Use Progressive Flow
**Description:** The current market creation flow tries to fit too much information in one modal, making it overwhelming on mobile.
**Current Behavior:** Single large modal with all fields at once
**Expected Behavior:** Should use a sliding/progressive step-by-step flow (Step 1: Basic Info, Step 2: Location, Step 3: Schedule, etc.)
**Priority:** High
**Affected Users:** Market Organizers creating markets on mobile
**Platform:** iOS (likely all mobile)
**UI/UX Issue:** Yes