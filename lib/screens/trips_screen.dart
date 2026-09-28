import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'trip_details_screen.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  List<Map<String, dynamic>> _savedTrips = [];

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedTrips = prefs.getStringList('saved_trips') ?? [];
    setState(() {
      _savedTrips = savedTrips.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
    });
  }

  Future<void> _deleteTrip(int index) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedTripsStr = prefs.getStringList('saved_trips') ?? [];
    if (index >= 0 && index < savedTripsStr.length) {
      savedTripsStr.removeAt(index);
      await prefs.setStringList('saved_trips', savedTripsStr);
      setState(() {
        _savedTrips.removeAt(index);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip deleted successfully')),
        );
      }
    }
  }

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Trip?'),
        content: const Text('Are you sure you want to delete this planned trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteTrip(index);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _openTripDetails(Map<String, dynamic> trip, int index) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TripDetailsScreen(
          trip: trip,
          tripIndex: index,
          onDelete: () => _deleteTrip(index),
        ),
      ),
    );
    if (mounted) {
      _loadTrips();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Trips',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _savedTrips.isEmpty
          ? Center(
              child: Text(
                'No saved trips yet. Start planning!',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? const Color(0xFF94A3B8) : Colors.grey,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _savedTrips.length,
              itemBuilder: (context, index) {
                final trip = _savedTrips[index];
                final places = (trip['places'] as List?)?.join(', ') ?? 'No places';
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    ),
                  ),
                  elevation: 2,
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _openTripDetails(trip, index),
                    splashColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    highlightColor: const Color(0xFF6366F1).withValues(alpha: 0.05),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  trip['destination'] ?? 'Unknown Destination',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E1B4B),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _confirmDelete(index),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${trip['startDate']} - ${trip['endDate']}',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.group,
                                size: 16,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Group Size: ${trip['groupSize']}',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Selected Places:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            places,
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.map_rounded,
                                      size: 16,
                                      color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'View Plan & Google Map',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 13,
                                  color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
