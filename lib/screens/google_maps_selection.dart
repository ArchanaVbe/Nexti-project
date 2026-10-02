import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart' as geo;

class GoogleMapsSelection extends StatefulWidget {
  const GoogleMapsSelection({super.key});

  @override
  State<GoogleMapsSelection> createState() => _GoogleMapsSelectionState();
}

class _GoogleMapsSelectionState extends State<GoogleMapsSelection> {
  late GoogleMapController mapController;
  final loc.Location locationController = loc.Location();

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

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final locationData = await locationController.getLocation();
      final lat = locationData.latitude;
      final lng = locationData.longitude;

      if (lat == null || lng == null) {
        setState(() => isLoading = false);
        return;
      }

      final fetchedLocation = LatLng(lat, lng);
      setState(() {
        currentLocation = fetchedLocation;
        isLoading = false;
      });

      try {
        final placemarks = await geo.placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty && mounted) {
          setState(() {
            currentLocationController.text =
                '${placemarks[0].locality ?? ''}, ${placemarks[0].administrativeArea ?? ''}'.trim();
          });
        }
      } catch (_) {}

      _addCurrentLocationMarker();
      _updateMapCamera(fetchedLocation);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching location: $e')),
        );
      }
      setState(() => isLoading = false);
    }
  }

  void _addCurrentLocationMarker() {
    if (currentLocation == null) return;

    setState(() {
      markers.add(
        Marker(
          markerId: const MarkerId('current'),
          position: currentLocation!,
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    });
  }

  Future<void> _updateMapCamera(LatLng position) async {
    if (!mounted) return;
    await mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: 14),
      ),
    );
  }

  Future<void> _drawRoute() async {
    if (currentLocation == null || selectedDestination == null) return;

    final distance = _calculateDistance(currentLocation!, selectedDestination!);
    final time = _estimateTravelTime(distance);

    try {
      final placemarks = await geo.placemarkFromCoordinates(
        selectedDestination!.latitude,
        selectedDestination!.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        setState(() {
          destinationController.text =
              '${placemarks[0].locality ?? ''}, ${placemarks[0].administrativeArea ?? ''}'.trim();
        });
      }
    } catch (_) {}

    setState(() {
      distanceInKm = distance;
      travelTime = time;

      markers.clear();
      _addCurrentLocationMarker();
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: selectedDestination!,
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );

      polylines.clear();
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: [currentLocation!, selectedDestination!],
          color: Colors.blue,
          width: 5,
          geodesic: true,
        ),
      );

      circles.clear();
      circles.add(
        Circle(
          circleId: const CircleId('radius_500m'),
          center: selectedDestination!,
          radius: 500,
          fillColor: Colors.blue.withOpacity(0.1),
          strokeColor: Colors.blue.withOpacity(0.5),
          strokeWidth: 2,
        ),
      );
      circles.add(
        Circle(
          circleId: const CircleId('radius_1km'),
          center: selectedDestination!,
          radius: 1000,
          fillColor: Colors.transparent,
          strokeColor: Colors.blue.withOpacity(0.3),
          strokeWidth: 1,
        ),
      );
    });
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
    final minutes = (distanceInKm / 40 * 60).round();
    return Duration(minutes: minutes);
  }

  void _handleDone() {
    if (currentLocation == null || selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both locations on the map')),
      );
      return;
    }

    Navigator.pop(context, {
      'currentLocation': currentLocation,
      'destination': selectedDestination,
      'distance': distanceInKm,
      'travelTime': travelTime,
      'currentLocationName': currentLocationController.text,
      'destinationName': destinationController.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : currentLocation == null
              ? const Center(child: Text('Unable to fetch current location'))
              : Stack(
                  children: [
                    GoogleMap(
                      onMapCreated: (GoogleMapController controller) {
                        mapController = controller;
                      },
                      initialCameraPosition: CameraPosition(
                        target: currentLocation!,
                        zoom: 14,
                      ),
                      markers: markers,
                      polylines: polylines,
                      circles: circles,
                      onTap: (LatLng position) {
                        setState(() {
                          selectedDestination = position;
                        });
                        _drawRoute();
                      },
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      compassEnabled: true,
                      zoomControlsEnabled: true,
                    ),
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Current Location', style: TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              currentLocationController.text.isNotEmpty
                                  ? currentLocationController.text
                                  : 'Fetching location...',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (distanceInKm != null && travelTime != null)
                      Positioned(
                        bottom: 110,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Route Details',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      destinationController.text,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.directions_car, color: Colors.blue),
                                        const SizedBox(width: 8),
                                        Text('${distanceInKm!.toStringAsFixed(2)} km'),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.timer, color: Colors.blue),
                                        const SizedBox(width: 8),
                                        Text('${travelTime!.inMinutes} mins'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: ElevatedButton(
                        onPressed: _handleDone,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
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
