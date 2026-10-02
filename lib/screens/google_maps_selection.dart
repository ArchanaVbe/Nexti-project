import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/karnataka_places.dart';
import '../services/road_routing_service.dart';
import '../services/trip_api.dart';

class GoogleMapsSelection extends StatefulWidget {
  final String? initialDestination;
  final String? initialStartPoint;
  final LatLng? initialDestinationLocation;

  const GoogleMapsSelection({
    super.key,
    this.initialDestination,
    this.initialStartPoint,
    this.initialDestinationLocation,
  });

  @override
  State<GoogleMapsSelection> createState() => _GoogleMapsSelectionState();
}

class _GoogleMapsSelectionState extends State<GoogleMapsSelection> {
  GoogleMapController? mapController;
  final Geocoding _geocoding = Geocoding();

  LatLng? currentLocation;
  LatLng? selectedDestination;
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  Set<Circle> circles = {};

  final TextEditingController currentLocationController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();

  double? distanceInKm;
  Duration? travelTime;
  bool isLoading = true;
  bool isFetchingLocation = false;
  bool isSearchingDestination = false;
  bool isCalculatingRoute = false;
  List<KarnatakaPlace> destinationSuggestions = [];

  // Popular quick-pick destinations
  final List<String> popularDestinations = [
    'Shimoga',
    'Coorg',
    'Mysuru',
    'Hampi',
    'Bengaluru',
    'Chikmagalur',
    'Gokarna',
    'Davanagere',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialStartPoint != null && widget.initialStartPoint!.isNotEmpty) {
      final init = widget.initialStartPoint!.trim();
      if (!init.startsWith('Location (') && !RegExp(r'^\s*\(?\s*\d+\.\d+').hasMatch(init)) {
        currentLocationController.text = init;
      }
    }
    if (widget.initialDestination != null && widget.initialDestination!.isNotEmpty) {
      destinationController.text = widget.initialDestination!;
    }
    if (widget.initialDestinationLocation != null) {
      selectedDestination = widget.initialDestinationLocation;
    }

    _fetchCurrentLocation();
  }

  String? _findNearestKarnatakaCity(double lat, double lng) {
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
      return closest.name.split(',').map((e) => e.trim()).take(2).join(', ');
    }
    return null;
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => isFetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Fallback default (Bengaluru) if GPS disabled
        _setDefaultLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _setDefaultLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _setDefaultLocation();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final fetchedLocation = LatLng(position.latitude, position.longitude);
      setState(() {
        currentLocation = fetchedLocation;
        isLoading = false;
        isFetchingLocation = false;
      });

      // Reverse geocode if start location text is empty or contains raw coordinate pattern
      final currentText = currentLocationController.text.trim();
      if (currentText.isEmpty || currentText.startsWith('Location (') || RegExp(r'^\s*\(?\s*\d+\.\d+').hasMatch(currentText)) {
        try {
          final placeName = await TripApi.reverseGeocode(position.latitude, position.longitude);
          if (placeName.isNotEmpty && mounted) {
            setState(() {
              currentLocationController.text = placeName;
            });
          }
        } catch (_) {}

        if (currentLocationController.text.isEmpty || currentLocationController.text.startsWith('Location (')) {
          final nearestCity = _findNearestKarnatakaCity(position.latitude, position.longitude);
          if (nearestCity != null && mounted) {
            setState(() {
              currentLocationController.text = nearestCity;
            });
          }
        }
      }

      _addCurrentLocationMarker();
      _updateMapCamera(fetchedLocation);

      // If initial destination was already passed, resolve and draw route
      if (widget.initialDestination != null && widget.initialDestination!.isNotEmpty) {
        _resolveDestinationAndRoute(widget.initialDestination!);
      }
    } catch (e) {
      _setDefaultLocation();
    }
  }

  void _setDefaultLocation() {
    // Default to Bengaluru center
    final fallback = const LatLng(12.9716, 77.5946);
    setState(() {
      currentLocation ??= fallback;
      if (currentLocationController.text.isEmpty) {
        currentLocationController.text = 'Bengaluru, Karnataka';
      }
      isLoading = false;
      isFetchingLocation = false;
    });
    _addCurrentLocationMarker();
    _updateMapCamera(currentLocation!);

    if (widget.initialDestination != null && widget.initialDestination!.isNotEmpty) {
      _resolveDestinationAndRoute(widget.initialDestination!);
    }
  }

  void _addCurrentLocationMarker() {
    if (currentLocation == null) return;
    setState(() {
      markers.removeWhere((m) => m.markerId.value == 'current');
      markers.add(
        Marker(
          markerId: const MarkerId('current'),
          position: currentLocation!,
          infoWindow: InfoWindow(
            title: 'Your Location',
            snippet: currentLocationController.text,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    });
  }

  Future<void> _updateMapCamera(LatLng position, {double zoom = 13}) async {
    if (!mounted || mapController == null) return;
    await mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: zoom),
      ),
    );
  }

  Future<void> _fitRouteBounds({List<LatLng>? points}) async {
    if (!mounted || mapController == null) return;
    if (currentLocation == null || selectedDestination == null) return;

    double minLat = min(currentLocation!.latitude, selectedDestination!.latitude);
    double maxLat = max(currentLocation!.latitude, selectedDestination!.latitude);
    double minLng = min(currentLocation!.longitude, selectedDestination!.longitude);
    double maxLng = max(currentLocation!.longitude, selectedDestination!.longitude);

    if (points != null && points.isNotEmpty) {
      for (final p in points) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    try {
      await mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 75),
      );
    } catch (_) {
      final center = LatLng(
        (minLat + maxLat) / 2,
        (minLng + maxLng) / 2,
      );
      await _updateMapCamera(center, zoom: 8);
    }
  }

  Future<void> _resolveDestinationAndRoute(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    setState(() => isSearchingDestination = true);

    LatLng? resolvedPos;
    String resolvedName = clean;

    // 1. Try Karnataka places registry for instantaneous exact/fuzzy match
    for (final p in KarnatakaPlacesRegistry.destinations) {
      final pName = p.name.toLowerCase();
      final qLower = clean.toLowerCase();
      if (pName.contains(qLower) || qLower.contains(p.name.split(',').first.toLowerCase())) {
        resolvedPos = LatLng(p.lat, p.lng);
        resolvedName = p.name.split(',').first.trim();
        break;
      }
      for (final kw in p.keywords) {
        if (kw.toLowerCase() == qLower || qLower.contains(kw.toLowerCase())) {
          resolvedPos = LatLng(p.lat, p.lng);
          resolvedName = p.name.split(',').first.trim();
          break;
        }
      }
      if (resolvedPos != null) break;
    }

    // 2. Fallback to geocoding if not in registry
    if (resolvedPos == null) {
      try {
        final locations = await _geocoding.locationFromAddress('$clean, Karnataka, India');
        if (locations.isNotEmpty) {
          resolvedPos = LatLng(locations[0].latitude, locations[0].longitude);
        }
      } catch (_) {
        try {
          final locations = await _geocoding.locationFromAddress(clean);
          if (locations.isNotEmpty) {
            resolvedPos = LatLng(locations[0].latitude, locations[0].longitude);
          }
        } catch (_) {}
      }
    }

    setState(() => isSearchingDestination = false);

    if (resolvedPos != null) {
      setState(() {
        selectedDestination = resolvedPos;
        destinationController.text = resolvedName;
        destinationSuggestions = [];
      });
      _drawRoute();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not locate "$clean". Tap on map to pin destination.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _onDestinationQueryChanged(String query) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      setState(() => destinationSuggestions = []);
      return;
    }

    final matches = KarnatakaPlacesRegistry.destinations.where((p) {
      final nameLower = p.name.toLowerCase();
      return nameLower.contains(clean) ||
          p.keywords.any((kw) => kw.toLowerCase().contains(clean));
    }).take(6).toList();

    setState(() {
      destinationSuggestions = matches;
    });
  }

  Future<void> _handleMapTap(LatLng position) async {
    setState(() {
      selectedDestination = position;
      destinationSuggestions = [];
    });

    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks[0];
        final parts = <String>[];
        final area = (p.subLocality != null && p.subLocality!.isNotEmpty)
            ? p.subLocality!
            : (p.street != null && p.street!.isNotEmpty && !p.street!.contains('+') && p.street != p.name)
                ? p.street!
                : (p.name != null && p.name!.isNotEmpty && !p.name!.contains('+'))
                    ? p.name!
                    : null;
        if (area != null && area.isNotEmpty) parts.add(area);

        final city = (p.locality != null && p.locality!.isNotEmpty)
            ? p.locality!
            : (p.subAdministrativeArea != null && p.subAdministrativeArea!.isNotEmpty)
                ? p.subAdministrativeArea!
                : null;
        if (city != null && city.isNotEmpty && !parts.contains(city)) parts.add(city);

        if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty && !parts.contains(p.administrativeArea)) {
          parts.add(p.administrativeArea!);
        }

        if (parts.isNotEmpty) {
          setState(() {
            destinationController.text = parts.join(', ');
          });
        }
      }
    } catch (_) {}

    if (destinationController.text.isEmpty || destinationController.text.contains(RegExp(r'\d+\.\d+'))) {
      final nearestCity = _findNearestKarnatakaCity(position.latitude, position.longitude);
      if (nearestCity != null && mounted) {
        setState(() {
          destinationController.text = 'near $nearestCity';
        });
      }
    }

    _drawRoute();
  }

  Future<void> _drawRoute() async {
    if (currentLocation == null || selectedDestination == null) return;

    final start = currentLocation!;
    final dest = selectedDestination!;

    // Initial instant preview calculations
    final initialDistance = _calculateDistance(start, dest);
    final initialTime = _estimateTravelTime(initialDistance);

    setState(() {
      isCalculatingRoute = true;
      distanceInKm = initialDistance;
      travelTime = initialTime;

      markers.clear();
      _addCurrentLocationMarker();

      // Destination Marker (Red pin with info)
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: dest,
          infoWindow: InfoWindow(
            title: destinationController.text.isNotEmpty
                ? destinationController.text
                : 'Destination',
            snippet: '${initialDistance.toStringAsFixed(1)} km away • ${_formatTravelTime(initialTime)}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );

      // Highlight Radius Circle (500m & 1.2km radius like Google Maps destination highlight)
      circles.clear();
      circles.add(
        Circle(
          circleId: const CircleId('radius_inner'),
          center: dest,
          radius: 500,
          fillColor: const Color(0xFF4285F4).withValues(alpha: 0.15),
          strokeColor: const Color(0xFF4285F4).withValues(alpha: 0.6),
          strokeWidth: 2,
        ),
      );
      circles.add(
        Circle(
          circleId: const CircleId('radius_outer'),
          center: dest,
          radius: 1200,
          fillColor: const Color(0xFF4285F4).withValues(alpha: 0.05),
          strokeColor: const Color(0xFF4285F4).withValues(alpha: 0.3),
          strokeWidth: 1,
        ),
      );
    });

    _fitRouteBounds();

    try {
      // Fetch actual road highway route using Google Maps Directions API (or high-speed OSRM fallback)
      final routeResult = await RoadRoutingService.getDrivingRoute(start, dest);
      if (!mounted) return;

      setState(() {
        isCalculatingRoute = false;
        distanceInKm = routeResult.distanceKm;
        travelTime = routeResult.duration;

        // Actual road route polyline (Google Maps Blue with smooth joints and end caps)
        polylines.clear();
        polylines.add(
          Polyline(
            polylineId: const PolylineId('route_preview'),
            points: routeResult.points,
            color: const Color(0xFF4285F4),
            width: 6,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            geodesic: true,
          ),
        );

        // Update destination marker info window with exact road driving distance & duration
        markers.removeWhere((m) => m.markerId.value == 'destination');
        markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: dest,
            infoWindow: InfoWindow(
              title: destinationController.text.isNotEmpty
                  ? destinationController.text
                  : 'Destination',
              snippet: '${routeResult.distanceKm.toStringAsFixed(1)} km by road • ${_formatTravelTime(routeResult.duration)}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        );
      });

      _fitRouteBounds(points: routeResult.points);
    } catch (e) {
      if (mounted) {
        setState(() => isCalculatingRoute = false);
      }
    }
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(end.latitude - start.latitude);
    final dLon = _toRadians(end.longitude - start.longitude);
    final lat1 = _toRadians(start.latitude);
    final lat2 = _toRadians(end.latitude);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRadians(double degree) => degree * pi / 180;

  Duration _estimateTravelTime(double distanceInKm) {
    // Average 45 km/h driving speed in mixed terrain + highway
    final minutes = (distanceInKm / 45 * 60).round();
    return Duration(minutes: max(1, minutes));
  }

  String _formatTravelTime(Duration d) {
    if (d.inHours > 0) {
      final mins = d.inMinutes % 60;
      return mins > 0 ? '${d.inHours} hr $mins min' : '${d.inHours} hr';
    }
    return '${d.inMinutes} mins';
  }

  void _handleDone() {
    if (selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or tap a destination on the map first.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final destName = destinationController.text.trim().isNotEmpty
        ? destinationController.text.trim()
        : 'Selected Destination';
    String cleanStart = currentLocationController.text.trim();
    if (cleanStart.isEmpty || cleanStart.startsWith('Location (') || RegExp(r'^\s*\(?\s*\d+\.\d+').hasMatch(cleanStart)) {
      if (currentLocation != null) {
        cleanStart = _findNearestKarnatakaCity(currentLocation!.latitude, currentLocation!.longitude) ?? 'Present Location, Karnataka';
      } else {
        cleanStart = 'Present Location, Karnataka';
      }
    }

    Navigator.pop(context, {
      'currentLocation': currentLocation,
      'destination': selectedDestination,
      'distance': distanceInKm,
      'travelTime': travelTime,
      'currentLocationName': cleanStart,
      'destinationName': destName,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Google Map View
            if (isLoading)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
              )
            else
              GoogleMap(
                onMapCreated: (GoogleMapController controller) {
                  mapController = controller;
                  if (currentLocation != null && selectedDestination != null) {
                    _fitRouteBounds();
                  }
                },
                initialCameraPosition: CameraPosition(
                  target: currentLocation ?? const LatLng(12.9716, 77.5946),
                  zoom: 12,
                ),
                markers: markers,
                polylines: polylines,
                circles: circles,
                onTap: _handleMapTap,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                compassEnabled: true,
                zoomControlsEnabled: false,
              ),

            // 2. Google Maps Navigation Header (Start & Destination Inputs + Directions)
            Positioned(
              top: 12,
              left: 14,
              right: 14,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row with Back button & Header
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Directions & Route Preview',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4285F4).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.directions_rounded,
                                color: Color(0xFF4285F4),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Starting Location Input
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4285F4),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 3),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: currentLocationController,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Your starting location...',
                                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                  isDense: true,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                                ),
                              ),
                            ),
                            if (isFetchingLocation)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4285F4)),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.my_location_rounded, color: Color(0xFF4285F4), size: 19),
                                tooltip: 'Fetch Current GPS Location',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: _fetchCurrentLocation,
                              ),
                          ],
                        ),

                        // Divider with dots
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0, top: 4.0, bottom: 4.0),
                          child: Row(
                            children: [
                              Column(
                                children: [
                                  Container(width: 2, height: 4, color: const Color(0xFFCBD5E1)),
                                  const SizedBox(height: 2),
                                  Container(width: 2, height: 4, color: const Color(0xFFCBD5E1)),
                                ],
                              ),
                              const SizedBox(width: 18),
                              const Expanded(
                                child: Divider(height: 1, thickness: 0.8, color: Color(0xFFE2E8F0)),
                              ),
                            ],
                          ),
                        ),

                        // Destination Location Input
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: Color(0xFFEA4335), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: destinationController,
                                onChanged: _onDestinationQueryChanged,
                                onSubmitted: _resolveDestinationAndRoute,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Enter destination or tap on map...',
                                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                  isDense: true,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                                ),
                              ),
                            ),
                            if (isSearchingDestination)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEA4335)),
                              )
                            else if (destinationController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.search_rounded, color: Color(0xFF6366F1), size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _resolveDestinationAndRoute(destinationController.text),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Destination Suggestions Dropdown
                  if (destinationSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: destinationSuggestions.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, thickness: 0.5),
                        itemBuilder: (context, index) {
                          final place = destinationSuggestions[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.place_rounded, color: Color(0xFFEA4335), size: 18),
                            title: Text(
                              place.name,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            onTap: () {
                              setState(() {
                                destinationController.text = place.name.split(',').first.trim();
                                selectedDestination = LatLng(place.lat, place.lng);
                                destinationSuggestions = [];
                              });
                              _drawRoute();
                            },
                          );
                        },
                      ),
                    ),

                  // Quick Popular City Chips
                  if (destinationSuggestions.isEmpty && selectedDestination == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: popularDestinations.map((city) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: ActionChip(
                                label: Text(city),
                                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                backgroundColor: const Color(0xFF1E293B).withValues(alpha: 0.85),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                onPressed: () {
                                  destinationController.text = city;
                                  _resolveDestinationAndRoute(city);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 3. Floating Re-Center / GPS Button on Right
            Positioned(
              right: 16,
              bottom: (distanceInKm != null) ? 180 : 90,
              child: FloatingActionButton.small(
                heroTag: 'gps_btn',
                backgroundColor: Colors.white,
                onPressed: () {
                  if (currentLocation != null) {
                    _updateMapCamera(currentLocation!, zoom: 14);
                  } else {
                    _fetchCurrentLocation();
                  }
                },
                child: const Icon(Icons.my_location_rounded, color: Color(0xFF4285F4)),
              ),
            ),

            // 4. Route Details Card (Travel Time, Distance & Radius)
            if (distanceInKm != null && travelTime != null)
              Positioned(
                bottom: 84,
                left: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4285F4).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: isCalculatingRoute
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Color(0xFF4285F4),
                                        ),
                                      )
                                    : const Icon(Icons.directions_car_rounded, color: Color(0xFF4285F4), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatTravelTime(travelTime!),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E8E3E), // Green travel time
                                    ),
                                  ),
                                  Text(
                                    isCalculatingRoute
                                        ? 'Finding actual road route...'
                                        : '${distanceInKm!.toStringAsFixed(1)} km • Fastest road route',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4285F4).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.radar_rounded, size: 14, color: Color(0xFF4285F4)),
                                SizedBox(width: 4),
                                Text(
                                  'Radius Active',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4285F4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // 5. Done Button at Bottom
            Positioned(
              bottom: 16,
              left: 14,
              right: 14,
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _handleDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4285F4), // Google Maps Primary Blue
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        selectedDestination != null ? 'Done • Set Destination' : 'Done',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    currentLocationController.dispose();
    destinationController.dispose();
    super.dispose();
  }
}