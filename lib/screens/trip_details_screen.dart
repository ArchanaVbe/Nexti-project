import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;
import '../models/trip_plan_models.dart';

class TripDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  final int? tripIndex;
  final VoidCallback? onDelete;
  final bool isEmbedded;
  final ScrollController? scrollController;

  const TripDetailsScreen({
    super.key,
    required this.trip,
    this.tripIndex,
    this.onDelete,
    this.isEmbedded = false,
    this.scrollController,
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

  late LatLng _destinationCenter;
  final Map<String, LatLng> _placeCoordinates = {};
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  ScrollController? _internalScrollController;
  ScrollController get _activeScrollController =>
      widget.scrollController ?? (_internalScrollController ??= ScrollController());

  // Known destination coordinates across Karnataka & South India
  static const Map<String, LatLng> _knownDestinations = {
    'shimoga': LatLng(13.9299, 75.5681),
    'shivamogga': LatLng(13.9299, 75.5681),
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
    _initializeCoordinatesAndMarkers();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _internalScrollController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TripDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initializeCoordinatesAndMarkers();
    if (_mapController != null) {
      _resetMapBounds();
    }
  }

  void _initializeCoordinatesAndMarkers() {
    final destRaw = (widget.trip['destination'] ?? 'Karnataka').toString().trim();
    final destKey = destRaw.toLowerCase();

    // 1. Resolve destination center
    if (_knownDestinations.containsKey(destKey)) {
      _destinationCenter = _knownDestinations[destKey]!;
    } else {
      // Default to central Karnataka
      _destinationCenter = const LatLng(15.3173, 75.7139);
    }

    final rawPlaces = (widget.trip['places'] as List?)?.map((e) => e.toString()).toList() ?? [];
    _placeCoordinates.clear();

    final markers = <Marker>{};
    final routePoints = <LatLng>[_destinationCenter];

    // Add destination center marker
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

    // 2. Resolve place coordinates
    for (int i = 0; i < rawPlaces.length; i++) {
      final place = rawPlaces[i];
      final placeKey = place.toLowerCase().trim();

      LatLng coordinate;
      if (_knownPlaces.containsKey(placeKey)) {
        coordinate = _knownPlaces[placeKey]!;
      } else {
        // Deterministically space out points around the destination center
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
              setState(() {
                _selectedPlace = place;
              });
            },
          ),
          onTap: () {
            setState(() {
              _selectedPlace = place;
            });
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
          color: const Color(0xFF6366F1),
          width: 4,
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

  void _focusOnPlace(String place) {
    setState(() {
      _selectedPlace = place;
    });

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

  void _resetMapBounds() {
    if (_mapController == null) return;

    if (_placeCoordinates.isEmpty) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_destinationCenter, 11),
      );
      return;
    }

    double minLat = _destinationCenter.latitude;
    double maxLat = _destinationCenter.latitude;
    double minLng = _destinationCenter.longitude;
    double maxLng = _destinationCenter.longitude;

    for (var pos in _placeCoordinates.values) {
      minLat = math.min(minLat, pos.latitude);
      maxLat = math.max(maxLat, pos.latitude);
      minLng = math.min(minLng, pos.longitude);
      maxLng = math.max(maxLng, pos.longitude);
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat - 0.03, minLng - 0.03),
      northeast: LatLng(maxLat + 0.03, maxLng + 0.03),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  IconData _getCategoryIcon(String place, [String? stopType]) {
    final sType = stopType?.toUpperCase() ?? '';
    if (sType == 'MEAL') return Icons.restaurant_rounded;
    if (sType == 'TRANSIT') return Icons.directions_car_rounded;
    if (sType == 'BREAK') return Icons.coffee_rounded;
    if (sType == 'START' || sType == 'END') return Icons.hotel_rounded;

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
    // 1. Check if AI-generated itinerary plan exists
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
            final stopsList = (dayMap['stops'] as List?) ?? [];
            final List<Map<String, String>> activities = [];

            for (var stopItem in stopsList) {
              final stopMap = Map<String, dynamic>.from(stopItem);
              final placeName = (stopMap['name'] ?? stopMap['place_name'] ?? stopMap['placeName'] ?? '').toString();
              final timeStr = (stopMap['time'] ?? '').toString();
              final stopType = (stopMap['activity_type'] ?? stopMap['stop_type'] ?? stopMap['stopType'] ?? 'visit').toString().toUpperCase();
              final activity = (stopMap['notes'] ?? stopMap['activity'] ?? '').toString();
              final address = (stopMap['address'] ?? '').toString();
              final durationMins = stopMap['duration_mins'] ?? stopMap['durationMins'] ?? 60;
              final transitMins = stopMap['transit_mins'] ?? stopMap['transitMins'];

              String period = stopType;
              if (transitMins != null && transitMins > 0) {
                period += ' • ${transitMins}m transit';
              } else if (durationMins > 0) {
                period += ' • ${durationMins}m';
              }

              activities.add({
                'place': placeName.isNotEmpty ? placeName : (activity.isNotEmpty ? activity : 'Scheduled Stop'),
                'time': timeStr.isNotEmpty ? timeStr : 'Flexible Time',
                'period': period,
                'activity': activity,
                'address': address,
                'stopType': stopType,
              });
            }

            if (activities.isNotEmpty) {
              parsedSchedule.add({
                'dayNumber': dayNum,
                'title': dateStr.isNotEmpty ? 'Day $dayNum • $dateStr' : 'Day $dayNum • Highlights',
                'activities': activities,
              });
            }
          }

          if (parsedSchedule.isNotEmpty) {
            return parsedSchedule;
          }
        }
      } catch (e) {
        debugPrint('Error parsing itineraryPlan: $e');
      }
    }

    // Fallback: heuristic distribution
    if (places.isEmpty) return [];

    int actualDays = math.max(1, math.min(days, places.length));
    List<Map<String, dynamic>> schedule = [];

    int placesPerDay = (places.length / actualDays).ceil();
    int placeIdx = 0;

    for (int day = 1; day <= actualDays; day++) {
      List<Map<String, String>> dayActivities = [];

      for (int p = 0; p < placesPerDay && placeIdx < places.length; p++) {
        final placeName = places[placeIdx];
        String timeSlot;
        String period;

        if (p == 0) {
          timeSlot = '09:00 AM - 12:30 PM';
          period = 'Morning Adventure';
        } else if (p == 1) {
          timeSlot = '03:30 PM - 06:30 PM';
          period = 'Afternoon Exploration';
        } else {
          timeSlot = '07:30 PM - 09:30 PM';
          period = 'Evening Stroll';
        }

        dayActivities.add({
          'place': placeName,
          'time': timeSlot,
          'period': period,
          'activity': 'Explore and enjoy $placeName',
          'address': '',
          'stopType': 'VISIT',
        });

        placeIdx++;
      }

      schedule.add({
        'dayNumber': day,
        'title': 'Day $day • Highlights',
        'activities': dayActivities,
      });
    }

    return schedule;
  }

  void _shareTripPlan() {
    final destination = widget.trip['destination'] ?? 'Karnataka';
    final dates = '${widget.trip['startDate']} to ${widget.trip['endDate']}';
    final group = widget.trip['groupSize'] ?? '1';
    final places = (widget.trip['places'] as List?)?.join(', ') ?? 'No places selected';

    final text = '''
🌟 NexTripia-AI Plan for $destination
📅 Dates: $dates
👥 Travelers: $group
📍 Must-Visit Places:
$places

Plan crafted with NexTripia-AI Travel Companion!
''';

    Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Trip plan copied to clipboard! Ready to share.'),
        backgroundColor: Color(0xFF4F46E5),
        behavior: SnackBarBehavior.floating,
      ),
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
    final schedule = _buildDailySchedule(places, daysCount);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Interactive Google Map Container
        _buildMapSection(),

        // 2. Trip Header Banner & Quick Badges
        _buildTripHeaderBanner(destination, startDate, endDate, groupSize, daysCount, places.length),

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
          onPressed: () => Navigator.pop(context),
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
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Color(0xFF6366F1)),
            tooltip: 'Share Plan',
            onPressed: _shareTripPlan,
          ),
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
                          Navigator.pop(context);
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
    final double mapHeight = _isMapExpanded ? 420 : 260;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: mapHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
              // Reset bounds after map is loaded
              Future.delayed(const Duration(milliseconds: 500), _resetMapBounds);
            },
          ),

          // Top floating controls
          Positioned(
            top: 12,
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
                const SizedBox(height: 8),

                // Recenter All Stops
                _buildMapFloatingButton(
                  icon: Icons.fit_screen_rounded,
                  tooltip: 'Fit All Stops',
                  onTap: _resetMapBounds,
                ),
              ],
            ),
          ),

          // Bottom Route Banner on Map
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
                          : 'Interactive Route Map • ${_markers.length - 1} Spots',
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
                      onTap: () {
                        setState(() {
                          _selectedPlace = null;
                        });
                        _resetMapBounds();
                      },
                      child: const Text(
                        'Show All',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
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
    int placesCount,
  ) {
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
    return Container(
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
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
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

  Widget _buildItinerarySection(List<Map<String, dynamic>> schedule) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final warnings = _getItineraryWarnings();

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
          else
            ...schedule.map((dayPlan) {
              final dayNum = dayPlan['dayNumber'] as int;
              final dayTitle = (dayPlan['title'] ?? 'Day $dayNum').toString();
              final activities = dayPlan['activities'] as List<Map<String, String>>;

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
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
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
                          final placeName = act['place']!;
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
            }),
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
