import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';

class EventService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'events';


  /// Get all active events
  static Stream<List<Event>> getAllActiveEventsStream() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .where('endDateTime', isGreaterThan: DateTime.now())
        .orderBy('endDateTime')
        .orderBy('startDateTime')
        .snapshots()
        .handleError((error) {
          print('❌ FIRESTORE INDEX ERROR - getAllActiveEventsStream:');
          print('Query: events where isActive == true AND endDateTime > now, orderBy endDateTime, startDateTime');
          print('Error: $error');
          print('🔗 CREATE INDEX AT: https://console.firebase.google.com/project/hipop-markets-staging/firestore/indexes');
          print('');
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => Event.fromFirestore(doc))
            .toList());
  }

  /// Get events by city
  static Stream<List<Event>> getEventsByCityStream(String city) {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .where('city', isEqualTo: city)
        .where('endDateTime', isGreaterThan: DateTime.now())
        .orderBy('endDateTime')
        .orderBy('startDateTime')
        .snapshots()
        .handleError((error) {
          print('❌ FIRESTORE INDEX ERROR - getEventsByCityStream:');
          print('Query: events where isActive == true AND city == "$city" AND endDateTime > now, orderBy endDateTime, startDateTime');
          print('Error: $error');
          print('🔗 CREATE INDEX AT: https://console.firebase.google.com/project/hipop-markets-staging/firestore/indexes');
          print('');
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => Event.fromFirestore(doc))
            .toList());
  }

  /// Get events by location search
  static Stream<List<Event>> searchEventsByLocation(String location) {
    // For now, search by city - could be enhanced with more sophisticated search
    return getEventsByCityStream(location);
  }

  /// Get a specific event by ID
  static Future<Event?> getEvent(String eventId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(eventId).get();
      if (doc.exists) {
        return Event.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Error getting event: $e');
    }
  }

  /// Create a new event
  static Future<String> createEvent(Event event) async {
    try {
      final docRef = await _firestore.collection(_collection).add(event.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Error creating event: $e');
    }
  }

  /// Update an existing event
  static Future<void> updateEvent(String eventId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.fromDate(DateTime.now());
      await _firestore.collection(_collection).doc(eventId).update(updates);
    } catch (e) {
      throw Exception('Error updating event: $e');
    }
  }

  /// Delete an event
  static Future<void> deleteEvent(String eventId) async {
    try {
      await _firestore.collection(_collection).doc(eventId).delete();
    } catch (e) {
      throw Exception('Error deleting event: $e');
    }
  }

  /// Get current and upcoming events
  static Stream<List<Event>> getCurrentAndUpcomingEventsStream() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .where('endDateTime', isGreaterThan: DateTime.now())
        .orderBy('endDateTime')
        .orderBy('startDateTime')
        .snapshots()
        .handleError((error) {
          print('❌ FIRESTORE INDEX ERROR - getCurrentAndUpcomingEventsStream:');
          print('Query: events where isActive == true AND endDateTime > now, orderBy endDateTime, startDateTime');
          print('Error: $error');
          print('🔗 CREATE INDEX AT: https://console.firebase.google.com/project/hipop-markets-staging/firestore/indexes');
          print('');
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => Event.fromFirestore(doc))
            .toList());
  }

  /// Get events for a specific market
  static Stream<List<Event>> getEventsForMarketStream(String marketId) {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .where('marketId', isEqualTo: marketId)
        .where('endDateTime', isGreaterThan: DateTime.now())
        .orderBy('endDateTime')
        .orderBy('startDateTime')
        .snapshots()
        .handleError((error) {
          print('❌ FIRESTORE INDEX ERROR - getEventsForMarketStream:');
          print('Query: events where isActive == true AND marketId == "$marketId" AND endDateTime > now, orderBy endDateTime, startDateTime');
          print('Error: $error');
          print('🔗 CREATE INDEX AT: https://console.firebase.google.com/project/hipop-markets-staging/firestore/indexes');
          print('');
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => Event.fromFirestore(doc))
            .toList());
  }

  /// Get events organized by a specific organizer
  static Stream<List<Event>> getEventsByOrganizerStream(String organizerId) {
    return _firestore
        .collection(_collection)
        .where('organizerId', isEqualTo: organizerId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Event.fromFirestore(doc))
            .toList());
  }

  /// Filter events that are currently active or upcoming
  static List<Event> filterCurrentAndUpcomingEvents(List<Event> events) {
    final now = DateTime.now();
    return events.where((event) => event.endDateTime.isAfter(now)).toList();
  }

  /// Search events by name or description
  static Stream<List<Event>> searchEventsByText(String searchText) {
    if (searchText.isEmpty) {
      return getAllActiveEventsStream();
    }
    
    // Note: Firestore doesn't have full-text search, so this is a basic implementation
    // For production, consider using Algolia or similar search service
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .where('endDateTime', isGreaterThan: DateTime.now())
        .orderBy('endDateTime')
        .orderBy('startDateTime')
        .snapshots()
        .handleError((error) {
          print('❌ FIRESTORE INDEX ERROR - searchEventsByText:');
          print('Query: events where isActive == true AND endDateTime > now, orderBy endDateTime, startDateTime');
          print('Error: $error');
          print('🔗 CREATE INDEX AT: https://console.firebase.google.com/project/hipop-markets-staging/firestore/indexes');
          print('');
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => Event.fromFirestore(doc))
            .where((event) => 
                event.name.toLowerCase().contains(searchText.toLowerCase()) ||
                event.description.toLowerCase().contains(searchText.toLowerCase()) ||
                event.location.toLowerCase().contains(searchText.toLowerCase()))
            .toList());
  }
}