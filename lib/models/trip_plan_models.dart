// trip_plan_models.dart
// Typed data models for Trip AI: Autocomplete, Places Discovery (70 km),
// 5 Categories (Adventure, Food, Nature, Culture, Sightseeing),
// and AI-generated Daily Itineraries with validation warnings.

class CitySuggestion {
  final String description;
  final String placeId;

  CitySuggestion({required this.description, required this.placeId});

  factory CitySuggestion.fromJson(Map<String, dynamic> json) {
    return CitySuggestion(
      description: json['description']?.toString() ?? '',
      placeId: json['place_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'description': description,
        'place_id': placeId,
      };
}

class CityResolution {
  final String name;
  final String placeId;
  final double lat;
  final double lng;
  final String formattedAddress;

  CityResolution({
    required this.name,
    required this.placeId,
    required this.lat,
    required this.lng,
    required this.formattedAddress,
  });

  factory CityResolution.fromJson(Map<String, dynamic> json) {
    return CityResolution(
      name: json['name']?.toString() ?? 'City',
      placeId: json['place_id']?.toString() ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 13.9299,
      lng: (json['lng'] as num?)?.toDouble() ?? 75.5681,
      formattedAddress: json['formatted_address']?.toString() ?? '',
    );
  }
}

class PlaceCard {
  final String placeId;
  final String name;
  final List<String> types;
  final double lat;
  final double lng;
  final double rating;
  final int userRatingsTotal;
  final String address;
  final double distanceKm;
  String? category; // Adventure, Food, Nature, Culture, Sightseeing

  PlaceCard({
    required this.placeId,
    required this.name,
    required this.types,
    required this.lat,
    required this.lng,
    required this.rating,
    required this.userRatingsTotal,
    required this.address,
    required this.distanceKm,
    this.category,
  });

  factory PlaceCard.fromJson(Map<String, dynamic> json) {
    return PlaceCard(
      placeId: json['place_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Place',
      types: (json['types'] as List?)?.map((e) => e.toString()).toList() ?? [],
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      userRatingsTotal: (json['user_ratings_total'] as num?)?.toInt() ?? 0,
      address: json['address']?.toString() ?? '',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      category: json['category']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'place_id': placeId,
        'name': name,
        'types': types,
        'lat': lat,
        'lng': lng,
        'rating': rating,
        'user_ratings_total': userRatingsTotal,
        'address': address,
        'distance_km': distanceKm,
        'category': category,
      };
}

class DiscoverResponse {
  final String tripId;
  final String city;
  final double radiusKm;
  final int totalPlaces;
  final Map<String, List<String>> categories;
  final List<PlaceCard> places;

  DiscoverResponse({
    required this.tripId,
    required this.city,
    required this.radiusKm,
    required this.totalPlaces,
    required this.categories,
    required this.places,
  });

  factory DiscoverResponse.fromJson(Map<String, dynamic> json) {
    final rawCats = json['categories'] as Map<String, dynamic>? ?? {};
    final Map<String, List<String>> cats = {};
    rawCats.forEach((key, val) {
      if (val is List) {
        cats[key] = val.map((e) => e.toString()).toList();
      }
    });

    final rawPlaces = json['places'] as List? ?? [];
    final List<PlaceCard> placeCards =
        rawPlaces.map((e) => PlaceCard.fromJson(Map<String, dynamic>.from(e))).toList();

    // Link assigned categories back to place cards
    for (final entry in cats.entries) {
      final catName = entry.key;
      final ids = entry.value.toSet();
      for (final p in placeCards) {
        if (ids.contains(p.placeId)) {
          p.category = catName;
        }
      }
    }

    return DiscoverResponse(
      tripId: json['trip_id']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      radiusKm: (json['radius_km'] as num?)?.toDouble() ?? 70.0,
      totalPlaces: (json['total_places'] as num?)?.toInt() ?? placeCards.length,
      categories: cats,
      places: placeCards,
    );
  }
}

class DailyScheduleStop {
  final String time;
  final String placeId;
  final String name;
  final String activityType; // 'start', 'visit', 'meal', 'break', 'end'
  final int durationMinutes;
  final int travelToNextMinutes;
  final List<String> openingHours;
  final String notes;

  DailyScheduleStop({
    required this.time,
    required this.placeId,
    required this.name,
    required this.activityType,
    required this.durationMinutes,
    required this.travelToNextMinutes,
    required this.openingHours,
    required this.notes,
  });

  factory DailyScheduleStop.fromJson(Map<String, dynamic> json) {
    return DailyScheduleStop(
      time: json['time']?.toString() ?? '',
      placeId: json['place_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      activityType: json['activity_type']?.toString() ?? 'visit',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 60,
      travelToNextMinutes: (json['travel_to_next_minutes'] as num?)?.toInt() ?? 15,
      openingHours: (json['opening_hours'] as List?)?.map((e) => e.toString()).toList() ?? [],
      notes: json['notes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'time': time,
        'place_id': placeId,
        'name': name,
        'activity_type': activityType,
        'duration_minutes': durationMinutes,
        'travel_to_next_minutes': travelToNextMinutes,
        'opening_hours': openingHours,
        'notes': notes,
      };
}

class DailySchedule {
  final int dayNumber;
  final String date;
  final String summary;
  final List<DailyScheduleStop> stops;
  final int dailyTotalTravelMinutes;
  final double dailyTotalDistanceKm;

  DailySchedule({
    required this.dayNumber,
    required this.date,
    required this.summary,
    required this.stops,
    required this.dailyTotalTravelMinutes,
    required this.dailyTotalDistanceKm,
  });

  factory DailySchedule.fromJson(Map<String, dynamic> json) {
    final rawStops = json['stops'] as List? ?? [];
    return DailySchedule(
      dayNumber: (json['day_number'] as num?)?.toInt() ?? 1,
      date: json['date']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      stops: rawStops.map((e) => DailyScheduleStop.fromJson(Map<String, dynamic>.from(e))).toList(),
      dailyTotalTravelMinutes: (json['daily_total_travel_minutes'] as num?)?.toInt() ?? 0,
      dailyTotalDistanceKm: (json['daily_total_distance_km'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'day_number': dayNumber,
        'date': date,
        'summary': summary,
        'stops': stops.map((s) => s.toJson()).toList(),
        'daily_total_travel_minutes': dailyTotalTravelMinutes,
        'daily_total_distance_km': dailyTotalDistanceKm,
      };
}

class ItineraryPlan {
  final String tripId;
  final String travelMode;
  final String startPoint;
  final String endPoint;
  final List<DailySchedule> days;
  final List<Map<String, dynamic>> unfittedStops;
  final List<String> warnings;
  final bool isValid;
  final Map<String, dynamic> rawJson;

  ItineraryPlan({
    required this.tripId,
    required this.travelMode,
    required this.startPoint,
    required this.endPoint,
    required this.days,
    required this.unfittedStops,
    required this.warnings,
    required this.isValid,
    required this.rawJson,
  });

  factory ItineraryPlan.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'] as List? ?? [];
    final rawUnfitted = json['unfitted_stops'] as List? ?? [];
    final rawWarnings = json['warnings'] as List? ?? [];
    final validation = json['validation'] as Map<String, dynamic>? ?? {};

    return ItineraryPlan(
      tripId: json['trip_id']?.toString() ?? '',
      travelMode: json['travel_mode']?.toString() ?? 'DRIVE',
      startPoint: json['start_point']?.toString() ?? 'Hotel',
      endPoint: json['end_point']?.toString() ?? 'Hotel',
      days: rawDays.map((e) => DailySchedule.fromJson(Map<String, dynamic>.from(e))).toList(),
      unfittedStops: rawUnfitted.map((e) => Map<String, dynamic>.from(e is Map ? e : {'item': e})).toList(),
      warnings: rawWarnings.map((e) => e.toString()).toList(),
      isValid: validation['is_valid'] == true || rawWarnings.isEmpty,
      rawJson: json,
    );
  }

  Map<String, dynamic> toJson() => rawJson;
}
