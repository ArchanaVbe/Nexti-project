import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HotelBookingMaps extends StatefulWidget {
  final LatLng userLocation;

  const HotelBookingMaps({Key? key, required this.userLocation}) : super(key: key);

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
          imageUrl: 'https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=400&h=300&fit=crop',
          latitude: 14.4644,
          longitude: 75.9218,
          pricePerNight: 3500,
          checkInTime: '2:00 PM',
          checkOutTime: '11:00 AM',
          amenities: ['Free WiFi', 'Swimming Pool', 'Restaurant', 'Gym', 'Spa'],
          description: 'A luxurious 5-star hotel in the heart of Davangere with world-class amenities.',
        ),
        Hotel(
          id: '2',
          name: 'Mysuru Resort & Spa',
          rating: 4.3,
          reviews: 250,
          address: 'Mysuru, Karnataka, India',
          distance: 35.8,
          travelTime: const Duration(hours: 1, minutes: 10),
          imageUrl: 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=400&h=300&fit=crop',
          latitude: 12.2958,
          longitude: 76.6394,
          pricePerNight: 2800,
          checkInTime: '3:00 PM',
          checkOutTime: '12:00 PM',
          amenities: ['Free WiFi', 'Ayurveda Spa', 'Multi-cuisine Restaurant', 'Gardens'],
          description: 'A premium resort offering traditional Ayurveda treatments and modern comfort.',
        ),
        Hotel(
          id: '3',
          name: 'Harihara Heritage Hotel',
          rating: 4.0,
          reviews: 180,
          address: 'Harihara, Karnataka, India',
          distance: 45.2,
          travelTime: const Duration(hours: 1, minutes: 30),
          imageUrl: 'https://images.unsplash.com/photo-1495521821757-a1efb6729352?w=400&h=300&fit=crop',
          latitude: 14.1868,
          longitude: 75.1277,
          pricePerNight: 2200,
          checkInTime: '1:00 PM',
          checkOutTime: '10:00 AM',
          amenities: ['Free WiFi', 'Temple View Room', 'Indian Restaurant', 'Parking'],
          description: 'A heritage hotel with traditional architecture and cultural experiences.',
        ),
      ];

      _updateHotelMarkers();
    });
  }

  void _updateHotelMarkers() {
    hotelMarkers.clear();
    for (int i = 0; i < nearbyHotels.length; i++) {
      final hotel = nearbyHotels[i];
      hotelMarkers.add(
        Marker(
          markerId: MarkerId(hotel.id),
          position: LatLng(hotel.latitude, hotel.longitude),
          infoWindow: InfoWindow(
            title: hotel.name,
            snippet: '${hotel.distance} km - ₹${hotel.pricePerNight}/night',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          onTap: () => _selectHotel(hotel),
        ),
      );
    }
  }

  Future<void> _selectHotel(Hotel hotel) async {
    setState(() {
      selectedHotel = hotel;

      routeToHotel = Polyline(
        polylineId: const PolylineId('hotel_route'),
        points: [
          widget.userLocation,
          LatLng(hotel.latitude, hotel.longitude),
        ],
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

    _showHotelDetails(hotel);
  }

  void _showHotelDetails(Hotel hotel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => HotelDetailsSheet(
        hotel: hotel,
        userLocation: widget.userLocation,
        onBook: () => _handleHotelBooking(hotel),
      ),
    );
  }

  void _handleHotelBooking(Hotel hotel) {
    Navigator.pop(context);
    Navigator.pop(context, hotel);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Hotel'),
        elevation: 0,
      ),
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
                      blurRadius: 10,
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
    Key? key,
    required this.hotel,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          elevation: isSelected ? 8 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected
                ? const BorderSide(color: Colors.blue, width: 2)
                : BorderSide.none,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                    child: Image.network(
                      hotel.imageUrl,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 120,
                          color: Colors.grey[300],
                          child: const Icon(Icons.hotel, size: 40),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            '${hotel.rating}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hotel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${hotel.reviews} reviews',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${hotel.distance} km',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              Text(
                                '${hotel.travelTime.inMinutes} mins',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '₹${hotel.pricePerNight}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
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
    Key? key,
    required this.hotel,
    required this.userLocation,
    required this.onBook,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    hotel.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                hotel.imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: const Icon(Icons.hotel, size: 80),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${hotel.rating}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${hotel.reviews} reviews',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'About',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              hotel.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.blue, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Location',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            Text(
                              hotel.address,
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.directions, color: Colors.blue, size: 18),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Distance',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                                Text(
                                  '${hotel.distance} km',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.timer, color: Colors.blue, size: 18),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Travel Time',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                                Text(
                                  '${hotel.travelTime.inMinutes} mins',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Check-in',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hotel.checkInTime,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Check-out',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hotel.checkOutTime,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Amenities',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: hotel.amenities
                  .map(
                    (amenity) => Chip(
                      label: Text(amenity),
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      labelStyle: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 12,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Price per Night',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    '₹${hotel.pricePerNight}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onBook,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Book Now',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}