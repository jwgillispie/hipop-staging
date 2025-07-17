# HiPop Markets

**Connecting communities with local farmers markets, artisan markets, and local vendors.**

HiPop Markets is a comprehensive platform that brings together shoppers, vendors, and market organizers to strengthen local food systems and artisan communities. The platform consists of a Flutter mobile app and a Next.js marketing website.

## 🌟 Features

### For Shoppers
- **Smart Market Discovery**: Find farmers markets, artisan markets, and craft fairs nearby
- **Vendor & Product Search**: Search for specific vendors, products, or crafts
- **Favorites System**: Save favorite markets, vendors, and products
- **Smart Notifications**: Get alerts about market updates and new vendor collections
- **Calendar Integration**: Never miss your favorite market days

### For Vendors
- **Vendor Dashboard**: Manage your market presence and product listings
- **Analytics**: Track customer engagement and sales performance  
- **Market Applications**: Apply to new markets directly through the platform
- **Post Management**: Share updates, new products, and market schedules
- **Customer Connection**: Build relationships with regular customers

### For Market Organizers
- **Organizer Dashboard**: Comprehensive market management tools
- **Vendor Management**: Handle vendor applications and approvals
- **Analytics & Insights**: Real-time market performance data
- **Calendar Management**: Schedule and coordinate market events
- **Market Promotion**: Tools to attract shoppers and grow your market

## 🏗️ Project Structure

### Mobile App (`/hipop/`)
- **Framework**: Flutter
- **Language**: Dart
- **State Management**: BLoC pattern
- **Backend**: Firebase (Firestore, Auth, Storage, Remote Config)
- **Maps**: Google Maps integration
- **Authentication**: Firebase Auth with Google Sign-In

### Marketing Website (`/hipop-website/`)
- **Framework**: Next.js 15
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **Deployment**: Firebase Hosting
- **SEO**: Comprehensive optimization with sitemap, structured data
- **URL**: https://hipop-markets-website.web.app

## 🚀 Getting Started

### Mobile App Development

#### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK
- Firebase CLI
- iOS: Xcode and iOS Simulator
- Android: Android Studio and Android SDK

#### Setup
1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd hipop/hipop
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Configuration**
   - The app uses Firebase for backend services
   - Configuration files are already included:
     - `firebase_options.dart` - Auto-generated Firebase config
     - `GoogleService-Info.plist` (iOS)
     - `google-services.json` (Android - if needed)

4. **Run the app**
   ```bash
   # iOS
   flutter run -d ios
   
   # Android
   flutter run -d android
   
   # Web (for testing)
   flutter run -d web
   ```

#### Key Directories
- `lib/screens/` - UI screens for different user types
- `lib/services/` - Business logic and Firebase integrations
- `lib/models/` - Data models
- `lib/blocs/` - State management (BLoC pattern)
- `lib/widgets/` - Reusable UI components

### Website Development

#### Prerequisites
- Node.js 18+ and npm
- Firebase CLI (for deployment)

#### Setup
1. **Navigate to website directory**
   ```bash
   cd hipop-website
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Environment Configuration**
   Create `.env.local` with Firebase configuration:
   ```env
   # Main app Firebase config
   NEXT_PUBLIC_FIREBASE_API_KEY=your_api_key
   NEXT_PUBLIC_FIREBASE_PROJECT_ID=hipop-markets
   # ... other Firebase config values
   
   # Website Firebase config  
   NEXT_PUBLIC_WEBSITE_FIREBASE_PROJECT_ID=hipop-markets-website
   # ... other website Firebase config values
   ```

4. **Development server**
   ```bash
   npm run dev
   ```
   Visit `http://localhost:3000`

5. **Build and deploy**
   ```bash
   # Build static site
   npm run build
   
   # Deploy to Firebase Hosting
   firebase deploy --only hosting
   ```

#### Website Features
- **SEO Optimized**: Comprehensive meta tags, sitemap, structured data
- **Responsive Design**: Mobile-first design with Tailwind CSS
- **Static Site Generation**: Optimized for performance and SEO
- **Multi-page Structure**: Home, About, Shoppers, Vendors, Markets pages

## 🔧 Technical Architecture

### Mobile App Tech Stack
- **Frontend**: Flutter with Material Design
- **State Management**: BLoC (Business Logic Component)
- **Database**: Cloud Firestore
- **Authentication**: Firebase Auth
- **File Storage**: Firebase Storage  
- **Push Notifications**: Firebase Cloud Messaging (planned)
- **Maps**: Google Maps Flutter plugin
- **Analytics**: Firebase Analytics

### Backend Services (Firebase)
- **Firestore Collections**:
  - `markets` - Market information and schedules
  - `vendors` - Vendor profiles and products
  - `users` - User profiles and preferences
  - `favorites` - User favorites system
  - `vendor_applications` - Market application management
  - `vendor_posts` - Vendor updates and announcements

### Website Tech Stack
- **Framework**: Next.js 15 with App Router
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **Icons**: Heroicons
- **Deployment**: Firebase Hosting
- **SEO**: Built-in Next.js SEO features + custom optimization

## 🧪 Testing

### Mobile App Testing
```bash
# Run unit tests
flutter test

# Run integration tests (if available)
flutter test integration_test/
```

### Website Testing
```bash
# Run type checking
npm run type-check

# Run linting
npm run lint

# Build test
npm run build
```

## 📱 App Store Deployment

### iOS Deployment
1. Update version in `pubspec.yaml`
2. Build iOS app: `flutter build ios --release`
3. Open `ios/Runner.xcworkspace` in Xcode
4. Archive and upload to App Store Connect

### Android Deployment
1. Update version in `pubspec.yaml`
2. Build Android app: `flutter build apk --release`
3. Upload to Google Play Console

## 🌐 Website Deployment

The website is automatically deployed to Firebase Hosting:
- **Production URL**: https://hipop-markets-website.web.app
- **Deploy command**: `firebase deploy --only hosting`

## 📊 Analytics & Monitoring

### Mobile App Analytics
- Firebase Analytics for user behavior tracking
- Crashlytics for crash reporting (when implemented)
- Performance monitoring for app performance

### Website Analytics
- SEO monitoring through Google Search Console
- Performance monitoring through Core Web Vitals
- Firebase Analytics integration (when implemented)

## 🔐 Security & Privacy

### Data Protection
- User authentication through Firebase Auth
- Secure data storage in Firestore with security rules
- Privacy-compliant data handling

### API Security
- Firebase security rules for data access control
- Authenticated API calls only
- Input validation and sanitization

## 🤝 Contributing

### Development Workflow
1. Create feature branch from `main`
2. Implement changes with proper testing
3. Ensure code follows project conventions
4. Submit pull request with clear description

### Code Style
- **Flutter**: Follow Dart style guide and use `flutter format`
- **Website**: ESLint configuration with TypeScript support
- **Commits**: Use conventional commit messages

## 📞 Support & Contact

For technical issues or questions about the HiPop Markets platform:
- Check existing documentation
- Review Firebase console for backend issues
- Test on multiple devices for mobile app issues

## 🗺️ Roadmap

### Upcoming Features
- Push notifications for market updates
- In-app messaging between shoppers and vendors
- Advanced search filters and recommendations
- Vendor inventory management tools
- Market event calendar integration
- Social features and community building

### Performance Improvements
- App performance optimization
- Website Core Web Vitals enhancement
- Database query optimization
- Image loading and caching improvements

---

**HiPop Markets** - *Strengthening local communities through technology* 🌱🏪✨
