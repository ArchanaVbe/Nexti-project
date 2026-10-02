import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/karnataka_places.dart';
import '../services/road_routing_service.dart';

class Hotel {
  final String id;
  final String name;
  final double rating;
  final int reviews;
  final String address;
  final double distance; // Distance in km from present place
  final Duration travelTime; // Travel time from present place
  final String imageUrl;
  final double latitude;
  final double longitude;
  final int pricePerNight;
  final String checkInTime;
  final String checkOutTime;
  final List<String> amenities;
  final String description;

  Hotel({
    required this.id,
    required this.name,
    required this.rating,
    required this.reviews,
    required this.address,
    required this.distance,
    required this.travelTime,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.pricePerNight,
    required this.checkInTime,
    required this.checkOutTime,
    required this.amenities,
    required this.description,
  });
}

class HotelBookingMaps extends StatefulWidget {
  final LatLng userLocation;
  final String? destinationCity;
  final LatLng? destinationLocation;

  const HotelBookingMaps({
    super.key,
    this.userLocation = const LatLng(14.4644, 75.9218),
    this.destinationCity,
    this.destinationLocation,
  });

  @override
  State<HotelBookingMaps> createState() => _HotelBookingMapsState();
}

class _HotelBookingMapsState extends State<HotelBookingMaps> {
  GoogleMapController? mapController;
  List<Hotel> allHotels = [];
  List<Hotel> filteredHotels = [];
  Hotel? selectedHotel;
  Set<Marker> hotelMarkers = {};
  Polyline? routeToHotel;
  Set<Circle> radiusCircles = {};
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHotels();
  }

  void _loadHotels() {
    final dest = widget.destinationCity?.trim() ?? 'Coorg';
    final destLower = dest.toLowerCase();

    // Resolve destination center coordinates
    LatLng centerPos;
    if (widget.destinationLocation != null) {
      centerPos = widget.destinationLocation!;
    } else {
      final kPlace = KarnatakaPlacesRegistry.resolvePlace(dest);
      if (kPlace != null) {
        centerPos = LatLng(kPlace.lat, kPlace.lng);
      } else {
        centerPos = const LatLng(12.4244, 75.7382); // Coorg fallback
      }
    }

    final hotels = _getHotelsForDestination(destLower, centerPos);

    setState(() {
      allHotels = hotels;
      filteredHotels = hotels;
      if (filteredHotels.isNotEmpty) {
        selectedHotel = filteredHotels.first;
      }
    });

    _updateHotelMarkers();

    if (selectedHotel != null) {
      _applyHotelSelection(selectedHotel!, animateCamera: false);
    }
  }

  List<Hotel> _getHotelsForDestination(String destLower, LatLng center) {
    if (destLower.contains('coorg') || destLower.contains('madikeri') || destLower.contains('kodagu')) {
      return [
        _buildHotel(
          id: 'c1',
          name: 'The Tamara Coorg Nature Resort',
          rating: 4.8,
          reviews: 1420,
          address: 'Kabbinakad Estate, Napoklu Nad, Coorg, Karnataka',
          lat: 12.2356,
          lng: 75.7681,
          price: 11500,
          checkIn: '02:00 PM',
          checkOut: '11:00 AM',
          image: 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=600&h=400&fit=crop',
          amenities: ['Infinity Pool', 'Ayurveda Spa', 'Coffee Plantation Walk', 'Multi-cuisine Restaurant', 'Free WiFi'],
          description: 'A 5-star luxury eco-resort nestled amidst lush coffee plantations and mist-covered hills.',
        ),
        _buildHotel(
          id: 'c2',
          name: 'Heritage Resort Coorg',
          rating: 4.5,
          reviews: 980,
          address: '50/3, 1st Monnangeri Village, Galibeedu, Madikeri, Coorg',
          lat: 12.4589,
          lng: 75.7214,
          price: 5200,
          checkIn: '01:00 PM',
          checkOut: '11:00 AM',
          image: 'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=600&h=400&fit=crop',
          amenities: ['Valley View Suites', 'Swimming Pool', 'Bonfire & BBQ', 'Kids Play Area', 'Restaurant'],
          description: 'Perched on a scenic cliff top offering breathtaking panoramic valley views of Western Ghats.',
        ),
        _buildHotel(
          id: 'c3',
          name: 'Club Mahindra Madikeri Resort',
          rating: 4.4,
          reviews: 1650,
          address: 'Galibeedu Road, Kalakeri Nidugane, Madikeri, Coorg',
          lat: 12.4410,
          lng: 75.7190,
          price: 6800,
          checkIn: '02:00 PM',
          checkOut: '10:00 AM',
          image: 'https://images.unsplash.com/photo-1618773928121-c32242e63f39?w=600&h=400&fit=crop',
          amenities: ['Two Pools', 'Adventure Sports', 'Spa & Wellness', 'Traditional Kodava Dining', 'Free Parking'],
          description: 'Built in traditional Ainmane style surrounded by fragrant cardamom hills and dense greenery.',
        ),
        _buildHotel(
          id: 'c4',
          name: 'Coorg Wilderness Resort & Spa',
          rating: 4.9,
          reviews: 840,
          address: 'Virajpet Road, Madikeri, Coorg, Karnataka',
          lat: 12.3920,
          lng: 75.7890,
          price: 13500,
          checkIn: '02:00 PM',
          checkOut: '12:00 PM',
          image: 'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=600&h=400&fit=crop',
          amenities: ['Heated Pool', 'Luxury Chalets', 'Bird Watching Trail', 'Fine Dining Bar', 'Gym'],
          description: 'Sprawling European-style luxury resort offering wilderness suites with heated private bathrooms.',
        ),
      ];
    } else if (destLower.contains('shimoga') || destLower.contains('shivamogga')) {
      return [
        _buildHotel(
          id: 's1',
          name: 'Royal Orchid Central Shivamogga',
          rating: 4.5,
          reviews: 1120,
          address: 'B.H. Road, opposite Vinayak Theatre, Shivamogga, Karnataka',
          lat: 13.9312,
          lng: 75.5701,
          price: 3900,
          checkIn: '01:00 PM',
          checkOut: '11:00 AM',
          image: 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=600&h=400&fit=crop',
          amenities: ['Pinxx Multi-cuisine Restaurant', 'Fitness Center', 'Banquet Halls', 'Valet Parking', 'Free WiFi'],
          description: 'Premier business and leisure luxury hotel situated in the heart of Shimoga city.',
        ),
        _buildHotel(
          id: 's2',
          name: 'Harsha The Fern Shivamogga',
          rating: 4.6,
          reviews: 780,
          address: 'Savadal Nirvanappa Layout, Vidyanagar, Shivamogga, Karnataka',
          lat: 13.9180,
          lng: 75.5890,
          price: 4400,
          checkIn: '02:00 PM',
          checkOut: '12:00 PM',
          image: 'https://images.unsplash.com/photo-1618773928121-c32242e63f39?w=600&h=400&fit=crop',
          amenities: ['Eco Boutique Hotel', 'Swimming Pool', 'Rooftop Lounge', 'Coffee Shop', 'Conference Rooms'],
          description: 'Environment-sensitive hotel offering luxurious contemporary rooms and sustainable hospitality.',
        ),
        _buildHotel(
          id: 's3',
          name: 'Kimmane Luxury Golf Resort',
          rating: 4.8,
          reviews: 520,
          address: 'Bhairumbe, Bilaki Village, Shimoga, Karnataka',
          lat: 13.9850,
          lng: 75.4620,
          price: 9800,
          checkIn: '02:00 PM',
          checkOut: '11:00 AM',
          image: 'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=600&h=400&fit=crop',
          amenities: ['9-Hole Golf Course', 'Lake View Suites', 'Spa Retreat', 'Kayaking', 'Fine Dining'],
          description: 'Nestled between Western Ghats valleys and water reservoirs, featuring world-class golf amenities.',
        ),
        _buildHotel(
          id: 's4',
          name: 'Hotel Jewel Rock',
          rating: 4.1,
          reviews: 640,
          address: 'Durgigudi, Shivamogga, Karnataka',
          lat: 13.9350,
          lng: 75.5620,
          price: 2100,
          checkIn: '12:00 PM',
          checkOut: '11:00 AM',
          image: 'https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=600&h=400&fit=crop',
          amenities: ['Vegetarian Restaurant', 'Bar', 'Travel Desk', '24/7 Room Service', 'Free Parking'],
          description: 'Renowned legacy hotel known for great South Indian hospitality and proximity to Jog Falls routes.',
        ),
      ];
    } else if (destLower.contains('mysore') || destLower.contains('mysuru')) {
      return [
        _buildHotel(
          id: 'm1',
          name: 'Grand Mercure Mysore',
          rating: 4.7,
          reviews: 1850,
          address: 'New Sayyaji Rao Road, Nelson Mandela Circle, Mysuru, Karnataka',
          lat: 12.3325,
          lng: 76.6432,
          price: 5400,
          checkIn: '02:00 PM',
          checkOut: '11:00 AM',
          image: 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=600&h=400&fit=crop',
          amenities: ['Rooftop Pool', 'La Petite Spa', 'Palace View Dining', 'Kids Club', 'Fitness Center'],
          description: 'Contemporary 5-star hotel near Mysore Palace celebrating the city’s rich cultural heritage.',
        ),
        _buildHotel(
          id: 'm2',
          name: 'Radisson Blu Plaza Hotel Mysore',
          rating: 4.6,
          reviews: 2100,
          address: 'MG Road, Chamundi Hill Road, Mysuru, Karnataka',
          lat: 12.3015,
          lng: 76.6690,
          price: 6200,
          checkIn: '02:00 PM',
          checkOut: '12:00 PM',
          image: 'https://images.unsplash.com/photo-1618773928121-c32242e63f39?w=600&h=400&fit=crop',
          amenities: ['Chamundi Hill View', 'Outdoor Pool', 'Spa', 'Spring Multi-cuisine', 'Golf Course Nearby'],
          description: 'Sprawling upscale property nestled at the foot of Chamundi Hills with luxurious rooms.',
        ),
        _buildHotel(
          id: 'm3',
          name: 'Royal Orchid Metropole Mysore',
          rating: 4.5,
          reviews: 1300,
          address: 'J.H. Patel Circle, Mysuru, Karnataka',
          lat: 12.3130,
          lng: 76.6450,
          price: 4900,
          checkIn: '01:00 PM',
          checkOut: '11:00 AM',
          image: 'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=600&h=400&fit=crop',
          amenities: ['Heritage Architecture', 'Courtyard Restaurant', 'Swimming Pool', 'Bar & Lounge', 'Gym'],
          description: 'Historic royal heritage hotel with vintage colonial arches, lush lawns, and royal suites.',
        ),
      ];
    } else if (destLower.contains('hampi')) {
      return [
        _buildHotel(
          id: 'h1',
          name: 'Evolve Back Kamalapura Palace Hampi',
          rating: 4.9,
          reviews: 950,
          address: 'Kamalapura, Vijayanagara, Hampi, Karnataka',
          lat: 15.3020,
          lng: 76.4820,
          price: 18500,
          checkIn: '02:00 PM',
          checkOut: '11:00 AM',
          image: 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=600&h=400&fit=crop',
          amenities: ['Palace Architecture', 'Private Jacuzzi Suites', 'Infinity Pool', 'Ayurvedic Spa', 'Historian Walks'],
          description: 'UNESCO heritage-inspired palace hotel reflecting 14th-century Vijayanagara imperial architecture.',
        ),
        _buildHotel(
          id: 'h2',
          name: 'Heritage Resort Hampi',
          rating: 4.5,
          reviews: 1200,
          address: 'Hosapete-Hampi Road, Hampi, Karnataka',
          lat: 15.2950,
          lng: 76.4350,
          price: 6800,
          checkIn: '01:00 PM',
          checkOut: '11:00 AM',
          image: 'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=600&h=400&fit=crop',
          amenities: ['Organic Mango Orchard', 'Swimming Pool', 'Ayurveda Centre', 'Cycling Tours', 'Restaurant'],
          description: 'Serene eco-resort in rural Hampi surrounded by mango trees and gentle boulder hills.',
        ),
      ];
    }

    // Generic dynamic hotel generator around destination coordinates
    return [
      _buildHotel(
        id: 'gen1',
        name: 'The Grand ${widget.destinationCity ?? "Karnataka"} Resort & Spa',
        rating: 4.6,
        reviews: 890,
        address: 'Central Boulevard, ${widget.destinationCity ?? "City Center"}, Karnataka',
        lat: center.latitude + 0.015,
        lng: center.longitude + 0.012,
        price: 4500,
        checkIn: '02:00 PM',
        checkOut: '11:00 AM',
        image: 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=600&h=400&fit=crop',
        amenities: ['Swimming Pool', 'Spa & Wellness', 'Multi-cuisine Restaurant', 'Free High-speed WiFi', 'Parking'],
        description: 'Upscale premium hotel featuring elegant rooms and top-tier amenities near major attractions.',
      ),
      _buildHotel(
        id: 'gen2',
        name: '${widget.destinationCity ?? "Hill"} Heritage Valley Stays',
        rating: 4.4,
        reviews: 620,
        address: 'Bypass Road, near ${widget.destinationCity ?? "Sightseeing Route"}, Karnataka',
        lat: center.latitude - 0.018,
        lng: center.longitude + 0.022,
        price: 3200,
        checkIn: '01:00 PM',
        checkOut: '11:00 AM',
        image: 'https://images.unsplash.com/photo-1618773928121-c32242e63f39?w=600&h=400&fit=crop',
        amenities: ['Garden View Rooms', 'Restaurant', 'Bonfire', 'Room Service', 'Travel Desk'],
        description: 'Serene scenic stay with spacious comfortable cottages and authentic regional culinary offerings.',
      ),
      _buildHotel(
        id: 'gen3',
        name: '${widget.destinationCity ?? "Central"} Royal Orchid Inn',
        rating: 4.3,
        reviews: 430,
        address: 'Station Road, ${widget.destinationCity ?? "Town"}, Karnataka',
        lat: center.latitude - 0.010,
        lng: center.longitude - 0.015,
        price: 2400,
        checkIn: '12:00 PM',
        checkOut: '11:00 AM',
        image: 'https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=600&h=400&fit=crop',
        amenities: ['Air Conditioned', 'Free WiFi', 'Vegetarian Kitchen', '24h Front Desk', 'Laundry'],
        description: 'Cozy and conveniently situated modern hotel with exceptional service and dining options.',
      ),
    ];
  }

  Hotel _buildHotel({
    required String id,
    required String name,
    required double rating,
    required int reviews,
    required String address,
    required double lat,
    required double lng,
    required int price,
    required String checkIn,
    required String checkOut,
    required String image,
    required List<String> amenities,
    required String description,
  }) {
    final distance = _calculateDistance(widget.userLocation, LatLng(lat, lng));
    final travelTime = _estimateTravelTime(distance);

    return Hotel(
      id: id,
      name: name,
      rating: rating,
      reviews: reviews,
      address: address,
      distance: distance,
      travelTime: travelTime,
      imageUrl: image,
      latitude: lat,
      longitude: lng,
      pricePerNight: price,
      checkInTime: checkIn,
      checkOutTime: checkOut,
      amenities: amenities,
      description: description,
    );
  }

  double _calculateDistance(LatLng start, LatLng end) {
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

  Duration _estimateTravelTime(double distanceInKm) {
    final minutes = (distanceInKm / 45 * 60).round();
    return Duration(minutes: max(5, minutes));
  }

  void _updateHotelMarkers() {
    hotelMarkers.clear();
    for (final hotel in filteredHotels) {
      final isSelected = selectedHotel?.id == hotel.id;
      hotelMarkers.add(
        Marker(
          markerId: MarkerId(hotel.id),
          position: LatLng(hotel.latitude, hotel.longitude),
          infoWindow: InfoWindow(
            title: hotel.name,
            snippet: '₹${hotel.pricePerNight} • ${hotel.distance.toStringAsFixed(1)} km away',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isSelected ? BitmapDescriptor.hueRed : BitmapDescriptor.hueOrange,
          ),
          onTap: () => _applyHotelSelection(hotel),
        ),
      );
    }
  }

  Future<void> _applyHotelSelection(Hotel hotel, {bool animateCamera = true}) async {
    setState(() {
      selectedHotel = hotel;

      // Draw radius circle around hotel
      radiusCircles.clear();
      radiusCircles.add(
        Circle(
          circleId: const CircleId('hotel_radius_inner'),
          center: LatLng(hotel.latitude, hotel.longitude),
          radius: 500,
          fillColor: const Color(0xFF1E8E3E).withValues(alpha: 0.15),
          strokeColor: const Color(0xFF1E8E3E).withValues(alpha: 0.6),
          strokeWidth: 2,
        ),
      );
      radiusCircles.add(
        Circle(
          circleId: const CircleId('hotel_radius_outer'),
          center: LatLng(hotel.latitude, hotel.longitude),
          radius: 1000,
          fillColor: const Color(0xFF1E8E3E).withValues(alpha: 0.05),
          strokeColor: const Color(0xFF1E8E3E).withValues(alpha: 0.3),
          strokeWidth: 1,
        ),
      );
    });

    _updateHotelMarkers();

    // Fetch actual driving road route to the selected hotel
    try {
      final routeResult = await RoadRoutingService.getDrivingRoute(
        widget.userLocation,
        LatLng(hotel.latitude, hotel.longitude),
      );
      if (mounted && selectedHotel?.id == hotel.id) {
        setState(() {
          routeToHotel = Polyline(
            polylineId: const PolylineId('hotel_route'),
            points: routeResult.points,
            color: const Color(0xFF1E8E3E), // Google Maps Green
            width: 5,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            geodesic: true,
          );
        });
      }
    } catch (_) {}

    _updateHotelMarkers();

    if (animateCamera && mapController != null) {
      await mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(hotel.latitude, hotel.longitude),
            zoom: 14.5,
          ),
        ),
      );
    }
  }

  void _onSearchQueryChanged(String query) {
    final clean = query.trim().toLowerCase();
    setState(() {
      if (clean.isEmpty) {
        filteredHotels = allHotels;
      } else {
        filteredHotels = allHotels.where((h) {
          return h.name.toLowerCase().contains(clean) ||
              h.address.toLowerCase().contains(clean) ||
              h.amenities.any((a) => a.toLowerCase().contains(clean));
        }).toList();
      }
    });
    _updateHotelMarkers();
  }

  void _showHotelDetailsModal(Hotel hotel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HotelDetailsSheet(
        hotel: hotel,
        userLocation: widget.userLocation,
        onBook: () => _handleHotelConfirmation(hotel),
      ),
    );
  }

  void _handleHotelConfirmation(Hotel hotel) {
    Navigator.pop(context); // close bottom sheet
    Navigator.pop(context, hotel); // return hotel object to CreateTripScreen
  }

  @override
  Widget build(BuildContext context) {
    final centerTarget = selectedHotel != null
        ? LatLng(selectedHotel!.latitude, selectedHotel!.longitude)
        : widget.userLocation;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Google Map
            GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                mapController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: centerTarget,
                zoom: 13,
              ),
              markers: hotelMarkers,
              polylines: routeToHotel != null ? {routeToHotel!} : {},
              circles: radiusCircles,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              compassEnabled: true,
              zoomControlsEnabled: false,
            ),

            // 2. Top Header & Search Bar
            Positioned(
              top: 12,
              left: 14,
              right: 14,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            onChanged: _onSearchQueryChanged,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: 'Search hotels in ${widget.destinationCity ?? "Karnataka"}...',
                              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const Icon(Icons.hotel_rounded, color: Color(0xFF6366F1), size: 22),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3. Floating GPS re-center button
            Positioned(
              right: 14,
              bottom: 240,
              child: FloatingActionButton.small(
                heroTag: 'hotel_gps',
                backgroundColor: Colors.white,
                onPressed: () {
                  if (selectedHotel != null && mapController != null) {
                    mapController!.animateCamera(
                      CameraUpdate.newLatLngZoom(
                        LatLng(selectedHotel!.latitude, selectedHotel!.longitude),
                        14,
                      ),
                    );
                  }
                },
                child: const Icon(Icons.location_searching_rounded, color: Color(0xFF6366F1)),
              ),
            ),

            // 4. Horizontal Hotel Cards Carousel at Bottom
            if (filteredHotels.isNotEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 225,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                        Colors.black.withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    itemCount: filteredHotels.length,
                    itemBuilder: (context, index) {
                      final hotel = filteredHotels[index];
                      final isSel = selectedHotel?.id == hotel.id;
                      return HotelCard(
                        hotel: hotel,
                        isSelected: isSel,
                        onTap: () {
                          _applyHotelSelection(hotel);
                          _showHotelDetailsModal(hotel);
                        },
                      );
                    },
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
    searchController.dispose();
    super.dispose();
  }
}

class HotelCard extends StatelessWidget {
  final Hotel hotel;
  final bool isSelected;
  final VoidCallback onTap;

  const HotelCard({
    super.key,
    required this.hotel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
              width: isSelected ? 2.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? const Color(0xFF6366F1).withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Thumbnail with Rating Badge
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: Image.network(
                      hotel.imageUrl,
                      height: 105,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 105,
                        color: Colors.grey[200],
                        child: const Icon(Icons.hotel_rounded, size: 36, color: Colors.grey),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 12, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            '${hotel.rating}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '₹${hotel.pricePerNight} / night',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),

              // Details
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hotel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.near_me_rounded, size: 13, color: Color(0xFF6366F1)),
                        const SizedBox(width: 4),
                        Text(
                          '${hotel.distance.toStringAsFixed(1)} km away',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF1E8E3E)),
                        const SizedBox(width: 3),
                        Text(
                          hotel.travelTime.inHours > 0
                              ? '${hotel.travelTime.inHours}h ${hotel.travelTime.inMinutes % 60}m'
                              : '${hotel.travelTime.inMinutes}m',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E8E3E)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${hotel.reviews} reviews',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                        const Text(
                          'View details →',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HotelDetailsSheet extends StatelessWidget {
  final Hotel hotel;
  final LatLng userLocation;
  final VoidCallback onBook;

  const HotelDetailsSheet({
    super.key,
    required this.hotel,
    required this.userLocation,
    required this.onBook,
  });

  String _formatTravelTime(Duration d) {
    if (d.inHours > 0) {
      final mins = d.inMinutes % 60;
      return mins > 0 ? '${d.inHours} hr $mins min' : '${d.inHours} hr';
    }
    return '${d.inMinutes} mins';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title and close
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hotel.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star, size: 12, color: Colors.white),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${hotel.rating}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${hotel.reviews} reviews on Google Maps)',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Photo Banner
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  hotel.imageUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 180,
                    color: Colors.grey[200],
                    child: const Icon(Icons.hotel_rounded, size: 50, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Location from Present Place Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: Color(0xFFEA4335), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            hotel.address,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20, thickness: 0.8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text(
                              'Distance from You',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${hotel.distance.toStringAsFixed(1)} km',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF4285F4)),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 30, color: const Color(0xFFCBD5E1)),
                        Column(
                          children: [
                            const Text(
                              'Travel Time by Drive',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatTravelTime(hotel.travelTime),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E8E3E)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Timings (Check-in & Check-out)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.login_rounded, size: 18, color: Color(0xFF6366F1)),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Check-in', style: TextStyle(fontSize: 10, color: Color(0xFF6366F1))),
                            Text(hotel.checkInTime, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.logout_rounded, size: 18, color: Color(0xFF6366F1)),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Check-out', style: TextStyle(fontSize: 10, color: Color(0xFF6366F1))),
                            Text(hotel.checkOutTime, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Description
              const Text('About this stay', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 6),
              Text(
                hotel.description,
                style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 16),

              // Amenities
              const Text('Amenities & Highlights', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: hotel.amenities.map((a) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF1E8E3E)),
                        const SizedBox(width: 5),
                        Text(a, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Price & Confirm / Book button
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total per night', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      Text(
                        '₹${hotel.pricePerNight}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: onBook,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_rounded, size: 18),
                            SizedBox(width: 6),
                            Text('Confirm Hotel Stay', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}