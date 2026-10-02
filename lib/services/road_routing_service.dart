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

class RoadRoutingService {
  static const String googleMapsApiKey = 'AIzaSyCSSBlacuia1G1BpjpbFHRSOUOXvkinYYQ';

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
}
