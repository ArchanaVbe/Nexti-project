import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;
import '../models/trip_plan_models.dart';
import '../services/karnataka_places.dart';
import '../services/road_routing_service.dart';
import '../services/one_day_trip_service.dart';
import '../services/group_trip_schedule_service.dart';
import '../services/trip_api.dart';

class TripDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  final int? tripIndex;
  final VoidCallback? onDelete;
  final bool isEmbedded;
  final ScrollController? scrollController;
  final void Function(Map<String, dynamic> updatedTrip)? onTripUpdated;

  const TripDetailsScreen({
    super.key,
    required this.trip,
    this.tripIndex,
    this.onDelete,
    this.isEmbedded = false,
    this.scrollController,
    this.onTripUpdated,
  });

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  GoogleMapController? _mapController;
  MapType _currentMapType = MapType.normal;
  bool _isMapExpanded = false;
  String? _selectedPlace;
  final Set<String> _visitedPlaces = {};
  int _selectedDayIndex = 0;
  List<Map<String, dynamic>>? _activeSchedule;
  List<Map<String, dynamic>>? _previousSchedule;

  late LatLng _destinationCenter;
  final Map<String, LatLng> _placeCoordinates = {};
  List<String> _allPlaces = [];
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // Direction & Turn-by-Turn Navigation State
  DetailedRouteResult? _activeDirectionRoute;
  NavigationStep? _currentNavStep;
  NavigationStep? _nextNavStep;
  int _currentStepIndex = 0;
  double _distanceToNextManeuverMeters = 0.0;
  bool _isNavigating = false;
  bool _isSimulating = false;
  Timer? _simulationTimer;
  int _simulationPointIndex = 0;
  LatLng? _userLiveLocation;
  double _userLiveHeading = 0.0;
  StreamSubscription<Position>? _positionStreamSub;
  String? _turnPopupToastMessage;
  Timer? _turnPopupToastTimer;

  ScrollController? _internalScrollController;
  ScrollController get _activeScrollController =>
      widget.scrollController ?? (_internalScrollController ??= ScrollController());

  // Known destination coordinates across Karnataka & South India
  static const Map<String, LatLng> _knownDestinations = {
    'shimoga': LatLng(13.9299, 75.5681),
    'shivamogga': LatLng(13.9299, 75.5681),
    'vinoba nagar': LatLng(13.9416, 75.5657),
    'vinobha nagar': LatLng(13.9416, 75.5657),
    'vinoba nagara': LatLng(13.9416, 75.5657),
    'vinobha nagara': LatLng(13.9416, 75.5657),
    'coorg': LatLng(12.4244, 75.7382),
    'kodagu': LatLng(12.4244, 75.7382),
    'madikeri': LatLng(12.4244, 75.7382),
    'hampi': LatLng(15.3350, 76.4600),
    'mysuru': LatLng(12.2958, 76.6394),
    'mysore': LatLng(12.2958, 76.6394),
    'chikmagalur': LatLng(13.3161, 75.7720),
    'chikkamagaluru': LatLng(13.3161, 75.7720),
    'gokarna': LatLng(14.5479, 74.3188),
    'badami': LatLng(15.9187, 75.6766),
    'dandeli': LatLng(15.2447, 74.6225),
    'kabini': LatLng(11.9261, 76.2711),
    'jog falls': LatLng(14.2285, 74.8125),
    'bengaluru': LatLng(12.9716, 77.5946),
    'bangalore': LatLng(12.9716, 77.5946),
    'mangalore': LatLng(12.9141, 74.8560),
    'mangaluru': LatLng(12.9141, 74.8560),
    'udupi': LatLng(13.3409, 74.7421),
    'belagavi': LatLng(15.8497, 74.4977),
    'belgaum': LatLng(15.8497, 74.4977),
    'hubballi': LatLng(15.3647, 75.1240),
    'hubli': LatLng(15.3647, 75.1240),
    'hassan': LatLng(13.0033, 76.1004),
    'murudeshwar': LatLng(14.0940, 74.4899),
    'wayanad': LatLng(11.6854, 76.1320),
    'ooty': LatLng(11.4102, 76.6950),
    'goa': LatLng(15.2993, 74.1240),
  };

  // Specific spot coordinates for realistic mapping
  static const Map<String, LatLng> _knownPlaces = {
    // Shimoga places
    'mountain trek': LatLng(13.8560, 74.8732), // Kodachadri / Western Ghats trek
    'sunset point': LatLng(13.5042, 75.0934), // Agumbe sunset view
    'botanical garden': LatLng(14.0042, 75.5218), // Tyavarekoppa Safari / Garden
    'historic fort': LatLng(13.7196, 75.1218), // Kavaledurga Fort
    'local market': LatLng(13.9320, 75.5695), // Gandhi Bazaar Shimoga
    'handicraft street': LatLng(13.9350, 75.5640), // Nehru Road Handicrafts
    'river rafting': LatLng(13.9180, 75.5800), // Tunga River
    'rock climbing': LatLng(13.5574, 75.1706), // Kundadri Peak
    'lake view': LatLng(13.8550, 75.5340), // Gajanur Dam
    'ancient temple': LatLng(14.2185, 75.0118), // Keladi Rameshwara
    'old city walk': LatLng(13.9310, 75.5660),

    // Coorg places
    'abbey falls': LatLng(12.4542, 75.7180),
    "raja's seat": LatLng(12.4172, 75.7360),
    'dubare elephant camp': LatLng(12.3685, 75.9042),
    'talakaveri': LatLng(12.3840, 75.4920),

    // Hampi places
    'virupaksha temple': LatLng(15.3353, 76.4597),
    'stone chariot': LatLng(15.3392, 76.4789),
    'vittala temple': LatLng(15.3392, 76.4789),
    'matanga hill': LatLng(15.3320, 76.4680),

    // Mysuru places
    'mysore palace': LatLng(12.3051, 76.6551),
    'chamundi hill': LatLng(12.2725, 76.6710),
    'brindavan gardens': LatLng(12.4242, 76.5724),
    'st. philomena church': LatLng(12.3210, 76.6580),
  };

  @override
  void initState() {
    super.initState();
    final rawPlaces = (widget.trip['places'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final daysCount = _calculateDaysCount();
    _activeSchedule = _buildDailySchedule(rawPlaces, daysCount);
    _initializeCoordinatesAndMarkers();
    _initLiveUserLocation();
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _simulationTimer?.cancel();
    _turnPopupToastTimer?.cancel();
    _mapController?.dispose();
    _internalScrollController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TripDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPlaces = (oldWidget.trip['places'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final newPlaces = (widget.trip['places'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final placesChanged = !listEquals(oldPlaces, newPlaces);
    final planChanged = widget.trip['itineraryPlan'] != oldWidget.trip['itineraryPlan'];
    final datesChanged = widget.trip['startDate'] != oldWidget.trip['startDate'] ||
        widget.trip['endDate'] != oldWidget.trip['endDate'];

    if (_activeSchedule == null || placesChanged || planChanged || datesChanged) {
      final daysCount = _calculateDaysCount();
      _activeSchedule = _buildDailySchedule(newPlaces, daysCount);
    }
    _initializeCoordinatesAndMarkers();
    if (_mapController != null) {
      _resetMapBounds();
    }
  }

  void _initializeCoordinatesAndMarkers() {
    final destRaw = (widget.trip['destination'] ?? 'Karnataka').toString().trim();
    final destKey = destRaw.toLowerCase();

    // 1. Resolve destination center using KarnatakaPlacesRegistry or known destinations
    final resolvedCenter = KarnatakaPlacesRegistry.resolvePlace(destRaw);
    if (resolvedCenter != null) {
      _destinationCenter = LatLng(resolvedCenter.lat, resolvedCenter.lng);
    } else if (_knownDestinations.containsKey(destKey)) {
      _destinationCenter = _knownDestinations[destKey]!;
    } else {
      // Default to central Karnataka
      _destinationCenter = const LatLng(15.3173, 75.7139);
    }

    var rawPlaces = (widget.trip['places'] as List?)?.map((e) => e.toString()).toList() ?? [];
    // Sanitize to only strictly voted/selected places (no current-location strings, GPS coordinates, or generic stops)
    rawPlaces = rawPlaces.where((p) {
      final l = p.trim().toLowerCase();
      return l.isNotEmpty &&
          !l.startsWith('day ') &&
          !l.startsWith('stop_') &&
          !l.startsWith('local_') &&
          !l.startsWith('start:') &&
          l != 'starting point' &&
          !l.startsWith('location (') &&
          !l.startsWith('present location') &&
          !l.contains('taralabalu') &&
          !l.contains('layout rd') &&
          !RegExp(r'^\s*\(?\s*-?\d+\.\d+').hasMatch(l) &&
          !l.endsWith(' hotel') &&
          !l.endsWith(' resort');
    }).toList();

    if (rawPlaces.isEmpty) {
      final curated = KarnatakaPlacesRegistry.getCuratedAttractions(destRaw);
      if (curated.isNotEmpty) {
        rawPlaces = curated.take(6).map((p) => p.name).toList();
      }
    }

    final Map<String, dynamic>? explicitCoords = widget.trip['placeCoordinates'] is Map
        ? Map<String, dynamic>.from(widget.trip['placeCoordinates'] as Map)
        : null;

    _placeCoordinates.clear();
    _allPlaces = rawPlaces;

    final markers = <Marker>{};
    final routePoints = <LatLng>[];

    // Optional hotel marker if available (does not distort the primary attraction sequence)
    final hotelName = widget.trip['hotel']?.toString();
    final hotelLat = (widget.trip['hotelLat'] as num?)?.toDouble();
    final hotelLng = (widget.trip['hotelLng'] as num?)?.toDouble();
    if (hotelLat != null && hotelLng != null && hotelLat != 0.0 && hotelLng != 0.0) {
      final hotelPos = LatLng(hotelLat, hotelLng);
      markers.add(
        Marker(
          markerId: const MarkerId('trip_hotel'),
          position: hotelPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: hotelName != null && hotelName.isNotEmpty ? hotelName : 'Selected Hotel / Stay',
            snippet: 'Stay / Accommodation Base',
          ),
        ),
      );
    }

    // 2. Resolve place coordinates
    for (int i = 0; i < rawPlaces.length; i++) {
      final place = rawPlaces[i];
      final placeKey = place.toLowerCase().trim();

      LatLng? coordinate;

      // A. Check explicit coordinates passed from creation or sync
      if (explicitCoords != null && explicitCoords.containsKey(place)) {
        final c = explicitCoords[place];
        if (c is Map && c['lat'] != null && c['lng'] != null) {
          final lat = (c['lat'] as num).toDouble();
          final lng = (c['lng'] as num).toDouble();
          if (lat != 0.0 || lng != 0.0) {
            coordinate = LatLng(lat, lng);
          }
        }
      }

      // B. Lookup in KarnatakaPlacesRegistry
      if (coordinate == null) {
        final regCoord = KarnatakaPlacesRegistry.findPlaceCoordinate(place, destination: destRaw);
        if (regCoord != null) {
          coordinate = LatLng(regCoord.lat, regCoord.lng);
        }
      }

      // C. Lookup in legacy known places map
      if (coordinate == null && _knownPlaces.containsKey(placeKey)) {
        coordinate = _knownPlaces[placeKey]!;
      }

      // D. Fallback: space out around center
      if (coordinate == null) {
        final angle = (i * (2 * math.pi / (rawPlaces.isEmpty ? 1 : rawPlaces.length))) + 0.35;
        final distanceDegrees = 0.025 + ((i % 3) * 0.022); // roughly 3km - 8km offset
        final latOffset = distanceDegrees * math.sin(angle);
        final lngOffset = distanceDegrees * math.cos(angle);
        coordinate = LatLng(_destinationCenter.latitude + latOffset, _destinationCenter.longitude + lngOffset);
      }

      _placeCoordinates[place] = coordinate;
      routePoints.add(coordinate);

      // Add marker for each place
      final isSelected = _selectedPlace == place;
      markers.add(
        Marker(
          markerId: MarkerId('place_$i'),
          position: coordinate,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isSelected ? BitmapDescriptor.hueRed : BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(
            title: '${i + 1}. $place',
            snippet: 'Stop ${i + 1} on your itinerary',
            onTap: () {
              _focusOnPlace(place);
            },
          ),
          onTap: () {
            _focusOnPlace(place);
          },
        ),
      );
    }

    // Connect places with a route polyline
    final polylines = <Polyline>{};
    if (routePoints.length > 1) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('trip_route'),
          points: routePoints,
          color: const Color(0xFF6366F1).withValues(alpha: 0.6),
          width: 3,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    }

    setState(() {
      _markers = markers;
      _polylines = polylines;
    });
  }

  Future<void> _initLiveUserLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 4),
              ),
            );
        if (mounted) {
          setState(() {
            _userLiveLocation = LatLng(pos.latitude, pos.longitude);
            _userLiveHeading = pos.heading;
          });
        }
      }
    } catch (_) {}
  }

  void _triggerTurnPopupToast(String message) {
    _turnPopupToastTimer?.cancel();
    setState(() {
      _turnPopupToastMessage = message;
    });
    _turnPopupToastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _turnPopupToastMessage = null;
        });
      }
    });
  }

  static double _calculateBearing(LatLng start, LatLng end) {
    final startLat = start.latitude * math.pi / 180;
    final startLng = start.longitude * math.pi / 180;
    final endLat = end.latitude * math.pi / 180;
    final endLng = end.longitude * math.pi / 180;

    final dLng = endLng - startLng;
    final y = math.sin(dLng) * math.cos(endLat);
    final x = math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(dLng);
    final bearing = math.atan2(y, x);
    return (bearing * 180 / math.pi + 360) % 360;
  }

  static String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }

  IconData _getManeuverIcon(String maneuver) {
    final m = maneuver.toLowerCase();
    if (m.contains('uturn') || m.contains('u-turn')) return Icons.u_turn_left_rounded;
    if (m.contains('left')) return Icons.turn_left_rounded;
    if (m.contains('right')) return Icons.turn_right_rounded;
    if (m.contains('roundabout')) return Icons.roundabout_right_rounded;
    if (m.contains('arrive')) return Icons.flag_rounded;
    return Icons.straight_rounded;
  }

  Color _getManeuverColor(String maneuver) {
    final m = maneuver.toLowerCase();
    if (m.contains('uturn') || m.contains('u-turn')) return const Color(0xFFF59E0B);
    if (m.contains('left')) return const Color(0xFF10B981);
    if (m.contains('right')) return const Color(0xFF3B82F6);
    if (m.contains('arrive')) return const Color(0xFF8B5CF6);
    return const Color(0xFF6366F1);
  }

  Future<void> _startTripNavigation({bool simulate = false}) async {
    if (_allPlaces.isEmpty) return;
    final firstPlace = _allPlaces.first;
    final destPos = _placeCoordinates[firstPlace] ?? _destinationCenter;

    LatLng origin;
    if (_userLiveLocation != null) {
      origin = _userLiveLocation!;
    } else {
      final sLat = (widget.trip['startLat'] as num?)?.toDouble();
      final sLng = (widget.trip['startLng'] as num?)?.toDouble();
      if (sLat != null && sLng != null && sLat != 0.0 && sLng != 0.0) {
        origin = LatLng(sLat, sLng);
      } else {
        origin = _destinationCenter;
      }
    }

    try {
      final route = await RoadRoutingService.getDetailedRoute(
        origin,
        destPos,
        travelMode: widget.trip['travelMode']?.toString() ?? 'DRIVE',
      );
      if (!mounted) return;
      setState(() {
        _activeDirectionRoute = route;
        _currentStepIndex = 0;
        _currentNavStep = route.steps.isNotEmpty ? route.steps[0] : null;
        _nextNavStep = route.steps.length > 1 ? route.steps[1] : null;
      });
      if (simulate) {
        _startSimulatedNavigation();
      } else {
        await _startLiveNavigation();
      }
    } catch (_) {}
  }

  void _stopNavigation() {
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
    _simulationTimer?.cancel();
    _simulationTimer = null;
    if (mounted) {
      setState(() {
        _isNavigating = false;
        _isSimulating = false;
        _activeDirectionRoute = null;
        _currentNavStep = null;
        _nextNavStep = null;
        _turnPopupToastMessage = null;
      });
      _updateMarkers();
      _resetMapBounds();
    }
  }

  Future<void> _startLiveNavigation() async {
    if (_activeDirectionRoute == null) return;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable GPS / Location services to navigate.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission required for turn-by-turn navigation.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission denied permanently. Please enable in settings.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _stopNavigation();

    setState(() {
      _isNavigating = true;
      _isSimulating = false;
      _currentStepIndex = 0;
      _currentNavStep = _activeDirectionRoute!.steps.isNotEmpty
          ? _activeDirectionRoute!.steps[0]
          : null;
      _nextNavStep = _activeDirectionRoute!.steps.length > 1
          ? _activeDirectionRoute!.steps[1]
          : null;
    });

    HapticFeedback.mediumImpact();
    _triggerTurnPopupToast('Live Navigation Started • GPS Active');

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    );

    _positionStreamSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen((pos) {
      _onUserPositionUpdated(LatLng(pos.latitude, pos.longitude), heading: pos.heading);
    });

    try {
      final curPos = await Geolocator.getCurrentPosition();
      _onUserPositionUpdated(LatLng(curPos.latitude, curPos.longitude), heading: curPos.heading);
    } catch (_) {}
  }

  void _startSimulatedNavigation() {
    if (_activeDirectionRoute == null || _activeDirectionRoute!.points.isEmpty) return;

    _stopNavigation();

    final allPoints = _activeDirectionRoute!.points;
    final allSteps = _activeDirectionRoute!.steps;

    setState(() {
      _isNavigating = true;
      _isSimulating = true;
      _simulationPointIndex = 0;
      _currentStepIndex = 0;
      _currentNavStep = allSteps.isNotEmpty ? allSteps[0] : null;
      _nextNavStep = allSteps.length > 1 ? allSteps[1] : null;
      _userLiveLocation = allPoints.first;
    });

    HapticFeedback.mediumImpact();
    _triggerTurnPopupToast('Demo Simulation Started • Watch turns');

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _userLiveLocation!, zoom: 16.5, tilt: 35.0),
      ),
    );

    final stride = math.max(1, (allPoints.length / 25).floor());

    _simulationTimer = Timer.periodic(const Duration(milliseconds: 1400), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      int nextIdx = _simulationPointIndex + stride;
      if (nextIdx >= allPoints.length) {
        nextIdx = allPoints.length - 1;
        timer.cancel();
        setState(() {
          _isSimulating = false;
        });
        HapticFeedback.vibrate();
        _triggerTurnPopupToast('Arrived at ${_allPlaces.isNotEmpty ? _allPlaces.first : "Destination"}!');
      }

      _simulationPointIndex = nextIdx;
      final currentPos = allPoints[nextIdx];

      double bearing = 0.0;
      if (nextIdx + 1 < allPoints.length) {
        bearing = _calculateBearing(currentPos, allPoints[nextIdx + 1]);
      }

      _onUserPositionUpdated(currentPos, heading: bearing);
    });
  }

  void _onUserPositionUpdated(LatLng userPos, {double? heading}) {
    if (!mounted || _activeDirectionRoute == null) return;

    setState(() {
      _userLiveLocation = userPos;
      _userLiveHeading = heading ?? _userLiveHeading;

      final markers = Set<Marker>.from(_markers);
      markers.removeWhere((m) => m.markerId.value == 'user_live_location');
      markers.add(
        Marker(
          markerId: const MarkerId('user_live_location'),
          position: userPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          rotation: heading ?? 0.0,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Moving along route',
          ),
          zIndexInt: 10,
        ),
      );
      _markers = markers;

      if (_currentNavStep != null) {
        final distToStepEnd = RoadRoutingService.calculateDistanceMeters(
          userPos,
          _currentNavStep!.endLocation,
        );
        _distanceToNextManeuverMeters = distToStepEnd;

        if (distToStepEnd < 35 && _currentStepIndex + 1 < _activeDirectionRoute!.steps.length) {
          _currentStepIndex++;
          _currentNavStep = _activeDirectionRoute!.steps[_currentStepIndex];
          _nextNavStep = (_currentStepIndex + 1 < _activeDirectionRoute!.steps.length)
              ? _activeDirectionRoute!.steps[_currentStepIndex + 1]
              : null;

          HapticFeedback.heavyImpact();
          _triggerTurnPopupToast(_currentNavStep!.shortActionTitle);
        }
      }
    });

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: userPos,
          zoom: 16.5,
          tilt: 35.0,
          bearing: heading ?? 0.0,
        ),
      ),
    );
  }

  void _focusOnPlace(String place) {
    setState(() {
      _selectedPlace = place;
    });
    _updateMarkers();

    final coordinate = _placeCoordinates[place];
    if (coordinate != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: coordinate, zoom: 14.5),
        ),
      );

      // Smooth scroll back to top to view map
      if (_activeScrollController.hasClients) {
        _activeScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _clearSelectedPlace() {
    setState(() {
      _selectedPlace = null;
    });
    _updateMarkers();
    _resetMapBounds();
  }

  void _updateMarkers() {
    final markers = <Marker>{};

    // Re-add hotel if exists
    final hotelName = widget.trip['hotel']?.toString();
    final hotelLat = (widget.trip['hotelLat'] as num?)?.toDouble();
    final hotelLng = (widget.trip['hotelLng'] as num?)?.toDouble();
    if (hotelLat != null && hotelLng != null && hotelLat != 0.0 && hotelLng != 0.0) {
      markers.add(
        Marker(
          markerId: const MarkerId('trip_hotel'),
          position: LatLng(hotelLat, hotelLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: hotelName != null && hotelName.isNotEmpty ? hotelName : 'Selected Hotel / Stay',
            snippet: 'Stay / Accommodation Base',
          ),
        ),
      );
    }

    // Re-add destination center
    final destRaw = widget.trip['destination']?.toString() ?? 'Destination';
    markers.add(
      Marker(
        markerId: const MarkerId('destination_center'),
        position: _destinationCenter,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        infoWindow: InfoWindow(
          title: '$destRaw Center',
          snippet: 'Trip Base Destination',
        ),
      ),
    );

    // Re-add user live location marker if active
    if (_userLiveLocation != null && _isNavigating) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_live_location'),
          position: _userLiveLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          rotation: _userLiveHeading,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Moving along route',
          ),
          zIndexInt: 10,
        ),
      );
    }

    // Re-add place markers with selected color
    for (int i = 0; i < _allPlaces.length; i++) {
      final place = _allPlaces[i];
      final coordinate = _placeCoordinates[place];
      if (coordinate == null) continue;
      final isSelected = _selectedPlace == place;
      markers.add(
        Marker(
          markerId: MarkerId('place_$i'),
          position: coordinate,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isSelected ? BitmapDescriptor.hueRed : BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(
            title: '${i + 1}. $place',
            snippet: 'Stop ${i + 1} on your itinerary',
            onTap: () {
              _focusOnPlace(place);
            },
          ),
          onTap: () {
            _focusOnPlace(place);
          },
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  void _resetMapBounds() {
    if (_mapController == null) return;

    if (_placeCoordinates.isEmpty) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_destinationCenter, 11),
      );
      return;
    }

    final firstCoord = _placeCoordinates.values.first;
    double minLat = firstCoord.latitude;
    double maxLat = firstCoord.latitude;
    double minLng = firstCoord.longitude;
    double maxLng = firstCoord.longitude;

    for (var pos in _placeCoordinates.values) {
      minLat = math.min(minLat, pos.latitude);
      maxLat = math.max(maxLat, pos.latitude);
      minLng = math.min(minLng, pos.longitude);
      maxLng = math.max(maxLng, pos.longitude);
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat - 0.02, minLng - 0.02),
      northeast: LatLng(maxLat + 0.02, maxLng + 0.02),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  IconData _getCategoryIcon(String place, [String? stopType]) {
    final sType = stopType?.toUpperCase() ?? '';
    if (sType == 'MEAL') return Icons.restaurant_rounded;
    if (sType == 'TRANSIT') return Icons.directions_car_rounded;
    if (sType == 'BREAK') return Icons.coffee_rounded;
    if (sType == 'START' || sType == 'END') return Icons.hotel_rounded;
    if (sType == 'LEISURE') return Icons.park_rounded;

    final lower = place.toLowerCase();
    if (lower.contains('trek') || lower.contains('mountain') || lower.contains('climb') || lower.contains('rafting') || lower.contains('adventure')) {
      return Icons.terrain_rounded;
    } else if (lower.contains('sunset') || lower.contains('lake') || lower.contains('garden') || lower.contains('falls') || lower.contains('nature') || lower.contains('forest') || lower.contains('park')) {
      return Icons.wb_twilight_rounded;
    } else if (lower.contains('fort') || lower.contains('temple') || lower.contains('ancient') || lower.contains('palace') || lower.contains('culture') || lower.contains('museum')) {
      return Icons.castle_rounded;
    } else if (lower.contains('market') || lower.contains('street') || lower.contains('shop') || lower.contains('food') || lower.contains('dining') || lower.contains('cuisine')) {
      return Icons.restaurant_rounded;
    } else if (lower.contains('sightseeing') || lower.contains('view') || lower.contains('square')) {
      return Icons.photo_camera_rounded;
    }
    return Icons.place_rounded;
  }

  Color _getCategoryColor(String place, [String? stopType]) {
    final sType = stopType?.toUpperCase() ?? '';
    if (sType == 'MEAL') return const Color(0xFFF43F5E);
    if (sType == 'TRANSIT') return const Color(0xFF3B82F6);
    if (sType == 'BREAK') return const Color(0xFF10B981);
    if (sType == 'START' || sType == 'END') return const Color(0xFF6366F1);
    if (sType == 'LEISURE') return const Color(0xFF0D9488);

    final lower = place.toLowerCase();
    if (lower.contains('trek') || lower.contains('mountain') || lower.contains('climb') || lower.contains('rafting') || lower.contains('adventure')) {
      return const Color(0xFFEA580C); // Warm Orange for Adventure
    } else if (lower.contains('sunset') || lower.contains('lake') || lower.contains('garden') || lower.contains('falls') || lower.contains('nature') || lower.contains('forest')) {
      return const Color(0xFF0D9488); // Teal for Nature
    } else if (lower.contains('fort') || lower.contains('temple') || lower.contains('ancient') || lower.contains('palace') || lower.contains('culture') || lower.contains('museum')) {
      return const Color(0xFF7C3AED); // Purple for Heritage
    } else if (lower.contains('market') || lower.contains('street') || lower.contains('shop') || lower.contains('food')) {
      return const Color(0xFFE11D48); // Rose for Food/Shopping
    } else if (lower.contains('sightseeing') || lower.contains('view')) {
      return const Color(0xFF0284C7); // Sky for Sightseeing
    }
    return const Color(0xFF6366F1);
  }

  List<String> _getItineraryWarnings() {
    final planData = widget.trip['itineraryPlan'];
    if (planData != null) {
      try {
        final Map<String, dynamic> planMap = planData is Map<String, dynamic>
            ? planData
            : (planData is ItineraryPlan ? planData.toJson() : Map<String, dynamic>.from(planData));
        final warningsList = planMap['warnings'] as List?;
        if (warningsList != null && warningsList.isNotEmpty) {
          return warningsList.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  int _calculateDaysCount() {
    final startStr = widget.trip['startDate']?.toString() ?? '';
    final endStr = widget.trip['endDate']?.toString() ?? '';

    try {
      DateTime? parseDate(String s) {
        final parts = s.split(RegExp(r'[/.-]'));
        if (parts.length == 3) {
          int d = int.parse(parts[0]);
          int m = int.parse(parts[1]);
          int y = int.parse(parts[2]);
          if (y < 100) y += 2000;
          return DateTime(y, m, d);
        }
        return null;
      }

      final start = parseDate(startStr);
      final end = parseDate(endStr);
      if (start != null && end != null) {
        final diff = end.difference(start).inDays + 1;
        return diff > 0 ? diff : 1;
      }
    } catch (_) {}

    return 3; // Default realistic duration
  }

  List<Map<String, dynamic>> _buildDailySchedule(List<String> places, int days) {
    final destination = widget.trip['destination'] ?? widget.trip['tripName'] ?? 'Karnataka';
    final startStr = widget.trip['startDate']?.toString() ?? '';
    final endStr = widget.trip['endDate']?.toString() ?? '';
    final hotel = widget.trip['hotel']?.toString();

    // Parse date strings for each day
    final List<String> dateStrings = [];
    try {
      DateTime? parseDate(String s) {
        final parts = s.split(RegExp(r'[/.-]'));
        if (parts.length == 3) {
          int d = int.parse(parts[0]);
          int m = int.parse(parts[1]);
          int y = int.parse(parts[2]);
          if (y < 100) y += 2000;
          return DateTime(y, m, d);
        }
        return null;
      }

      final start = parseDate(startStr);
      final end = parseDate(endStr);
      if (start != null && end != null) {
        DateTime cur = start;
        while (!cur.isAfter(end) && dateStrings.length < days) {
          dateStrings.add('${cur.day.toString().padLeft(2, '0')}/${cur.month.toString().padLeft(2, '0')}/${cur.year}');
          cur = cur.add(const Duration(days: 1));
        }
      }
    } catch (_) {}

    final cleanVotedPlaces = places.where((p) {
      final l = p.trim().toLowerCase();
      return l.isNotEmpty &&
          !l.startsWith('day ') &&
          !l.startsWith('stop_') &&
          !l.startsWith('local_') &&
          !l.startsWith('start:') &&
          l != 'starting point' &&
          !l.startsWith('location (') &&
          !l.startsWith('present location') &&
          !l.contains('taralabalu') &&
          !l.contains('layout rd') &&
          !RegExp(r'^\s*\(?\s*-?\d+\.\d+').hasMatch(l) &&
          !l.endsWith(' hotel') &&
          !l.endsWith(' resort');
    }).toList();

    bool hasDisallowedStops(List<Map<String, dynamic>> sched) {
      for (final d in sched) {
        final acts = (d['activities'] as List?) ?? (d['stops'] as List?) ?? [];
        for (final a in acts) {
          if (a is Map) {
            final name = (a['place'] ?? a['name'] ?? '').toString().toLowerCase();
            final addr = (a['address'] ?? '').toString().toLowerCase();
            final st = (a['stopType'] ?? a['period'] ?? a['activity_type'] ?? '').toString().toUpperCase();
            if (st == 'START' ||
                name.startsWith('start:') ||
                name.contains('cultural discovery') ||
                name.contains('twilight stroll') ||
                name.contains('artisan bazaars') ||
                name.contains('heritage street walk') ||
                name.contains('golden hour sunset') ||
                name.contains('sunset viewpoint') ||
                addr.contains('taralabalu') ||
                addr.contains('layout rd') ||
                addr.startsWith('location (')) {
              return true;
            }
          }
        }
      }
      return false;
    }

    // 0. If replannedPlan exists, prioritize it directly if it has no disallowed fake stops
    if (widget.trip['replannedPlan'] is List && (widget.trip['replannedPlan'] as List).isNotEmpty) {
      final repList = widget.trip['replannedPlan'] as List;
      final List<Map<String, dynamic>> parsedReplanned = [];
      for (var d in repList) {
        final dMap = Map<String, dynamic>.from(d as Map);
        final rawActs = (dMap['activities'] as List?) ?? (dMap['stops'] as List?) ?? [];
        final List<Map<String, String>> acts = rawActs.map((a) {
          final aMap = Map<String, dynamic>.from(a as Map);
          return {
            'place': (aMap['place'] ?? aMap['name'] ?? aMap['place_name'] ?? 'Scheduled Stop').toString(),
            'name': (aMap['place'] ?? aMap['name'] ?? aMap['place_name'] ?? 'Scheduled Stop').toString(),
            'time': (aMap['time'] ?? 'Flexible Time').toString(),
            'period': (aMap['period'] ?? aMap['stopType'] ?? aMap['activity_type'] ?? 'VISIT').toString().toUpperCase(),
            'activity': (aMap['activity'] ?? aMap['notes'] ?? '').toString(),
            'notes': (aMap['activity'] ?? aMap['notes'] ?? '').toString(),
            'address': (aMap['address'] ?? '').toString(),
            'stopType': (aMap['stopType'] ?? aMap['activity_type'] ?? 'VISIT').toString().toUpperCase(),
          };
        }).toList();
        dMap['activities'] = acts;
        dMap['stops'] = acts.map((a) => {
          'name': a['place'],
          'time': a['time'],
          'activity_type': a['stopType']?.toLowerCase(),
          'notes': a['activity'],
          'address': a['address'],
        }).toList();
        parsedReplanned.add(dMap);
      }
      if (parsedReplanned.isNotEmpty && !hasDisallowedStops(parsedReplanned)) {
        return parsedReplanned;
      }
    }

    // Check if AI-generated itinerary plan exists (only use if free of disallowed stops)
    final planData = widget.trip['itineraryPlan'];
    if (planData != null) {
      try {
        final Map<String, dynamic> planMap = planData is Map<String, dynamic>
            ? planData
            : (planData is ItineraryPlan ? planData.toJson() : Map<String, dynamic>.from(planData));
        final scheduleList = (planMap['days'] ?? planMap['schedule']) as List?;
        if (scheduleList != null && scheduleList.isNotEmpty) {
          final List<Map<String, dynamic>> parsedSchedule = [];
          for (var dayItem in scheduleList) {
            final dayMap = Map<String, dynamic>.from(dayItem);
            final dayNum = dayMap['day_number'] ?? dayMap['dayNumber'] ?? (parsedSchedule.length + 1);
            final dateStr = (dayMap['date'] ?? '').toString();
            final stopsList = (dayMap['stops'] as List?) ?? (dayMap['activities'] as List?) ?? [];
            final List<Map<String, String>> activities = [];

            for (var stopItem in stopsList) {
              final stopMap = Map<String, dynamic>.from(stopItem);
              final placeName = (stopMap['place'] ?? stopMap['name'] ?? stopMap['place_name'] ?? stopMap['placeName'] ?? '').toString();
              final timeStr = (stopMap['time'] ?? '').toString();
              final stopType = (stopMap['activity_type'] ?? stopMap['stop_type'] ?? stopMap['stopType'] ?? stopMap['period'] ?? 'visit').toString().toUpperCase();
              final activity = (stopMap['notes'] ?? stopMap['activity'] ?? '').toString();
              final address = (stopMap['address'] ?? '').toString();

              activities.add({
                'place': placeName.isNotEmpty ? placeName : (activity.isNotEmpty ? activity : 'Scheduled Stop'),
                'name': placeName.isNotEmpty ? placeName : (activity.isNotEmpty ? activity : 'Scheduled Stop'),
                'time': timeStr.isNotEmpty ? timeStr : 'Flexible Time',
                'period': stopType,
                'activity': activity,
                'notes': activity,
                'address': address,
                'stopType': stopType,
              });
            }

            if (activities.isNotEmpty) {
              parsedSchedule.add({
                'dayNumber': dayNum,
                'title': dateStr.isNotEmpty ? 'Day $dayNum • $dateStr' : 'Day $dayNum • Highlights',
                'date': dateStr,
                'activities': activities,
                'stops': activities.map((a) => {
                  'name': a['place'],
                  'time': a['time'],
                  'activity_type': a['stopType']?.toLowerCase(),
                  'notes': a['activity'],
                  'address': a['address'],
                }).toList(),
              });
            }
          }

          if (parsedSchedule.length >= days && !hasDisallowedStops(parsedSchedule)) {
            return parsedSchedule;
          }
        }
      } catch (e) {
        debugPrint('Error parsing itineraryPlan: $e');
      }
    }

    // Generate group multi-day plan strictly based on voted places
    return GroupTripScheduleService.buildMultiDayPlan(
      destination: destination.toString(),
      numberOfDays: days,
      votedPlaces: cleanVotedPlaces.isNotEmpty ? cleanVotedPlaces : places,
      dateStrings: dateStrings.isNotEmpty ? dateStrings : null,
      hotel: hotel,
      placeCoordinates: widget.trip['placeCoordinates'] is Map
          ? Map<String, dynamic>.from(widget.trip['placeCoordinates'] as Map)
          : null,
    );
  }


  @override
  Widget build(BuildContext context) {
    final destination = widget.trip['destination'] ?? 'Planned Trip';
    final startDate = widget.trip['startDate'] ?? 'TBD';
    final endDate = widget.trip['endDate'] ?? 'TBD';
    final groupSize = widget.trip['groupSize'] ?? '1';
    final places = (widget.trip['places'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final daysCount = _calculateDaysCount();
    final schedule = _activeSchedule ?? _buildDailySchedule(places, daysCount);
    _activeSchedule ??= schedule;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Interactive Google Map Container
        _buildMapSection(),

        // 2. Trip Header Banner & Quick Badges
        _buildTripHeaderBanner(
          destination,
          startDate,
          endDate,
          groupSize,
          daysCount,
          places.length,
          startPoint: widget.trip['startPoint']?.toString(),
          hotel: widget.trip['hotel']?.toString(),
        ),

        // 3. Trip Progress Counter
        if (places.isNotEmpty) _buildTripProgressSection(places.length),

        const SizedBox(height: 16),

        // 4. Day-by-Day Itinerary Schedule
        _buildItinerarySection(schedule),

        const SizedBox(height: 20),

        // 5. Selected Places Cards Grid
        _buildPlacesListSection(places),

        const SizedBox(height: 20),

        // 6. Destination Tips & Insights
        _buildTravelTipsSection(destination),

        const SizedBox(height: 36),
      ],
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: isDark ? 0 : 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Text(
          '$destination Plan',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (widget.onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Delete Trip',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Trip?'),
                    content: const Text('Are you sure you want to remove this planned trip?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pop(context, true);
                          widget.onDelete?.call();
                        },
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _activeScrollController,
        physics: const BouncingScrollPhysics(),
        child: content,
      ),
    );
  }

  Widget _buildMapSection() {
    final double mapHeight = (_isMapExpanded || _isNavigating)
        ? 460
        : (_activeDirectionRoute != null ? 380 : 270);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: mapHeight,
      width: double.infinity,
      margin: widget.isEmbedded ? const EdgeInsets.fromLTRB(16, 0, 16, 20) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: widget.isEmbedded ? BorderRadius.circular(20) : BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: widget.isEmbedded ? BorderRadius.circular(19) : BorderRadius.zero,
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _destinationCenter,
                zoom: 11,
              ),
              mapType: _currentMapType,
              markers: _markers,
              polylines: _polylines,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: true,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
              onMapCreated: (controller) {
                _mapController = controller;
                Future.delayed(const Duration(milliseconds: 500), _resetMapBounds);
              },
            ),

            // 1. Navigation HUD when user is actively moving / navigating
            if (_isNavigating)
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: _buildNavigationHUD(),
              ),

            // 2. Interactive Maneuver Toast Popup (turn left, turn right, take u-turn)
            if (_turnPopupToastMessage != null)
              Positioned(
                top: _isNavigating ? 118 : 16,
                left: 20,
                right: 20,
                child: _buildTurnPopupToast(),
              ),

            // 3. Top Right Floating Controls
            // NOTE: The 3rd button (fit_screen_rounded) pointed to by the green arrow has been completely removed!
            Positioned(
              top: _isNavigating ? 120 : 12,
              right: 12,
              child: Column(
                children: [
                  // Expand / Collapse map toggle
                  _buildMapFloatingButton(
                    icon: _isMapExpanded ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                    tooltip: _isMapExpanded ? 'Collapse Map' : 'Expand Map',
                    onTap: () {
                      setState(() {
                        _isMapExpanded = !_isMapExpanded;
                      });
                    },
                  ),
                  const SizedBox(height: 8),

                  // Map Style Switcher (Normal / Satellite)
                  _buildMapFloatingButton(
                    icon: Icons.layers_rounded,
                    tooltip: 'Map Style',
                    onTap: () {
                      setState(() {
                        _currentMapType = _currentMapType == MapType.normal
                            ? MapType.satellite
                            : MapType.normal;
                      });
                    },
                  ),
                ],
              ),
            ),

            // 4. Map Bottom Bar
            if (!_isNavigating)
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1E293B)
                            : Colors.white)
                        .withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF6366F1),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedPlace != null
                              ? 'Viewing: $_selectedPlace'
                              : 'Interactive Route Map • ${_allPlaces.length} Spots',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : const Color(0xFF1E1B4B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_selectedPlace != null)
                        GestureDetector(
                          onTap: _clearSelectedPlace,
                          child: const Text(
                            'Show All',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        )
                      else if (_allPlaces.isNotEmpty)
                        GestureDetector(
                          onTap: () => _startTripNavigation(),
                          onLongPress: () => _startTripNavigation(simulate: true),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.navigation_rounded, size: 14, color: Color(0xFF6366F1)),
                              SizedBox(width: 4),
                              Text(
                                'Navigate',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationHUD() {
    final step = _currentNavStep;
    final maneuver = step?.maneuver ?? 'straight';
    final actionTitle = step?.shortActionTitle ?? 'Continue Straight';
    final icon = _getManeuverIcon(maneuver);
    final color = _getManeuverColor(maneuver);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF0F172A) : Colors.white).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Center(
                  child: Icon(icon, color: color, size: 26),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          actionTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: color,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _distanceToNextManeuverMeters > 0
                                ? 'In ${_formatDistance(_distanceToNextManeuverMeters)}'
                                : (step?.distanceText ?? 'Ahead'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      step?.instruction ?? 'Proceed along indicated road route',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _stopNavigation,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
                ),
              ),
            ],
          ),
          if (_nextNavStep != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(_getManeuverIcon(_nextNavStep!.maneuver), size: 14, color: _getManeuverColor(_nextNavStep!.maneuver)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Next: ${_nextNavStep!.shortActionTitle} (${_nextNavStep!.distanceText})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  if (_isSimulating)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'DEMO',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTurnPopupToast() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: _turnPopupToastMessage != null ? 1.0 : 0.0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1B4B).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF6366F1), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.navigation_rounded, color: Color(0xFF818CF8), size: 16),
              const SizedBox(width: 8),
              Text(
                _turnPopupToastMessage ?? '',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildMapFloatingButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF1E293B) : Colors.white).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(icon, size: 20, color: isDark ? Colors.white : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  Widget _buildTripHeaderBanner(
    String destination,
    String startDate,
    String endDate,
    String groupSize,
    int daysCount,
    int placesCount, {
    String? startPoint,
    String? hotel,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: Color(0xFF6366F1)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Karnataka, India',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF10B981)),
                    SizedBox(width: 4),
                    Text(
                      'Ready to Go',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 16),

          // Badges row
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildFeatureBadge(
                icon: Icons.calendar_today_rounded,
                label: '$startDate - $endDate',
                color: const Color(0xFF6366F1),
                bg: isDark ? const Color(0xFF312E81).withValues(alpha: 0.3) : const Color(0xFFEEF2FF),
              ),
              _buildFeatureBadge(
                icon: Icons.timer_outlined,
                label: '$daysCount Days Tour',
                color: const Color(0xFF14B8A6),
                bg: isDark ? const Color(0xFF134E4A).withValues(alpha: 0.4) : const Color(0xFFF0FDFA),
              ),
              _buildFeatureBadge(
                icon: Icons.groups_rounded,
                label: 'Group of $groupSize',
                color: const Color(0xFFA855F7),
                bg: isDark ? const Color(0xFF581C87).withValues(alpha: 0.4) : const Color(0xFFF5F3FF),
              ),
              _buildFeatureBadge(
                icon: Icons.pin_drop_rounded,
                label: '$placesCount Destinations',
                color: const Color(0xFFF97316),
                bg: isDark ? const Color(0xFF7C2D12).withValues(alpha: 0.4) : const Color(0xFFFFF7ED),
              ),
              if (startPoint != null && startPoint.trim().isNotEmpty)
                _buildFeatureBadge(
                  icon: Icons.trip_origin_rounded,
                  label: 'From: $startPoint',
                  color: const Color(0xFF0EA5E9),
                  bg: isDark ? const Color(0xFF0C4A6E).withValues(alpha: 0.4) : const Color(0xFFF0F9FF),
                ),
              if (hotel != null && hotel.trim().isNotEmpty)
                _buildFeatureBadge(
                  icon: Icons.hotel_rounded,
                  label: 'Stay: $hotel',
                  color: const Color(0xFF8B5CF6),
                  bg: isDark ? const Color(0xFF4C1D95).withValues(alpha: 0.4) : const Color(0xFFF5F3FF),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
  }) {
    final maxBadgeWidth = MediaQuery.sizeOf(context).width - 72;
    return Tooltip(
      message: label,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxBadgeWidth > 140 ? maxBadgeWidth : 260),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripProgressSection(int totalPlaces) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visitedCount = _visitedPlaces.length;
    final progress = totalPlaces > 0 ? visitedCount / totalPlaces : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Trip Checklist ($visitedCount of $totalPlaces Visited)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6366F1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2FF),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // REPLAN TRIP: Banner, Bottom Sheet, and Conflict-Free Planner
  // -------------------------------------------------------------
  Widget _buildReplanTripBanner(List<Map<String, dynamic>> schedule) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF1E1B4B).withValues(alpha: 0.8),
                  const Color(0xFF1E293B),
                ]
              : [
                  const Color(0xFFEEF2FF),
                  Colors.white,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.45 : 0.3),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.16 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.alt_route_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'On-the-Go Trip Replan',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: const Text(
                            '⚡ ADK AI',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Reached a spot? Discover nearby places that fit before your next planned stop without time clashes.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () => _openReplanBottomSheet(schedule),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: Colors.amber),
                  SizedBox(width: 8),
                  Text(
                    'Replan Trip from Current Spot',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openReplanBottomSheet(
    List<Map<String, dynamic>> schedule, {
    String? preselectedPlace,
    int? preselectedDayIndex,
  }) {
    if (schedule.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No schedule available to replan. Please add places first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    int currentDayIdx = (preselectedDayIndex ?? _selectedDayIndex).clamp(0, schedule.length - 1);
    List<ReplanSuggestion> suggestions = [];
    bool isLoading = false;
    String? statusMessage;
    String? selectedPlaceName = preselectedPlace;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final activeDayMap = schedule[currentDayIdx];
            final rawActivities = (activeDayMap['activities'] as List?) ?? [];
            final activities = rawActivities
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();

            // Resolve initial selected place name if null
            if (selectedPlaceName == null || !activities.any((a) => (a['place'] ?? '').toString() == selectedPlaceName)) {
              final firstAttraction = activities.firstWhere(
                (a) => !((a['place'] ?? '').toString().toLowerCase().startsWith('start:')),
                orElse: () => activities.isNotEmpty ? activities.first : <String, dynamic>{'place': 'Current Spot'},
              );
              selectedPlaceName = (firstAttraction['place'] ?? 'Current Spot').toString();
            }

            final currStopIndex = activities.indexWhere(
              (a) => (a['place'] ?? '').toString() == selectedPlaceName,
            );

            // Determine next stop
            String nextStopName = '';
            String nextStopTime = '02:00 PM';

            if (currStopIndex >= 0) {
              if (currStopIndex < activities.length - 1) {
                final nAct = activities[currStopIndex + 1];
                nextStopName = (nAct['place'] ?? 'Next Stop').toString();
                nextStopTime = (nAct['time'] ?? '02:00 PM').toString();
              } else {
                nextStopName = widget.trip['hotel']?.toString() ?? 'Hotel Base (Night Stay)';
                nextStopTime = '08:30 PM';
              }
            } else {
              nextStopName = widget.trip['hotel']?.toString() ?? 'Next Scheduled Spot';
            }

            // Function to query ADK backend for replan suggestions
            void loadSuggestions() async {
              setModalState(() {
                isLoading = true;
                statusMessage = 'ADK AI evaluating detours near ${selectedPlaceName ?? 'current spot'}...';
                suggestions = [];
              });

              final currentDayActivities = ((schedule[currentDayIdx]['activities'] as List?) ?? [])
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList();

              final curIdx = currentDayActivities.indexWhere(
                (a) => (a['place'] ?? '').toString() == selectedPlaceName,
              );

              final effectiveCurrentPlace = selectedPlaceName ??
                  (currentDayActivities.isNotEmpty ? (currentDayActivities.first['place'] ?? 'Current Spot').toString() : 'Current Spot');

              final cAct = curIdx >= 0
                  ? currentDayActivities[curIdx]
                  : (currentDayActivities.isNotEmpty ? currentDayActivities.first : <String, dynamic>{});
              final curStopTime = (cAct['time'] ?? '11:00 AM').toString();

              String nStopName = '';
              String nStopTime = '02:00 PM';
              if (curIdx >= 0 && curIdx < currentDayActivities.length - 1) {
                final nAct = currentDayActivities[curIdx + 1];
                nStopName = (nAct['place'] ?? 'Next Stop').toString();
                nStopTime = (nAct['time'] ?? '02:00 PM').toString();
              } else {
                nStopName = widget.trip['hotel']?.toString() ?? 'Hotel Base (Night Stay)';
                nStopTime = '08:30 PM';
              }

              // Current place coordinates - highest accuracy lookup
              LatLng? currCoord;
              final aLat = (cAct['lat'] as num?)?.toDouble();
              final aLng = (cAct['lng'] as num?)?.toDouble();
              if (aLat != null && aLng != null && aLat != 0.0 && aLng != 0.0) {
                currCoord = LatLng(aLat, aLng);
              }
              currCoord ??= _placeCoordinates[effectiveCurrentPlace];
              if (currCoord == null) {
                final sCoord = OneDayTripService.findStopCoordinate(effectiveCurrentPlace);
                if (sCoord != null) currCoord = LatLng(sCoord.lat, sCoord.lng);
              }
              if (currCoord == null) {
                final reg = KarnatakaPlacesRegistry.findPlaceCoordinate(
                  effectiveCurrentPlace,
                  destination: widget.trip['destination'] ?? 'Karnataka',
                );
                if (reg != null) currCoord = LatLng(reg.lat, reg.lng);
              }
              currCoord ??= _destinationCenter;

              // Next place coordinates
              LatLng? nextCoord;
              if (curIdx >= 0 && curIdx < currentDayActivities.length - 1) {
                final nAct = currentDayActivities[curIdx + 1];
                final nLat = (nAct['lat'] as num?)?.toDouble();
                final nLng = (nAct['lng'] as num?)?.toDouble();
                if (nLat != null && nLng != null && nLat != 0.0 && nLng != 0.0) {
                  nextCoord = LatLng(nLat, nLng);
                }
              }
              nextCoord ??= _placeCoordinates[nStopName];
              if (nextCoord == null) {
                final sCoord = OneDayTripService.findStopCoordinate(nStopName);
                if (sCoord != null) nextCoord = LatLng(sCoord.lat, sCoord.lng);
              }
              if (nextCoord == null) {
                final reg = KarnatakaPlacesRegistry.findPlaceCoordinate(
                  nStopName,
                  destination: widget.trip['destination'] ?? 'Karnataka',
                );
                if (reg != null) nextCoord = LatLng(reg.lat, reg.lng);
              }

              final results = await TripApi.suggestReplanPlaces(
                tripId: (widget.trip['tripCode'] ?? widget.trip['id'] ?? 'active_trip').toString(),
                currentPlace: effectiveCurrentPlace,
                currentLat: currCoord.latitude,
                currentLng: currCoord.longitude,
                nextPlace: nStopName,
                nextLat: nextCoord?.latitude,
                nextLng: nextCoord?.longitude,
                currentTimeStr: curStopTime,
                nextTimeStr: nStopTime,
                availableMinutes: 120,
                destination: (widget.trip['destination'] ?? 'Karnataka').toString(),
                existingPlaces: _allPlaces,
                maxRadiusKm: 15.0,
              );

              setModalState(() {
                isLoading = false;
                suggestions = results;
                if (results.isEmpty) {
                  statusMessage = 'No additional nearby detours found. Tap Refresh to re-scan.';
                } else {
                  statusMessage = null;
                }
              });
            }

            // Auto-load once on sheet open
            if (suggestions.isEmpty && !isLoading && statusMessage == null) {
              Future.microtask(() => loadSuggestions());
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.alt_route_rounded, color: Color(0xFF6366F1), size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Smart Trip Replan',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Explore nearby • Zero clash with next stop',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : Colors.black54),
                          onPressed: () => Navigator.pop(bottomSheetContext),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),

                  // Scrollable Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Day Selector Tabs
                          Text(
                            'Active Trip Day',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 38,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: schedule.length,
                              separatorBuilder: (_, index) => const SizedBox(width: 8),
                              itemBuilder: (context, idx) {
                                final isSel = idx == currentDayIdx;
                                return ChoiceChip(
                                  label: Text('Day ${idx + 1}'),
                                  selected: isSel,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setModalState(() {
                                        currentDayIdx = idx;
                                        selectedPlaceName = null;
                                      });
                                      loadSuggestions();
                                    }
                                  },
                                  selectedColor: const Color(0xFF6366F1),
                                  labelStyle: TextStyle(
                                    color: isSel ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 16),

                          // 2. Current Stop Dropdown / Selector
                          Text(
                            'Where are you currently located?',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedPlaceName,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF6366F1)),
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                items: activities.map((a) {
                                  final pName = (a['place'] ?? '').toString();
                                  final pTime = (a['time'] ?? '').toString();
                                  return DropdownMenuItem<String>(
                                    value: pName,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF6366F1)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            pName,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          pTime,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (newVal) {
                                  if (newVal != null) {
                                    setModalState(() {
                                      selectedPlaceName = newVal;
                                    });
                                    loadSuggestions();
                                  }
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // 3. Time Management & Next Stop Context Card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.12 : 0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.schedule_rounded, color: Color(0xFF6366F1), size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Next Planned Destination:',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$nextStopName • Scheduled at $nextStopTime',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF6366F1),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // 5. Suggestions Header & Refresh
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Recommended Nearby Detours',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isLoading)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                                )
                              else
                                InkWell(
                                  onTap: loadSuggestions,
                                  child: const Text(
                                    'Refresh 🔄',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          if (isLoading) ...[
                            Container(
                              padding: const EdgeInsets.all(28),
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  const CircularProgressIndicator(color: Color(0xFF6366F1)),
                                  const SizedBox(height: 14),
                                  Text(
                                    statusMessage ?? 'Evaluating nearby spots & schedule clash...',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (statusMessage != null && suggestions.isEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(20),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                statusMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ] else ...[
                            ...suggestions.map((s) {
                              final isFit = s.timeStatus == 'fits';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isFit
                                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            s.name,
                                            style: TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.place_outlined,
                                                size: 12,
                                                color: Color(0xFF6366F1),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                s.category.isNotEmpty ? s.category.toUpperCase() : 'DETOUR',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF6366F1),
                                                  letterSpacing: 0.4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.near_me_rounded,
                                          size: 13.5,
                                          color: Color(0xFF6366F1),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '${s.distanceKm} km from ${(selectedPlaceName ?? "current spot").split("(").first.trim()} • ${s.travelFromCurrentMinutes} min drive',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.schedule_rounded,
                                          size: 13.5,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Suggested Detour: ${s.suggestedSlot} (${s.visitDurationMinutes}m visit)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: Icon(
                                            Icons.auto_awesome,
                                            size: 13.5,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Smart AI auto-rearranges Day ${currentDayIdx + 1} schedule & next stops smoothly',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                              height: 1.25,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 40,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(bottomSheetContext);
                                          _applyReplanSuggestion(
                                            currentDayIdx,
                                            currStopIndex,
                                            s,
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF6366F1),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                          elevation: 0,
                                        ),
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.add_circle_outline_rounded, size: 16),
                                            SizedBox(width: 6),
                                            Text(
                                              'Add to Day Plan',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _applyReplanSuggestion(
    int dayIdx,
    int insertAfterStopIdx,
    ReplanSuggestion suggestion,
  ) async {
    // 1. Snapshot previous schedule for undo support
    _previousSchedule = _activeSchedule != null
        ? jsonDecode(jsonEncode(_activeSchedule))
        : null;

    final updatedSchedule = List<Map<String, dynamic>>.from(
      (_activeSchedule ?? []).map((d) {
        final dayMap = Map<String, dynamic>.from(d);
        final rawActs = (dayMap['activities'] as List?) ?? (dayMap['stops'] as List?) ?? [];
        final acts = List<Map<String, dynamic>>.from(
          rawActs.map((a) => Map<String, dynamic>.from(a as Map)),
        );
        dayMap['activities'] = acts;
        return dayMap;
      }),
    );

    if (dayIdx >= updatedSchedule.length) return;

    final targetDay = updatedSchedule[dayIdx];
    final acts = targetDay['activities'] as List<Map<String, dynamic>>;

    final insertIdx = (insertAfterStopIdx >= 0 && insertAfterStopIdx < acts.length)
        ? insertAfterStopIdx + 1
        : acts.length;

    // Determine departure time of preceding stop
    int prevEndMin = 540; // 09:00 AM default
    if (insertAfterStopIdx >= 0 && insertAfterStopIdx < acts.length) {
      final prevAct = acts[insertAfterStopIdx];
      final prevTimeStr = (prevAct['time'] ?? '').toString();
      final pEnd = TripApi.parseTimeToMinutes(prevTimeStr, preferEnd: true);
      if (pEnd != null) {
        prevEndMin = pEnd;
      }
    }

    final travelToDetour = math.max(5, suggestion.travelFromCurrentMinutes);
    final detourStartMin = prevEndMin + travelToDetour;
    final detourDurationMin = math.max(30, suggestion.visitDurationMinutes);
    final detourEndMin = detourStartMin + detourDurationMin;

    final detourTimeSlot = '${TripApi.formatMinutesToTime(detourStartMin)} - ${TripApi.formatMinutesToTime(detourEndMin)}';

    final newAct = <String, dynamic>{
      'place': suggestion.name,
      'name': suggestion.name,
      'time': detourTimeSlot,
      'period': suggestion.category.isNotEmpty ? suggestion.category.toUpperCase() : 'VISIT',
      'activity': 'Detour visit to ${suggestion.name} (${suggestion.category})',
      'notes': 'Detour visit to ${suggestion.name} (${suggestion.category})',
      'address': suggestion.address ?? suggestion.name,
      'stopType': 'VISIT',
      'lat': suggestion.lat,
      'lng': suggestion.lng,
    };

    acts.insert(insertIdx, newAct);

    // Rearrange all subsequent stops smoothly with transit buffers
    int runningCursor = detourEndMin + math.max(10, suggestion.travelToNextMinutes);
    for (int i = insertIdx + 1; i < acts.length; i++) {
      final act = acts[i];
      final actTimeStr = (act['time'] ?? '').toString();
      final origStart = TripApi.parseTimeToMinutes(actTimeStr, preferEnd: false);
      final origEnd = TripApi.parseTimeToMinutes(actTimeStr, preferEnd: true);

      int dur = 60;
      if (origStart != null && origEnd != null && origEnd > origStart) {
        dur = origEnd - origStart;
      } else {
        final sType = (act['stopType'] ?? act['period'] ?? '').toString().toUpperCase();
        if (sType == 'MEAL') {
          dur = 60;
        } else if (sType == 'BREAK') {
          dur = 45;
        } else if (sType == 'START' || sType == 'END') {
          dur = 15;
        } else {
          dur = 90;
        }
      }

      int newStart;
      if (origStart != null && origStart > runningCursor) {
        newStart = origStart;
      } else {
        newStart = runningCursor;
      }

      final newEnd = newStart + dur;
      act['time'] = '${TripApi.formatMinutesToTime(newStart)} - ${TripApi.formatMinutesToTime(newEnd)}';
      runningCursor = newEnd + 15;
    }

    // Strongly type and sync activities and stops for all days
    for (int d = 0; d < updatedSchedule.length; d++) {
      final dayMap = updatedSchedule[d];
      final rawA = (dayMap['activities'] as List?) ?? (dayMap['stops'] as List?) ?? [];
      final List<Map<String, String>> sanitizedActs = rawA.map((a) {
        final m = Map<String, dynamic>.from(a as Map);
        return {
          'place': (m['place'] ?? m['name'] ?? 'Scheduled Stop').toString(),
          'name': (m['place'] ?? m['name'] ?? 'Scheduled Stop').toString(),
          'time': (m['time'] ?? 'Flexible Time').toString(),
          'period': (m['period'] ?? m['stopType'] ?? 'VISIT').toString().toUpperCase(),
          'activity': (m['activity'] ?? m['notes'] ?? '').toString(),
          'notes': (m['activity'] ?? m['notes'] ?? '').toString(),
          'address': (m['address'] ?? '').toString(),
          'stopType': (m['stopType'] ?? 'VISIT').toString().toUpperCase(),
        };
      }).toList();
      dayMap['activities'] = sanitizedActs;
      dayMap['stops'] = sanitizedActs.map((a) => {
        'name': a['place'],
        'time': a['time'],
        'activity_type': a['stopType']?.toLowerCase(),
        'notes': a['activity'],
        'address': a['address'],
      }).toList();
    }

    // 2. Update places list and coordinates
    if (!_allPlaces.contains(suggestion.name)) {
      _allPlaces.add(suggestion.name);
    }
    _placeCoordinates[suggestion.name] = LatLng(suggestion.lat, suggestion.lng);

    setState(() {
      _activeSchedule = updatedSchedule;
      _selectedPlace = suggestion.name;
      _selectedDayIndex = dayIdx;
    });

    // 3. Update widget.trip with both formats
    if (widget.trip['initialPlan'] == null && _previousSchedule != null) {
      widget.trip['initialPlan'] = jsonDecode(jsonEncode(_previousSchedule));
    }
    widget.trip['hasReplan'] = true;
    widget.trip['replannedPlan'] = updatedSchedule;
    widget.trip['places'] = List<String>.from(_allPlaces);
    final Map<String, dynamic> coordMap = {};
    _placeCoordinates.forEach((k, v) {
      coordMap[k] = {'lat': v.latitude, 'lng': v.longitude};
    });
    widget.trip['placeCoordinates'] = coordMap;
    widget.trip['itineraryPlan'] = {
      'schedule': updatedSchedule,
      'days': updatedSchedule,
    };

    // 4. Update map markers and camera
    _initializeCoordinatesAndMarkers();
    _focusOnPlace(suggestion.name);

    // 5. Persist to storage
    await _persistUpdatedTrip();

    // 6. Notify parent widget (e.g. CreateTripScreen)
    widget.onTripUpdated?.call(widget.trip);

    // 7. Show success feedback
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Added ${suggestion.name}! Day ${dayIdx + 1} schedule rearranged smoothly.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.white,
          onPressed: () {
            if (_previousSchedule != null) {
              setState(() {
                _activeSchedule = _previousSchedule;
                _allPlaces.remove(suggestion.name);
                _placeCoordinates.remove(suggestion.name);
                widget.trip['places'] = List<String>.from(_allPlaces);
                widget.trip['itineraryPlan'] = {
                  'schedule': _activeSchedule,
                  'days': _activeSchedule,
                };
              });
              _initializeCoordinatesAndMarkers();
              _persistUpdatedTrip();
              widget.onTripUpdated?.call(widget.trip);
            }
          },
        ),
      ),
    );
  }

  Future<void> _persistUpdatedTrip() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = FirebaseAuth.instance.currentUser;
      final userEmail = user?.email?.trim().toLowerCase() ??
          prefs.getString('user_profile_email')?.trim().toLowerCase() ?? '';
      final storageKey = userEmail.isNotEmpty ? 'saved_trips_$userEmail' : 'saved_trips';
      final savedTrips = prefs.getStringList(storageKey) ?? [];

      final tripCode = (widget.trip['tripCode'] ?? widget.trip['id'] ?? '').toString();
      if (tripCode.isNotEmpty) {
        bool found = false;
        for (int i = 0; i < savedTrips.length; i++) {
          try {
            final decoded = jsonDecode(savedTrips[i]);
            if (decoded['tripCode']?.toString() == tripCode || decoded['id']?.toString() == tripCode) {
              savedTrips[i] = jsonEncode(widget.trip);
              found = true;
              break;
            }
          } catch (_) {}
        }
        if (found) {
          await prefs.setStringList(storageKey, savedTrips);
        }
        final genericList = prefs.getStringList('saved_trips');
        if (genericList != null) {
          for (int i = 0; i < genericList.length; i++) {
            try {
              final decoded = jsonDecode(genericList[i]);
              if (decoded['tripCode']?.toString() == tripCode || decoded['id']?.toString() == tripCode) {
                genericList[i] = jsonEncode(widget.trip);
                await prefs.setStringList('saved_trips', genericList);
                break;
              }
            } catch (_) {}
          }
        }
        try {
          await FirebaseFirestore.instance.collection('trips').doc(tripCode).set(
            Map<String, dynamic>.from(widget.trip),
            SetOptions(merge: true),
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Persistence note: $e');
    }
  }

  Widget _buildItinerarySection(List<Map<String, dynamic>> schedule) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final warnings = _getItineraryWarnings();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -------------------------------------------------------------
          // Dynamic Trip Replan Action Banner & Button (Above Daily Schedule)
          // -------------------------------------------------------------
          _buildReplanTripBanner(schedule),
          const SizedBox(height: 18),

          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Daily Travel Schedule',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Schedule Validation Notice (Step 8 of PDF)
          if (warnings.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Schedule Validation Flags',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD97706),
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...warnings.map((w) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '• $w',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                            ),
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (schedule.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'No activities scheduled for this trip.',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            )
          else ...[
            // -------------------------------------------------------------
            // Day Selector Tabs: Day 1, Day 2, Day 3... based on days chosen
            // -------------------------------------------------------------
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: schedule.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final isSelected = index == _selectedDayIndex;
                  final dayNum = schedule[index]['dayNumber'] ?? (index + 1);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedDayIndex = index;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isSelected
                            ? null
                            : (isDark ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          width: 1.2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Day $dayNum',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // -------------------------------------------------------------
            // Render only the active chosen Day's optimized schedule
            // -------------------------------------------------------------
            Builder(
              builder: (context) {
                final activeIdx = _selectedDayIndex.clamp(0, schedule.length - 1);
                final dayPlan = schedule[activeIdx];
                final dayNum = dayPlan['dayNumber'] as int;
                final dayTitle = (dayPlan['title'] ?? 'Day $dayNum').toString();
                final rawActs = (dayPlan['activities'] as List?) ?? (dayPlan['stops'] as List?) ?? [];
                final List<Map<String, String>> activities = rawActs.map((a) {
                  if (a is Map) {
                    return a.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
                  }
                  return <String, String>{};
                }).toList();

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Day Title Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Day $dayNum',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                dayTitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${activities.length} Stops',
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Activities Timeline
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: activities.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final act = entry.value;
                            final placeName = (act['place'] ?? act['name'] ?? 'Scheduled Stop').toString();
                            final isVisited = _visitedPlaces.contains(placeName);
                            final isLast = idx == activities.length - 1;
                            final stopType = act['stopType'] ?? 'VISIT';
                            final activityDesc = act['activity'] ?? '';
                            final address = act['address'] ?? '';
                            final itemColor = _getCategoryColor(placeName, stopType);
                            final itemIcon = _getCategoryIcon(placeName, stopType);

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Timeline node
                                Column(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (isVisited) {
                                            _visitedPlaces.remove(placeName);
                                          } else {
                                            _visitedPlaces.add(placeName);
                                          }
                                        });
                                      },
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: isVisited
                                              ? const Color(0xFF059669)
                                              : (isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF)),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isVisited
                                                ? const Color(0xFF059669)
                                                : itemColor,
                                            width: 2,
                                          ),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            isVisited ? Icons.check : Icons.circle,
                                            size: isVisited ? 14 : 8,
                                            color: isVisited ? Colors.white : itemColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (!isLast)
                                      Container(
                                        width: 2,
                                        height: activityDesc.isNotEmpty ? 80 : 64,
                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 14),

                                // Activity Content Card
                                Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _selectedPlace == placeName
                                          ? (isDark ? const Color(0xFF312E81).withValues(alpha: 0.4) : const Color(0xFFF5F3FF))
                                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: _selectedPlace == placeName
                                            ? const Color(0xFF6366F1)
                                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              itemIcon,
                                              size: 16,
                                              color: itemColor,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                placeName,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                  color: isVisited
                                                      ? Colors.grey
                                                      : (isDark ? Colors.white : const Color(0xFF1E1B4B)),
                                                  decoration: isVisited
                                                      ? TextDecoration.lineThrough
                                                      : null,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              icon: const Icon(
                                                Icons.location_searching_rounded,
                                                size: 18,
                                                color: Color(0xFF6366F1),
                                              ),
                                              tooltip: 'Locate on Map',
                                              onPressed: () => _focusOnPlace(placeName),
                                            ),
                                          ],
                                        ),
                                        if (activityDesc.isNotEmpty && activityDesc != placeName) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            activityDesc,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                        if (address.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.location_on_outlined,
                                                size: 12,
                                                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  address,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Wrap(
                                          alignment: WrapAlignment.spaceBetween,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.access_time_rounded,
                                                  size: 13,
                                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  act['time']!,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              act['period']!,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: itemColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlacesListSection(List<String> places) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Selected Places & Map Waypoints',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: places.map((place) {
              final isSelected = _selectedPlace == place;
              return ActionChip(
                avatar: Icon(
                  _getCategoryIcon(place),
                  size: 16,
                  color: isSelected ? Colors.white : _getCategoryColor(place),
                ),
                label: Text(place),
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 13,
                ),
                backgroundColor: isSelected
                    ? const Color(0xFF6366F1)
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF6366F1)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
                onPressed: () => _focusOnPlace(place),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTravelTipsSection(String destination) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFEAB308), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Traveler Tips & Local Highlights',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildTipItem(
            icon: Icons.restaurant_rounded,
            title: 'Local Flavors to Try',
            desc: 'Don\'t miss authentic Benne Dosa, Akki Rotti, and steaming fresh filter coffee.',
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _buildTipItem(
            icon: Icons.camera_alt_outlined,
            title: 'Scenic Photography',
            desc: 'Golden hour (5:00 PM - 6:30 PM) offers the best lighting for western sunset vistas.',
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _buildTipItem(
            icon: Icons.backpack_outlined,
            title: 'Essentials to Pack',
            desc: 'Carry good trekking shoes, water bottles, sun protection, and a light jacket.',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem({
    required IconData icon,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF6366F1)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
