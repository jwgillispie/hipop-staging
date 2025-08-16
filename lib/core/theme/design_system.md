# HiPop Marketplace Design System

## Core Design Principles

### 1. Visual Hierarchy
- **Primary Actions**: Deep Sage (#558B6E) - CTAs, primary buttons
- **Secondary Actions**: Soft Sage (#6F9686) - Navigation, secondary buttons
- **Accent Elements**: Mauve (#946C7E) - Premium features, vendor-specific
- **Success States**: Deep Sage (#558B6E) - Checkmarks, success messages
- **Warning States**: Amber (#E8A87C) - Important notices
- **Error States**: Dusty Plum (#704C5E) - Error messages, destructive actions

### 2. Text Color Guidelines

#### On Light Backgrounds (White, Pale Pink, Soft Pink)
- **Primary Text**: lightTextPrimary (#2A2527) - Headlines, body text
- **Secondary Text**: lightTextSecondary (#5C5458) - Descriptions, subtitles
- **Tertiary Text**: lightTextTertiary (#8B8289) - Hints, metadata
- **Disabled Text**: lightTextDisabled (#B8B0B6) - Inactive elements

#### On Dark Backgrounds (Deep Sage, Mauve, Dark surfaces)
- **Primary Text**: White or darkTextPrimary (#F8F4F6)
- **Secondary Text**: White with 70% opacity or darkTextSecondary (#D6CED3)

### 3. Background Colors
- **Primary Background**: lightBackground (#FAFBFC)
- **Card Surfaces**: lightSurface (Pale Pink #F3D2E1)
- **Elevated Surfaces**: lightSurfaceVariant (Soft Pink #F1C8DB)
- **Muted Sections**: backgroundMutedGray (#88A09E) at 10% opacity

## Component-Specific Guidelines

### Market Discovery Screen
```dart
// Background
backgroundColor: HiPopColors.lightBackground

// Premium indicators
Icon: Icons.diamond
Color: HiPopColors.accentMauve (#946C7E)
Background: accentMauve with 20% opacity

// Success indicators (checkmarks, recruiting)
Icon: Icons.check_circle
Color: HiPopColors.successGreen (#558B6E)

// Filter chips
Selected: primaryDeepSage with 20% opacity
Unselected: lightSurface with lightBorder

// Action buttons
Primary: primaryDeepSage background, white text
Secondary: primaryDeepSage outline and text
```

### Premium Onboarding
```dart
// Backgrounds
Main: surfacePalePink with 30% opacity
Cards: lightSurface or white

// Text on pink backgrounds
ALWAYS use lightTextPrimary/Secondary, NEVER darkText variants

// Feature cards
Selected: primaryDeepSage with 5% opacity background
Border: 2px primaryDeepSage when selected

// CTAs
Gradient: primaryDeepSage to secondarySoftSage
Shadow: primaryDeepSage at 30% opacity
```

### Universal Premium Elements
```dart
// Premium badge
Container(
  padding: EdgeInsets.all(6),
  decoration: BoxDecoration(
    color: HiPopColors.accentMauve.withValues(alpha: 0.2),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Icon(
    Icons.diamond,
    color: HiPopColors.accentMauve,
    size: 20,
  ),
)

// Success checkmarks
Icon(
  Icons.check_circle,
  color: HiPopColors.successGreen,
  size: 20,
)

// Warning badges
Container(
  color: HiPopColors.warningAmber,
  child: Text('RECOMMENDED', style: white text),
)
```

## Accessibility Requirements

### Color Contrast Ratios
- Normal text on light backgrounds: 4.5:1 minimum
- Large text on light backgrounds: 3:1 minimum
- Interactive elements: 3:1 minimum
- Use HiPopColors.meetsContrastGuidelines() to verify

### Text Sizes
- Headlines: 24-32px (Poppins)
- Body text: 14-16px (Inter)
- Captions: 12px (Inter)
- Buttons: 16px (Poppins, 600 weight)

## Implementation Checklist

### When Creating New Screens
1. ✅ Set scaffold backgroundColor to HiPopColors.lightBackground
2. ✅ Use lightSurface for cards and containers
3. ✅ Apply lightTextPrimary/Secondary for text on light backgrounds
4. ✅ Use primaryDeepSage for primary CTAs
5. ✅ Use accentMauve for vendor/premium elements
6. ✅ Apply successGreen for positive feedback
7. ✅ Test text visibility on all background colors
8. ✅ Verify color contrast ratios meet WCAG AA standards

### Common Mistakes to Avoid
❌ Using darkTextPrimary/Secondary on light backgrounds
❌ Using amber for premium indicators (use Mauve instead)
❌ Using generic green for success (use Deep Sage)
❌ Hard-coding colors instead of using HiPopColors
❌ Inconsistent spacing and border radius

## Migration Guide

### Old Pattern → New Pattern
```dart
// OLD
color: Colors.amber[700] → color: HiPopColors.accentMauve
color: Colors.green[600] → color: HiPopColors.successGreen
color: Colors.orange → color: HiPopColors.primaryDeepSage
backgroundColor: Colors.white → backgroundColor: HiPopColors.lightSurface
backgroundColor: Colors.grey[50] → backgroundColor: HiPopColors.lightBackground

// Text colors
color: HiPopColors.darkTextPrimary (on light bg) → color: HiPopColors.lightTextPrimary
color: HiPopColors.darkTextSecondary (on light bg) → color: HiPopColors.lightTextSecondary
```

## Usage Examples

### Import Required Files
```dart
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/core/widgets/premium_ui_components.dart';
```

### Using Premium Components
```dart
// Premium badge
PremiumUIComponents.premiumBadge(size: 24)

// Feature check item
PremiumUIComponents.featureCheckItem(
  text: 'Advanced analytics',
)

// Premium CTA button
PremiumUIComponents.premiumCTAButton(
  text: 'Upgrade to Premium',
  icon: Icons.diamond,
  onPressed: () {},
)

// Tier selection card
PremiumUIComponents.tierSelectionCard(
  title: 'Vendor Pro',
  price: '\$29',
  description: 'Perfect for growing vendors',
  features: [...],
  isSelected: true,
  isRecommended: true,
  onTap: () {},
)
```