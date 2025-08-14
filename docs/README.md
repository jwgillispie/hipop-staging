# 📚 HiPop Documentation

## Quick Links
- [Premium Features Complete Guide](./PREMIUM_FEATURES_COMPLETE.md) - All premium features and implementation
- [Payment Setup Guide](./PAYMENT_SETUP_GUIDE.md) - Stripe payment integration and testing
- [Development Roadmap](./DEVELOPMENT_ROADMAP.md) - Future features and timeline

## Premium Implementation

### Core Documentation
- **[Premium Features Complete](./PREMIUM_FEATURES_COMPLETE.md)** ⭐
  - Comprehensive guide to all premium features
  - Subscription tiers and pricing
  - Implementation patterns
  - Testing procedures

- **[Payment Setup Guide](./PAYMENT_SETUP_GUIDE.md)**
  - Stripe integration details
  - Test card information
  - Production deployment steps

### Feature-Specific Guides
- **[Vendor Directory Feature](./vendor_directory_feature_plan.md)**
  - Market organizer vendor search
  - Implementation architecture
  - Premium gating details

- **[Post Limits Implementation](./POST_LIMITS_IMPLEMENTATION_SUMMARY.md)**
  - Free tier limitations
  - Visual feedback for limits
  - Upgrade prompts

## Historical/Archive Documentation
*These documents were created during development and are kept for reference:*

- [Premium Features Implementation Plan](./PREMIUM_FEATURES_IMPLEMENTATION_PLAN.md) - Original planning document
- [Organizer Premium MVP Implementation](./ORGANIZER_PREMIUM_MVP_IMPLEMENTATION_PLAN.md) - Initial MVP scope
- [Premium Implementation Phase 2](./PREMIUM_IMPLEMENTATION_PHASE2_GUIDE.md) - Phase 2 features
- [Vendor Premium Testing](./VENDOR_PREMIUM_TESTING.md) - Testing procedures
- [Market Connection Redesign](./MARKET_CONNECTION_REDESIGN_PLAN.md) - Connection system planning
- [Firebase Functions Config](./firebase-functions-config.md) - Cloud functions setup

## Quick Start for Testing

### Test Vendor Pro ($29/month)
1. Log in as vendor account
2. Try to create 4+ popup posts
3. Click upgrade when prompted
4. Use test card: `4242 4242 4242 4242`
5. Complete checkout
6. Access unlimited posts & analytics

### Test Market Organizer Pro ($69/month)
1. Log in as organizer account
2. Go to Vendor Directory
3. Click upgrade when prompted
4. Use test card: `4242 4242 4242 4242`
5. Complete checkout
6. Search and invite vendors

## Project Structure

```
hipop-staging/
├── docs/                    # All documentation
│   ├── README.md           # This file
│   ├── PREMIUM_FEATURES_COMPLETE.md
│   └── PAYMENT_SETUP_GUIDE.md
├── lib/features/
│   ├── premium/            # Premium feature implementation
│   ├── vendor/             # Vendor features
│   └── organizer/          # Organizer features
└── functions/              # Cloud functions for Stripe
```

## Key Collections in Firestore

- `user_subscriptions` - Active subscription data
- `user_profiles` - User account information
- `vendor_posts` - Vendor popup posts
- `organizer_vendor_posts` - "Looking for vendors" posts
- `vendor_directory_analytics` - Search analytics
- `usage_tracking` - Feature usage metrics

## Environment Variables

Required in `.env`:
```
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PRICE_VENDOR_PRO=price_...
STRIPE_PRICE_MARKET_ORGANIZER_PRO=price_...
ENVIRONMENT=staging
```

## Support & Troubleshooting

### Common Issues
- **Premium not unlocking**: Check `user_subscriptions` collection
- **Payment failing**: Verify Stripe keys in `.env`
- **Features not showing**: Check feature keys in `SubscriptionService`

### Logs & Monitoring
- Firebase Console → Functions → Logs
- Stripe Dashboard → Payments/Events
- Firestore → Data viewer

## Contact
For questions about the premium implementation, refer to the complete implementation guide or check the inline code documentation.