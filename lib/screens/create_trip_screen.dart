import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _groupSizeController = TextEditingController();

  int _currentStep = 1;
  final List<String> _selectedPlaces = [];
  Map<String, List<String>> _suggestedPlaces = {};
  bool _isLoadingPlaces = false;
  String _lastFetchedDestination = '';
  
  // ignore: prefer_final_fields
  bool _isHost = true; // Set to true by default for testing, friend can toggle this

  @override
  void dispose() {
    _destinationController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _groupSizeController.dispose();
    super.dispose();
  }

  Future<void> _fetchPlacesFromGoogle(String destination) async {
    if (destination == _lastFetchedDestination && _suggestedPlaces.isNotEmpty) return;
    
    setState(() {
      _isLoadingPlaces = true;
      _suggestedPlaces = {};
    });

    const apiKey = 'AIzaSyAE54ZyUoFHQ5JnJvaQBo15RjmxCS5v_ko';
    
    final categories = {
      'Adventure': 'adventure activities in $destination',
      'Nature': 'nature spots and parks in $destination',
      'Heritage': 'heritage sites and historical places in $destination',
      'Shopping': 'shopping markets and malls in $destination'
    };

    Map<String, List<String>> fetchedPlaces = {};

    for (var entry in categories.entries) {
      final categoryName = entry.key;
      final query = Uri.encodeComponent(entry.value);
      final url = 'https://maps.googleapis.com/maps/api/place/textsearch/json?query=$query&key=$apiKey';
      
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final results = data['results'] as List;
          
          List<String> places = [];
          for (var i = 0; i < results.length && i < 6; i++) { // Get top 6 places for each category
            places.add(results[i]['name'] as String);
          }
          fetchedPlaces[categoryName] = places;
        }
      } catch (e) {
        debugPrint('Error fetching $categoryName places: $e');
      }
    }

    if (mounted) {
      setState(() {
        // Fallback if API fails or returns no results
        if (fetchedPlaces.isEmpty || fetchedPlaces.values.every((list) => list.isEmpty)) {
          _suggestedPlaces = {
            'Adventure': ['Mountain Trek', 'River Rafting', 'Rock Climbing'],
            'Nature': ['Botanical Garden', 'Sunset Point', 'Lake View'],
            'Heritage': ['Historic Fort', 'Ancient Temple', 'Old City Walk'],
            'Shopping': ['Local Market', 'Handicraft Street']
          };
        } else {
          _suggestedPlaces = fetchedPlaces;
        }
        _lastFetchedDestination = destination;
        _isLoadingPlaces = false;
      });
    }
  }

  Widget _buildStepIndicator(String label, String number, bool isActive) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF6366F1) : const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF94A3B8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? const Color(0xFF6366F1) : const Color(0xFF94A3B8),
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          keyboardType: keyboardType,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.normal,
            ),
            prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6366F1), // header background color
              onPrimary: Colors.white, // header text color
              onSurface: Color(0xFF0F172A), // body text color
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        controller.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trip Details',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'Destination',
          hint: 'e.g. Mysuru, Hampi, Gokarna...',
          icon: Icons.location_on_outlined,
          controller: _destinationController,
          readOnly: !_isHost,
          onTap: () {
            if (!_isHost) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('You cannot change destination, ask host if you wish to change destination'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          },
        ),
        _buildTextField(
          label: 'Start Date',
          hint: 'Select start date',
          icon: Icons.calendar_today_outlined,
          controller: _startDateController,
          readOnly: true,
          onTap: () => _selectDate(context, _startDateController),
        ),
        _buildTextField(
          label: 'End Date',
          hint: 'Select end date',
          icon: Icons.calendar_today_outlined,
          controller: _endDateController,
          readOnly: true,
          onTap: () => _selectDate(context, _endDateController),
        ),
        _buildTextField(
          label: 'Group Size',
          hint: 'Number of people',
          icon: Icons.group_outlined,
          controller: _groupSizeController,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildStep2() {
    final suggestedPlaces = _suggestedPlaces;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preferences in ${_destinationController.text.isNotEmpty ? _destinationController.text : "your destination"}',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select the places you wish to visit',
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),
        if (_isLoadingPlaces)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFF6366F1)),
                  SizedBox(height: 16),
                  Text('Discovering real places from Google Maps...', style: TextStyle(color: Color(0xFF64748B))),
                ],
              ),
            ),
          )
        else
          ...suggestedPlaces.entries.map((category) {
            return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.key,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: category.value.map((place) {
                  final isSelected = _selectedPlaces.contains(place);
                  return FilterChip(
                    label: Text(place),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedPlaces.add(place);
                        } else {
                          _selectedPlaces.remove(place);
                        }
                      });
                    },
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    checkmarkColor: const Color(0xFF6366F1),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF64748B),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Group Planning',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Invite your friends to collaborate on this trip.',
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Column(
            children: [
              Icon(Icons.group_add_outlined, size: 48, color: Color(0xFF94A3B8)),
              SizedBox(height: 16),
              Text(
                'Group Features Coming Soon',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Pending integration from collaborator branch. Includes Trip Code, URL sharing, and QR Codes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Show trip',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Here is your finalized plan.',
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 32),
        // Trip details summary
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Destination: ${_destinationController.text}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 8),
              Text(
                'Dates: ${_startDateController.text} - ${_endDateController.text}',
                style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 8),
              Text(
                'Group Size: ${_groupSizeController.text}',
                style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Selected Places:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedPlaces.map((place) => Chip(
                  label: Text(place, style: const TextStyle(fontSize: 12)),
                  backgroundColor: const Color(0xFFF1F5F9),
                  side: BorderSide.none,
                )).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Google Map Placeholder
        Container(
          width: double.infinity,
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: const GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(15.3173, 75.7139), // Coordinates for Karnataka
                zoom: 6,
              ),
              mapType: MapType.normal,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          onPressed: () {
            if (_currentStep > 1) {
              setState(() {
                _currentStep--;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'Create Trip',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stepper
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStepIndicator('Details', '1', _currentStep >= 1),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: _currentStep >= 2 ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                            margin: const EdgeInsets.only(bottom: 24, left: 8, right: 8),
                          ),
                        ),
                        _buildStepIndicator('Preferences', '2', _currentStep >= 2),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: _currentStep >= 3 ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                            margin: const EdgeInsets.only(bottom: 24, left: 8, right: 8),
                          ),
                        ),
                        _buildStepIndicator('Group', '3', _currentStep >= 3),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: _currentStep >= 4 ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                            margin: const EdgeInsets.only(bottom: 24, left: 8, right: 8),
                          ),
                        ),
                        _buildStepIndicator('Show trip', '4', _currentStep >= 4),
                      ],
                    ),
                    const SizedBox(height: 32),

                    if (_currentStep == 1) _buildStep1(),
                    if (_currentStep == 2) _buildStep2(),
                    if (_currentStep == 3) _buildStep3(),
                    if (_currentStep == 4) _buildStep4(),
                  ],
                ),
              ),
            ),
            
            // Next Button
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_currentStep < 4) {
                      if (_currentStep == 1 && _destinationController.text.isNotEmpty) {
                        _fetchPlacesFromGoogle(_destinationController.text);
                      }
                      setState(() {
                        _currentStep++;
                      });
                    } else {
                      // Save Trip
                      final prefs = await SharedPreferences.getInstance();
                      List<String> savedTrips = prefs.getStringList('saved_trips') ?? [];
                      
                      final tripData = {
                        'id': DateTime.now().millisecondsSinceEpoch.toString(),
                        'destination': _destinationController.text,
                        'startDate': _startDateController.text,
                        'endDate': _endDateController.text,
                        'groupSize': _groupSizeController.text,
                        'places': _selectedPlaces,
                      };
                      
                      savedTrips.add(jsonEncode(tripData));
                      await prefs.setStringList('saved_trips', savedTrips);
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Trip Saved Successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        Navigator.pop(context, true);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentStep == 4 ? 'Save Trip' : 'Next',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _currentStep == 4 ? Icons.check : Icons.arrow_forward, 
                        color: Colors.white, 
                        size: 20
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
}
