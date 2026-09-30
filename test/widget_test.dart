import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexti_project/theme/app_theme.dart';
import 'package:nexti_project/screens/create_trip_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Typography Settings Tests (Requirement 1)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Default font is standard Times New Roman and scale is 1.0', () {
      expect(AppTheme.defaultFontFamily, 'Times New Roman');
      expect(AppTheme.defaultFontScale, 1.0);
      expect(AppTheme.fontFamilyNotifier.value, 'Times New Roman');
      expect(AppTheme.fontScaleNotifier.value, 1.0);
    });

    test('setFontFamily updates notifier and persists', () async {
      await AppTheme.setFontFamily('Roboto');
      expect(AppTheme.fontFamilyNotifier.value, 'Roboto');

      await AppTheme.setFontFamily('Times New Roman');
      expect(AppTheme.fontFamilyNotifier.value, 'Times New Roman');
    });

    test('setFontScale updates notifier and persists', () async {
      await AppTheme.setFontScale(1.15);
      expect(AppTheme.fontScaleNotifier.value, 1.15);

      await AppTheme.setFontScale(1.0);
      expect(AppTheme.fontScaleNotifier.value, 1.0);
    });

    test('resetTypography restores Times New Roman and 1.0 scale', () async {
      await AppTheme.setFontFamily('Arial');
      await AppTheme.setFontScale(1.30);
      expect(AppTheme.fontFamilyNotifier.value, 'Arial');
      expect(AppTheme.fontScaleNotifier.value, 1.30);

      await AppTheme.resetTypography();
      expect(AppTheme.fontFamilyNotifier.value, 'Times New Roman');
      expect(AppTheme.fontScaleNotifier.value, 1.0);
    });
  });

  group('Destination Formatter Tests (Requirement 3)', () {
    test('FirstLetterCapitalizationFormatter capitalizes the first letter', () {
      final formatter = FirstLetterCapitalizationFormatter();

      const oldValue = TextEditingValue.empty;
      const newValueLower = TextEditingValue(text: 'mysuru');
      final result1 = formatter.formatEditUpdate(oldValue, newValueLower);
      expect(result1.text, 'Mysuru');

      const newValueAlreadyUpper = TextEditingValue(text: 'Hampi');
      final result2 = formatter.formatEditUpdate(oldValue, newValueAlreadyUpper);
      expect(result2.text, 'Hampi');
    });
  });

  group('Stepper Previous Section Warning Tests', () {
    testWidgets('Tapping on step 2, 3, or 4 without completing step 1 displays warning and field errors', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: CreateTripScreen(isHost: true),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1 Details should be shown
      expect(find.text('Trip Details'), findsOneWidget);

      // Tap on step 2 ('Group')
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();

      // Warning should be displayed
      expect(find.text('Please fill previous sections first.'), findsWidgets);
      // Field errors should be shown
      expect(find.text('Please enter a destination'), findsOneWidget);
      expect(find.text('Please select a start date'), findsOneWidget);
      expect(find.text('Please select an end date'), findsOneWidget);
      expect(find.text('Please enter group size'), findsOneWidget);
      // Should still be on Step 1
      expect(find.text('Trip Details'), findsOneWidget);

      // Tap on step 3 ('Preferences')
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      expect(find.text('Please fill previous sections first.'), findsWidgets);
      expect(find.text('Trip Details'), findsOneWidget);

      // Tap on step 4 ('Show trip')
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();
      expect(find.text('Please fill previous sections first.'), findsWidgets);
      expect(find.text('Trip Details'), findsOneWidget);
    });
  });

  group('User-Scoped Trip Storage & Isolation Tests (Requirement 3)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Trips saved for user A are isolated from user B', () async {
      final prefs = await SharedPreferences.getInstance();

      final tripUserA = {
        'id': '101',
        'tripCode': 'TRIP-AAA',
        'destination': 'Coorg',
        'userEmail': 'usera@example.com',
      };
      final tripUserB = {
        'id': '102',
        'tripCode': 'TRIP-BBB',
        'destination': 'Hampi',
        'userEmail': 'userb@example.com',
      };

      // Save user A's trip under user A's key
      await prefs.setStringList('saved_trips_usera@example.com', [jsonEncode(tripUserA)]);
      // Save user B's trip under user B's key
      await prefs.setStringList('saved_trips_userb@example.com', [jsonEncode(tripUserB)]);

      // Verify User A only sees their own trip
      final loadedUserA = prefs.getStringList('saved_trips_usera@example.com') ?? [];
      expect(loadedUserA.length, 1);
      final decodedA = jsonDecode(loadedUserA.first);
      expect(decodedA['tripCode'], 'TRIP-AAA');
      expect(decodedA['destination'], 'Coorg');

      // Verify User B only sees their own trip
      final loadedUserB = prefs.getStringList('saved_trips_userb@example.com') ?? [];
      expect(loadedUserB.length, 1);
      final decodedB = jsonDecode(loadedUserB.first);
      expect(decodedB['tripCode'], 'TRIP-BBB');
      expect(decodedB['destination'], 'Hampi');

      // Ensure no crossover
      expect(loadedUserA.contains(jsonEncode(tripUserB)), isFalse);
      expect(loadedUserB.contains(jsonEncode(tripUserA)), isFalse);
    });
  });
}

