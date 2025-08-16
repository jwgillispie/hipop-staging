# HiPop Theme System Usage Guide

## Overview
The HiPop theme system provides a cohesive, nature-inspired design language optimized for marketplace conversion and user trust. This guide shows how to implement the new theme across the application.

## Color Palette
- **Primary (Forest Green)**: Trust, stability, organic
- **Secondary (Sage)**: Fresh, natural, calm
- **Accent (Coral)**: CTAs, energy, warmth
- **Success (Emerald)**: Confirmations, positive actions
- **Warning (Amber)**: Gentle alerts
- **Error (Dusty Rose)**: Soft error states
- **Premium (Gold)**: Premium features

## Theme Implementation

### 1. Replace Direct Colors with Theme Colors

#### ❌ OLD - Direct color usage:
```dart
Container(
  color: Colors.orange,
  child: Text(
    'Market Name',
    style: TextStyle(color: Colors.white),
  ),
)
```

#### ✅ NEW - Theme-aware colors:
```dart
Container(
  color: Theme.of(context).colorScheme.primary,
  child: Text(
    'Market Name',
    style: Theme.of(context).textTheme.titleMedium,
  ),
)
```

### 2. Replace Emojis with Material Icons

#### ❌ OLD - Emoji usage:
```dart
Text('🏪 Market Dashboard')
Text('👤 Profile')
Text('📅 Calendar')
Text('⭐ Premium')
```

#### ✅ NEW - Material Icons:
```dart
Row(
  children: [
    Icon(Icons.store_rounded),
    Text('Market Dashboard'),
  ],
)

// Common icon replacements:
// 🏪 → Icons.store_rounded
// 👤 → Icons.person_rounded
// 📅 → Icons.calendar_month_rounded
// ⭐ → Icons.star_rounded
// 💎 → Icons.diamond_rounded
// 🛒 → Icons.shopping_cart_rounded
// 📍 → Icons.location_on_rounded
// ⏰ → Icons.schedule_rounded
// ✅ → Icons.check_circle_rounded
// ❌ → Icons.cancel_rounded
// 📧 → Icons.email_rounded
// 🔔 → Icons.notifications_rounded
// 💳 → Icons.credit_card_rounded
// 📊 → Icons.analytics_rounded
// 🎯 → Icons.target_rounded
```

### 3. Using Custom Widgets

#### App Bars
```dart
import 'package:hipop/core/widgets/hipop_app_bar.dart';

// Standard app bar
Scaffold(
  appBar: HiPopAppBar(
    title: 'Vendor Dashboard',
    actions: [
      IconButton(
        icon: Icon(Icons.settings_rounded),
        onPressed: () {},
      ),
    ],
  ),
)

// Search app bar
Scaffold(
  appBar: HiPopSearchAppBar(
    hint: 'Search markets...',
    onChanged: (query) {
      // Handle search
    },
  ),
)
```

#### Cards
```dart
import 'package:hipop/core/widgets/hipop_card.dart';

// Basic card
HiPopCard(
  onTap: () {},
  child: Column(
    children: [
      Text('Card Content'),
    ],
  ),
)

// Market card with premium styling
MarketCard(
  marketName: 'Farmers Market',
  location: 'Downtown',
  schedule: 'Saturdays 9am-2pm',
  vendorCount: 25,
  rating: 4.5,
  isPremium: true,
  onTap: () {},
)
```

#### Buttons
```dart
import 'package:hipop/core/widgets/hipop_button.dart';

// Primary action button
HiPopButton.primary(
  text: 'Create Post',
  icon: Icons.add_rounded,
  onPressed: () {},
)

// Accent CTA button
HiPopButton.accent(
  text: 'Apply Now',
  onPressed: () {},
  fullWidth: true,
)

// Danger button
HiPopButton.danger(
  text: 'Delete',
  icon: Icons.delete_rounded,
  onPressed: () {},
)

// Icon button
HiPopIconButton(
  icon: Icons.favorite_rounded,
  onPressed: () {},
  color: HiPopColors.accentCoral,
)

// FAB
HiPopFAB(
  icon: Icons.add_rounded,
  onPressed: () {},
  label: 'New Post',
  extended: true,
)
```

### 4. Fix Text Contrast Issues

#### ❌ OLD - Poor contrast:
```dart
Container(
  color: Colors.white,
  child: Text(
    'Content',
    style: TextStyle(color: Colors.white), // White on white!
  ),
)
```

#### ✅ NEW - Proper contrast:
```dart
Container(
  color: Theme.of(context).colorScheme.surface,
  child: Text(
    'Content',
    style: Theme.of(context).textTheme.bodyMedium,
  ),
)
```

### 5. Responsive Styling

```dart
// Use theme text styles for consistency
Text(
  'Large Header',
  style: Theme.of(context).textTheme.headlineLarge,
)

Text(
  'Section Title',
  style: Theme.of(context).textTheme.titleMedium,
)

Text(
  'Body Content',
  style: Theme.of(context).textTheme.bodyMedium,
)

Text(
  'Caption',
  style: Theme.of(context).textTheme.bodySmall,
)
```

### 6. Dark Mode Support

The theme automatically supports dark mode. To check current theme:

```dart
final isDark = Theme.of(context).brightness == Brightness.dark;

Container(
  color: isDark ? HiPopColors.darkSurface : HiPopColors.lightSurface,
)
```

### 7. User Role-Specific Colors

```dart
// Access role-specific colors via theme extension
final vendorColor = Theme.of(context).vendorAccent;
final organizerColor = Theme.of(context).organizerAccent;
final shopperColor = Theme.of(context).shopperAccent;
final premiumColor = Theme.of(context).premiumColor;
```

## Migration Checklist

- [ ] Replace all `Colors.orange` with `Theme.of(context).colorScheme.primary`
- [ ] Replace all emojis with Material Icons
- [ ] Update AppBar widgets to use HiPopAppBar
- [ ] Update Card widgets to use HiPopCard
- [ ] Update Button widgets to use HiPopButton
- [ ] Fix all white-on-white text issues
- [ ] Remove hardcoded colors from widgets
- [ ] Test in both light and dark modes
- [ ] Verify WCAG contrast requirements

## Common Patterns

### List Tile with Icon
```dart
ListTile(
  leading: Container(
    padding: EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: HiPopColors.primaryForest.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(
      Icons.store_rounded,
      color: HiPopColors.primaryForest,
    ),
  ),
  title: Text('Market Name'),
  subtitle: Text('Location'),
  trailing: Icon(Icons.chevron_right_rounded),
  onTap: () {},
)
```

### Status Indicators
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: HiPopColors.successEmerald.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Icons.check_circle_rounded,
        size: 16,
        color: HiPopColors.successEmerald,
      ),
      SizedBox(width: 4),
      Text(
        'Active',
        style: TextStyle(
          color: HiPopColors.successEmerald,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  ),
)
```

### Form Fields
```dart
TextFormField(
  decoration: InputDecoration(
    labelText: 'Market Name',
    hintText: 'Enter market name',
    prefixIcon: Icon(Icons.store_rounded),
    // Theme handles the rest!
  ),
)
```

## Testing

Always test your UI in both light and dark modes:

```dart
// Toggle theme mode programmatically for testing
MaterialApp(
  themeMode: ThemeMode.light, // or ThemeMode.dark, ThemeMode.system
)
```