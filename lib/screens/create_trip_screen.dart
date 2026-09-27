import 'package:flutter/material.dart';

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

  Map<String, List<String>> _getSuggestedPlaces(String destination) {
    String dest = destination.toLowerCase().trim();
    if (dest == 'hampi') {
      return {
        'Adventure': ['Matanga Hill Trek', 'Coracle Ride', 'Bouldering at Hemakuta'],
        'Nature': ['Tungabhadra River', 'Sanapur Lake', 'Anjaneya Hill'],
        'Heritage': ['Virupaksha Temple', 'Vitthala Temple', 'Lotus Mahal', 'Elephant Stables'],
        'Shopping': ['Hampi Bazaar', 'Hippie Island Markets']
      };
    } else if (dest == 'mysuru' || dest == 'mysore') {
      return {
        'Adventure': ['Chamundi Hill Steps', 'KRS Dam Cycling'],
        'Nature': ['Brindavan Gardens', 'Karanji Lake', 'Ranganathittu Bird Sanctuary'],
        'Heritage': ['Mysore Palace', 'Chamundeshwari Temple', 'Jaganmohan Palace'],
        'Shopping': ['Devaraja Market', 'Cauvery Emporium', 'Silk Factory']
      };
    } else if (dest == 'gokarna') {
      return {
        'Adventure': ['Beach Trekking', 'Surfing', 'Banana Boat Ride'],
        'Nature': ['Om Beach', 'Half Moon Beach', 'Paradise Beach'],
        'Heritage': ['Mahabaleshwar Temple', 'Mirjan Fort'],
        'Shopping': ['Flea Market', 'Car Street Shops']
      };
    }
    // Default fallback
    return {
      'Adventure': ['Mountain Trek', 'River Rafting', 'Rock Climbing'],
      'Nature': ['Botanical Garden', 'Sunset Point', 'Lake View'],
      'Heritage': ['Historic Fort', 'Ancient Temple', 'Old City Walk'],
      'Shopping': ['Local Market', 'Handicraft Street']
    };
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
    final suggestedPlaces = _getSuggestedPlaces(_destinationController.text);
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
                        _buildStepIndicator('Review', '4', _currentStep >= 4),
                      ],
                    ),
                    const SizedBox(height: 32),

                    if (_currentStep == 1) _buildStep1(),
                    if (_currentStep == 2) _buildStep2(),
                    if (_currentStep == 3) _buildStep3(),
                    if (_currentStep == 4) const Center(child: Text("Review Section - Coming next")),
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
                  onPressed: () {
                    if (_currentStep < 4) {
                      setState(() {
                        _currentStep++;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Next',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, color: Colors.white, size: 20),
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
