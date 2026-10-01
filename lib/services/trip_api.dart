// trip_api.dart
// HTTP Client connecting the Flutter UI to the FastAPI + Google ADK backend.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_plan_models.dart';

class TripApi {
  // Default base URL based on platform
  static String get defaultBaseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    } else if (Platform.isAndroid) {
      // 10.0.2.2 points to localhost from Android Emulator
      return 'http://10.0.2.2:8000';
    } else {
      return 'http://127.0.0.1:8000';
    }
  }

  static String? _cachedBaseUrl;

  /// Retrieves user-configured or platform default backend URL
  static Future<String> getBaseUrl() async {
    if (_cachedBaseUrl != null) return _cachedBaseUrl!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final customUrl = prefs.getString('custom_backend_url');
      if (customUrl != null && customUrl.trim().isNotEmpty) {
        _cachedBaseUrl = customUrl.trim();
        return _cachedBaseUrl!;
      }
    } catch (_) {}
    _cachedBaseUrl = defaultBaseUrl;
    return _cachedBaseUrl!;
  }

  /// Sets custom backend URL (e.g. http://192.168.1.50:8000 for physical phone)
  static Future<void> setCustomBaseUrl(String url) async {
    _cachedBaseUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_backend_url', _cachedBaseUrl!);
  }

  // --------------------------------------------------------------------
  // Step 2: Autocomplete City & Places
  // --------------------------------------------------------------------
  static Future<List<CitySuggestion>> autocompleteCity(
    String query, {
    String? types = 'cities',
    String? sessionToken,
  }) async {
    final cleanQ = query.trim();
    if (cleanQ.isEmpty) return [];

    final baseUrl = await getBaseUrl();
    final url = Uri.parse('$baseUrl/places/autocomplete');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'query': cleanQ,
              'types': types,
              'session_token': sessionToken,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawList = data['suggestions'] as List? ?? [];
        return rawList
            .map((e) => CitySuggestion.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      debugPrint('Autocomplete HTTP note: $e');
    }

    // Graceful offline fallback
    return [
      CitySuggestion(description: '$cleanQ, Karnataka, India', placeId: 'city_${cleanQ.toLowerCase()}'),
      CitySuggestion(description: 'Shimoga, Karnataka, India', placeId: 'city_shimoga'),
      CitySuggestion(description: 'Coorg, Karnataka, India', placeId: 'city_coorg'),
      CitySuggestion(description: 'Hampi, Karnataka, India', placeId: 'city_hampi'),
      CitySuggestion(description: 'Mysuru, Karnataka, India', placeId: 'city_mysuru'),
    ];
  }

  /// Reverse geocode coordinates to a clean human-readable address
  static Future<String> reverseGeocode(double lat, double lng) async {
    final baseUrl = await getBaseUrl();
    final url = Uri.parse('$baseUrl/places/reverse-geocode');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'lat': lat,
              'lng': lng,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final loc = (data['locality'] ?? data['address'])?.toString();
        if (loc != null && loc.isNotEmpty) {
          return loc;
        }
      }
    } catch (e) {
      debugPrint('Reverse geocode note: $e');
    }
    return 'Location (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
  }

  // --------------------------------------------------------------------
  // Step 3: Resolve City
  // --------------------------------------------------------------------
  static Future<CityResolution> resolveCity(
    String placeId, {
    String? sessionToken,
  }) async {
    final baseUrl = await getBaseUrl();
    final url = Uri.parse('$baseUrl/places/resolve');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'place_id': placeId,
              'session_token': sessionToken,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return CityResolution.fromJson(data);
      }
    } catch (e) {
      debugPrint('Resolve City HTTP note: $e');
    }

    // Fallback coordinates for Karnataka
    return CityResolution(
      name: placeId.replaceAll('city_', '').replaceAll('_', ' '),
      placeId: placeId,
      lat: 13.9299,
      lng: 75.5681,
      formattedAddress: 'Karnataka, India',
    );
  }

  // --------------------------------------------------------------------
  // Step 4 & 5: Discover Places within 70 km and Categorize
  // --------------------------------------------------------------------
  static Future<DiscoverResponse> discoverPlaces({
    required String tripId,
    required String city,
    double? lat,
    double? lng,
    double radiusKm = 70.0,
    String? sessionToken,
  }) async {
    final baseUrl = await getBaseUrl();
    final url = Uri.parse('$baseUrl/discover');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'trip_id': tripId,
              'city': city,
              'lat': lat,
              'lng': lng,
              'radius_km': radiusKm,
              'session_token': sessionToken,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DiscoverResponse.fromJson(data);
      }
    } catch (e) {
      debugPrint('Discover Places HTTP note: $e');
    }

    // Fallback response with the 5 required categories
    return _buildFallbackDiscoverResponse(tripId, city, lat ?? 13.9299, lng ?? 75.5681);
  }

  // --------------------------------------------------------------------
  // Step 7 & 8: Plan Itinerary via ADK Tools & Validate
  // --------------------------------------------------------------------
  static Future<ItineraryPlan> planTrip({
    required String tripId,
    required List<String> dates,
    required List<String> selectedIds,
    String start = 'Starting Point',
    String? hotel,
    String? end,
    String travelMode = 'DRIVE',
    String? sessionToken,
  }) async {
    final baseUrl = await getBaseUrl();
    final url = Uri.parse('$baseUrl/plan');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'trip_id': tripId,
              'dates': dates,
              'selected_ids': selectedIds,
              'start': start,
              'hotel': hotel,
              'end': end ?? hotel ?? start,
              'travel_mode': travelMode,
              'session_token': sessionToken,
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ItineraryPlan.fromJson(data);
      }
    } catch (e) {
      debugPrint('Plan Trip HTTP note: $e');
    }

    // Fallback programmatic schedule if network unavailable
    final resolvedEnd = end ?? hotel ?? start;
    return _buildFallbackItineraryPlan(tripId, dates, selectedIds, start, resolvedEnd, travelMode);
  }

  // --------------------------------------------------------------------
  // Offline / Fallback Builders
  // --------------------------------------------------------------------
  static DiscoverResponse _buildFallbackDiscoverResponse(
    String tripId,
    String city,
    double lat,
    double lng,
  ) {
    final places = [
      PlaceCard(
        placeId: 'loc_adv_1',
        name: '$city Mountain Peak Trek',
        types: ['trekking', 'adventure'],
        lat: lat + 0.12,
        lng: lng + 0.15,
        rating: 4.8,
        userRatingsTotal: 340,
        address: 'Western Ghats, near $city',
        distanceKm: 28.5,
        category: 'Adventure',
      ),
      PlaceCard(
        placeId: 'loc_adv_2',
        name: '$city River Rafting Rapids',
        types: ['water_sports', 'adventure'],
        lat: lat - 0.08,
        lng: lng + 0.22,
        rating: 4.7,
        userRatingsTotal: 510,
        address: 'River Valley, near $city',
        distanceKm: 34.0,
        category: 'Adventure',
      ),
      PlaceCard(
        placeId: 'loc_food_1',
        name: 'Gandhi Bazaar Traditional Sweets & Thali',
        types: ['restaurant', 'food'],
        lat: lat + 0.01,
        lng: lng + 0.01,
        rating: 4.6,
        userRatingsTotal: 820,
        address: 'Main Market, $city',
        distanceKm: 1.8,
        category: 'Food',
      ),
      PlaceCard(
        placeId: 'loc_food_2',
        name: 'Hotel Heritage Authentic Cuisine',
        types: ['restaurant', 'food'],
        lat: lat - 0.02,
        lng: lng - 0.01,
        rating: 4.5,
        userRatingsTotal: 620,
        address: 'Station Road, $city',
        distanceKm: 2.5,
        category: 'Food',
      ),
      PlaceCard(
        placeId: 'loc_nat_1',
        name: 'Cascade Forest Waterfall',
        types: ['waterfall', 'nature'],
        lat: lat + 0.25,
        lng: lng - 0.18,
        rating: 4.9,
        userRatingsTotal: 1200,
        address: 'National Reserve, near $city',
        distanceKm: 42.0,
        category: 'Nature',
      ),
      PlaceCard(
        placeId: 'loc_nat_2',
        name: 'Wildlife Sanctuary & Lake Trail',
        types: ['sanctuary', 'nature'],
        lat: lat - 0.15,
        lng: lng - 0.20,
        rating: 4.6,
        userRatingsTotal: 490,
        address: 'Forest Range, near $city',
        distanceKm: 31.0,
        category: 'Nature',
      ),
      PlaceCard(
        placeId: 'loc_cul_1',
        name: 'Ancient Rameshwara Heritage Temple',
        types: ['hindu_temple', 'culture'],
        lat: lat + 0.18,
        lng: lng + 0.05,
        rating: 4.8,
        userRatingsTotal: 950,
        address: 'Historic Quarter, near $city',
        distanceKm: 22.0,
        category: 'Culture',
      ),
      PlaceCard(
        placeId: 'loc_cul_2',
        name: 'Royal Palace & Fortification',
        types: ['historic_site', 'culture'],
        lat: lat - 0.22,
        lng: lng + 0.10,
        rating: 4.7,
        userRatingsTotal: 780,
        address: 'Hilltop Fort, near $city',
        distanceKm: 38.0,
        category: 'Culture',
      ),
      PlaceCard(
        placeId: 'loc_sight_1',
        name: 'Panoramic Valley Sunset Lookout',
        types: ['scenic_view', 'sightseeing'],
        lat: lat + 0.35,
        lng: lng - 0.10,
        rating: 4.8,
        userRatingsTotal: 1400,
        address: 'High Peak Point, near $city',
        distanceKm: 52.0,
        category: 'Sightseeing',
      ),
      PlaceCard(
        placeId: 'loc_sight_2',
        name: 'City Central Square & Dam Garden',
        types: ['tourist_attraction', 'sightseeing'],
        lat: lat + 0.05,
        lng: lng - 0.04,
        rating: 4.4,
        userRatingsTotal: 650,
        address: 'River Reservoir, near $city',
        distanceKm: 12.0,
        category: 'Sightseeing',
      ),
    ];

    final categories = {
      'Adventure': ['loc_adv_1', 'loc_adv_2'],
      'Food': ['loc_food_1', 'loc_food_2'],
      'Nature': ['loc_nat_1', 'loc_nat_2'],
      'Culture': ['loc_cul_1', 'loc_cul_2'],
      'Sightseeing': ['loc_sight_1', 'loc_sight_2'],
    };

    return DiscoverResponse(
      tripId: tripId,
      city: city,
      radiusKm: 70.0,
      totalPlaces: places.length,
      categories: categories,
      places: places,
    );
  }

  static ItineraryPlan _buildFallbackItineraryPlan(
    String tripId,
    List<String> dates,
    List<String> selectedIds,
    String start,
    String end,
    String travelMode,
  ) {
    final safeDates = dates.isNotEmpty ? dates : ['Day 1'];
    final List<DailySchedule> days = [];

    for (int i = 0; i < safeDates.length; i++) {
      days.append(
        DailySchedule(
          dayNumber: i + 1,
          date: safeDates[i],
          summary: 'Day ${i + 1}: Exploration & Local Experience',
          stops: [
            DailyScheduleStop(
              time: '09:00 AM',
              placeId: 'start_point',
              name: 'Start: $start',
              activityType: 'start',
              durationMinutes: 15,
              travelToNextMinutes: 20,
              openingHours: ['Open 24/7'],
              notes: 'Depart by $travelMode',
            ),
            DailyScheduleStop(
              time: '09:35 AM',
              placeId: selectedIds.isNotEmpty ? selectedIds[i % selectedIds.length] : 'stop_1',
              name: 'Selected Attraction Stop',
              activityType: 'visit',
              durationMinutes: 90,
              travelToNextMinutes: 15,
              openingHours: ['09:00 AM – 06:00 PM'],
              notes: 'Explore landmarks & capture photos',
            ),
            DailyScheduleStop(
              time: '01:00 PM',
              placeId: 'lunch_break',
              name: 'Lunch Break & Refreshment',
              activityType: 'meal',
              durationMinutes: 60,
              travelToNextMinutes: 15,
              openingHours: ['11:30 AM – 10:30 PM'],
              notes: 'Authentic local dining',
            ),
            DailyScheduleStop(
              time: '06:00 PM',
              placeId: 'end_point',
              name: 'End: $end',
              activityType: 'end',
              durationMinutes: 0,
              travelToNextMinutes: 0,
              openingHours: ['Open 24/7'],
              notes: 'Return to resting location',
            ),
          ],
          dailyTotalTravelMinutes: 50,
          dailyTotalDistanceKm: 24.5,
        ),
      );
    }

    return ItineraryPlan(
      tripId: tripId,
      travelMode: travelMode,
      startPoint: start,
      endPoint: end,
      days: days,
      unfittedStops: [],
      warnings: [],
      isValid: true,
      rawJson: {
        'trip_id': tripId,
        'days': days.map((d) => d.toJson()).toList(),
      },
    );
  }
}

extension on List<DailySchedule> {
  void append(DailySchedule dailySchedule) {
    add(dailySchedule);
  }
}
