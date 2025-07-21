# HiPop Staging to Production Workflow Guide

## Initial Setup (One Time Only)

### 1. Connect Your Repos
```bash
# In your production repo
cd /Users/jordangillispie/development/hipop/hipop/hipop
git remote add staging /Users/jordangillispie/development/hipop/hipop/hipop-staging
# OR if using the GitHub URL
git remote add staging https://github.com/jwgillispie/hipop-staging.git

# Verify it worked
git remote -v
```

### 2. Protect Your Firebase Configs
Add these to `.gitignore` in BOTH repos:
```gitignore
# Firebase configs - NEVER commit these between environments
ios/Runner/GoogleService-Info.plist
lib/firebase_options.dart
.firebaserc
firebase.json

# Environment files
.env
```

### 3. Handle Staging Flags
Your staging has these flags that need to be different in production:

**In `lib/main.dart` staging has:**
```dart
title: 'HiPop - STAGING',
// ...
Banner(
  message: 'STAGING',
  location: BannerLocation.topStart,
  color: Colors.pink,
  // ...
)
```

**Production should have:**
```dart
title: 'HiPop',
// No banner widget - just return child directly
```

## Daily Workflow

### Making Changes in Staging
```bash
cd /Users/jordangillispie/development/hipop/hipop/hipop-staging
# Make your changes
git add .
git commit -m "Add: vendor market permissions feature"
git push origin main
```

### Moving Changes to Production

#### Option 1: Cherry-Pick Specific Commits (RECOMMENDED)
```bash
# 1. Go to production repo
cd /Users/jordangillispie/development/hipop/hipop/hipop

# 2. See what's new in staging
git fetch staging
git log --oneline HEAD..staging/main

# 3. Pick specific commits you want
git cherry-pick abc123  # Replace with actual commit hash

# 4. Fix staging flags manually in main.dart
# Change title to 'HiPop' and remove Banner widget

# 5. Commit the staging flag fix
git add lib/main.dart
git commit -m "Fix: remove staging flags for production"

# 6. Push to production
git push origin main
```

#### Option 2: Merge Everything (BE CAREFUL)
```bash
# 1. Go to production repo
cd /Users/jordangillispie/development/hipop/hipop/hipop

# 2. Fetch and merge but DON'T COMMIT YET
git fetch staging
git merge staging/main --no-commit --no-ff

# 3. CHECK WHAT'S BEING MERGED
git status

# 4. REMOVE Firebase configs that got included
git reset HEAD ios/Runner/GoogleService-Info.plist
git reset HEAD lib/firebase_options.dart
git reset HEAD .firebaserc
git reset HEAD firebase.json

# 5. Fix staging flags in main.dart
# Edit the file to change title and remove Banner

# 6. Review changes one more time
git diff --cached

# 7. Commit if everything looks good
git commit -m "Deploy: features from staging"

# 8. Push to production
git push origin main
```

## Pre-Deployment Checklist

Before moving code to production, verify:

- [ ] All features tested in staging
- [ ] No debug widgets (DebugAccountSwitcher, DebugDatabaseCleaner, etc.)
- [ ] Staging banner removed from main.dart
- [ ] App title is 'HiPop' not 'HiPop - STAGING'
- [ ] Firebase configs NOT included in merge
- [ ] Android/iOS platform configs preserved (different app IDs)

## Quick Reference Commands

```bash
# See what's different between staging and production
cd /Users/jordangillispie/development/hipop/hipop/hipop
git fetch staging
git diff HEAD..staging/main --name-only

# See commits in staging but not in production
git log --oneline HEAD..staging/main

# Check which Firebase project you're using
grep "projectId" .firebaserc
grep "hipop-markets" lib/firebase_options.dart
```

## Emergency Fixes

If you accidentally merge staging Firebase configs:
```bash
# 1. DON'T PUSH YET!

# 2. Check what the production configs should be
# Production should have: hipop-markets (not hipop-markets-staging)

# 3. Reset the problematic files
git reset HEAD ios/Runner/GoogleService-Info.plist
git reset HEAD lib/firebase_options.dart
git reset HEAD .firebaserc
git reset HEAD firebase.json

# 4. They'll revert to production versions
# 5. Commit without the wrong configs
git commit -m "Deploy: changes from staging"
```

## File Structure Reference

```
Files that should be DIFFERENT between environments:
├── lib/
│   ├── firebase_options.dart (hipop-markets vs hipop-markets-staging)
│   └── main.dart (title and banner differences)
├── ios/Runner/
│   └── GoogleService-Info.plist (different project IDs)
├── android/app/
│   └── build.gradle.kts (different applicationId)
├── .firebaserc (different project names)
└── firebase.json (different project IDs)

Files that should be THE SAME (via merging):
├── lib/
│   ├── screens/ (all your app screens)
│   ├── widgets/ (all your components)
│   ├── services/ (all your services)
│   ├── models/ (all your models)
│   └── blocs/ (all your state management)
├── assets/ (images, etc.)
└── VENDOR_MARKET_PLANNING.md (documentation)
```

## Tips

1. **Always fetch before merging**: `git fetch staging`
2. **Use --no-commit on merges**: Gives you a chance to review
3. **Check main.dart after every merge**: Remove staging flags
4. **Your repo paths**:
   - Staging: `/Users/jordangillispie/development/hipop/hipop/hipop-staging`
   - Production: `/Users/jordangillispie/development/hipop/hipop/hipop`

## Common Issues

**"Wrong Firebase project" error**
- You merged staging Firebase configs
- Check `.firebaserc` - should say `hipop-markets` not `hipop-markets-staging`

**App shows "STAGING" banner in production**
- Edit `lib/main.dart` and remove the Banner widget
- Change title from 'HiPop - STAGING' to 'HiPop'

**Build fails after merge**
- Run `flutter clean && flutter pub get`
- Check if you accidentally merged different app IDs

This workflow is tailored specifically for your hipop project setup and should handle the main differences between your staging and production environments.