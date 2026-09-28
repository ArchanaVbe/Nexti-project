import 'package:flutter/material.dart';
import 'trip_details_screen.dart';

class ItineraryScreen extends StatelessWidget {
  final Map<String, dynamic>? trip;

  const ItineraryScreen({super.key, this.trip});

  @override
  Widget build(BuildContext context) {
    if (trip != null) {
      return TripDetailsScreen(trip: trip!);
    }

    // Default sample planned trip for demonstration
    final sampleTrip = {
      'destination': 'Shimoga',
      'startDate': '28/9/2026',
      'endDate': '30/9/2026',
      'groupSize': '4',
      'places': [
        'Mountain Trek',
        'Sunset Point',
        'Botanical Garden',
        'Historic Fort',
        'Local Market',
        'Handicraft Street'
      ],
    };

    return TripDetailsScreen(trip: sampleTrip);
  }
}

