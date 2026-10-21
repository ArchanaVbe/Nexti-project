import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RoadRouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final Duration duration;
  final String? distanceText;
  final String? durationText;

  RoadRouteResult({
    required this.points,
    required this.distanceKm,
    required this.duration,
    this.distanceText,
    this.durationText,
  });
}

class RouteLegInfo {
  final double distanceKm;
  final int durationMinutes;
  final String distanceText;
  final String durationText;

  const RouteLegInfo({
    required this.distanceKm,
    required this.durationMinutes,
    required this.distanceText,
    required this.durationText,
  });
}

class NavigationStep {
  final String instruction;
  final String maneuver; // 'turn-left', 'turn-right', 'u-turn', 'straight', 'roundabout', 'arrive', etc.
  final double distanceMeters;
  final String distanceText;
  final int durationSeconds;
  final String durationText;
  final LatLng startLocation;
  final LatLng endLocation;
  final List<LatLng> polylinePoints;

  const NavigationStep({
    required this.instruction,
    required this.maneuver,
    required this.distanceMeters,
    required this.distanceText,
    required this.durationSeconds,
    required this.durationText,
    required this.startLocation,
    required this.endLocation,
    this.polylinePoints = const [],
  });

  /// User friendly short banner title e.g. "Turn Left", "Turn Right", "Take a U-Turn"
  String get shortActionTitle {
    final m = maneuver.toLowerCase();
    final inst = instruction.toLowerCase();
    if (m.contains('uturn') || m.contains('u-turn') || inst.contains('u-turn') || inst.contains('uturn')) {
      return 'Take a U-Turn';
    }
    if (m.contains('left') || inst.contains('turn left') || inst.contains('bear left') || inst.contains('slight left')) {
      if (m.contains('slight') || inst.contains('slight')) return 'Slight Left';
      if (m.contains('sharp') || inst.contains('sharp')) return 'Sharp Left';
      return 'Turn Left';
    }
    if (m.contains('right') || inst.contains('turn right') || inst.contains('bear right') || inst.contains('slight right')) {
      if (m.contains('slight') || inst.contains('slight')) return 'Slight Right';
      if (m.contains('sharp') || inst.contains('sharp')) return 'Sharp Right';
      return 'Turn Right';
    }
    if (m.contains('roundabout') || inst.contains('roundabout')) {
      return 'At Roundabout';
    }
    if (m.contains('merge') || inst.contains('merge')) {
      return 'Merge Ahead';
    }
    if (inst.contains('destination') || inst.contains('arrive')) {
      return 'Arriving at Destination';
    }
    return 'Continue Straight';
  }
}

class DetailedRouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final Duration duration;
  final String distanceText;
  final String durationText;
  final List<NavigationStep> steps;

  const DetailedRouteResult({
    required this.points,
    required this.distanceKm,
    required this.duration,
    required this.distanceText,
    required this.durationText,
    required this.steps,
  });
}

class RoadRoutingService {
  static const String googleMapsApiKey = 'AIzaSyCSSBlacuia1G1BpjpbFHRSOUOXvkinYYQ';

  /// Calculate distance between two coordinates in meters
  static double calculateDistanceMeters(LatLng p1, LatLng p2) {
    return _calculateHaversine(p1, p2) * 1000.0;
  }

  /// Fetches a detailed turn-by-turn route with maneuvers and exact geometry
  static Future<DetailedRouteResult> getDetailedRoute(
    LatLng start,
    LatLng end, {
    String travelMode = 'DRIVE',
  }) async {
    final modeLower = travelMode.toLowerCase();
    String googleMode = 'driving';
    if (modeLower.contains('walk')) {
      googleMode = 'walking';
    } else if (modeLower.contains('bike') || modeLower.contains('bicycle')) {
      googleMode = 'bicycling';
    } else if (modeLower.contains('transit')) {
      googleMode = 'transit';
    }

    // 1. Try Google Maps Directions API
    try {
      final googleUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${start.latitude},${start.longitude}'
        '&destination=${end.latitude},${end.longitude}'
        '&mode=$googleMode'
        '&key=$googleMapsApiKey',
      );

      final response = await http.get(googleUrl).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final polylineStr = route['overview_polyline']?['points'] as String?;
          final leg = (route['legs'] as List).isNotEmpty ? route['legs'][0] : null;

          if (polylineStr != null && polylineStr.isNotEmpty && leg != null) {
            final decodedPoints = decodePolyline(polylineStr);
            final distMeters = (leg['distance']?['value'] as num?)?.toDouble() ?? 0.0;
            final durSeconds = (leg['duration']?['value'] as num?)?.toInt() ?? 0;
            final distText = leg['distance']?['text']?.toString() ?? '${(distMeters / 1000).toStringAsFixed(1)} km';
            final durText = leg['duration']?['text']?.toString() ?? '${(durSeconds / 60).ceil()} mins';

            final rawSteps = (leg['steps'] as List?) ?? [];
            final List<NavigationStep> navSteps = [];

            for (var rawStep in rawSteps) {
              final htmlInst = (rawStep['html_instructions'] ?? '').toString();
              final cleanInst = htmlInst
                  .replaceAll(RegExp(r'<[^>]*>'), ' ')
                  .replaceAll(RegExp(r'&nbsp;'), ' ')
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim();

              final stepDistM = (rawStep['distance']?['value'] as num?)?.toDouble() ?? 0.0;
              final stepDistTxt = rawStep['distance']?['text']?.toString() ?? '${stepDistM.toInt()} m';
              final stepDurS = (rawStep['duration']?['value'] as num?)?.toInt() ?? 0;
              final stepDurTxt = rawStep['duration']?['text']?.toString() ?? '${(stepDurS / 60).ceil()} min';

              final sLat = (rawStep['start_location']?['lat'] as num?)?.toDouble() ?? start.latitude;
              final sLng = (rawStep['start_location']?['lng'] as num?)?.toDouble() ?? start.longitude;
              final eLat = (rawStep['end_location']?['lat'] as num?)?.toDouble() ?? end.latitude;
              final eLng = (rawStep['end_location']?['lng'] as num?)?.toDouble() ?? end.longitude;

              final maneuver = (rawStep['maneuver'] ?? '').toString().toLowerCase();
              final stepPolyStr = rawStep['polyline']?['points'] as String?;
              final stepPoints = stepPolyStr != null ? decodePolyline(stepPolyStr) : <LatLng>[];

              navSteps.add(
                NavigationStep(
                  instruction: cleanInst.isNotEmpty ? cleanInst : 'Continue along route',
                  maneuver: maneuver.isNotEmpty ? maneuver : _deduceManeuver(cleanInst),
                  distanceMeters: stepDistM,
                  distanceText: stepDistTxt,
                  durationSeconds: stepDurS,
                  durationText: stepDurTxt,
                  startLocation: LatLng(sLat, sLng),
                  endLocation: LatLng(eLat, eLng),
                  polylinePoints: stepPoints,
                ),
              );
            }

            if (decodedPoints.isNotEmpty) {
              return DetailedRouteResult(
                points: decodedPoints,
                distanceKm: distMeters / 1000.0,
                duration: Duration(seconds: durSeconds),
                distanceText: distText,
                durationText: durText,
                steps: navSteps,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Google Detailed Directions error: $e');
    }

    // 2. Fallback to OSRM with steps
    try {
      final osrmUrl = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving'
        '/${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&steps=true&geometries=polyline',
      );

      final response = await http.get(osrmUrl).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'] as String?;
          final leg = (route['legs'] as List).isNotEmpty ? route['legs'][0] : null;

          if (geometry != null && geometry.isNotEmpty && leg != null) {
            final decodedPoints = decodePolyline(geometry);
            final distM = (route['distance'] as num?)?.toDouble() ?? 0.0;
            final durS = (route['duration'] as num?)?.toInt() ?? 0;
            final distKm = distM / 1000.0;
            final durMin = (durS / 60).ceil();

            final rawSteps = (leg['steps'] as List?) ?? [];
            final List<NavigationStep> navSteps = [];

            for (var rawStep in rawSteps) {
              final stepDistM = (rawStep['distance'] as num?)?.toDouble() ?? 0.0;
              final stepDurS = (rawStep['duration'] as num?)?.toInt() ?? 0;
              final stepName = (rawStep['name'] ?? '').toString();
              final manType = (rawStep['maneuver']?['type'] ?? '').toString();
              final manMod = (rawStep['maneuver']?['modifier'] ?? '').toString();

              String instruction = 'Continue on route';
              String maneuver = 'straight';

              if (manType == 'depart') {
                instruction = stepName.isNotEmpty ? 'Head on $stepName' : 'Start trip on road';
                maneuver = 'straight';
              } else if (manType == 'turn') {
                if (manMod.contains('left')) {
                  instruction = stepName.isNotEmpty ? 'Turn left onto $stepName' : 'Turn left';
                  maneuver = manMod.contains('slight') ? 'turn-slight-left' : 'turn-left';
                } else if (manMod.contains('right')) {
                  instruction = stepName.isNotEmpty ? 'Turn right onto $stepName' : 'Turn right';
                  maneuver = manMod.contains('slight') ? 'turn-slight-right' : 'turn-right';
                } else if (manMod.contains('uturn')) {
                  instruction = 'Take a U-turn';
                  maneuver = 'u-turn';
                }
              } else if (manType == 'arrive') {
                instruction = 'Arrive at destination';
                maneuver = 'arrive';
              }

              final locList = (rawStep['maneuver']?['location'] as List?) ?? [];
              final sLng = locList.isNotEmpty ? (locList[0] as num).toDouble() : start.longitude;
              final sLat = locList.length > 1 ? (locList[1] as num).toDouble() : start.latitude;

              navSteps.add(
                NavigationStep(
                  instruction: instruction,
                  maneuver: maneuver,
                  distanceMeters: stepDistM,
                  distanceText: stepDistM >= 1000 ? '${(stepDistM / 1000).toStringAsFixed(1)} km' : '${stepDistM.toInt()} m',
                  durationSeconds: stepDurS,
                  durationText: '${(stepDurS / 60).ceil()} min',
                  startLocation: LatLng(sLat, sLng),
                  endLocation: end,
                ),
              );
            }

            if (decodedPoints.isNotEmpty) {
              return DetailedRouteResult(
                points: decodedPoints,
                distanceKm: distKm,
                duration: Duration(seconds: durS),
                distanceText: '${distKm.toStringAsFixed(1)} km',
                durationText: '$durMin mins',
                steps: navSteps,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('OSRM Detailed Directions error: $e');
    }

    // 3. Fallback: Interpolated road steps
    final distKm = _calculateHaversine(start, end) * 1.35;
    final durMin = (distKm / 45 * 60).round();
    final List<LatLng> fallbackPoints = [
      start,
      LatLng((start.latitude * 2 + end.latitude) / 3, (start.longitude * 2 + end.longitude) / 3),
      LatLng((start.latitude + end.latitude * 2) / 3, (start.longitude + end.longitude * 2) / 3),
      end,
    ];

    return DetailedRouteResult(
      points: fallbackPoints,
      distanceKm: distKm,
      duration: Duration(minutes: max(5, durMin)),
      distanceText: '${distKm.toStringAsFixed(1)} km',
      durationText: '$durMin mins',
      steps: [
        NavigationStep(
          instruction: 'Head toward destination',
          maneuver: 'straight',
          distanceMeters: (distKm * 500),
          distanceText: '${(distKm * 0.5).toStringAsFixed(1)} km',
          durationSeconds: durMin * 30,
          durationText: '${durMin ~/ 2} mins',
          startLocation: start,
          endLocation: fallbackPoints[1],
        ),
        NavigationStep(
          instruction: 'Turn onto main connecting road',
          maneuver: 'turn-left',
          distanceMeters: (distKm * 500),
          distanceText: '${(distKm * 0.5).toStringAsFixed(1)} km',
          durationSeconds: durMin * 30,
          durationText: '${durMin ~/ 2} mins',
          startLocation: fallbackPoints[1],
          endLocation: end,
        ),
        NavigationStep(
          instruction: 'Arrive at destination',
          maneuver: 'arrive',
          distanceMeters: 50,
          distanceText: '50 m',
          durationSeconds: 30,
          durationText: '1 min',
          startLocation: fallbackPoints[2],
          endLocation: end,
        ),
      ],
    );
  }

  static String _deduceManeuver(String instruction) {
    final lower = instruction.toLowerCase();
    if (lower.contains('u-turn') || lower.contains('uturn')) return 'u-turn';
    if (lower.contains('turn left') || lower.contains('slight left') || lower.contains('sharp left')) return 'turn-left';
    if (lower.contains('turn right') || lower.contains('slight right') || lower.contains('sharp right')) return 'turn-right';
    if (lower.contains('roundabout')) return 'roundabout';
    if (lower.contains('merge')) return 'merge';
    if (lower.contains('arrive') || lower.contains('destination')) return 'arrive';
    return 'straight';
  }

  /// Fetches the real driving road route between two points using Google Maps Directions API,
  /// with automatic fallback to Open Source Routing Machine (OSRM).
  static Future<RoadRouteResult> getDrivingRoute(LatLng start, LatLng end) async {
    // 1. Try Google Maps Directions API (Official Google Maps highway & road routes)
    try {
      final googleUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${start.latitude},${start.longitude}'
        '&destination=${end.latitude},${end.longitude}'
        '&mode=driving'
        '&key=$googleMapsApiKey',
      );

      final response = await http.get(googleUrl).timeout(const Duration(seconds: 7));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final polylineStr = route['overview_polyline']?['points'] as String?;
          final leg = (route['legs'] as List).isNotEmpty ? route['legs'][0] : null;

          if (polylineStr != null && polylineStr.isNotEmpty) {
            final decodedPoints = decodePolyline(polylineStr);
            if (decodedPoints.isNotEmpty) {
              final distMeters = (leg?['distance']?['value'] as num?)?.toDouble() ?? 0;
              final durSeconds = (leg?['duration']?['value'] as num?)?.toInt() ?? 0;
              final distText = leg?['distance']?['text']?.toString();
              final durText = leg?['duration']?['text']?.toString();

              final distanceKm = distMeters > 0 ? (distMeters / 1000) : _calculateHaversine(start, end);
              final duration = durSeconds > 0 ? Duration(seconds: durSeconds) : _estimateDuration(distanceKm);

              return RoadRouteResult(
                points: decodedPoints,
                distanceKm: distanceKm,
                duration: duration,
                distanceText: distText,
                durationText: durText,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Google Directions note: $e');
    }

    // 2. High-speed Fallback: OSRM driving engine (returns real road geometry without API key limits)
    try {
      final osrmUrl = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving'
        '/${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=polyline',
      );

      final response = await http.get(osrmUrl).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'] as String?;
          if (geometry != null && geometry.isNotEmpty) {
            final decodedPoints = decodePolyline(geometry);
            if (decodedPoints.isNotEmpty) {
              final distMeters = (route['distance'] as num?)?.toDouble() ?? 0;
              final durSeconds = (route['duration'] as num?)?.toInt() ?? 0;
              final distanceKm = distMeters > 0 ? (distMeters / 1000) : _calculateHaversine(start, end);
              final duration = durSeconds > 0 ? Duration(seconds: durSeconds) : _estimateDuration(distanceKm);

              return RoadRouteResult(
                points: decodedPoints,
                distanceKm: distanceKm,
                duration: duration,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('OSRM routing note: $e');
    }

    // 3. Fallback when offline
    final distanceKm = _calculateHaversine(start, end);
    return RoadRouteResult(
      points: [start, end],
      distanceKm: distanceKm,
      duration: _estimateDuration(distanceKm),
    );
  }

  /// Decodes Google-encoded polyline string to a List of LatLng points
  static List<LatLng> decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return poly;
  }

  static double _calculateHaversine(LatLng start, LatLng end) {
    const earthRadiusKm = 6371.0;
    final dLat = (end.latitude - start.latitude) * pi / 180;
    final dLon = (end.longitude - start.longitude) * pi / 180;
    final lat1 = start.latitude * pi / 180;
    final lat2 = end.latitude * pi / 180;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static Duration _estimateDuration(double distanceKm) {
    final minutes = (distanceKm / 45 * 60).round();
    return Duration(minutes: max(5, minutes));
  }

  /// Calculates accurate travel time and distance for all legs of a multi-stop route
  /// (origin -> waypoints -> destination) using Google Maps Directions API,
  /// with automatic fallback to high-precision road calculation.
  static Future<List<RouteLegInfo>> getMultiStopRoute({
    required LatLng origin,
    required LatLng destination,
    required List<LatLng> waypoints,
    String travelMode = 'DRIVE',
  }) async {
    final List<RouteLegInfo> legs = [];

    // Map travel mode to Google Maps mode parameter
    final modeLower = travelMode.toLowerCase();
    String googleMode = 'driving';
    if (modeLower.contains('walk')) {
      googleMode = 'walking';
    } else if (modeLower.contains('bike') || modeLower.contains('bicycle')) {
      googleMode = 'bicycling';
    } else if (modeLower.contains('transit')) {
      googleMode = 'transit';
    }

    // 1. Try Google Maps Directions API with multi-point waypoints
    try {
      String url = 'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&mode=$googleMode'
          '&key=$googleMapsApiKey';

      if (waypoints.isNotEmpty) {
        final wpStr = waypoints.map((w) => '${w.latitude},${w.longitude}').join('|');
        url += '&waypoints=optimize:true|${Uri.encodeComponent(wpStr)}';
      }

      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
          final rawLegs = data['routes'][0]['legs'] as List?;
          if (rawLegs != null && rawLegs.isNotEmpty) {
            for (final leg in rawLegs) {
              final distM = (leg['distance']?['value'] as num?)?.toDouble() ?? 0.0;
              final durS = (leg['duration']?['value'] as num?)?.toInt() ?? 0;
              final distKm = distM > 0 ? (distM / 1000.0) : 10.0;
              final durMin = durS > 0 ? (durS / 60).ceil() : 15;
              final distTxt = leg['distance']?['text']?.toString() ?? '${distKm.toStringAsFixed(1)} km';
              final durTxt = leg['duration']?['text']?.toString() ?? '$durMin mins';

              legs.add(RouteLegInfo(
                distanceKm: double.parse(distKm.toStringAsFixed(1)),
                durationMinutes: durMin,
                distanceText: distTxt,
                durationText: durTxt,
              ));
            }

            if (legs.isNotEmpty) {
              return legs;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Google Multi-stop route note: $e');
    }

    // 2. High-Precision Offline Fallback Routing Engine
    // Computes realistic road distance and travel time for each leg
    final allStops = [origin, ...waypoints, destination];
    for (int i = 0; i < allStops.length - 1; i++) {
      final p1 = allStops[i];
      final p2 = allStops[i + 1];

      final straightKm = _calculateHaversine(p1, p2);

      // Karnataka Ghats / Winding terrain factor
      final inGhats = (p1.latitude >= 13.0 && p1.latitude <= 15.6 && p1.longitude >= 74.0 && p1.longitude <= 76.2) ||
                      (p2.latitude >= 13.0 && p2.latitude <= 15.6 && p2.longitude >= 74.0 && p2.longitude <= 76.2);
      final windingFactor = inGhats ? 1.52 : 1.32;
      final roadKm = straightKm * windingFactor;

      double speedKmh = 48.0;
      int bufferMin = 0;
      final modeUpper = travelMode.toUpperCase();

      if (modeUpper.contains('WALK')) {
        speedKmh = 4.5;
      } else if (modeUpper.contains('BIKE') || modeUpper.contains('BICYCLE')) {
        speedKmh = 15.0;
      } else if (modeUpper.contains('TRANSIT')) {
        speedKmh = 38.0;
        bufferMin = 20; // Terminal & boarding buffer
      } else {
        // DRIVE
        if (roadKm > 35) {
          speedKmh = inGhats ? 45.0 : 55.0; // Highway speed
        } else {
          speedKmh = 30.0; // In-city / local speed
        }
      }

      final durMins = max(5, ((roadKm / speedKmh) * 60).ceil() + bufferMin);
      final dText = '${roadKm.toStringAsFixed(1)} km';
      final h = durMins ~/ 60;
      final m = durMins % 60;
      final durText = h > 0 ? (m == 0 ? '$h hrs' : '$h hr $m mins') : '$m mins';

      legs.add(RouteLegInfo(
        distanceKm: double.parse(roadKm.toStringAsFixed(1)),
        durationMinutes: durMins,
        distanceText: dText,
        durationText: durText,
      ));
    }

    return legs;
  }
}

