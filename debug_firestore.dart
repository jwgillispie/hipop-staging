import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/firebase_options.dart';

Future<void> main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  print('🔥 Firebase initialized');
  
  // Check auth state
  final auth = FirebaseAuth.instance;
  final user = auth.currentUser;
  
  print('👤 Current user: ${user?.uid}');
  print('📧 User email: ${user?.email}');
  print('🔐 User authenticated: ${user != null}');
  
  if (user == null) {
    print('❌ No user is logged in - this might be causing permission errors');
    return;
  }
  
  // Test Firestore queries
  final firestore = FirebaseFirestore.instance;
  
  // Test 1: Try to read user profile
  print('\n🧪 Testing user profile read...');
  try {
    final userProfileDoc = await firestore
        .collection('user_profiles')
        .doc(user.uid)
        .get();
    
    print('✅ User profile read successful');
    print('📄 Profile exists: ${userProfileDoc.exists}');
    if (userProfileDoc.exists) {
      print('📄 Profile data: ${userProfileDoc.data()}');
    }
  } catch (e) {
    print('❌ User profile read failed: $e');
  }
  
  // Test 2: Try to read events
  print('\n🧪 Testing events read...');
  try {
    final eventsSnapshot = await firestore
        .collection('events')
        .where('isActive', isEqualTo: true)
        .limit(5)
        .get();
    
    print('✅ Events read successful');
    print('📄 Found ${eventsSnapshot.docs.length} events');
  } catch (e) {
    print('❌ Events read failed: $e');
  }
  
  // Test 3: Try events with time filter
  print('\n🧪 Testing events with time filter...');
  try {
    final eventsSnapshot = await firestore
        .collection('events')
        .where('isActive', isEqualTo: true)
        .where('endDateTime', isGreaterThan: DateTime.now())
        .limit(5)
        .get();
    
    print('✅ Events with time filter read successful');
    print('📄 Found ${eventsSnapshot.docs.length} events');
  } catch (e) {
    print('❌ Events with time filter read failed: $e');
  }
  
  // Test 4: Check if we can read other users' profiles
  print('\n🧪 Testing read permissions for other profiles...');
  try {
    final profilesSnapshot = await firestore
        .collection('user_profiles')
        .limit(3)
        .get();
    
    print('✅ Other profiles read successful');
    print('📄 Found ${profilesSnapshot.docs.length} profiles');
  } catch (e) {
    print('❌ Other profiles read failed: $e');
  }
}