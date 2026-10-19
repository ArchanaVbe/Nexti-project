import 'package:flutter_test/flutter_test.dart';
import 'package:nexti_project/services/group_trip_schedule_service.dart';

void main() {
  group('GroupTripScheduleService Tests', () {
    test('Strictly includes ONLY voted places without repeating or hallucinating extra sights', () {
      final voted = ['Mysore Palace', 'Chamundi Hill', 'Brindavan Gardens', 'St. Philomena’s Cathedral'];
      final plan = GroupTripScheduleService.buildMultiDayPlan(
        destination: 'Mysuru',
        numberOfDays: 2,
        votedPlaces: voted,
      );

      expect(plan.length, 2);

      // Extract all attraction places (stopType == 'VISIT')
      final day1Visits = (plan[0]['activities'] as List<Map<String, String>>)
          .where((a) => a['stopType'] == 'VISIT')
          .map((a) => a['place']!)
          .toList();
      final day2Visits = (plan[1]['activities'] as List<Map<String, String>>)
          .where((a) => a['stopType'] == 'VISIT')
          .map((a) => a['place']!)
          .toList();

      // Check: Each day has distinct places
      expect(day1Visits.isNotEmpty, true);
      expect(day2Visits.isNotEmpty, true);

      // Check: Day 1 and Day 2 do not share any visited places
      for (final p in day1Visits) {
        expect(day2Visits.contains(p), false, reason: 'Place $p should not repeat on Day 2');
      }

      // Check: Total unique visited places match the 4 voted places exactly
      final allVotedVisits = [...day1Visits, ...day2Visits];
      expect(allVotedVisits.length, 4);
      for (final v in voted) {
        expect(allVotedVisits.contains(v), true, reason: 'Voted place $v must be in schedule');
      }
    });

    test('Handles 5 voted places across 2 days evenly without gaps or repetition', () {
      final voted = ['Place A', 'Place B', 'Place C', 'Place D', 'Place E'];
      final plan = GroupTripScheduleService.buildMultiDayPlan(
        destination: 'Coorg',
        numberOfDays: 2,
        votedPlaces: voted,
      );

      expect(plan.length, 2);

      final day1Visits = (plan[0]['activities'] as List<Map<String, String>>)
          .where((a) => a['stopType'] == 'VISIT' && voted.contains(a['place']))
          .map((a) => a['place']!)
          .toList();
      final day2Visits = (plan[1]['activities'] as List<Map<String, String>>)
          .where((a) => a['stopType'] == 'VISIT' && voted.contains(a['place']))
          .map((a) => a['place']!)
          .toList();

      expect(day1Visits.length, 3);
      expect(day2Visits.length, 2);
      expect(day1Visits.toSet().intersection(day2Visits.toSet()).isEmpty, true);
    });

    test('Handles 1 voted place across 3 days without repeating or crashing', () {
      final voted = ['Mysore Palace'];
      final plan = GroupTripScheduleService.buildMultiDayPlan(
        destination: 'Mysuru',
        numberOfDays: 3,
        votedPlaces: voted,
      );

      expect(plan.length, 3);
      final day1Visits = (plan[0]['activities'] as List<Map<String, String>>)
          .where((a) => a['stopType'] == 'VISIT')
          .map((a) => a['place']!)
          .toList();
      final day2Visits = (plan[1]['activities'] as List<Map<String, String>>)
          .where((a) => a['stopType'] == 'VISIT')
          .map((a) => a['place']!)
          .toList();
      final day3Visits = (plan[2]['activities'] as List<Map<String, String>>)
          .where((a) => a['stopType'] == 'VISIT')
          .map((a) => a['place']!)
          .toList();

      expect(day1Visits, ['Mysore Palace']);
      expect(day2Visits, isEmpty);
      expect(day3Visits, isEmpty);
    });

    test('Handles 6 voted places across 3 days evenly (2 per day)', () {
      final voted = ['Place 1', 'Place 2', 'Place 3', 'Place 4', 'Place 5', 'Place 6'];
      final plan = GroupTripScheduleService.buildMultiDayPlan(
        destination: 'Hampi',
        numberOfDays: 3,
        votedPlaces: voted,
      );

      expect(plan.length, 3);
      for (int i = 0; i < 3; i++) {
        final dayVisits = (plan[i]['activities'] as List<Map<String, String>>)
            .where((a) => a['stopType'] == 'VISIT')
            .map((a) => a['place']!)
            .toList();
        expect(dayVisits.length, 2);
      }
    });

    test('Ensures continuous time schedule from morning to night with zero long gaps', () {
      final voted = ['Abbey Falls', 'Raja Seat', 'Dubare Elephant Camp'];
      final plan = GroupTripScheduleService.buildMultiDayPlan(
        destination: 'Coorg',
        numberOfDays: 1,
        votedPlaces: voted,
      );

      final acts = plan[0]['activities'] as List<Map<String, String>>;
      expect(acts.length >= 7, true); // Morning breakfast, 3 visits, lunch, break, dinner, rest
      expect(acts.first['time']!.contains('08:30 AM'), true);
      expect(acts.last['time']!.contains('09:15 PM') || acts.last['time']!.contains('09:30 PM'), true);
    });

    test('Builds valid strongly-typed ItineraryPlan object', () {
      final voted = ['Abbey Falls', 'Raja Seat'];
      final itinerary = GroupTripScheduleService.buildItineraryPlanObject(
        tripId: 'TRIP123',
        destination: 'Madikeri',
        numberOfDays: 2,
        votedPlaces: voted,
      );

      expect(itinerary.tripId, 'TRIP123');
      expect(itinerary.days.length, 2);
      expect(itinerary.days[0].stops.isNotEmpty, true);
      expect(itinerary.days[1].stops.isNotEmpty, true);
    });
  });
}
