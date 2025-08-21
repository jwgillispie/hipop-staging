import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PlacesService {
  // Firebase Function proxy URL (solves CORS issues)
  static const String _firebaseFunctionUrl = 'https://us-central1-hipop-markets-staging.cloudfunctions.net/placesProxy';
  // Original staging server URL (kept as fallback)
  static const String _stagingApiUrl = 'https://hipop-places-server-788332607491.us-central1.run.app/api/places';

  static String get _baseUrl {
    if (kIsWeb) {
      // For web builds, use Firebase Function proxy to avoid CORS issues
      const proxyUrl = String.fromEnvironment('PLACES_API_URL', defaultValue: _firebaseFunctionUrl);
      return proxyUrl;
    }
    // For mobile development, can use staging server directly (no CORS issues)
    return _stagingApiUrl;
  }

  static Future<List<PlacePrediction>> getPlacePredictions(String input) async {
    if (input.length < 3) {
      return [];
    }

    try {
      final url = kIsWeb 
        ? '$_baseUrl/api/places/autocomplete?input=${Uri.encodeComponent(input)}'
        : '$_baseUrl/autocomplete?input=${Uri.encodeComponent(input)}';
      
      final response = await http.get(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final predictions = data['predictions'] as List? ?? [];
        
        return predictions
            .map((prediction) => PlacePrediction.fromServerJson(prediction))
            .toList();
      } else {
        debugPrint('Places API returned status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting place predictions: $e');
    }
    
    return [];
  }

  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    try {
      final url = kIsWeb 
        ? '$_baseUrl/api/places/details?place_id=$placeId'
        : '$_baseUrl/details?place_id=$placeId';
      
      final response = await http.get(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['result'];
        
        if (result != null) {
          return PlaceDetails.fromServerJson(result);
        }
      } else {
        debugPrint('Place details API returned status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting place details: $e');
    }
    
    return null;
  }

}

class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlacePrediction.fromServerJson(Map<String, dynamic> json) {
    return PlacePrediction(
      placeId: json['place_id'],
      description: json['description'],
      mainText: json['structured_formatting']['main_text'],
      secondaryText: json['structured_formatting']['secondary_text'] ?? '',
    );
  }

  factory PlacePrediction.fromWebJson(Map<String, dynamic> json) {
    return PlacePrediction(
      placeId: json['place_id'],
      description: json['description'],
      mainText: json['structured_formatting']['main_text'],
      secondaryText: json['structured_formatting']['secondary_text'] ?? '',
    );
  }
}

class PlaceDetails {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;

  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
  });

  factory PlaceDetails.fromServerJson(Map<String, dynamic> json) {
    final geometry = json['geometry']['location'];
    return PlaceDetails(
      placeId: json['place_id'],
      name: json['name'] ?? json['formatted_address'],
      formattedAddress: json['formatted_address'],
      latitude: geometry['lat'].toDouble(),
      longitude: geometry['lng'].toDouble(),
    );
  }

  factory PlaceDetails.fromWebJson(Map<String, dynamic> json) {
    final geometry = json['geometry']['location'];
    return PlaceDetails(
      placeId: json['place_id'],
      name: json['name'] ?? json['formatted_address'],
      formattedAddress: json['formatted_address'],
      latitude: geometry['lat'].toDouble(),
      longitude: geometry['lng'].toDouble(),
    );
  }
}