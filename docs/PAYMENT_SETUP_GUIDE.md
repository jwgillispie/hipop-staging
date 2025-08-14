# 💳 Stripe Payment Setup Guide

## Overview
The payment system is now fully integrated with Stripe Checkout for real payments. Users can subscribe to Vendor Pro ($29/month) or Market Organizer Pro ($69/month) using their credit cards.

## Current Setup

### 1. **Test Mode Configuration**
- Currently using Stripe TEST keys (safe for testing with test cards)
- Keys are configured in `.env` file
- Test mode allows using test cards without real charges

### 2. **Test Cards for Testing**
Use these Stripe test cards to test the payment flow:

- ✅ **Success**: `4242 4242 4242 4242`
- ❌ **Decline**: `4000 0000 0000 0002`
- 🔐 **3D Secure**: `4000 0025 0000 3155`
- 📅 **Any future expiry date** (e.g., 12/34)
- 🔢 **Any 3-digit CVC** (e.g., 123)
- 📮 **Any ZIP code** (e.g., 12345)

### 3. **Payment Flow**

1. User selects premium tier (Vendor Pro or Market Organizer Pro)
2. Clicks "Subscribe Now" button
3. Redirected to Stripe Checkout (secure hosted page)
4. Enters payment information
5. Stripe processes payment
6. User redirected back to app
7. App polls for subscription status
8. Premium features unlocked upon success

## Testing Instructions

### For Vendor Pro ($29/month):
1. Log in as a vendor account
2. Navigate to any premium-gated feature
3. Click "Upgrade to Vendor Pro"
4. Select plan and click "Subscribe Now"
5. Enter test card: `4242 4242 4242 4242`
6. Complete checkout
7. Verify premium features are unlocked

### For Market Organizer Pro ($69/month):
1. Log in as a market organizer account
2. Navigate to any premium-gated feature (e.g., Vendor Directory)
3. Click "Upgrade to Market Organizer Pro"
4. Select plan and click "Subscribe Now"
5. Enter test card: `4242 4242 4242 4242`
6. Complete checkout
7. Verify premium features are unlocked (Vendor Directory, etc.)

## Going Live (Production)

To enable real payments:

1. **Get Production Stripe Keys**:
   - Log into Stripe Dashboard
   - Switch to "Live" mode
   - Copy production keys

2. **Update `.env` file**:
   ```env
   STRIPE_PUBLISHABLE_KEY=pk_live_YOUR_LIVE_KEY
   STRIPE_SECRET_KEY=sk_live_YOUR_LIVE_KEY
   ENVIRONMENT=production
   ```

3. **Update Cloud Functions**:
   ```bash
   firebase functions:config:set stripe.secret_key="sk_live_YOUR_LIVE_KEY"
   firebase deploy --only functions
   ```

4. **Set up Webhooks**:
   - In Stripe Dashboard, add webhook endpoint
   - Point to: `https://YOUR_DOMAIN/stripe-webhook`
   - Copy webhook secret to `.env`

## Features Unlocked by Premium

### Vendor Pro ($29/month):
- ✅ Unlimited popup posts
- ✅ Advanced analytics dashboard
- ✅ Sales tracking
- ✅ Customer insights
- ✅ Priority market applications

### Market Organizer Pro ($69/month):
- ✅ Vendor Directory (search & filter all vendors)
- ✅ Unlimited vendor recruitment posts
- ✅ Vendor performance analytics
- ✅ Multi-market management
- ✅ Financial reporting
- ✅ Bulk vendor invitations

## Troubleshooting

### Payment Not Processing?
1. Check browser console for errors
2. Verify Stripe keys in `.env`
3. Ensure Cloud Functions are deployed
4. Check Firebase Functions logs

### Premium Not Unlocking?
1. Check Firestore `user_subscriptions` collection
2. Verify subscription status is "active"
3. Check subscription tier matches expected
4. Clear app cache and reload

### Need Help?
- Stripe Test Mode Docs: https://stripe.com/docs/testing
- Stripe Checkout: https://stripe.com/docs/payments/checkout
- Firebase Functions: https://firebase.google.com/docs/functions

## Security Notes
- ✅ Payment processing handled entirely by Stripe (PCI compliant)
- ✅ No credit card data stored in our database
- ✅ Subscription status verified server-side
- ✅ Premium features protected by server-side checks