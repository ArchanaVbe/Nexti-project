import 'package:flutter_test/flutter_test.dart';
import 'package:nexti_project/services/karnataka_places.dart';

void main() {
  test('Autocomplete suggestions prioritize starting letters', () {
    // Test 's'
    final resS = KarnatakaPlacesRegistry.searchSuggestions('s');
    expect(resS.isNotEmpty, isTrue);
    expect(resS.first.description.toLowerCase().startsWith('s'), isTrue);
    final namesS = resS.map((e) => e.description.split(',').first.trim()).toList();
    print('Query "s": $namesS');
    expect(namesS, contains('Shimoga (Shivamogga)'));
    expect(namesS, contains('Sagar'));
    expect(namesS, contains('Sringeri'));

    // Test 'sh'
    final resSh = KarnatakaPlacesRegistry.searchSuggestions('sh');
    final namesSh = resSh.map((e) => e.description.split(',').first.trim()).toList();
    print('Query "sh": $namesSh');
    expect(namesSh.first, 'Shimoga (Shivamogga)');
    expect(namesSh, contains('Shravanabelagola'));
    expect(namesSh, contains('Shivanasamudra Falls'));

    // Test 'b'
    final resB = KarnatakaPlacesRegistry.searchSuggestions('b');
    final namesB = resB.map((e) => e.description.split(',').first.trim()).toList();
    print('Query "b": $namesB');
    expect(namesB, contains('Bengaluru (Bangalore)'));
    expect(namesB, contains('Badami'));
    expect(namesB, contains('Belur'));
    expect(namesB, contains('Bandipur National Park'));

    // Test 'm'
    final resM = KarnatakaPlacesRegistry.searchSuggestions('m');
    final namesM = resM.map((e) => e.description.split(',').first.trim()).toList();
    print('Query "m": $namesM');
    expect(namesM, contains('Mangaluru (Mangalore)'));
    expect(namesM, contains('Mysuru (Mysore)'));
    expect(namesM, contains('Murudeshwar'));
    expect(namesM, contains('Malpe'));

    // Test 'u'
    final resU = KarnatakaPlacesRegistry.searchSuggestions('u');
    final namesU = resU.map((e) => e.description.split(',').first.trim()).toList();
    print('Query "u": $namesU');
    expect(namesU, contains('Udupi'));

    // Test coordinate resolution
    final resShimoga = KarnatakaPlacesRegistry.resolvePlace('city_shimoga');
    expect(resShimoga, isNotNull);
    expect(resShimoga!.lat, closeTo(13.9299, 0.001));
    expect(resShimoga.lng, closeTo(75.5681, 0.001));

    final resCoorg = KarnatakaPlacesRegistry.resolvePlace('city_coorg');
    expect(resCoorg, isNotNull);
    expect(resCoorg!.lat, closeTo(12.4244, 0.001));
    expect(resCoorg.lng, closeTo(75.7382, 0.001));
  });
}
