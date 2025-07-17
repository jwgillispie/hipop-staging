// Simple script to create a test event in Firestore
// Run this with: dart create_test_event.dart

import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  // Initialize Firestore (you'll need to configure this for your project)
  final firestore = FirebaseFirestore.instance;
  
  // Create a test event
  final testEvent = {
    'name': 'Test Farmers Market Event',
    'description': 'A test event to create the required Firestore fields',
    'location': 'Downtown Square',
    'address': '123 Main St',
    'city': 'Test City',
    'state': 'CA',
    'latitude': 37.7749,
    'longitude': -122.4194,
    'startDateTime': Timestamp.fromDate(DateTime.now().add(Duration(days: 1))),
    'endDateTime': Timestamp.fromDate(DateTime.now().add(Duration(days: 1, hours: 4))),
    'organizerId': 'test-organizer-id',
    'organizerName': 'Test Organizer',
    'marketId': null,
    'tags': ['farmers market', 'local', 'organic'],
    'imageUrl': null,
    'isActive': true,
    'createdAt': Timestamp.fromDate(DateTime.now()),
    'updatedAt': Timestamp.fromDate(DateTime.now()),
  };
  
  try {
    await firestore.collection('events').add(testEvent);
    print('✅ Test event created successfully!');
    print('Now the startDateTime and endDateTime fields exist in Firestore.');
    print('You can try creating the index again.');
  } catch (e) {
    print('❌ Error creating test event: $e');
  }
}