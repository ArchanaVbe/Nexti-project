import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/trip_api.dart';
import '../models/trip_plan_models.dart';

class HotelPickResult {
  final String name;
  final double lat;
  final double lng;
  final String? address;

  HotelPickResult({
    required this.name,
    required this.lat,
    required this.lng,
    this.address,
  });
}

class HotelMapPickerScreen extends StatefulWidget {
  final LatLng initialCenter;
  final String destinationName;
  final String? initialHotelName;

  const HotelMapPickerScreen({
    super.key,
    required this.initialCenter,
    required this.destinationName,
    this.initialHotelName,
  });

  @override
  State<HotelMapPickerScreen> createState() => _HotelMapPickerScreenState();
}

class _HotelMapPickerScreenState extends State<HotelMapPickerScreen> {
  GoogleMapController? _mapController;
  late LatLng _selectedLocation;
  late TextEditingController _nameController;
  final TextEditingController _searchController = TextEditingController();

  String _resolvedAddress = '';
  bool _isResolving = false;
  MapType _currentMapType = MapType.normal;

  List<CitySuggestion> _searchSuggestions = [];
  bool _isSearching = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialCenter;
    _nameController = TextEditingController(
      text: widget.initialHotelName?.isNotEmpty == true
          ? widget.initialHotelName
          : '${widget.destinationName} Stay',
    );
    _resolveAddress(_selectedLocation.latitude, _selectedLocation.longitude);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _resolveAddress(double lat, double lng) async {
    setState(() {
      _isResolving = true;
    });

    try {
      final addr = await TripApi.reverseGeocode(lat, lng);
      if (mounted) {
        setState(() {
          _resolvedAddress = addr;
          _isResolving = false;
          if (_nameController.text.isEmpty ||
              _nameController.text.endsWith('Stay')) {
            _nameController.text = addr;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isResolving = false;
        });
      }
    }
  }

  void _onMapTapped(LatLng position) {
    setState(() {
      _selectedLocation = position;
    });
    _resolveAddress(position.latitude, position.longitude);
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchSuggestions = [];
        _isSearching = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 150), () async {
      setState(() {
        _isSearching = true;
      });

      try {
        final results = await TripApi.autocompleteCity(
          query.trim(),
          types: 'lodging',
          destination: widget.destinationName,
        );
        if (mounted) {
          setState(() {
            _searchSuggestions = results;
            _isSearching = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
        }
      }
    });
  }

  Future<void> _selectSearchSuggestion(CitySuggestion suggestion) async {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchSuggestions = [];
      _isSearching = false;
      _nameController.text = suggestion.description.split(',').first.trim();
    });

    try {
      final res = await TripApi.resolveCity(suggestion.placeId);
      final newPos = LatLng(res.lat, res.lng);
      setState(() {
        _selectedLocation = newPos;
        _resolvedAddress = suggestion.description;
      });
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: newPos, zoom: 16),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('hotel_pin'),
        position: _selectedLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        infoWindow: InfoWindow(
          title: _nameController.text,
          snippet: _resolvedAddress.isNotEmpty ? _resolvedAddress : 'Selected Stay',
        ),
      ),
    };

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close_rounded,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Choose Hotel on Map',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _currentMapType == MapType.normal ? Icons.satellite_alt_rounded : Icons.map_rounded,
              color: const Color(0xFF6366F1),
            ),
            tooltip: 'Toggle Satellite / Normal',
            onPressed: () {
              setState(() {
                _currentMapType = _currentMapType == MapType.normal
                    ? MapType.hybrid
                    : MapType.normal;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLocation,
              zoom: 13.5,
            ),
            mapType: _currentMapType,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: markers,
            onMapCreated: (ctrl) => _mapController = ctrl,
            onTap: _onMapTapped,
          ),

          // Search bar overlay
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search hotel or resort in ${widget.destinationName}...',
                      hintStyle: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
                        fontSize: 13.5,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6366F1)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchSuggestions = [];
                                });
                              },
                            )
                          : (_isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : null),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                if (_searchSuggestions.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 280),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchSuggestions.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        thickness: 0.5,
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                      itemBuilder: (ctx, idx) {
                        final sugg = _searchSuggestions[idx];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.hotel_rounded, size: 18, color: Color(0xFF6366F1)),
                          title: Text(
                            sugg.description,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          onTap: () => _selectSearchSuggestion(sugg),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Instruction badge (only visible when not searching)
          if (_searchSuggestions.isEmpty)
            Positioned(
              top: 76,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app_rounded, color: Colors.amberAccent, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Tap anywhere on the map to place hotel pin',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom card with confirm button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.hotel_rounded, color: Color(0xFF6366F1), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Hotel / Stay Location',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (_isResolving)
                                const Row(
                                  children: [
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 1.8),
                                    ),
                                    SizedBox(width: 6),
                                    Text('Resolving address...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                )
                              else
                                Text(
                                  _resolvedAddress.isNotEmpty
                                      ? _resolvedAddress
                                      : 'Coordinates: ${_selectedLocation.latitude.toStringAsFixed(4)}, ${_selectedLocation.longitude.toStringAsFixed(4)}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Hotel / Stay Name',
                        labelStyle: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                        label: const Text(
                          'Confirm Hotel Stay',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          final name = _nameController.text.trim().isNotEmpty
                              ? _nameController.text.trim()
                              : (_resolvedAddress.isNotEmpty
                                  ? _resolvedAddress
                                  : '${widget.destinationName} Hotel');
                          Navigator.pop(
                            context,
                            HotelPickResult(
                              name: name,
                              lat: _selectedLocation.latitude,
                              lng: _selectedLocation.longitude,
                              address: _resolvedAddress,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
