import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'trip_details_screen.dart';
import '../trip_qr_screen.dart';

/// Automatically capitalizes the first letter of entered text
class FirstLetterCapitalizationFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final text = newValue.text;
    final firstChar = text[0];
    final upperFirst = firstChar.toUpperCase();
    if (firstChar != upperFirst) {
      final updatedText = upperFirst + text.substring(1);
      return newValue.copyWith(
        text: updatedText,
        selection: newValue.selection,
      );
    }
    return newValue;
  }
}

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

  DateTime? _startDate;
  DateTime? _endDate;

  // Specific error warnings for Step 1 details inputs
  String? _destinationError;
  String? _startDateError;
  String? _endDateError;
  String? _groupSizeError;
  String? _stepWarningMessage;
  int _maxStepReached = 1;

  DateTime? _parseDate(String text) {
    try {
      final parts = text.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return null;
  }

  int _currentStep = 1;
  final List<String> _selectedPlaces = [];
  Map<String, List<String>> _suggestedPlaces = {};
  bool _isLoadingPlaces = false;
  String _lastFetchedDestination = '';
  
  late bool _isHost;
  late String _tripCode;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _tripSubscription;
  Set<String> _groupPlaces = {};
  int _approvedMemberCount = 1;
  final Set<String> _pendingRequestIdsHandled = {};
  bool _isShowingApprovalDialog = false;

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

    if (_isHost) {
      _syncTripToFirestore(isInitial: true);
    }

    _listenToTripUpdates();
  }

  void _applyTripData(Map<String, dynamic> data) {
    if (data['destination'] != null && data['destination'].toString().isNotEmpty) {
      String dest = data['destination'].toString().trim();
      if (dest.length > 100) dest = dest.substring(0, 100);
      if (dest.isNotEmpty) {
        dest = dest[0].toUpperCase() + dest.substring(1);
      }
      _destinationController.text = dest;
      _fetchPlacesFromGoogle(_destinationController.text);
    }
    if (data['startDate'] != null) {
      _startDateController.text = data['startDate'].toString();
      _startDate = _parseDate(_startDateController.text);
    }
    if (data['endDate'] != null) {
      _endDateController.text = data['endDate'].toString();
      _endDate = _parseDate(_endDateController.text);
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

  Future<void> _syncTripToFirestore({bool isInitial = false}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final docRef = FirebaseFirestore.instance.collection('trips').doc(_tripCode);

      final Map<String, dynamic> updateData = {
        'tripCode': _tripCode,
        'destination': _destinationController.text.trim(),
        'startDate': _startDateController.text.trim(),
        'endDate': _endDateController.text.trim(),
        'groupSize': _groupSizeController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (isInitial && _isHost) {
        updateData['hostUid'] = user?.uid ?? 'host';
        updateData['hostName'] = user?.displayName ?? (user?.email?.split('@').first ?? 'Host');
        updateData['hostPhotoUrl'] = user?.photoURL ?? '';
        updateData['createdAt'] = FieldValue.serverTimestamp();
        updateData['approvedMembers'] = [
          {
            'uid': user?.uid ?? 'host',
            'name': user?.displayName ?? (user?.email?.split('@').first ?? 'Host'),
            'photoUrl': user?.photoURL ?? '',
            'role': 'host',
          }
        ];
        updateData['pendingRequests'] = [];
        updateData['memberPreferences'] = {};
        updateData['places'] = _selectedPlaces;
      }

      await docRef.set(updateData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error syncing trip to Firestore: $e');
    }
  }

  Future<void> _syncPreferencesToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? (_isHost ? 'host' : 'participant_${DateTime.now().millisecondsSinceEpoch}');
      final docRef = FirebaseFirestore.instance.collection('trips').doc(_tripCode);

      await docRef.set({
        'memberPreferences': {
          uid: _selectedPlaces,
        },
        'places': FieldValue.arrayUnion(_selectedPlaces),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error syncing preferences to Firestore: $e');
    }
  }

  void _listenToTripUpdates() {
    try {
      _tripSubscription = FirebaseFirestore.instance
        .collection('trips')
        .doc(_tripCode)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return;
      final data = snapshot.data()!;

      // 1. Gather group preferences from all members
      final Set<String> groupPlaces = {};
      final memberPrefs = data['memberPreferences'] as Map<String, dynamic>?;
      if (memberPrefs != null) {
        for (final userPlaces in memberPrefs.values) {
          if (userPlaces is List) {
            groupPlaces.addAll(userPlaces.map((e) => e.toString()));
          }
        }
      }
      if (data['places'] is List) {
        groupPlaces.addAll((data['places'] as List).map((e) => e.toString()));
      }

      final approved = (data['approvedMembers'] as List?) ?? [];

      if (mounted) {
        setState(() {
          _groupPlaces = groupPlaces;
          _approvedMemberCount = approved.isNotEmpty ? approved.length : 1;

          // If participant, ensure destination & groupSize mirror the host's exact values
          if (!_isHost) {
            final hostDest = (data['destination'] ?? data['tripName'])?.toString();
            if (hostDest != null &&
                hostDest.isNotEmpty &&
                _destinationController.text != hostDest) {
              _destinationController.text = hostDest;
              _fetchPlacesFromGoogle(hostDest);
            }
            final hostGroupSize = data['groupSize']?.toString();
            if (hostGroupSize != null &&
                hostGroupSize.isNotEmpty &&
                _groupSizeController.text != hostGroupSize) {
              _groupSizeController.text = hostGroupSize;
            }
          }
        });
      }

      // 2. If Host, handle any pending join requests
      if (_isHost) {
        final pending = (data['pendingRequests'] as List?) ?? [];
        for (final req in pending) {
          if (req is Map) {
            final uid = req['uid']?.toString() ?? '';
            if (uid.isNotEmpty && !_pendingRequestIdsHandled.contains(uid)) {
              _pendingRequestIdsHandled.add(uid);
              _showHostApprovalDialog(req);
              break; // Show one at a time
            }
          }
        }
      }
    }, onError: (e) {
      debugPrint('Error listening to trip updates: $e');
    });
    } catch (e) {
      debugPrint('Error initializing trip listener: $e');
    }
  }

  Future<void> _showHostApprovalDialog(Map req) async {
    if (_isShowingApprovalDialog) return;
    _isShowingApprovalDialog = true;
    final userName = req['name']?.toString() ?? 'A traveler';
    final userUid = req['uid']?.toString() ?? '';
    final userPhoto = req['photoUrl']?.toString();

    if (!mounted) {
      _isShowingApprovalDialog = false;
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_add_rounded, color: Color(0xFF6366F1), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Join Request',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$userName wants to join your trip planning room for ${_destinationController.text.isNotEmpty ? _destinationController.text : "this trip"}.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pin_rounded, size: 16, color: Color(0xFF6366F1)),
                    const SizedBox(width: 6),
                    Text(
                      'Trip Code: $_tripCode',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text('Deny', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text('Allow', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    _isShowingApprovalDialog = false;

    // Update Firestore with the host's decision
    final docRef = FirebaseFirestore.instance.collection('trips').doc(_tripCode);
    try {
      if (result == true) {
        await docRef.update({
          'pendingRequests': FieldValue.arrayRemove([req]),
          'approvedMembers': FieldValue.arrayUnion([
            {
              'uid': userUid,
              'name': userName,
              'photoUrl': userPhoto ?? '',
              'role': 'member',
              'joinedAt': Timestamp.now(),
            }
          ]),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$userName joined the planning room!'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        await docRef.update({
          'pendingRequests': FieldValue.arrayRemove([req]),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Request from $userName was declined.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating join request decision: $e');
    }
  }

  Future<void> _lookupAndApplyTrip(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = FirebaseAuth.instance.currentUser;
      final userEmail = user?.email?.trim().toLowerCase() ??
          prefs.getString('user_profile_email')?.trim().toLowerCase() ?? '';
      final userKey = userEmail.isNotEmpty ? 'saved_trips_$userEmail' : 'saved_trips';
      final savedTrips = prefs.getStringList(userKey) ?? (prefs.getStringList('saved_trips') ?? []);
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
              'destination': data['destination'] ?? data['tripName'] ?? '',
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
  }

  @override
  void dispose() {
    _tripSubscription?.cancel();
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

  bool _validateStep1({bool showWarning = false}) {
    bool hasError = false;
    String? destErr;
    String? startErr;
    String? endErr;
    String? groupErr;

    final destText = _destinationController.text.trim();
    if (destText.isEmpty) {
      destErr = 'Please enter a destination';
      hasError = true;
    } else if (destText.length > 100) {
      destErr = 'Destination must be within 100 characters';
      hasError = true;
    }

    final startText = _startDateController.text.trim();
    if (startText.isEmpty) {
      startErr = 'Please select a start date';
      hasError = true;
    }

    final endText = _endDateController.text.trim();
    if (endText.isEmpty) {
      endErr = 'Please select an end date';
      hasError = true;
    } else if (_startDate != null && _endDate != null && _endDate!.isBefore(_startDate!)) {
      endErr = 'End date must be on or after start date';
      hasError = true;
    }

    if (_isHost) {
      final groupText = _groupSizeController.text.trim();
      if (groupText.isEmpty) {
        groupErr = 'Please enter group size';
        hasError = true;
      } else {
        final size = int.tryParse(groupText);
        if (size == null || size <= 0) {
          groupErr = 'Please enter a valid group size (at least 1)';
          hasError = true;
        }
      }
    }

    setState(() {
      _destinationError = destErr;
      _startDateError = startErr;
      _endDateError = endErr;
      _groupSizeError = groupErr;
      if (hasError && showWarning) {
        _stepWarningMessage = 'Please fill previous sections first.';
      } else if (!hasError) {
        _stepWarningMessage = null;
      }
    });

    if (hasError && showWarning) {
      _showFillPreviousWarning();
    }

    return !hasError;
  }

  void _showFillPreviousWarning([String message = 'Please fill previous sections first.']) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _onStepTapped(int targetStep) async {
    if (targetStep == _currentStep) return;

    if (targetStep < _currentStep) {
      setState(() {
        _stepWarningMessage = null;
        _currentStep = targetStep;
      });
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      return;
    }

    // User is tapping 2, 3, or 4 without completing step 1
    if (!_validateStep1(showWarning: true)) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      return;
    }

    // If jumping ahead of the next unvisited step
    if (targetStep > _currentStep + 1 && targetStep > _maxStepReached) {
      setState(() {
        _stepWarningMessage = 'Please fill previous sections first.';
      });
      _showFillPreviousWarning();
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      return;
    }

    if (_currentStep == 1) {
      _fetchPlacesFromGoogle(_destinationController.text.trim());
      await _syncTripToFirestore();
    } else if ((_isHost && _currentStep == 3) || (!_isHost && _currentStep == 2)) {
      await _syncPreferencesToFirestore();
    }

    setState(() {
      _stepWarningMessage = null;
      _currentStep = targetStep;
      if (_currentStep > _maxStepReached) {
        _maxStepReached = _currentStep;
      }
    });

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Widget _buildStepIndicator(String label, String number, bool isActive, bool isDark, int stepIndex) {
    return GestureDetector(
      onTap: () => _onStepTapped(stepIndex),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
        child: Column(
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
        ),
      ),
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
    String? errorText,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    ValueChanged<String>? onChanged,
  }) {
    final bool hasError = errorText != null && errorText.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: hasError
                    ? const Color(0xFFEF4444)
                    : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
              ),
            ),
            if (maxLength != null)
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final currentLen = value.text.length;
                  return Text(
                    '$currentLen / $maxLength',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: currentLen > maxLength
                          ? const Color(0xFFEF4444)
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              fontWeight: FontWeight.normal,
            ),
            prefixIcon: Icon(
              icon,
              color: hasError
                  ? const Color(0xFFEF4444)
                  : (isDark ? const Color(0xFF818CF8) : const Color(0xFF64748B)),
            ),
            filled: true,
            fillColor: hasError
                ? (isDark ? const Color(0xFF450A0A).withValues(alpha: 0.3) : const Color(0xFFFEF2F2))
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFEF4444)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                width: hasError ? 1.5 : 1.0,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFEF4444)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                width: hasError ? 1.5 : 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(
                color: hasError ? const Color(0xFFEF4444) : const Color(0xFF6366F1),
                width: 2,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFEF4444),
                  size: 15,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    errorText,
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDatePickerTheme(BuildContext context, bool isDark, Widget? child) {
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
                primary: Color(0xFF6366F1),
                onPrimary: Colors.white,
                onSurface: Color(0xFF0F172A),
              ),
      ),
      child: child!,
    );
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final initialDate = (_startDate != null && !_startDate!.isBefore(today))
        ? _startDate!
        : today;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: DateTime(2101),
      builder: (context, child) => _buildDatePickerTheme(context, isDark, child),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        _startDateController.text = "${picked.day}/${picked.month}/${picked.year}";
        _startDateError = null;
        _stepWarningMessage = null;

        // If existing end date is before new start date, clear it and prompt for update
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
          _endDateController.clear();
          _endDateError = 'Please select an end date on or after start date';
        } else {
          _endDateError = null;
        }
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    if (_startDate == null) {
      setState(() {
        _startDateError = 'Please select start date first';
        _endDateError = 'Please select start date first';
      });
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final firstAllowedDate = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);

    final initialDate = (_endDate != null && !_endDate!.isBefore(firstAllowedDate))
        ? _endDate!
        : firstAllowedDate;

    // Requirement 2: app should only allow users to select end date from the date of start and onwards only
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstAllowedDate,
      lastDate: DateTime(2101),
      builder: (context, child) => _buildDatePickerTheme(context, isDark, child),
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
        _endDateController.text = "${picked.day}/${picked.month}/${picked.year}";
        _endDateError = null;
        _stepWarningMessage = null;
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
          errorText: _destinationError,
          maxLength: 100,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [
            LengthLimitingTextInputFormatter(100),
            FirstLetterCapitalizationFormatter(),
          ],
          onChanged: (val) {
            if (_destinationError != null || _stepWarningMessage != null) {
              setState(() {
                _destinationError = null;
                _stepWarningMessage = null;
              });
            }
          },
          onTap: () {
            if (!_isHost) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Destination is chosen by the host and cannot be changed.'),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
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
          errorText: _startDateError,
          onTap: () => _selectStartDate(context),
        ),
        _buildTextField(
          label: 'End Date',
          hint: 'Select end date (on or after start date)',
          icon: Icons.calendar_today_outlined,
          controller: _endDateController,
          readOnly: true,
          isDark: isDark,
          errorText: _endDateError,
          onTap: () => _selectEndDate(context),
        ),
        _buildTextField(
          label: 'Group Size',
          hint: 'Number of people',
          icon: Icons.group_outlined,
          controller: _groupSizeController,
          readOnly: !_isHost,
          keyboardType: TextInputType.number,
          isDark: isDark,
          errorText: _groupSizeError,
          onChanged: (val) {
            if (_groupSizeError != null || _stepWarningMessage != null) {
              setState(() {
                _groupSizeError = null;
                _stepWarningMessage = null;
              });
            }
          },
          onTap: () {
            if (!_isHost) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Group size is managed by the host and cannot be changed.'),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
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
        if (_approvedMemberCount > 1 || !_isHost) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.groups_rounded, color: Color(0xFF6366F1), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Group Planning Room • $_approvedMemberCount active member${_approvedMemberCount > 1 ? 's' : ''}\nAll places selected by you and others are automatically blended into the shared plan.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6366F1),
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
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
          'Select the places you wish to visit (everyone\'s choices will be merged)',
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
                    final isSelectedByMe = _selectedPlaces.contains(place);
                    final isSelectedByGroup = _groupPlaces.contains(place);

                    return FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(place),
                          if (isSelectedByGroup && !isSelectedByMe) ...[
                            const SizedBox(width: 4),
                            const Text('👥', style: TextStyle(fontSize: 11)),
                          ],
                        ],
                      ),
                      selected: isSelectedByMe,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedPlaces.add(place);
                          } else {
                            _selectedPlaces.remove(place);
                          }
                        });
                        _syncPreferencesToFirestore();
                      },
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      selectedColor: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.35 : 0.1),
                      checkmarkColor: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1),
                      labelStyle: TextStyle(
                        color: isSelectedByMe
                            ? (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1))
                            : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B)),
                        fontWeight: isSelectedByMe ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelectedByMe
                              ? const Color(0xFF6366F1)
                              : (isSelectedByGroup
                                  ? const Color(0xFF818CF8).withValues(alpha: 0.7)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
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
    // Combine choices from everyone in the group and local selections into a unified set
    final allCombinedPlaces = <String>{..._groupPlaces, ..._selectedPlaces}.toList();
    if (allCombinedPlaces.isEmpty) {
      allCombinedPlaces.addAll(['Mountain Trek', 'Sunset Point', 'Historic Fort']);
    }

    final previewTrip = {
      'id': _tripCode,
      'tripCode': _tripCode,
      'destination': _destinationController.text.trim().isNotEmpty
          ? _destinationController.text.trim()
          : 'Trip Destination',
      'startDate': _startDateController.text.trim(),
      'endDate': _endDateController.text.trim(),
      'groupSize': _groupSizeController.text.trim().isNotEmpty
          ? _groupSizeController.text.trim()
          : '1',
      'places': allCombinedPlaces,
      'memberCount': _approvedMemberCount,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_approvedMemberCount > 1 || _groupPlaces.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6366F1), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Unified Group Itinerary',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Considering choices of all $_approvedMemberCount group member${_approvedMemberCount > 1 ? 's' : ''} (${allCombinedPlaces.length} places included).',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        TripDetailsScreen(
          trip: previewTrip,
          isEmbedded: true,
          scrollController: _scrollController,
        ),
      ],
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
                    Expanded(
                      child: Text(
                        'Trip Code: $sampleTripId',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                        ),
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

  Widget _buildStepDivider(bool isActive, bool isDark) {
    return Expanded(
      child: Container(
        height: 2,
        color: isActive
            ? const Color(0xFF6366F1)
            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        margin: const EdgeInsets.only(bottom: 24, left: 8, right: 8),
      ),
    );
  }

  Widget _buildStepper(bool isDark) {
    if (_isHost) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStepIndicator('Details', '1', _currentStep >= 1, isDark, 1),
          _buildStepDivider(_currentStep >= 2, isDark),
          _buildStepIndicator('Group', '2', _currentStep >= 2, isDark, 2),
          _buildStepDivider(_currentStep >= 3, isDark),
          _buildStepIndicator('Preferences', '3', _currentStep >= 3, isDark, 3),
          _buildStepDivider(_currentStep >= 4, isDark),
          _buildStepIndicator('Show trip', '4', _currentStep >= 4, isDark, 4),
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStepIndicator('Details', '1', _currentStep >= 1, isDark, 1),
          _buildStepDivider(_currentStep >= 2, isDark),
          _buildStepIndicator('Preferences', '2', _currentStep >= 2, isDark, 2),
          _buildStepDivider(_currentStep >= 3, isDark),
          _buildStepIndicator('Show trip', '3', _currentStep >= 3, isDark, 3),
        ],
      );
    }
  }

  Widget _buildCurrentStep(bool isDark) {
    if (_isHost) {
      switch (_currentStep) {
        case 1:
          return _buildStep1(isDark);
        case 2:
          return _buildStep4(isDark);
        case 3:
          return _buildStep2(isDark);
        case 4:
        default:
          return _buildStep3(isDark);
      }
    } else {
      switch (_currentStep) {
        case 1:
          return _buildStep1(isDark);
        case 2:
          return _buildStep2(isDark);
        case 3:
        default:
          return _buildStep3(isDark);
      }
    }
  }

  Future<void> _saveTrip() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email?.trim().toLowerCase() ??
        prefs.getString('user_profile_email')?.trim().toLowerCase() ?? '';
    final storageKey = userEmail.isNotEmpty ? 'saved_trips_$userEmail' : 'saved_trips';
    List<String> savedTrips = prefs.getStringList(storageKey) ?? [];
    
    final allCombinedPlaces = <String>{..._groupPlaces, ..._selectedPlaces}.toList();
    if (allCombinedPlaces.isEmpty) {
      allCombinedPlaces.addAll(['Mountain Trek', 'Sunset Point', 'Historic Fort']);
    }

    final tripData = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'tripCode': _tripCode,
      'destination': _destinationController.text.trim(),
      'startDate': _startDateController.text.trim(),
      'endDate': _endDateController.text.trim(),
      'groupSize': _groupSizeController.text.trim(),
      'places': allCombinedPlaces,
      'isHost': _isHost,
      'userEmail': userEmail,
      'creatorEmail': userEmail,
    };
    
    savedTrips.removeWhere((item) {
      try {
        final decoded = jsonDecode(item);
        return decoded['tripCode'] == _tripCode;
      } catch (_) {
        return false;
      }
    });

    savedTrips.add(jsonEncode(tripData));
    await prefs.setStringList(storageKey, savedTrips);

    // If saving under a user key, clean up any previous instance from generic list
    if (userEmail.isNotEmpty) {
      final genericTrips = prefs.getStringList('saved_trips');
      if (genericTrips != null) {
        final updatedGeneric = genericTrips.where((item) {
          try {
            final decoded = jsonDecode(item);
            return decoded['tripCode'] != _tripCode;
          } catch (_) {
            return true;
          }
        }).toList();
        await prefs.setStringList('saved_trips', updatedGeneric);
      }
    }
    
    try {
      await FirebaseFirestore.instance.collection('trips').doc(_tripCode).set({
        'places': allCombinedPlaces,
        'status': 'completed',
        'userEmail': userEmail,
        'creatorEmail': userEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isHost ? 'Trip Saved Successfully!' : 'Trip Plan Saved to My Trips!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int maxSteps = _isHost ? 4 : 3;
    final bool isLastStep = _currentStep == maxSteps;

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
                padding: isLastStep ? EdgeInsets.zero : const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stepper
                    Padding(
                      padding: isLastStep
                          ? const EdgeInsets.fromLTRB(24, 16, 24, 16)
                          : EdgeInsets.zero,
                      child: _buildStepper(isDark),
                    ),
                    if (_stepWarningMessage != null) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: isLastStep
                            ? const EdgeInsets.symmetric(horizontal: 24)
                            : EdgeInsets.zero,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _stepWarningMessage!,
                                  style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _stepWarningMessage = null),
                                child: const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (!isLastStep) SizedBox(height: _stepWarningMessage != null ? 16 : 32),

                    _buildCurrentStep(isDark),
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
                    if (_currentStep < maxSteps) {
                      if (_currentStep == 1) {
                        if (!_validateStep1(showWarning: false)) {
                          return;
                        }

                        _fetchPlacesFromGoogle(_destinationController.text.trim());
                        await _syncTripToFirestore();
                      } else if ((_isHost && _currentStep == 3) || (!_isHost && _currentStep == 2)) {
                        await _syncPreferencesToFirestore();
                      }
                      setState(() {
                        _stepWarningMessage = null;
                        _currentStep++;
                        if (_currentStep > _maxStepReached) {
                          _maxStepReached = _currentStep;
                        }
                      });
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(0);
                      }
                    } else {
                      await _saveTrip();
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
                        isLastStep ? 'Save Trip' : 'Next',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isLastStep ? Icons.check : Icons.arrow_forward, 
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
