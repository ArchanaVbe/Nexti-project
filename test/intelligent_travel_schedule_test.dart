import 'package:flutter_test/flutter_test.dart';
import 'package:nexti_project/services/trip_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TripApi generates realistic travel schedule based on distance and mode', () async {
    // Test trip from Vinoba Nagara, Shivamogga to Murudeshwar
    final plan = await TripApi.planTrip(
      tripId: 'TEST_TRIP_001',
      dates: ['Day 1 - 2026-10-15'],
      selectedIds: ['stop_0', 'stop_1'],
      selectedNames: [
        'Murudeshwar Beach & Watersports',
        'Raja Gopura 20-Storey Tower & Lift',
      ],
      start: 'Vinoba Nagara, Shivamogga, Karnataka',
      startLat: 13.9350,
      startLng: 75.5680,
      hotel: 'RNS Residency Sea View Hotel, Murudeshwar',
      hotelLat: 14.0938,
      hotelLng: 74.4842,
      end: 'RNS Residency Sea View Hotel, Murudeshwar',
      travelMode: 'DRIVE',
    );

    expect(plan.days.isNotEmpty, true);
    final day1 = plan.days.first;
    expect(day1.stops.isNotEmpty, true);

    // Stop 0: Departure from Vinoba Nagara, Shivamogga at 06:00 AM
    final startStop = day1.stops.first;
    expect(startStop.activityType, 'start');
    expect(startStop.time, '06:00 AM');
    // Long drive >= 180 mins from Shivamogga to Murudeshwar (~234 mins)
    expect(startStop.travelToNextMinutes > 150, true);

    // Should include a Highway Tea Break for drives >= 2.5 hours
    final breakStops = day1.stops.where((s) => s.activityType == 'break').toList();
    expect(breakStops.isNotEmpty, true);
    expect(breakStops.first.name.contains('Highway'), true);

    // First destination stop (Murudeshwar Beach) must NOT arrive at 07:00 AM
    // Real travel time from Shivamogga to Murudeshwar is ~3.5 to 4 hours plus break, arriving after 10:00 AM
    final beachStop = day1.stops.firstWhere((s) => s.name.contains('Murudeshwar Beach'));
    expect(beachStop.time != '07:00 AM', true);
    final timeStr = beachStop.time;
    // Should arrive between 10:00 AM and 11:30 AM
    expect(timeStr.contains('10:') || timeStr.contains('11:'), true);

    // Night return to hotel should be around 09:15 PM
    final endStop = day1.stops.last;
    expect(endStop.activityType, 'end');
    expect(endStop.time, '09:15 PM');
  });
}
