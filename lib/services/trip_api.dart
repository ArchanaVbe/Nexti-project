// trip_api.dart
// HTTP Client connecting the Flutter UI to the FastAPI + Google ADK backend.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_plan_models.dart';
import 'karnataka_places.dart';

class TripApi {
  // In-memory discover cache: avoids re-fetching places for the same city
  // within the same app session.  Key = "cityLower|lat1dp|lng1dp".
  static final Map<String, DiscoverResponse> _discoverCache = {};

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

    // Candidate URLs for Android emulator vs physical device vs web
    final candidates = <String>[];
    if (kIsWeb) {
      candidates.add('http://127.0.0.1:8000');
    } else if (Platform.isAndroid) {
      // Prioritize localhost (works with adb reverse tcp:8000 tcp:8000), current LAN IP, then emulator
      candidates.addAll([
        'http://127.0.0.1:8000',
        'http://192.168.0.203:8000',
        'http://10.0.2.2:8000',
      ]);
    } else {
      candidates.addAll([
        'http://127.0.0.1:8000',
        'http://192.168.0.203:8000',
      ]);
    }

    // Fast probe with 1.2s timeout to auto-connect to the live backend
    for (final candidate in candidates) {
      try {
        final res = await http
            .get(Uri.parse('$candidate/'))
            .timeout(const Duration(milliseconds: 1200));
        if (res.statusCode == 200) {
          debugPrint('Connected to backend at $candidate');
          _cachedBaseUrl = candidate;
          return _cachedBaseUrl!;
        }
      } catch (_) {}
    }

    _cachedBaseUrl = candidates.first;
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
    String? destination,
  }) async {
    final cleanQ = query.trim();
    if (cleanQ.isEmpty) return [];

    // 1. Fetch from backend with destination context
    List<CitySuggestion> backendSuggestions = [];
    try {
      final baseUrl = await getBaseUrl();
      final url = Uri.parse('$baseUrl/places/autocomplete');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'query': cleanQ,
              'types': types,
              'session_token': sessionToken,
              if (destination != null && destination.trim().isNotEmpty)
                'destination': destination.trim(),
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawList = data['suggestions'] as List? ?? [];
        backendSuggestions = rawList
            .map((e) => CitySuggestion.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      debugPrint('Autocomplete HTTP note: $e');
    }

    // 2. Handling LODGING / HOTEL search
    if (types == 'lodging') {
      if (backendSuggestions.isNotEmpty) {
        return backendSuggestions;
      }

      // Direct OpenStreetMap Nominatim fallback if backend didn't return
      try {
        final destSuffix = (destination != null && destination.trim().isNotEmpty)
            ? ' ${destination.trim()}'
            : '';
        final osmQuery = Uri.encodeComponent('$cleanQ$destSuffix Karnataka');
        final osmUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$osmQuery&format=json&limit=8&countrycodes=in',
        );
        final res = await http.get(
          osmUrl,
          headers: {'User-Agent': 'NextiTravelCompanion/1.0 (hotel search)'},
        ).timeout(const Duration(seconds: 3));

        if (res.statusCode == 200) {
          final List list = jsonDecode(res.body);
          final osmSuggestions = <CitySuggestion>[];
          for (final item in list) {
            final dispName = item['display_name']?.toString() ?? '';
            final lat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
            final lng = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
            final shortName = dispName.split(',').first.trim();
            final slug = shortName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
            final pid = 'osm_${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}_$slug';
            osmSuggestions.add(CitySuggestion(description: dispName, placeId: pid));
          }
          if (osmSuggestions.isNotEmpty) {
            return osmSuggestions;
          }
        }
      } catch (_) {}

      // Clean fallback if no hotels found
      final destLabel = (destination != null && destination.trim().isNotEmpty)
          ? '$destination, Karnataka, India'
          : 'Karnataka, India';
      return [
        CitySuggestion(
          description: '$cleanQ Stay, $destLabel',
          placeId: 'hotel_${cleanQ.toLowerCase().replaceAll(' ', '_')}',
        ),
      ];
    }

    // 3. Handling CITIES / GEOCODE search
    final localMatches = KarnatakaPlacesRegistry.searchSuggestions(cleanQ, limit: 25);
    final Set<String> seenIds = {};
    final List<CitySuggestion> merged = [];

    // Prioritize local prefix matches from Karnataka registry
    for (final s in localMatches) {
      if (!seenIds.contains(s.placeId)) {
        merged.add(s);
        seenIds.add(s.placeId);
      }
    }

    // Append unique backend / OSM suggestions
    for (final s in backendSuggestions) {
      final normDesc = s.description.toLowerCase();
      final isDup = merged.any(
        (m) => m.description.toLowerCase().split(',').first.trim() == normDesc.split(',').first.trim(),
      );
      if (!seenIds.contains(s.placeId) && !isDup) {
        merged.add(s);
        seenIds.add(s.placeId);
      }
    }

    if (merged.isNotEmpty) {
      return merged;
    }

    // Graceful fallback
    return [
      CitySuggestion(
        description: '$cleanQ, Karnataka, India',
        placeId: 'city_${cleanQ.toLowerCase().replaceAll(' ', '_')}',
      ),
    ];
  }

  /// Reverse geocode coordinates to a clean human-readable address with area and city
  static Future<String> reverseGeocode(double lat, double lng) async {
    // 1. Try on-device native geocoding (fastest, most accurate street/area + city)
    try {
      final geocoding = Geocoding();
      final placemarks = await geocoding.placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks[0];
        final parts = <String>[];

        // Specific area / street (e.g. Vinoba Nagara)
        final area = (p.subLocality != null && p.subLocality!.isNotEmpty)
            ? p.subLocality!
            : (p.street != null && p.street!.isNotEmpty && !p.street!.contains('+') && p.street != p.name)
                ? p.street!
                : (p.name != null && p.name!.isNotEmpty && !p.name!.contains('+'))
                    ? p.name!
                    : null;
        if (area != null && area.isNotEmpty) {
          parts.add(area);
        }

        // City / town (e.g. Shivamogga)
        final city = (p.locality != null && p.locality!.isNotEmpty)
            ? p.locality!
            : (p.subAdministrativeArea != null && p.subAdministrativeArea!.isNotEmpty)
                ? p.subAdministrativeArea!
                : null;
        if (city != null && city.isNotEmpty && !parts.contains(city)) {
          parts.add(city);
        }

        // State (e.g. Karnataka)
        if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty && !parts.contains(p.administrativeArea)) {
          parts.add(p.administrativeArea!);
        }

        if (parts.isNotEmpty) {
          return parts.join(', ');
        }
      }
    } catch (_) {}

    // 2. Try backend reverse-geocode endpoint if reachable
    try {
      final baseUrl = await getBaseUrl();
      final url = Uri.parse('$baseUrl/places/reverse-geocode');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'lat': lat, 'lng': lng}),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final loc = (data['address'] ?? data['locality'])?.toString();
        if (loc != null && loc.isNotEmpty && !loc.startsWith('Location (')) {
          return loc;
        }
      }
    } catch (_) {}

    // 3. Fallback: match nearest Karnataka hub/city center
    KarnatakaPlace? closest;
    double minDistance = double.infinity;
    for (final dest in KarnatakaPlacesRegistry.destinations) {
      final dLat = (dest.lat - lat);
      final dLng = (dest.lng - lng);
      final distSq = dLat * dLat + dLng * dLng;
      if (distSq < minDistance) {
        minDistance = distSq;
        closest = dest;
      }
    }

    if (closest != null) {
      final parts = closest.name.split(',').map((e) => e.trim()).take(2).join(', ');
      return parts;
    }

    return 'Karnataka, India';
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

    // 1. Instant accurate coordinate decoding from osm_{lat}_{lng}_{slug}
    if (placeId.startsWith('osm_')) {
      final parts = placeId.split('_');
      if (parts.length >= 3) {
        final parsedLat = double.tryParse(parts[1]);
        final parsedLng = double.tryParse(parts[2]);
        if (parsedLat != null && parsedLng != null) {
          final slug = parts.length > 3 ? parts.sublist(3).join(' ') : 'Place';
          return CityResolution(
            name: slug,
            placeId: placeId,
            lat: parsedLat,
            lng: parsedLng,
            formattedAddress: '$slug, Karnataka, India',
          );
        }
      }
    }

    // 2. Instant accurate coordinate lookup from comprehensive Karnataka registry
    final localResolved = KarnatakaPlacesRegistry.resolvePlace(placeId);
    if (localResolved != null) {
      return localResolved;
    }

    // Fallback coordinates for Karnataka
    return CityResolution(
      name: placeId.replaceAll('city_', '').replaceAll('hotel_', '').replaceAll('_', ' '),
      placeId: placeId,
      lat: 12.4244,
      lng: 75.7382,
      formattedAddress: '${placeId.replaceAll('city_', '').replaceAll('hotel_', '').replaceAll('_', ' ')}, Karnataka, India',
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
    // Client-side cache: return immediately on repeat visits
    final cacheKey =
        '${city.toLowerCase().trim()}|${(lat ?? 0).toStringAsFixed(1)}|${(lng ?? 0).toStringAsFixed(1)}';
    if (_discoverCache.containsKey(cacheKey)) {
      debugPrint('Discover cache HIT for $city — returning instantly');
      return _discoverCache[cacheKey]!;
    }

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
          .timeout(const Duration(seconds: 30)); // increased from 15s

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = DiscoverResponse.fromJson(data);
        _discoverCache[cacheKey] = result; // cache for this session
        return result;
      }
    } catch (e) {
      debugPrint('Discover Places HTTP note: \$e');
    }

    // Fallback response with the 5 required categories
    return _buildFallbackDiscoverResponse(
      tripId,
      city,
      lat ?? 13.9299,
      lng ?? 75.5681,
      radiusKm: radiusKm,
    );
  }

  // --------------------------------------------------------------------
  // Step 7 & 8: Plan Itinerary via ADK Tools & Validate
  // --------------------------------------------------------------------
  static Future<ItineraryPlan> planTrip({
    required String tripId,
    required List<String> dates,
    required List<String> selectedIds,
    List<String>? selectedNames,
    List<PlaceCard>? availablePlaces,
    String start = 'Starting Point',
    String? hotel,
    String? end,
    String travelMode = 'DRIVE',
    String? sessionToken,
  }) async {
    final baseUrl = await getBaseUrl();
    final url = Uri.parse('$baseUrl/plan');

    final resolvedHotel = hotel ?? '${start.replaceAll('Start:', '').trim()} Hotel';
    final resolvedEnd = end ?? resolvedHotel;

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'trip_id': tripId,
              'dates': dates,
              'selected_ids': selectedIds,
              'selected_names': selectedNames,
              'start': start,
              'hotel': resolvedHotel,
              'end': resolvedEnd,
              'travel_mode': travelMode,
              'session_token': sessionToken,
            }),
          )
          .timeout(const Duration(seconds: 40));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ItineraryPlan.fromJson(data);
      }
    } catch (e) {
      debugPrint('Plan Trip HTTP note: $e');
    }

    // Fallback programmatic schedule if network unavailable
    return _buildFallbackItineraryPlan(
      tripId: tripId,
      dates: dates,
      selectedIds: selectedIds,
      selectedNames: selectedNames,
      availablePlaces: availablePlaces,
      start: start,
      hotel: resolvedHotel,
      end: resolvedEnd,
      travelMode: travelMode,
    );
  }

  // --------------------------------------------------------------------
  // Offline / Fallback Builders
  // --------------------------------------------------------------------
  static DiscoverResponse _buildFallbackDiscoverResponse(
    String tripId,
    String city,
    double lat,
    double lng, {
    double radiusKm = 70.0,
  }) {
    return KarnatakaPlacesRegistry.getDiscoverResponseForCity(
      tripId: tripId,
      destination: city,
      centerLat: lat,
      centerLng: lng,
      radiusKm: radiusKm,
    );
  }

  static ItineraryPlan _buildFallbackItineraryPlan({
    required String tripId,
    required List<String> dates,
    required List<String> selectedIds,
    List<String>? selectedNames,
    List<PlaceCard>? availablePlaces,
    required String start,
    required String hotel,
    required String end,
    required String travelMode,
  }) {
    final safeDates = dates.isNotEmpty ? dates : ['Day 1'];
    final List<DailySchedule> days = [];

    // 1. Gather human-readable explicit place names
    final List<String> resolvedNames = [];
    if (selectedNames != null && selectedNames.isNotEmpty) {
      resolvedNames.addAll(selectedNames.where((n) => n.trim().isNotEmpty));
    } else if (availablePlaces != null && availablePlaces.isNotEmpty) {
      resolvedNames.addAll(availablePlaces.map((p) => p.name));
    } else {
      for (final id in selectedIds) {
        if (!id.startsWith('stop_') && !id.startsWith('place_') && id.trim().isNotEmpty) {
          resolvedNames.add(id.replaceAll('local_', '').replaceAll('_', ' ').trim());
        }
      }
    }

    if (resolvedNames.isEmpty) {
      resolvedNames.addAll([
        'City Heritage Center',
        'Scenic Nature Lake & Park',
        'Historic Monument & Viewpoint',
        'Botanical Gardens & Reserve',
      ]);
    }

    // 2. Distribute places across the days
    final numDays = safeDates.length;
    final List<List<String>> stopsByDay = List.generate(numDays, (_) => []);
    for (int i = 0; i < resolvedNames.length; i++) {
      stopsByDay[i % numDays].add(resolvedNames[i]);
    }

    for (int i = 0; i < numDays; i++) {
      final dayNumber = i + 1;
      final dateStr = safeDates[i];
      final dayStops = stopsByDay[i];

      // Day 1 starts from user's starting point; Day 2+ starts from hotel!
      final dayStartPoint = (dayNumber == 1) ? start : hotel;
      final List<DailyScheduleStop> scheduleStops = [];

      // Morning Start (6:00 AM)
      scheduleStops.add(
        DailyScheduleStop(
          time: '06:00 AM',
          placeId: 'start_point',
          name: 'Start: $dayStartPoint',
          activityType: 'start',
          durationMinutes: 15,
          travelToNextMinutes: 30,
          openingHours: ['Open 24/7'],
          notes: 'Depart by $travelMode',
        ),
      );

      // Morning Stop 1 (07:00 AM)
      if (dayStops.isNotEmpty) {
        scheduleStops.add(
          DailyScheduleStop(
            time: '07:00 AM',
            placeId: 'stop_${i}_0',
            name: dayStops[0],
            activityType: 'visit',
            durationMinutes: 90,
            travelToNextMinutes: 25,
            openingHours: ['06:00 AM – 06:00 PM'],
            notes: 'Explore landmarks & capture photos',
          ),
        );
      }

      // Morning Stop 2 (09:30 AM) if available
      if (dayStops.length > 1) {
        scheduleStops.add(
          DailyScheduleStop(
            time: '09:30 AM',
            placeId: 'stop_${i}_1',
            name: dayStops[1],
            activityType: 'visit',
            durationMinutes: 90,
            travelToNextMinutes: 25,
            openingHours: ['08:00 AM – 06:00 PM'],
            notes: 'Sightseeing and local cultural tour',
          ),
        );
      }

      // Lunch Break (01:00 PM)
      scheduleStops.add(
        DailyScheduleStop(
          time: '01:00 PM',
          placeId: 'lunch_break',
          name: 'Lunch Break & Refreshment',
          activityType: 'meal',
          durationMinutes: 60,
          travelToNextMinutes: 20,
          openingHours: ['11:30 AM – 10:30 PM'],
          notes: 'Authentic regional dining & refreshment',
        ),
      );

      // Afternoon Stop 3+ (02:30 PM onwards)
      if (dayStops.length > 2) {
        for (int sIdx = 2; sIdx < dayStops.length; sIdx++) {
          final pName = dayStops[sIdx];
          final hour = 2 + (sIdx - 2) * 2;
          final timeStr = '${hour.toString().padLeft(2, '0')}:30 PM';
          scheduleStops.add(
            DailyScheduleStop(
              time: timeStr,
              placeId: 'stop_${i}_$sIdx',
              name: pName,
              activityType: 'visit',
              durationMinutes: 90,
              travelToNextMinutes: 25,
              openingHours: ['09:00 AM – 07:00 PM'],
              notes: 'Scenic exploration & photography',
            ),
          );
        }
      }

      // Night Arrival at Hotel with 6-Hour Sleep Schedule
      final finalTimeStr = (numDays > 1) ? '12:00 AM' : '08:00 PM';
      final finalNotes = (numDays > 1)
          ? 'Route to hotel stay (6-hour sleep schedule: 12:00 AM – 06:00 AM)'
          : 'Return to resting location';

      scheduleStops.add(
        DailyScheduleStop(
          time: finalTimeStr,
          placeId: 'end_point',
          name: 'End: $hotel',
          activityType: 'end',
          durationMinutes: 0,
          travelToNextMinutes: 0,
          openingHours: ['Open 24/7'],
          notes: finalNotes,
        ),
      );

      days.add(
        DailySchedule(
          dayNumber: dayNumber,
          date: dateStr,
          summary: 'Day $dayNumber: ${dayStops.isNotEmpty ? dayStops.take(2).join(' & ') : "Exploration & Local Sights"}',
          stops: scheduleStops,
          dailyTotalTravelMinutes: 65,
          dailyTotalDistanceKm: 32.0,
        ),
      );
    }

    return ItineraryPlan(
      tripId: tripId,
      travelMode: travelMode,
      startPoint: start,
      endPoint: hotel,
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

