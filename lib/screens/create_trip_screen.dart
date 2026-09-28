import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'trip_details_screen.dart';
import '../trip_qr_screen.dart';

class CreateTripScreen extends StatefulWidget {
  final bool isHost;
  final String? tripCode;
  final Map<String, dynamic>? initialTripData;

  const CreateTripScreen({
    super.key,
    this.isHost = true,
    this.tripCode,
    this.initialTripData,
  });

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _groupSizeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int _currentStep = 1;
  final List<String> _selectedPlaces = [];
  Map<String, List<String>> _suggestedPlaces = {};
  bool _isLoadingPlaces = false;
  String _lastFetchedDestination = '';
  
  late bool _isHost;
  late String _tripCode;

  @override
  void initState() {
    super.initState();
    _isHost = widget.isHost;
    _tripCode = widget.tripCode ??
        'TRIP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    if (widget.initialTripData != null) {
      _applyTripData(widget.initialTripData!);
    } else if (widget.tripCode != null) {
      _lookupAndApplyTrip(widget.tripCode!);
    }
  }

  void _applyTripData(Map<String, dynamic> data) {
    if (data['destination'] != null && data['destination'].toString().isNotEmpty) {
      _destinationController.text = data['destination'].toString();
      _fetchPlacesFromGoogle(_destinationController.text);
    }
    if (data['startDate'] != null) {
      _startDateController.text = data['startDate'].toString();
    }
    if (data['endDate'] != null) {
      _endDateController.text = data['endDate'].toString();
    }
    if (data['groupSize'] != null) {
      _groupSizeController.text = data['groupSize'].toString();
    }
    if (data['places'] is List) {
      _selectedPlaces.clear();
      _selectedPlaces.addAll((data['places'] as List).map((e) => e.toString()));
    }
    if (data['tripCode'] != null && data['tripCode'].toString().isNotEmpty) {
      _tripCode = data['tripCode'].toString();
    }
  }

  Future<void> _lookupAndApplyTrip(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTrips = prefs.getStringList('saved_trips') ?? [];
      final cleanCode = code.trim().toUpperCase();

      for (final tripStr in savedTrips) {
        try {
          final Map<String, dynamic> trip = jsonDecode(tripStr);
          final tripCode =
              (trip['tripCode'] ?? trip['id'] ?? '').toString().toUpperCase();
          if (tripCode == cleanCode ||
              tripCode.contains(cleanCode) ||
              cleanCode.contains(tripCode)) {
            if (mounted) {
              setState(() {
                _applyTripData(trip);
              });
            }
            return;
          }
        } catch (_) {}
      }
    } catch (_) {}

    // Firestore lookup
    try {
      final doc =
          await FirebaseFirestore.instance.collection('trips').doc(code.trim()).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _applyTripData({
              'destination': data['destination'] ?? data['tripName'] ?? 'Karnataka',
              'startDate': data['startDate'],
              'endDate': data['endDate'],
              'groupSize': data['groupSize'],
              'places': data['places'],
              'tripCode': code.trim(),
            });
          });
        }
        return;
      }
    } catch (_) {}

    // Fallback if not found in local or remote storage
    if (mounted && _destinationController.text.isEmpty) {
      setState(() {
        _destinationController.text = 'Karnataka';
        _startDateController.text = '28/9/2026';
        _endDateController.text = '30/9/2026';
        _groupSizeController.text = '4';
        _fetchPlacesFromGoogle('Karnataka');
      });
    }
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _groupSizeController.dispose();
    _scrollController.dispose();
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

  Widget _buildStepIndicator(String label, String number, bool isActive, bool isDark) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF6366F1)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            shape: BoxShape.circle,
            border: !isActive && isDark
                ? Border.all(color: const Color(0xFF334155))
                : null,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: isActive ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8)),
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
            color: isActive
                ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1))
                : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
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
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          keyboardType: keyboardType,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              fontWeight: FontWeight.normal,
            ),
            prefixIcon: Icon(
              icon,
              color: isDark ? const Color(0xFF818CF8) : const Color(0xFF64748B),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFF6366F1),
                    onPrimary: Colors.white,
                    surface: Color(0xFF1E293B),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
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

  Widget _buildStep1(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_isHost) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Color(0xFF6366F1), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You joined as participant. Destination is managed by host.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6366F1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          'Trip Details',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'Destination',
          hint: 'e.g. Mysuru, Hampi, Gokarna...',
          icon: Icons.location_on_outlined,
          controller: _destinationController,
          readOnly: !_isHost,
          isDark: isDark,
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
          isDark: isDark,
          onTap: () => _selectDate(context, _startDateController),
        ),
        _buildTextField(
          label: 'End Date',
          hint: 'Select end date',
          icon: Icons.calendar_today_outlined,
          controller: _endDateController,
          readOnly: true,
          isDark: isDark,
          onTap: () => _selectDate(context, _endDateController),
        ),
        _buildTextField(
          label: 'Group Size',
          hint: 'Number of people',
          icon: Icons.group_outlined,
          controller: _groupSizeController,
          keyboardType: TextInputType.number,
          isDark: isDark,
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildStep2(bool isDark) {
    final suggestedPlaces = _suggestedPlaces;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preferences in ${_destinationController.text.isNotEmpty ? _destinationController.text : "your destination"}',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select the places you wish to visit',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 24),
        if (_isLoadingPlaces)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  const CircularProgressIndicator(color: Color(0xFF6366F1)),
                  const SizedBox(height: 16),
                  Text(
                    'Discovering real places from Google Maps...',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
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
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      selectedColor: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.35 : 0.1),
                      checkmarkColor: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1))
                            : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B)),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF6366F1)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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

  Widget _buildStep3(bool isDark) {
    final previewTrip = {
      'id': 'preview_trip',
      'destination': _destinationController.text.trim().isNotEmpty
          ? _destinationController.text.trim()
          : 'Karnataka',
      'startDate': _startDateController.text.trim().isNotEmpty
          ? _startDateController.text.trim()
          : '28/9/2026',
      'endDate': _endDateController.text.trim().isNotEmpty
          ? _endDateController.text.trim()
          : '30/9/2026',
      'groupSize': _groupSizeController.text.trim().isNotEmpty
          ? _groupSizeController.text.trim()
          : '1',
      'places': _selectedPlaces,
    };

    return TripDetailsScreen(
      trip: previewTrip,
      isEmbedded: true,
      scrollController: _scrollController,
    );
  }

  Widget _buildStep4(bool isDark) {
    final dest = _destinationController.text.trim().isNotEmpty
        ? _destinationController.text.trim()
        : 'Karnataka';
    final tripName = '$dest Expedition';
    final sampleTripId = _tripCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Group Planning & QR Invite',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Invite friends to your trip using QR codes or by sharing your trip code.',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 24),

        // Trip Info Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
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
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.groups_rounded, color: Color(0xFF6366F1), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tripName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Group Size: ${_groupSizeController.text.trim().isNotEmpty ? _groupSizeController.text.trim() : '1'} People',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Trip Code: $sampleTripId',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: sampleTripId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Trip code copied!'),
                            backgroundColor: Color(0xFF6366F1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF6366F1)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Action 1: Generate QR Code
        _buildGroupActionCard(
          isDark: isDark,
          icon: Icons.qr_code_2_rounded,
          iconColor: const Color(0xFF6366F1),
          title: 'Generate Trip QR Code',
          subtitle: 'Let friends scan your screen to join this group instantly',
          buttonLabel: 'Show QR Code',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TripQrScreen(
                  tripId: sampleTripId,
                  tripName: tripName,
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 36),
      ],
    );
  }

  Widget _buildGroupActionCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
            height: 42,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: iconColor.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                foregroundColor: iconColor,
              ),
              child: Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            size: 20,
          ),
          onPressed: () {
            if (_currentStep > 1) {
              setState(() {
                _currentStep--;
              });
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(0);
              }
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isHost ? 'Create Trip' : 'Trip Planning Room',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (!_isHost)
              Text(
                'Participant Mode • $_tripCode',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: _currentStep == 4 ? EdgeInsets.zero : const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stepper
                    Padding(
                      padding: _currentStep == 4
                          ? const EdgeInsets.fromLTRB(24, 16, 24, 16)
                          : EdgeInsets.zero,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStepIndicator('Details', '1', _currentStep >= 1, isDark),
                          Expanded(
                            child: Container(
                              height: 2,
                              color: _currentStep >= 2
                                  ? const Color(0xFF6366F1)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              margin: const EdgeInsets.only(bottom: 24, left: 8, right: 8),
                            ),
                          ),
                          _buildStepIndicator('Group', '2', _currentStep >= 2, isDark),
                          Expanded(
                            child: Container(
                              height: 2,
                              color: _currentStep >= 3
                                  ? const Color(0xFF6366F1)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              margin: const EdgeInsets.only(bottom: 24, left: 8, right: 8),
                            ),
                          ),
                          _buildStepIndicator('Preferences', '3', _currentStep >= 3, isDark),
                          Expanded(
                            child: Container(
                              height: 2,
                              color: _currentStep >= 4
                                  ? const Color(0xFF6366F1)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              margin: const EdgeInsets.only(bottom: 24, left: 8, right: 8),
                            ),
                          ),
                          _buildStepIndicator('Show trip', '4', _currentStep >= 4, isDark),
                        ],
                      ),
                    ),
                    if (_currentStep != 4) const SizedBox(height: 32),

                    if (_currentStep == 1) _buildStep1(isDark),
                    if (_currentStep == 2) _buildStep4(isDark),
                    if (_currentStep == 3) _buildStep2(isDark),
                    if (_currentStep == 4) _buildStep3(isDark),
                  ],
                ),
              ),
            ),
            
            // Next Button
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
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
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(0);
                      }
                    } else {
                      // Save Trip
                      final prefs = await SharedPreferences.getInstance();
                      List<String> savedTrips = prefs.getStringList('saved_trips') ?? [];
                      
                      final tripData = {
                        'id': DateTime.now().millisecondsSinceEpoch.toString(),
                        'tripCode': _tripCode,
                        'destination': _destinationController.text.trim().isNotEmpty
                            ? _destinationController.text.trim()
                            : 'Karnataka',
                        'startDate': _startDateController.text.trim().isNotEmpty
                            ? _startDateController.text.trim()
                            : '28/9/2026',
                        'endDate': _endDateController.text.trim().isNotEmpty
                            ? _endDateController.text.trim()
                            : '30/9/2026',
                        'groupSize': _groupSizeController.text.trim().isNotEmpty
                            ? _groupSizeController.text.trim()
                            : '1',
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
