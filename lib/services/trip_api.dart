// trip_api.dart
// HTTP Client connecting the Flutter UI to the FastAPI + Google ADK backend.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_plan_models.dart';
import 'karnataka_places.dart';
import 'road_routing_service.dart';

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

    // Do not fabricate Karnataka suggestions for places explicitly outside Karnataka
    if (KarnatakaPlacesRegistry.isExplicitlyOutsideKarnataka(cleanQ)) {
      return [];
    }

    if (KarnatakaPlacesRegistry.isPlaceInKarnataka(cleanQ)) {
      return [
        CitySuggestion(
          description: '$cleanQ, Karnataka, India',
          placeId: 'city_${cleanQ.toLowerCase().replaceAll(' ', '_')}',
        ),
      ];
    }

    return [];
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

  /// Resolves any place, address, locality, or city string to coordinates (CityResolution)
  static Future<CityResolution?> resolveAddressOrPlace(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return null;

    // 1. Instant accurate local resolution from Karnataka registry
    final local = KarnatakaPlacesRegistry.resolvePlace(clean);
    if (local != null) return local;

    // 2. Decode osm_ lat/lng if applicable
    if (clean.startsWith('osm_')) {
      final parts = clean.split('_');
      if (parts.length >= 3) {
        final parsedLat = double.tryParse(parts[1]);
        final parsedLng = double.tryParse(parts[2]);
        if (parsedLat != null && parsedLng != null) {
          final slug = parts.length > 3 ? parts.sublist(3).join(' ') : 'Place';
          return CityResolution(
            name: slug,
            placeId: clean,
            lat: parsedLat,
            lng: parsedLng,
            formattedAddress: '$slug, Karnataka, India',
          );
        }
      }
    }

    // 3. Native geocoding lookup
    try {
      final geocoding = Geocoding();
      final locations = await geocoding.locationFromAddress('$clean, Karnataka, India')
          .timeout(const Duration(seconds: 2));
      if (locations.isNotEmpty) {
        final first = locations.first;
        return CityResolution(
          name: clean.split(',').first.trim(),
          placeId: 'geo_${first.latitude}_${first.longitude}',
          lat: first.latitude,
          lng: first.longitude,
          formattedAddress: '$clean, Karnataka, India',
        );
      }
    } catch (_) {}

    // 4. Try backend resolution
    try {
      final res = await resolveCity(clean);
      return res;
    } catch (_) {}

    return null;
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
    double? startLat,
    double? startLng,
    String? hotel,
    double? hotelLat,
    double? hotelLng,
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
              'start_lat': startLat,
              'start_lng': startLng,
              'hotel': resolvedHotel,
              'hotel_lat': hotelLat,
              'hotel_lng': hotelLng,
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

    // Intelligent programmatic schedule using Google Maps & road metrics
    return await _buildIntelligentItineraryPlan(
      tripId: tripId,
      dates: dates,
      selectedIds: selectedIds,
      selectedNames: selectedNames,
      availablePlaces: availablePlaces,
      start: start,
      startLat: startLat,
      startLng: startLng,
      hotel: resolvedHotel,
      hotelLat: hotelLat,
      hotelLng: hotelLng,
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

  /// Resolves the most accurate geographical coordinate for a place/locality
  static LatLng _resolvePointLatLng(
    String rawName, {
    double? fallbackLat,
    double? fallbackLng,
    List<PlaceCard>? availablePlaces,
  }) {
    if (fallbackLat != null && fallbackLng != null && fallbackLat != 0.0 && fallbackLng != 0.0) {
      return LatLng(fallbackLat, fallbackLng);
    }

    final clean = rawName
        .replaceAll(RegExp(r'^Start:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^End:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^Depart:\s*', caseSensitive: false), '')
        .trim();

    if (clean.isEmpty) return const LatLng(13.9299, 75.5681); // Default Karnataka center

    // 1. Check in available places
    if (availablePlaces != null) {
      for (final p in availablePlaces) {
        if (p.name.toLowerCase() == clean.toLowerCase() ||
            p.name.toLowerCase().contains(clean.toLowerCase()) ||
            clean.toLowerCase().contains(p.name.toLowerCase())) {
          return LatLng(p.lat, p.lng);
        }
      }
    }

    // 2. Check Karnataka Places Registry
    final coord = KarnatakaPlacesRegistry.findPlaceCoordinate(clean);
    if (coord != null) {
      return LatLng(coord.lat, coord.lng);
    }

    final resolved = KarnatakaPlacesRegistry.resolvePlace(clean);
    if (resolved != null) {
      return LatLng(resolved.lat, resolved.lng);
    }

    return const LatLng(13.9299, 75.5681);
  }

  static String _formatTime(int hour24, int minute) {
    final ampm = (hour24 % 24) < 12 ? 'AM' : 'PM';
    int h = (hour24 % 24) % 12;
    if (h == 0) h = 12;
    final m = minute.toString().padLeft(2, '0');
    return '${h.toString().padLeft(2, '0')}:$m $ampm';
  }

  static String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  /// Builds a real-world, human-friendly, distance-aware travel schedule using Google Maps
  /// and intelligent day/night suitable time slots.
  static Future<ItineraryPlan> _buildIntelligentItineraryPlan({
    required String tripId,
    required List<String> dates,
    required List<String> selectedIds,
    List<String>? selectedNames,
    List<PlaceCard>? availablePlaces,
    required String start,
    double? startLat,
    double? startLng,
    required String hotel,
    double? hotelLat,
    double? hotelLng,
    required String end,
    required String travelMode,
  }) async {
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

    // 2. Distribute places across the days (balanced human-friendly pacing)
    final numDays = safeDates.length;
    final List<List<String>> stopsByDay = List.generate(numDays, (_) => []);
    for (int i = 0; i < resolvedNames.length; i++) {
      stopsByDay[i % numDays].add(resolvedNames[i]);
    }

    // Pre-resolve hotel coordinates
    final hotelLatLng = _resolvePointLatLng(
      hotel,
      fallbackLat: hotelLat,
      fallbackLng: hotelLng,
      availablePlaces: availablePlaces,
    );

    // Pre-resolve start coordinates
    final startLatLng = _resolvePointLatLng(
      start,
      fallbackLat: startLat,
      fallbackLng: startLng,
      availablePlaces: availablePlaces,
    );

    for (int i = 0; i < numDays; i++) {
      final dayNumber = i + 1;
      final dateStr = safeDates[i];
      final dayStops = stopsByDay[i];

      // Day 1 starts from user's starting point; Day 2+ starts from hotel stay!
      final dayOriginName = (dayNumber == 1) ? start : hotel;
      final dayOriginLatLng = (dayNumber == 1) ? startLatLng : hotelLatLng;

      // Resolve coordinates for each stop of this day
      final List<LatLng> stopLatLngs = [];
      for (final sName in dayStops) {
        stopLatLngs.add(_resolvePointLatLng(sName, availablePlaces: availablePlaces));
      }

      // Query Google Maps Directions for accurate road distance and travel times
      final List<RouteLegInfo> legs = await RoadRoutingService.getMultiStopRoute(
        origin: dayOriginLatLng,
        destination: hotelLatLng,
        waypoints: stopLatLngs,
        travelMode: travelMode,
      );

      final List<DailyScheduleStop> scheduleStops = [];

      // Transit to the first destination
      final int transitToFirstMins = legs.isNotEmpty ? legs[0].durationMinutes : 25;
      final double firstLegDistanceKm = legs.isNotEmpty ? legs[0].distanceKm : 12.0;

      // -------------------------------------------------------------
      // Dynamic, Human-Friendly Departure Time Determination
      // -------------------------------------------------------------
      int curHour;
      int curMin = 0;

      if (dayNumber == 1) {
        if (transitToFirstMins >= 180) {
          // Long journey (3+ hours, e.g. Shivamogga to Murudeshwar): Depart early at 06:00 AM
          curHour = 6;
          curMin = 0;
        } else if (transitToFirstMins >= 90) {
          // Medium journey (1.5 to 3 hours): Depart at 07:00 AM
          curHour = 7;
          curMin = 0;
        } else if (transitToFirstMins >= 45) {
          // Short journey: Depart at 08:00 AM
          curHour = 8;
          curMin = 0;
        } else {
          // Local start (< 45 mins): Depart at 08:30 AM
          curHour = 8;
          curMin = 30;
        }
      } else {
        // Day 2+ starts from Hotel: 08:30 AM (relaxing wake up and hotel breakfast)
        curHour = 8;
        curMin = 30;
      }

      // 1. Start Stop Card
      final startNotes = (dayNumber == 1)
          ? 'Depart by $travelMode • ${_formatDuration(transitToFirstMins)} travel (${firstLegDistanceKm.toStringAsFixed(1)} km)'
          : 'Depart from hotel after breakfast';

      scheduleStops.add(
        DailyScheduleStop(
          time: _formatTime(curHour, curMin),
          placeId: 'start_point',
          name: (dayNumber == 1) ? 'Start: $dayOriginName' : 'Depart: $dayOriginName',
          activityType: 'start',
          durationMinutes: 15,
          travelToNextMinutes: transitToFirstMins,
          openingHours: ['Open 24/7'],
          notes: startNotes,
        ),
      );

      // 2. Highway Tea / Refreshment Break for long road trips (> 2.5 hours travel)
      bool hasHighwayBreak = false;
      if (dayNumber == 1 && transitToFirstMins >= 150) {
        hasHighwayBreak = true;
        final halfTransit = transitToFirstMins ~/ 2;
        final breakInitialMin = curMin + 15 + halfTransit;
        final breakHour = curHour + breakInitialMin ~/ 60;
        final breakMin = breakInitialMin % 60;

        scheduleStops.add(
          DailyScheduleStop(
            time: _formatTime(breakHour, breakMin),
            placeId: 'highway_break',
            name: 'Highway Refreshment & Tea Break',
            activityType: 'break',
            durationMinutes: 25,
            travelToNextMinutes: transitToFirstMins - halfTransit,
            openingHours: ['Open 24/7'],
            notes: 'Restroom, tea/coffee & light breakfast on highway route',
          ),
        );
      }

      // Advance clock to exact arrival time at first destination
      final totalInitialMins = curMin + 15 + transitToFirstMins + (hasHighwayBreak ? 25 : 0);
      curHour += totalInitialMins ~/ 60;
      curMin = totalInitialMins % 60;

      // 3. Sequenced Daytime Visits & Realistic Lunch Break
      bool lunchAdded = false;

      for (int sIdx = 0; sIdx < dayStops.length; sIdx++) {
        final stopName = dayStops[sIdx];
        final legToNext = (sIdx + 1 < legs.length)
            ? legs[sIdx + 1]
            : RouteLegInfo(
                distanceKm: 2.0,
                durationMinutes: 10,
                distanceText: '2.0 km',
                durationText: '10 mins',
              );

        // Midday Lunch Break (12:45 PM – 02:00 PM window)
        final timeInMins = curHour * 60 + curMin;
        if (!lunchAdded && timeInMins >= (12 * 60 + 45) && timeInMins <= (14 * 60 + 30)) {
          scheduleStops.add(
            DailyScheduleStop(
              time: _formatTime(curHour, curMin),
              placeId: 'lunch_break',
              name: 'Lunch & Regional Cuisine Refreshment',
              activityType: 'meal',
              durationMinutes: 60,
              travelToNextMinutes: 10,
              openingHours: ['11:30 AM – 10:30 PM'],
              notes: 'Authentic regional dining & relaxing break',
            ),
          );
          final totalLunchMins = curMin + 60 + 10;
          curHour += totalLunchMins ~/ 60;
          curMin = totalLunchMins % 60;
          lunchAdded = true;
        }

        // Tailor visit duration to place type
        int visitDuration = 90;
        final lower = stopName.toLowerCase();
        if (lower.contains('beach') || lower.contains('falls') || lower.contains('park') || lower.contains('safari')) {
          visitDuration = 90;
        } else if (lower.contains('temple') || lower.contains('gopura') || lower.contains('tower') || lower.contains('monument')) {
          visitDuration = 75;
        } else if (lower.contains('sunset') || lower.contains('viewpoint')) {
          visitDuration = 60;
        } else if (lower.contains('museum') || lower.contains('palace') || lower.contains('fort')) {
          visitDuration = 90;
        }

        scheduleStops.add(
          DailyScheduleStop(
            time: _formatTime(curHour, curMin),
            placeId: 'stop_${i}_$sIdx',
            name: stopName,
            activityType: 'visit',
            durationMinutes: visitDuration,
            travelToNextMinutes: legToNext.durationMinutes,
            openingHours: ['06:00 AM – 07:00 PM'],
            notes: 'Explore landmarks & capture photos • ${_formatDuration(legToNext.durationMinutes)} to next (${legToNext.distanceKm.toStringAsFixed(1)} km)',
          ),
        );

        final totalStopMins = curMin + visitDuration + legToNext.durationMinutes;
        curHour += totalStopMins ~/ 60;
        curMin = totalStopMins % 60;

        // If lunch wasn't added yet and afternoon progresses past 02:00 PM
        if (!lunchAdded && curHour >= 14) {
          scheduleStops.add(
            DailyScheduleStop(
              time: _formatTime(curHour, curMin),
              placeId: 'lunch_break',
              name: 'Late Lunch & Refreshment Break',
              activityType: 'meal',
              durationMinutes: 45,
              travelToNextMinutes: 10,
              openingHours: ['11:30 AM – 10:30 PM'],
              notes: 'Regional dining & afternoon refreshment',
            ),
          );
          final totalLateLunchMins = curMin + 45 + 10;
          curHour += totalLateLunchMins ~/ 60;
          curMin = totalLateLunchMins % 60;
          lunchAdded = true;
        }
      }

      // 4. Dinner Break (around 07:30 PM – 08:30 PM if evening concluded)
      if (curHour >= 19 && curHour < 21) {
        scheduleStops.add(
          DailyScheduleStop(
            time: _formatTime(curHour, curMin),
            placeId: 'dinner_break',
            name: 'Dinner & Evening Relaxation',
            activityType: 'meal',
            durationMinutes: 50,
            travelToNextMinutes: 15,
            openingHours: ['07:00 PM – 11:00 PM'],
            notes: 'Authentic local dinner & relaxing evening downtime',
          ),
        );
        final totalDinnerMins = curMin + 50 + 15;
        curHour += totalDinnerMins ~/ 60;
        curMin = totalDinnerMins % 60;
      }

      // 5. Night Arrival at Hotel (09:15 PM – 09:30 PM) with 9-hour restful sleep schedule
      final hotelArrivalTime = (curHour < 21 || (curHour == 21 && curMin < 15))
          ? '09:15 PM'
          : _formatTime(math.min(22, curHour), curMin);

      scheduleStops.add(
        DailyScheduleStop(
          time: hotelArrivalTime,
          placeId: 'end_point',
          name: 'End: $hotel',
          activityType: 'end',
          durationMinutes: 0,
          travelToNextMinutes: 0,
          openingHours: ['Open 24/7'],
          notes: (numDays > 1 && dayNumber < numDays)
              ? 'Hotel check-in & rest (sleep schedule: 10:00 PM – 07:30 AM • 9 hrs rest)'
              : 'Return to resting location (trip completion)',
        ),
      );

      // Compute actual daily totals from legs
      int dailyTravelMinutes = legs.fold(0, (sum, l) => sum + l.durationMinutes);
      double dailyTotalKm = legs.fold(0.0, (sum, l) => sum + l.distanceKm);
      if (dailyTravelMinutes == 0) dailyTravelMinutes = transitToFirstMins + 30;
      if (dailyTotalKm == 0) dailyTotalKm = firstLegDistanceKm + 10.0;

      days.add(
        DailySchedule(
          dayNumber: dayNumber,
          date: dateStr,
          summary: 'Day $dayNumber: ${dayStops.isNotEmpty ? dayStops.take(2).join(' & ') : "Exploration & Local Sights"}',
          stops: scheduleStops,
          dailyTotalTravelMinutes: dailyTravelMinutes,
          dailyTotalDistanceKm: double.parse(dailyTotalKm.toStringAsFixed(1)),
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

