import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HotelBookingMaps extends StatefulWidget {
  final LatLng userLocation;

  const HotelBookingMaps({super.key, required this.userLocation});

  @override
  State<HotelBookingMaps> createState() => _HotelBookingMapsState();
}

class _HotelBookingMapsState extends State<HotelBookingMaps> {
  late GoogleMapController mapController;
  List<Hotel> nearbyHotels = [];
  Hotel? selectedHotel;
  Set<Marker> hotelMarkers = {};
  Polyline? routeToHotel;
  Set<Circle> radiusCircles = {};

  @override
  void initState() {
    super.initState();
    _fetchNearbyHotels();
  }

  Future<void> _fetchNearbyHotels() async {
    setState(() {
      nearbyHotels = [
        Hotel(
          id: '1',
          name: 'Hotel Grand Karnataka',
          rating: 4.5,
          reviews: 320,
          address: 'Davangere, Karnataka, India',
          distance: 2.5,
          travelTime: const Duration(minutes: 15),
          imageUrl: 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800&q=80',
          latitude: 14.4644,
          longitude: 75.9218,
          pricePerNight: 3500,
          checkInTime: '2:00 PM',
          checkOutTime: '11:00 AM',
          amenities: ['Free WiFi', 'Pool', 'Restaurant', 'Gym'],
          description: 'Luxury hotel with modern amenities and easy access to the city center.',
        ),
        Hotel(
          id: '2',
          name: 'Mysuru Resort & Spa',
          rating: 4.3,
          reviews: 250,
          address: 'Mysuru, Karnataka, India',
          distance: 35.8,
          travelTime: const Duration(hours: 1, minutes: 10),
          imageUrl: 'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800&q=80',
          latitude: 12.2958,
          longitude: 76.6394,
          pricePerNight: 2800,
          checkInTime: '3:00 PM',
          checkOutTime: '12:00 PM',
          amenities: ['Spa', 'Parking', 'Buffet', 'Garden'],
          description: 'Premium resort experience with wellness and spacious rooms.',
        ),
      ];

      _updateHotelMarkers();
    });
  }

  void _updateHotelMarkers() {
    hotelMarkers.clear();
    for (final hotel in nearbyHotels) {
      hotelMarkers.add(
        Marker(
          markerId: MarkerId(hotel.id),
          position: LatLng(hotel.latitude, hotel.longitude),
          infoWindow: InfoWindow(
            title: hotel.name,
            snippet: '${hotel.distance} km • ₹${hotel.pricePerNight}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          onTap: () => _selectHotel(hotel),
        ),
      );
    }
  }

  Future<void> _selectHotel(Hotel hotel) async {
    final distance = _calculateDistance(
      widget.userLocation.latitude,
      widget.userLocation.longitude,
      hotel.latitude,
      hotel.longitude,
    );

    setState(() {
      selectedHotel = hotel;
      routeToHotel = Polyline(
        polylineId: const PolylineId('hotel_route'),
        points: [widget.userLocation, LatLng(hotel.latitude, hotel.longitude)],
        color: Colors.green,
        width: 5,
        geodesic: true,
      );
      radiusCircles.clear();
      radiusCircles.add(Circle(
        circleId: const CircleId('hotel_radius'),
        center: LatLng(hotel.latitude, hotel.longitude),
        radius: 500,
        fillColor: Colors.green.withOpacity(0.1),
        strokeColor: Colors.green.withOpacity(0.5),
        strokeWidth: 2,
      ));
    });

    await mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(hotel.latitude, hotel.longitude),
          zoom: 15,
        ),
      ),
    );

    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => HotelDetailsSheet(
          hotel: hotel,
          distance: distance,
          onBook: () {
            Navigator.pop(context);
            Navigator.pop(context, hotel);
          },
        ),
      );
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final distanceLat = _toRadians(lat2 - lat1);
    final distanceLon = _toRadians(lon2 - lon1);
    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);

    final a = sin(distanceLat / 2) * sin(distanceLat / 2) +
        sin(distanceLon / 2) * sin(distanceLon / 2) * cos(lat1Rad) * cos(lat2Rad);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRadians(double degree) => degree * pi / 180;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Hotel')),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              mapController = controller;
            },
            initialCameraPosition: CameraPosition(
              target: widget.userLocation,
              zoom: 14,
            ),
            markers: hotelMarkers,
            polylines: routeToHotel != null ? {routeToHotel!} : {},
            circles: radiusCircles,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            compassEnabled: true,
            zoomControlsEnabled: true,
          ),
          if (nearbyHotels.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  itemCount: nearbyHotels.length,
                  itemBuilder: (context, index) {
                    final hotel = nearbyHotels[index];
                    return HotelCard(
                      hotel: hotel,
                      isSelected: selectedHotel?.id == hotel.id,
                      onTap: () => _selectHotel(hotel),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class Hotel {
  final String id;
  final String name;
  final double rating;
  final int reviews;
  final String address;
  final double distance;
  final Duration travelTime;
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
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          elevation: isSelected ? 6 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected ? const BorderSide(color: Colors.blue, width: 2) : BorderSide.none,
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  hotel.imageUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hotel.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text('${hotel.distance} km away', style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${hotel.travelTime.inMinutes} mins', style: const TextStyle(color: Colors.blue)),
                        Text('₹${hotel.pricePerNight}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
  final double distance;
  final VoidCallback onBook;

  const HotelDetailsSheet({
    super.key,
    required this.hotel,
    required this.distance,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                hotel.imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hotel.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 18),
                const SizedBox(width: 4),
                Text('${hotel.rating} (${hotel.reviews} reviews)'),
              ],
            ),
            const SizedBox(height: 16),
            Text(hotel.description),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Distance: ${distance.toStringAsFixed(1)} km'),
                Text('Travel: ${hotel.travelTime.inMinutes} mins'),
              ],
            ),
            const SizedBox(height: 16),
            Text('Address: ${hotel.address}'),
            const SizedBox(height: 16),
            Text('Check-in: ${hotel.checkInTime}'),
            Text('Check-out: ${hotel.checkOutTime}'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: hotel.amenities
                  .map(
                    (amenity) => Chip(
                      label: Text(amenity),
                      backgroundColor: Colors.blue.withOpacity(0.1),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Price per night'),
                Text('₹${hotel.pricePerNight}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onBook,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Book Now', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
