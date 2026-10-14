// one_day_trip_service.dart
// Service providing curated, highly-efficient 1-day ready itineraries
// across Karnataka cities featuring famous food spots and iconic exploration places.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'karnataka_places.dart';
import '../models/trip_plan_models.dart';

class OneDayStop {
  final String name;
  final String time;
  final String period; // e.g. 'Morning Breakfast', 'Morning Landmark', 'Authentic Lunch', etc.
  final String category; // 'Food', 'Culture', 'Nature', 'Sightseeing', 'Adventure'
  final String highlight; // "Why it's famous & what to eat/see"
  final String address;
  final double lat;
  final double lng;
  final double rating;
  final int durationMinutes;
  final bool isFood;
  final String tag; // e.g., 'Must Try Food', 'UNESCO Heritage', 'Scenic Sunset'

  const OneDayStop({
    required this.name,
    required this.time,
    required this.period,
    required this.category,
    required this.highlight,
    required this.address,
    required this.lat,
    required this.lng,
    required this.rating,
    required this.durationMinutes,
    required this.isFood,
    this.tag = '',
  });
}

class OneDayTripPlan {
  final String city;
  final String district;
  final String title;
  final String tagline;
  final String estimatedDuration;
  final String famousFoodHighlight;
  final List<OneDayStop> stops;
  final Color themeColor;
  final String cityIcon;

  const OneDayTripPlan({
    required this.city,
    required this.district,
    required this.title,
    required this.tagline,
    required this.estimatedDuration,
    required this.famousFoodHighlight,
    required this.stops,
    required this.themeColor,
    required this.cityIcon,
  });

  int get foodStopsCount => stops.where((s) => s.isFood).length;
  int get sightStopsCount => stops.where((s) => !s.isFood).length;

  /// Converts this 1-day plan into a standard NextTripia trip map ready for TripDetailsScreen
  Map<String, dynamic> toTripData() {
    final now = DateTime.now();
    final tripCode = '1DAY-${city.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '')}-${now.millisecondsSinceEpoch % 100000}';
    final dateStr = '${now.day}/${now.month}/${now.year}';

    return {
      'id': tripCode,
      'tripCode': tripCode,
      'destination': '$city, Karnataka',
      'tripName': '1-Day $city: $title',
      'startDate': dateStr,
      'endDate': dateStr,
      'groupSize': '1-4 Travelers',
      'places': stops.map((s) => s.name).toList(),
      'itineraryPlan': {
        'trip_id': tripCode,
        'destination': '$city, Karnataka',
        'days': [
          {
            'day_number': 1,
            'date': dateStr,
            'stops': stops.map((s) => {
              'place_name': s.name,
              'name': s.name,
              'time': s.time,
              'activity_type': s.isFood ? 'MEAL' : 'VISIT',
              'notes': s.highlight,
              'address': s.address,
              'duration_minutes': s.durationMinutes,
              'category': s.category,
              'lat': s.lat,
              'lng': s.lng,
            }).toList(),
          }
        ]
      }
    };
  }
}

class OneDayTripService {
  /// Featured Karnataka tourist hubs for quick 1-tap pill selection
  static const List<Map<String, String>> featuredCities = [
    {'name': 'Mysuru', 'emoji': '👑', 'tag': 'Palaces & Mylari Dosa'},
    {'name': 'Bengaluru', 'emoji': '🏙️', 'tag': 'Heritage & Filter Coffee'},
    {'name': 'Coorg', 'emoji': '☕', 'tag': 'Misty Hills & Akki Roti'},
    {'name': 'Hampi', 'emoji': '🏛️', 'tag': 'UNESCO Ruins & Boulders'},
    {'name': 'Chikmagalur', 'emoji': '🌄', 'tag': 'Peaks & Coffee Estates'},
    {'name': 'Udupi', 'emoji': '🛕', 'tag': 'Krishna Matha & Coast'},
    {'name': 'Gokarna', 'emoji': '🌊', 'tag': 'Om Beach & Seafront Cafes'},
    {'name': 'Mangaluru', 'emoji': '🦀', 'tag': 'Ghee Roast & Sea Walk'},
    {'name': 'Badami', 'emoji': '🏰', 'tag': 'Cave Temples & Jolada Rotti'},
    {'name': 'Dandeli', 'emoji': '🚣', 'tag': 'River Rafting & Hornbills'},
    {'name': 'Davanagere', 'emoji': '🧈', 'tag': 'Original Benne Dosa'},
    {'name': 'Shimoga', 'emoji': '🌿', 'tag': 'Waterfalls & Malnad Food'},
    {'name': 'Belur', 'emoji': '🛕', 'tag': 'Hoysala Architecture'},
    {'name': 'Vijayapura', 'emoji': '🕌', 'tag': 'Gol Gumbaz & Heritage'},
    {'name': 'Sakleshpur', 'emoji': '⛰️', 'tag': 'Star Fort & Mist Trails'},
    {'name': 'Nandi Hills', 'emoji': '🌅', 'tag': 'Sunrise Peak & Parathas'},
  ];

  /// Master pre-curated 1-Day ready trips for major Karnataka destinations
  static final Map<String, OneDayTripPlan> _curatedPlans = {
    'mysuru': OneDayTripPlan(
      city: 'Mysuru',
      district: 'Mysuru District',
      title: 'Royal Heritage & Iconic Food Trail',
      tagline: 'Palace grandeur, melt-in-mouth Mylari dosas, Chamundi Hill & pure ghee Mysore Pak.',
      estimatedDuration: '9.0 Hours (Full Day)',
      famousFoodHighlight: 'Original Mylari Dosa, RRR Banana Leaf Meals & Guru Sweet Mysore Pak',
      themeColor: const Color(0xFF7C3AED),
      cityIcon: '👑',
      stops: [
        const OneDayStop(
          name: 'Hotel Original Vinayaka Mylari',
          time: '08:00 AM',
          period: 'Morning Breakfast',
          category: 'Food',
          highlight: 'Legendary soft butter Mylari sagu dosa with fresh coconut chutney & hot tumbler filter coffee.',
          address: 'Nazarbad Main Road, Mysuru',
          lat: 12.3115,
          lng: 76.6631,
          rating: 4.8,
          durationMinutes: 45,
          isFood: true,
          tag: 'Famous Food Spot 🍜',
        ),
        const OneDayStop(
          name: 'Mysore Grand Palace (Amba Vilas)',
          time: '09:15 AM',
          period: 'Morning Landmark',
          category: 'Culture',
          highlight: 'World-renowned Indo-Saracenic royal palace with golden throne, ornate Durbar Hall & stained glass.',
          address: 'Sayyaji Rao Road, Agrahara, Mysuru',
          lat: 12.3051,
          lng: 76.6551,
          rating: 4.9,
          durationMinutes: 120,
          isFood: false,
          tag: 'Must-Visit Monument 🏛️',
        ),
        const OneDayStop(
          name: 'Hotel RRR Mysore',
          time: '12:30 PM',
          period: 'Authentic Lunch Feast',
          category: 'Food',
          highlight: 'Famous Andhra-Mysore spicy banana leaf meals, Mutton Biryani & Chicken Fry loved by foodies for decades.',
          address: 'Gandhi Square, Near Clock Tower, Mysuru',
          lat: 12.3087,
          lng: 76.6534,
          rating: 4.7,
          durationMinutes: 60,
          isFood: true,
          tag: 'Legendary Eatery 🍽️',
        ),
        const OneDayStop(
          name: "St. Philomena's Neo-Gothic Cathedral",
          time: '02:00 PM',
          period: 'Afternoon Architecture',
          category: 'Culture',
          highlight: 'Spectacular twin 175ft neo-gothic spires, stained glass windows depicting biblical stories & underground relics.',
          address: 'Ashoka Road, St. Philomena, Mysuru',
          lat: 12.3210,
          lng: 76.6580,
          rating: 4.6,
          durationMinutes: 50,
          isFood: false,
          tag: 'Heritage Wonder ⛪',
        ),
        const OneDayStop(
          name: 'Chamundi Hill & Sri Chamundeshwari Temple',
          time: '03:45 PM',
          period: 'Panoramic Viewpoint',
          category: 'Sightseeing',
          highlight: 'Revered hilltop temple offering breathtaking 360-degree vistas over Mysuru city and the 16-foot giant Nandi statue.',
          address: 'Chamundi Hill Road, Mysuru',
          lat: 12.2725,
          lng: 76.6710,
          rating: 4.8,
          durationMinutes: 90,
          isFood: false,
          tag: 'Scenic Viewpoint 🌄',
        ),
        const OneDayStop(
          name: 'Brindavan Gardens Musical Fountain',
          time: '06:00 PM',
          period: 'Sunset & Fountain Show',
          category: 'Sightseeing',
          highlight: 'Terraced Mughal-style garden below KRS Dam featuring illuminated dancing water fountains set to Indian music.',
          address: 'KRS Dam Road, Mandya-Mysuru Border',
          lat: 12.4242,
          lng: 76.5724,
          rating: 4.5,
          durationMinutes: 90,
          isFood: false,
          tag: 'Evening Light Show ⛲',
        ),
        const OneDayStop(
          name: 'Guru Sweet Mart',
          time: '08:00 PM',
          period: 'Famous Evening Sweet Stop',
          category: 'Food',
          highlight: 'The original birthplace of authentic Mysore Pak, invented in the royal palace and still prepared with pure melted desi ghee.',
          address: 'Sayyaji Rao Road, Near Devaraja Market, Mysuru',
          lat: 12.3102,
          lng: 76.6521,
          rating: 4.8,
          durationMinutes: 30,
          isFood: true,
          tag: 'Original Mysore Pak 🍯',
        ),
      ],
    ),

    'bengaluru': OneDayTripPlan(
      city: 'Bengaluru',
      district: 'Bengaluru Urban',
      title: 'Garden City Heritage & Food Trail',
      tagline: 'Crisp benne dosas, Victorian botanical glasshouses, royal palaces & bustling food lanes.',
      estimatedDuration: '8.5 Hours (Full Day)',
      famousFoodHighlight: 'Vidyarthi Bhavan Benne Dosa, MTR Thali & VV Puram Street Food',
      themeColor: const Color(0xFF2563EB),
      cityIcon: '🏙️',
      stops: [
        const OneDayStop(
          name: 'Vidyarthi Bhavan (Gandhi Bazaar)',
          time: '08:00 AM',
          period: 'Morning Breakfast',
          category: 'Food',
          highlight: 'Heritage breakfast spot since 1943 famous for crisp thick Benne Masala Dosa and piping hot chicory filter coffee.',
          address: 'Gandhi Bazaar Main Road, Basavanagudi, Bengaluru',
          lat: 12.9431,
          lng: 77.5702,
          rating: 4.7,
          durationMinutes: 50,
          isFood: true,
          tag: 'Heritage Food Spot 🍜',
        ),
        const OneDayStop(
          name: 'Lalbagh Botanical Gardens & Glass House',
          time: '09:15 AM',
          period: 'Morning Nature Stroll',
          category: 'Nature',
          highlight: '240-acre historic garden commissioned by Hyder Ali, featuring India’s largest tropical plant collection and Victorian glasshouse.',
          address: 'Mavalli, Bengaluru',
          lat: 12.9507,
          lng: 77.5848,
          rating: 4.8,
          durationMinutes: 90,
          isFood: false,
          tag: 'Botanical Haven 🌿',
        ),
        const OneDayStop(
          name: 'Bangalore Palace & Tudor Grounds',
          time: '11:30 AM',
          period: 'Royal Heritage',
          category: 'Culture',
          highlight: 'Magnificent wooden palace built inspired by Windsor Castle, adorned with Tudor towers, stained glass and royal collectibles.',
          address: 'Vasanth Nagar, Bengaluru',
          lat: 12.9988,
          lng: 77.5921,
          rating: 4.6,
          durationMinutes: 90,
          isFood: false,
          tag: 'Royal Castle 🏰',
        ),
        const OneDayStop(
          name: 'Mavalli Tiffin Room (MTR) / Nagarjuna',
          time: '01:30 PM',
          period: 'Authentic Lunch Feast',
          category: 'Food',
          highlight: 'Legendary pure ghee Karnataka royal silver thali, Bisibelebath, Rava Idli & Payasa served with unmatched hospitality.',
          address: 'Lalbagh Road / Residency Road, Bengaluru',
          lat: 12.9555,
          lng: 77.5860,
          rating: 4.8,
          durationMinutes: 60,
          isFood: true,
          tag: 'Royal Thali 🍽️',
        ),
        const OneDayStop(
          name: 'Cubbon Park & Vidhana Soudha',
          time: '03:00 PM',
          period: 'Afternoon Architecture & Walk',
          category: 'Sightseeing',
          highlight: '300-acre green lungs of Bangalore alongside the grand Neo-Dravidian architecture of Vidhana Soudha.',
          address: 'Kasturba Road, Bengaluru',
          lat: 12.9763,
          lng: 77.5929,
          rating: 4.7,
          durationMinutes: 75,
          isFood: false,
          tag: 'Iconic Landmark 🏛️',
        ),
        const OneDayStop(
          name: 'Sankey Tank Sunset Promenade',
          time: '05:30 PM',
          period: 'Sunset Stroll',
          category: 'Nature',
          highlight: 'Tranquil man-made lake surrounded by blooming trees, cool evening breeze and relaxing pedestrian promenade.',
          address: 'Sadashivnagar, Bengaluru',
          lat: 13.0076,
          lng: 77.5746,
          rating: 4.6,
          durationMinutes: 60,
          isFood: false,
          tag: 'Lakeside Sunset 🌅',
        ),
        const OneDayStop(
          name: 'VV Puram Food Street (Thindi Beedi)',
          time: '07:15 PM',
          period: 'Iconic Night Food Walk',
          category: 'Food',
          highlight: 'Bangalore’s most famous vegetarian street food lane: Gulkand with Ice Cream, Floating Holige, Paddus, and Congress Bun.',
          address: 'Old Market Road, Sajjan Rao Circle, Bengaluru',
          lat: 12.9514,
          lng: 77.5758,
          rating: 4.8,
          durationMinutes: 75,
          isFood: true,
          tag: 'Street Food Capital 🍧',
        ),
      ],
    ),

    'coorg': OneDayTripPlan(
      city: 'Coorg (Madikeri)',
      district: 'Kodagu District',
      title: 'Misty Highlands & Authentic Kodava Trail',
      tagline: 'Fragrant coffee valleys, gushing waterfalls, Tibetan monasteries & spicy Kodava delicacies.',
      estimatedDuration: '8.5 Hours (Full Day)',
      famousFoodHighlight: 'Authentic Akki Roti, Pandi Curry & Estate Filter Coffee',
      themeColor: const Color(0xFF059669),
      cityIcon: '☕',
      stops: [
        const OneDayStop(
          name: 'Taste of Coorg / East End Hotel',
          time: '08:15 AM',
          period: 'Morning Breakfast',
          category: 'Food',
          highlight: 'Hot soft Akki Rotti with bamboo shoot curry (Kani Curry) & freshly brewed estate Robusta filter coffee.',
          address: 'Stuart Hill Road, Madikeri, Coorg',
          lat: 12.4240,
          lng: 75.7390,
          rating: 4.7,
          durationMinutes: 45,
          isFood: true,
          tag: 'Kodava Breakfast ☕',
        ),
        const OneDayStop(
          name: 'Abbey Falls Cascades',
          time: '09:30 AM',
          period: 'Morning Waterfall Wonder',
          category: 'Nature',
          highlight: 'Spectacular 70ft waterfall roaring amidst private coffee, pepper and spice plantations with hanging footbridge.',
          address: 'Abbi Falls Road, Madikeri, Coorg',
          lat: 12.4542,
          lng: 75.7180,
          rating: 4.7,
          durationMinutes: 75,
          isFood: false,
          tag: 'Cascading Waterfalls 🌊',
        ),
        const OneDayStop(
          name: 'Madikeri Fort & Palace Museum',
          time: '11:15 AM',
          period: 'Historic Fortress',
          category: 'Culture',
          highlight: '17th-century stone fortress with life-sized stone elephants, British clock tower and historical Kodagu artifacts.',
          address: 'Madikeri Town Center, Coorg',
          lat: 12.4244,
          lng: 75.7382,
          rating: 4.4,
          durationMinutes: 60,
          isFood: false,
          tag: 'Historic Fort 🏰',
        ),
        const OneDayStop(
          name: 'Coorg Cuisine Restaurant',
          time: '12:45 PM',
          period: 'Authentic Kodava Lunch Feast',
          category: 'Food',
          highlight: 'Signature authentic Pandi (Pork) Curry, Kadambuttu steamed rice balls, Noolputtu and spicy Koli Curry.',
          address: 'Main Road, Opposite Post Office, Madikeri',
          lat: 12.4230,
          lng: 75.7405,
          rating: 4.8,
          durationMinutes: 60,
          isFood: true,
          tag: 'Signature Kodava Feast 🍛',
        ),
        const OneDayStop(
          name: 'Namdroling Golden Temple Monastery',
          time: '02:45 PM',
          period: 'Buddhist Culture & Art',
          category: 'Culture',
          highlight: 'Mesmerizing 40-foot gilded gold Buddha statues, Tibetan mural paintings, prayer wheels and peaceful chanting.',
          address: 'Bylakuppe, near Kushalnagar, Coorg',
          lat: 12.4287,
          lng: 75.9669,
          rating: 4.9,
          durationMinutes: 90,
          isFood: false,
          tag: 'Golden Temple 🛕',
        ),
        const OneDayStop(
          name: "Raja's Seat Sunset Viewpoint",
          time: '05:30 PM',
          period: 'Sunset Valley Vista',
          category: 'Sightseeing',
          highlight: 'Historic scenic garden where the Kings of Kodagu watched spectacular sunsets over endless misty blue mountains.',
          address: 'Stuart Hill, Madikeri, Coorg',
          lat: 12.4172,
          lng: 75.7360,
          rating: 4.7,
          durationMinutes: 60,
          isFood: false,
          tag: 'Valley Sunset 🌅',
        ),
        const OneDayStop(
          name: 'Aromas of Coorg & Artisan Chocolate Studio',
          time: '07:00 PM',
          period: 'Spices & Dessert',
          category: 'Food',
          highlight: 'Take home organic hill spices, pure Kodagu honey, homemade fruit wines and handcrafted single-origin chocolates.',
          address: 'College Road, Madikeri, Coorg',
          lat: 12.4215,
          lng: 75.7380,
          rating: 4.6,
          durationMinutes: 40,
          isFood: true,
          tag: 'Chocolates & Spices 🍫',
        ),
      ],
    ),

    'hampi': OneDayTripPlan(
      city: 'Hampi',
      district: 'Vijayanagara District',
      title: 'Empire Odyssey & Bouldering Cafes',
      tagline: 'UNESCO World Heritage temples, giant boulder canyons, riverside cafes & musical pillars.',
      estimatedDuration: '9.0 Hours (Full Day)',
      famousFoodHighlight: 'Riverside Shakshuka & Banana Lassi, North Karnataka Jolada Rotti Oota',
      themeColor: const Color(0xFFD97706),
      cityIcon: '🏛️',
      stops: [
        const OneDayStop(
          name: 'Mango Tree Cafe / The Goan Corner',
          time: '07:30 AM',
          period: 'Riverside Breakfast',
          category: 'Food',
          highlight: 'Famous bohemian open-air cafe overlooking banana plantations: thick banana lassi, shakshuka, pancakes & mint tea.',
          address: 'Near Tungabhadra River Bank, Hampi',
          lat: 15.3340,
          lng: 76.4625,
          rating: 4.7,
          durationMinutes: 50,
          isFood: true,
          tag: 'Famous Riverside Cafe ☕',
        ),
        const OneDayStop(
          name: 'Virupaksha Temple & Sacred Bazaar',
          time: '08:45 AM',
          period: 'Ancient Sacred Temple',
          category: 'Culture',
          highlight: '7th-century functioning temple with 160ft tiered gopuram, Lakshmi the temple elephant and ancient carved bazaar ruins.',
          address: 'Hampi Bazaar Street, Hampi',
          lat: 15.3352,
          lng: 76.4601,
          rating: 4.8,
          durationMinutes: 90,
          isFood: false,
          tag: 'UNESCO Heritage 🛕',
        ),
        const OneDayStop(
          name: 'Vijaya Vittala Temple & Stone Chariot',
          time: '10:45 AM',
          period: 'Architectural Marvel',
          category: 'Culture',
          highlight: 'The crown jewel of Vijayanagara architecture featuring 56 acoustic musical pillars and the iconic stone chariot.',
          address: 'Vittala Complex, Hampi',
          lat: 15.3392,
          lng: 76.4795,
          rating: 4.9,
          durationMinutes: 100,
          isFood: false,
          tag: 'The Stone Chariot 🛞',
        ),
        const OneDayStop(
          name: 'Hampi Heritage Oota / Gopi Rooftop',
          time: '01:00 PM',
          period: 'Authentic North Karnataka Lunch',
          category: 'Food',
          highlight: 'Traditional Jolada Rotti meal with Yennegai stuffed brinjal curry, Shenga chutney, spiced buttermilk and jaggery.',
          address: 'Hampi Main Bazaar, Vijayanagara',
          lat: 15.3345,
          lng: 76.4610,
          rating: 4.6,
          durationMinutes: 60,
          isFood: true,
          tag: 'Jolada Rotti Feast 🍲',
        ),
        const OneDayStop(
          name: 'Lotus Mahal & Royal Elephant Stables',
          time: '02:30 PM',
          period: 'Royal Enclosure',
          category: 'Culture',
          highlight: 'Exquisite Indo-Islamic zenana pavilion with arching lotus petals, paired with the 11 colossal domed elephant chambers.',
          address: 'Zenana Enclosure, Kamalapura, Hampi',
          lat: 15.3204,
          lng: 76.4695,
          rating: 4.7,
          durationMinutes: 75,
          isFood: false,
          tag: 'Royal Palaces 🐘',
        ),
        const OneDayStop(
          name: 'Matanga Hill or Hemakuta Hill Sunset',
          time: '05:15 PM',
          period: 'Epic Boulder Sunset',
          category: 'Sightseeing',
          highlight: 'Breathtaking 360-degree panorama across the surreal boulder-strewn landscape as the sun sinks into Tungabhadra.',
          address: 'Hemakuta Hill Steps, Hampi',
          lat: 15.3330,
          lng: 76.4590,
          rating: 4.9,
          durationMinutes: 80,
          isFood: false,
          tag: 'Magical 360° Sunset 🌅',
        ),
        const OneDayStop(
          name: 'Riverside Coracle Pier & Evening Chai',
          time: '07:00 PM',
          period: 'Evening River Vibe',
          category: 'Sightseeing',
          highlight: 'Unwind along the sacred riverbanks with hot ginger cardamom tea, watching ancient coracle boats on the water.',
          address: 'Tungabhadra Ghat, Hampi',
          lat: 15.3360,
          lng: 76.4630,
          rating: 4.6,
          durationMinutes: 40,
          isFood: true,
          tag: 'Riverfront Chai ☕',
        ),
      ],
    ),

    'chikmagalur': OneDayTripPlan(
      city: 'Chikmagalur',
      district: 'Chikkamagaluru District',
      title: 'Coffee Capital & High Mountain Peaks',
      tagline: 'Misty highest peaks of Karnataka, century-old coffee plantations & spicy Malnad delicacies.',
      estimatedDuration: '8.5 Hours (Full Day)',
      famousFoodHighlight: 'Town Canteen Benne Dosa, Malnad Akki Roti & Fresh Peaberry Coffee',
      themeColor: const Color(0xFF0D9488),
      cityIcon: '🌄',
      stops: [
        const OneDayStop(
          name: 'Town Canteen (Shri Vishnu Bhavan)',
          time: '08:00 AM',
          period: 'Morning Breakfast',
          category: 'Food',
          highlight: 'Iconic spot since 1965 renowned for crispy butter masala dosa served with signature fiery red chutney & pure filter coffee.',
          address: 'Rathnagiri Road, Chikmagalur',
          lat: 13.3190,
          lng: 75.7730,
          rating: 4.7,
          durationMinutes: 45,
          isFood: true,
          tag: 'Famous Heritage Dosa 🥞',
        ),
        const OneDayStop(
          name: 'Mullayanagiri Peak',
          time: '09:15 AM',
          period: 'Highest Peak in Karnataka',
          category: 'Adventure',
          highlight: 'Karnataka’s highest summit (1,930m) with sweeping views of the Western Ghats, clouds rolling beneath you and hilltop temple.',
          address: 'Mullayanagiri Trek Point, Baba Budan Range',
          lat: 13.3917,
          lng: 75.7214,
          rating: 4.9,
          durationMinutes: 120,
          isFood: false,
          tag: 'Highest Peak ⛰️',
        ),
        const OneDayStop(
          name: 'Baba Budangiri & Manikyadhara Falls',
          time: '12:00 PM',
          period: 'Sacred Mountain Shrine',
          category: 'Sightseeing',
          highlight: 'Sacred cave shrine where Sufi saint Baba Budan first planted seven coffee beans brought from Yemen in 1670.',
          address: 'Baba Budan Giri Road, Chikmagalur',
          lat: 13.4228,
          lng: 75.7628,
          rating: 4.6,
          durationMinutes: 75,
          isFood: false,
          tag: 'Birthplace of Coffee ☕',
        ),
        const OneDayStop(
          name: 'Siri Coffee Cafe & Malnad Food Court',
          time: '01:45 PM',
          period: 'Authentic Malnad Feast',
          category: 'Food',
          highlight: 'Special Malnad lunch: Akki Roti, Kaalu Huli, tender Jackfruit curry and spicy Ghee Roast beside the giant greenery sculpture.',
          address: 'KM Road, Near Allampura, Chikmagalur',
          lat: 13.3050,
          lng: 75.7920,
          rating: 4.6,
          durationMinutes: 60,
          isFood: true,
          tag: 'Malnad Culinary Feast 🍛',
        ),
        const OneDayStop(
          name: 'Hirekolale Lake',
          time: '03:30 PM',
          period: 'Lakeside Serenity',
          category: 'Nature',
          highlight: 'Peaceful mountain lake surrounded by dense coffee slopes and hills, perfect for calm strolls and photography.',
          address: 'Hirekolale Road, Chikmagalur',
          lat: 13.3760,
          lng: 75.7480,
          rating: 4.6,
          durationMinutes: 60,
          isFood: false,
          tag: 'Scenic Lake 🌊',
        ),
        const OneDayStop(
          name: 'Coffee Yatra Museum & Tasting Lab',
          time: '05:00 PM',
          period: 'Coffee Heritage Tour',
          category: 'Culture',
          highlight: 'Thematic museum illustrating coffee cultivation, roasting technology and sensory tasting of single-origin beans.',
          address: 'Dasarahalli, Chikmagalur',
          lat: 13.3100,
          lng: 75.7800,
          rating: 4.5,
          durationMinutes: 60,
          isFood: false,
          tag: 'Coffee Heritage ☕',
        ),
        const OneDayStop(
          name: 'Panduranga Coffee & Spice Bazaar',
          time: '06:45 PM',
          period: 'Evening Treat & Roastery',
          category: 'Food',
          highlight: 'Take home authentic fresh-roasted Peaberry coffee powder, green cardamom, wild honey and homemade cashew snacks.',
          address: 'MG Road, Chikmagalur',
          lat: 13.3160,
          lng: 75.7725,
          rating: 4.8,
          durationMinutes: 40,
          isFood: true,
          tag: 'Fresh Roast Coffee 🛍️',
        ),
      ],
    ),

    'udupi': OneDayTripPlan(
      city: 'Udupi',
      district: 'Udupi District',
      title: 'Temple Bells, Basalt Coast & World Cuisine',
      tagline: 'World-famous Udupi cuisine, 13th-century Krishna Matha, volcanic basalt islands & coastal sunsets.',
      estimatedDuration: '8.5 Hours (Full Day)',
      famousFoodHighlight: 'Mitra Samaj Mangalore Buns, Satvik Thali & Diana Gadbad Ice Cream',
      themeColor: const Color(0xFF4F46E5),
      cityIcon: '🛕',
      stops: [
        const OneDayStop(
          name: 'Mitra Samaj (Car Street)',
          time: '08:00 AM',
          period: 'Morning Breakfast',
          category: 'Food',
          highlight: '70-year-old culinary institution famous for fluffy Mangalore Buns, crisp Goli Baje, Tuppa Dosa & authentic filter coffee.',
          address: 'Car Street, Opposite Krishna Temple, Udupi',
          lat: 13.3412,
          lng: 74.7430,
          rating: 4.8,
          durationMinutes: 45,
          isFood: true,
          tag: 'Original Mangalore Buns 🍌',
        ),
        const OneDayStop(
          name: 'Sri Krishna Matha & Kanakana Kindi',
          time: '09:00 AM',
          period: 'Sacred Temple Complex',
          category: 'Culture',
          highlight: 'Revered 13th-century Vaishnavite monastery founded by Saint Madhvacharya with the sacred 9-holed golden window.',
          address: 'Car Street, Thenkpete, Udupi',
          lat: 13.3409,
          lng: 74.7421,
          rating: 4.9,
          durationMinutes: 90,
          isFood: false,
          tag: 'Ancient Temple Matha 🛕',
        ),
        const OneDayStop(
          name: "St. Mary's Island Geologic Columns",
          time: '11:00 AM',
          period: 'Volcanic Island Adventure',
          category: 'Nature',
          highlight: 'National Geological Monument featuring distinctive hexagonal columns of volcanic basalt rock jutting out into Arabian Sea.',
          address: 'Ferry from Malpe Beach, Udupi',
          lat: 13.3800,
          lng: 74.6730,
          rating: 4.8,
          durationMinutes: 120,
          isFood: false,
          tag: 'Volcanic Island 🏝️',
        ),
        const OneDayStop(
          name: 'Woodlands Restaurant / Kediyoor',
          time: '01:30 PM',
          period: 'Grand Satvik Plantain Feast',
          category: 'Food',
          highlight: 'Authentic pure vegetarian Udupi Satvik thali with piping hot rasam, coconut pineapple menaskai and rich kheer/payasam.',
          address: 'Near Head Post Office, Udupi',
          lat: 13.3425,
          lng: 74.7470,
          rating: 4.7,
          durationMinutes: 60,
          isFood: true,
          tag: 'Grand Satvik Oota 🍛',
        ),
        const OneDayStop(
          name: 'End Point Manipal & Swarna River Valley',
          time: '03:45 PM',
          period: 'Scenic Cliff Overlook',
          category: 'Sightseeing',
          highlight: 'Spectacular clifftop park perched high above the Swarna River with panoramic views of the coastal plains and Western Ghats.',
          address: 'End Point Road, Manipal, Udupi',
          lat: 13.3600,
          lng: 74.7900,
          rating: 4.7,
          durationMinutes: 60,
          isFood: false,
          tag: 'Valley Overlook 🌿',
        ),
        const OneDayStop(
          name: 'Malpe Beach & Sea Walk Sunset',
          time: '05:30 PM',
          period: 'Arabian Sea Sunset',
          category: 'Nature',
          highlight: 'Walk along the stone sea walk stretching 450m directly into the open ocean as the golden sun sets into the Arabian Sea.',
          address: 'Malpe Port Road, Udupi',
          lat: 13.3551,
          lng: 74.7042,
          rating: 4.8,
          durationMinutes: 75,
          isFood: false,
          tag: 'Sea Walk Sunset 🌅',
        ),
        const OneDayStop(
          name: 'Diana Restaurant (Home of Gadbad)',
          time: '07:30 PM',
          period: 'Famous Dessert Stop',
          category: 'Food',
          highlight: 'The original inventor of world-renowned ‘Gadbad Ice Cream’ layered with mixed jelly, raisins, nuts, and three ice cream scoops.',
          address: 'Court Road, Udupi',
          lat: 13.3420,
          lng: 74.7450,
          rating: 4.8,
          durationMinutes: 40,
          isFood: true,
          tag: 'Original Gadbad Ice Cream 🍨',
        ),
      ],
    ),

    'gokarna': OneDayTripPlan(
      city: 'Gokarna',
      district: 'Uttara Kannada',
      title: 'Sacred Temples & Crescent Beach Shacks',
      tagline: 'Ancient Atmalinga temple, sacred holy tanks, Om-shaped beaches & cliffside sea cafes.',
      estimatedDuration: '8.0 Hours (Full Day)',
      famousFoodHighlight: 'Pai Hotel Neer Dosa & Namaste Cafe Clifftop Seafood',
      themeColor: const Color(0xFF0284C7),
      cityIcon: '🌊',
      stops: [
        const OneDayStop(
          name: 'Prema Restaurant / Pai Hotel',
          time: '08:00 AM',
          period: 'Morning Breakfast',
          category: 'Food',
          highlight: 'Famous local eatery serving melt-in-mouth Neer Dosa with sweet coconut jaggery syrup, Pineapple Sheera & herbal ginger tea.',
          address: 'Main Beach Road, Gokarna',
          lat: 14.5440,
          lng: 74.3160,
          rating: 4.6,
          durationMinutes: 45,
          isFood: true,
          tag: 'Neer Dosa & Sheera 🥞',
        ),
        const OneDayStop(
          name: 'Mahabaleshwar Temple & Kotitirtha',
          time: '09:00 AM',
          period: 'Ancient Atmalinga Temple',
          category: 'Culture',
          highlight: '4th-century classical Dravidian granite temple housing the sacred Pranalinga of Lord Shiva and the massive Kotitirtha temple pond.',
          address: 'Car Street, Gokarna',
          lat: 14.5479,
          lng: 74.3188,
          rating: 4.8,
          durationMinutes: 75,
          isFood: false,
          tag: 'Sacred Atmalinga 🛕',
        ),
        const OneDayStop(
          name: 'Kudle Beach Scenic Foot Trail',
          time: '10:45 AM',
          period: 'Coastal Cliff Trek',
          category: 'Nature',
          highlight: 'Picturesque golden crescent beach bordered by rocky sea cliffs and gently swaying coconut groves.',
          address: 'Kudle Beach Road, Gokarna',
          lat: 14.5380,
          lng: 74.3190,
          rating: 4.7,
          durationMinutes: 75,
          isFood: false,
          tag: 'Golden Sands 🏖️',
        ),
        const OneDayStop(
          name: 'Namaste Cafe at Om Beach',
          time: '12:30 PM',
          period: 'Clifftop Beach Lunch',
          category: 'Food',
          highlight: 'World-famous cliffside beach cafe overlooking the waves: fresh catch Kingfish curry, wood-fired pizzas, nutella crepes & tender coconut.',
          address: 'Om Beach Cliff, Gokarna',
          lat: 14.5200,
          lng: 74.3160,
          rating: 4.7,
          durationMinutes: 75,
          isFood: true,
          tag: 'Legendary Beach Cafe 🍕',
        ),
        const OneDayStop(
          name: 'Om Beach & Half Moon Bay Boat Ride',
          time: '02:30 PM',
          period: 'Coastal Boat Cruise',
          category: 'Adventure',
          highlight: 'Natural shoreline shaped in the sacred Hindu symbol of ‘ॐ’, offering fishing boat cruises to dolphin spots and secluded coves.',
          address: 'Om Beach Coast, Gokarna',
          lat: 14.5205,
          lng: 74.3175,
          rating: 4.8,
          durationMinutes: 90,
          isFood: false,
          tag: 'Om Coastline 🚤',
        ),
        const OneDayStop(
          name: 'Kudle Clifftop Sunset Point',
          time: '05:30 PM',
          period: 'Spectacular Ocean Sunset',
          category: 'Sightseeing',
          highlight: 'Uninterrupted cliffside views watching the crimson sun melt into the Arabian Sea with cool ocean breeze.',
          address: 'Kudle Hilltop, Gokarna',
          lat: 14.5360,
          lng: 74.3210,
          rating: 4.9,
          durationMinutes: 60,
          isFood: false,
          tag: 'Crimson Sunset 🌅',
        ),
        const OneDayStop(
          name: 'Gokarna Town Bazaar & Sea Spice Stalls',
          time: '07:00 PM',
          period: 'Evening Souvenirs & Treats',
          category: 'Food',
          highlight: 'Bustling town lane with brass lamps, local cashews, sea salt candies and hot cinnamon chai.',
          address: 'Temple Street, Gokarna',
          lat: 14.5450,
          lng: 74.3170,
          rating: 4.5,
          durationMinutes: 45,
          isFood: true,
          tag: 'Spices & Souvenirs 🛍️',
        ),
      ],
    ),

    'mangaluru': OneDayTripPlan(
      city: 'Mangaluru',
      district: 'Dakshina Kannada',
      title: 'Coastal Heritage & World Ghee Roast',
      tagline: 'Tulu Nadu spirit, world-famous fish ghee roasts, 19th-century chapel frescoes & sea walk sunsets.',
      estimatedDuration: '8.5 Hours (Full Day)',
      famousFoodHighlight: 'Giri Manja’s Ghee Roast, Janatha Deluxe Buns & Pabbas Ice Cream',
      themeColor: const Color(0xFFE11D48),
      cityIcon: '🦀',
      stops: [
        const OneDayStop(
          name: 'Hotel Janatha Deluxe / New Taj Mahal',
          time: '08:00 AM',
          period: 'Morning Breakfast',
          category: 'Food',
          highlight: 'Famous coastal breakfast: soft Tuwo Dosa, Mangalore Buns, savory Biscuit Rotti and rich chicory filter coffee.',
          address: 'KS Rao Road, Hampankatta, Mangaluru',
          lat: 12.8690,
          lng: 74.8420,
          rating: 4.7,
          durationMinutes: 45,
          isFood: true,
          tag: 'Tulu Nadu Breakfast 🥞',
        ),
        const OneDayStop(
          name: 'Kudroli Gokarnanatheshwara Temple',
          time: '09:15 AM',
          period: 'Grand Dravidian Temple',
          category: 'Culture',
          highlight: 'Magnificent temple built by social reformer Narayana Guru with golden gopuram, mirror palace and illuminated marble fountains.',
          address: 'Kudroli, Mangaluru',
          lat: 12.8770,
          lng: 74.8320,
          rating: 4.8,
          durationMinutes: 75,
          isFood: false,
          tag: 'Golden Temple 🛕',
        ),
        const OneDayStop(
          name: 'St. Aloysius Chapel Frescoes',
          time: '11:00 AM',
          period: 'Historic Art & Frescoes',
          category: 'Culture',
          highlight: 'Historic 1880 chapel whose ceilings and walls are painted by Italian master Antony Moscheni, rivaling the Sistine Chapel.',
          address: 'Lighthouse Hill, Hampankatta, Mangaluru',
          lat: 12.8720,
          lng: 74.8450,
          rating: 4.8,
          durationMinutes: 60,
          isFood: false,
          tag: 'Sistine Chapel of India ⛪',
        ),
        const OneDayStop(
          name: "Giri Manja's Authentic Seafood",
          time: '12:30 PM',
          period: 'Iconic Seafood Feast',
          category: 'Food',
          highlight: 'World-famous culinary destination for Anjal (Kingfish) Ghee Roast, Kane fish curry, Squid Sukka and coastal brown rice meals.',
          address: 'Bhavanthi Street, Car Street, Mangaluru',
          lat: 12.8710,
          lng: 74.8380,
          rating: 4.9,
          durationMinutes: 75,
          isFood: true,
          tag: 'Kingfish Ghee Roast 🐟',
        ),
        const OneDayStop(
          name: 'Pilikula Heritage Village & Guthu House',
          time: '02:45 PM',
          period: 'Traditional Living Heritage',
          category: 'Culture',
          highlight: 'Authentic reproduction of an ancestral coastal Guthu manor, artisan weaving stalls, bell-metal works and botanical arboretum.',
          address: 'Vamanjoor, Mangaluru',
          lat: 12.9260,
          lng: 74.9010,
          rating: 4.6,
          durationMinutes: 90,
          isFood: false,
          tag: 'Ancestral Guthu House 🏡',
        ),
        const OneDayStop(
          name: 'Tannirbhavi Beach & Sea Walk Sunset',
          time: '05:30 PM',
          period: 'Pine Forest & Sea Walk',
          category: 'Nature',
          highlight: 'Pristine beach lined with tall casuarina pine trees, featuring an elevated sea walk pier directly into the breaking waves.',
          address: 'Tannirbhavi, Mangaluru',
          lat: 12.8900,
          lng: 74.8100,
          rating: 4.7,
          durationMinutes: 75,
          isFood: false,
          tag: 'Pine Beach Sunset 🌅',
        ),
        const OneDayStop(
          name: 'Pabbas Ice Cream Parlour (Ideal)',
          time: '07:30 PM',
          period: 'World-Famous Ice Cream Destination',
          category: 'Food',
          highlight: 'Global icon for decadent frozen sundaes: the original Gadbad, ‘Parfait’, ‘Tiramisu’, and chocolate ‘Dilkush’.',
          address: 'Lalbagh Main Road, Mangaluru',
          lat: 12.8830,
          lng: 74.8420,
          rating: 4.9,
          durationMinutes: 45,
          isFood: true,
          tag: 'Iconic Pabbas Ice Cream 🍨',
        ),
      ],
    ),

    'badami': OneDayTripPlan(
      city: 'Badami',
      district: 'Bagalkot District',
      title: 'Rock-Cut Chalukyan Caves & Jolada Rotti',
      tagline: '6th-century red sandstone cave temples, water-edge shrines & authentic North Karnataka jolada rotti feasts.',
      estimatedDuration: '8.5 Hours (Full Day)',
      famousFoodHighlight: 'Traditional North Karnataka Jolada Rotti Oota with Yennegai & Shenga Chutney',
      themeColor: const Color(0xFFEA580C),
      cityIcon: '🏰',
      stops: [
        const OneDayStop(
          name: 'Geeta Darshini / Banashankari Canteen',
          time: '08:00 AM',
          period: 'Morning Breakfast',
          category: 'Food',
          highlight: 'Piping hot Poori Saagu, Avalakki (spiced beaten rice) and hot ginger tea.',
          address: 'Station Road, Badami',
          lat: 15.9180,
          lng: 75.6760,
          rating: 4.5,
          durationMinutes: 45,
          isFood: true,
          tag: 'Local Breakfast 🥞',
        ),
        const OneDayStop(
          name: 'Badami Rock-cut Cave Temples',
          time: '09:00 AM',
          period: 'Monolithic Rock Caves',
          category: 'Culture',
          highlight: 'Four 6th-century caves carved out of sheer red sandstone cliffs, featuring Nataraja with 81 dancing poses and Vishnu resting on Sesha.',
          address: 'Cave Temple Road, Badami',
          lat: 15.9187,
          lng: 75.6766,
          rating: 4.9,
          durationMinutes: 120,
          isFood: false,
          tag: 'UNESCO Tentative Heritage 🏛️',
        ),
        const OneDayStop(
          name: 'Bhutanatha Temple & Agastya Lake',
          time: '11:30 AM',
          period: 'Lakeside Shrines',
          category: 'Culture',
          highlight: 'Tranquil 7th-century sandstone shrines extending into the holy waters of Agastya lake beneath towering red cliffs.',
          address: 'Agastya Lake East Bank, Badami',
          lat: 15.9200,
          lng: 75.6860,
          rating: 4.8,
          durationMinutes: 60,
          isFood: false,
          tag: 'Lakeside Stone Shrine 🌊',
        ),
        const OneDayStop(
          name: 'Hotel Mayura Chalukya',
          time: '01:00 PM',
          period: 'North Karnataka Jolada Rotti Oota',
          category: 'Food',
          highlight: 'Authentic jowar rotis served with Yennegai (stuffed brinjal), Jhunka, Shenga (peanut) chutney powder, butter and fresh curd.',
          address: 'Ramdurg Road, Badami',
          lat: 15.9150,
          lng: 75.6720,
          rating: 4.6,
          durationMinutes: 60,
          isFood: true,
          tag: 'Jolada Rotti Oota 🌾',
        ),
        const OneDayStop(
          name: 'Pattadakal UNESCO World Heritage Complex',
          time: '02:45 PM',
          period: 'Crown Jewel of Chalukyan Architecture',
          category: 'Culture',
          highlight: 'Spectacular 7th & 8th-century temple complex representing the harmonious culmination of northern Rekha-Nagara and southern Dravidian styles.',
          address: 'Pattadakal Village, Bagalkot',
          lat: 15.9486,
          lng: 75.8160,
          rating: 4.9,
          durationMinutes: 90,
          isFood: false,
          tag: 'UNESCO World Heritage 🛕',
        ),
        const OneDayStop(
          name: 'Badami Red Sandstone Sunset Viewpoint',
          time: '05:30 PM',
          period: 'Fiery Canyon Sunset',
          category: 'Sightseeing',
          highlight: 'Watch the late afternoon sun illuminate the deep red sandstone gorge and ancient rock fort in blazing amber colors.',
          address: 'North Fort Hill Trail, Badami',
          lat: 15.9220,
          lng: 75.6820,
          rating: 4.8,
          durationMinutes: 60,
          isFood: false,
          tag: 'Red Cliff Sunset 🌅',
        ),
        const OneDayStop(
          name: 'Local Bellada Chai & Khaja Bazaar',
          time: '07:00 PM',
          period: 'Evening Sweet & Jaggery Tea',
          category: 'Food',
          highlight: 'Enjoy organic Bellada (jaggery) tea paired with sweet crispy regional Khaja snacks.',
          address: 'Badami Town Market',
          lat: 15.9170,
          lng: 75.6740,
          rating: 4.5,
          durationMinutes: 40,
          isFood: true,
          tag: 'Jaggery Tea & Khaja ☕',
        ),
      ],
    ),

    'davanagere': OneDayTripPlan(
      city: 'Davanagere',
      district: 'Davanagere District',
      title: 'Butter Dosa Capital & Hoysala River Shrines',
      tagline: 'World-famous Benne Dosa, spicy Mandakki Girmit & 13th-century Tungabhadra temples.',
      estimatedDuration: '8.0 Hours (Full Day)',
      famousFoodHighlight: 'Original Sri Guru Kottureshwara Benne Dosa & Spicy Mandakki Girmit',
      themeColor: const Color(0xFFF59E0B),
      cityIcon: '🧈',
      stops: [
        const OneDayStop(
          name: 'Sri Guru Kottureshwara Benne Dosa Hotel',
          time: '08:00 AM',
          period: 'World-Famous Breakfast',
          category: 'Food',
          highlight: 'The legendary epicenter of crisp golden Davanagere Benne (Butter) Dosa served with potato mash and spicy coconut chutney.',
          address: 'Dental College Road, MCC B Block, Davanagere',
          lat: 14.4690,
          lng: 75.9250,
          rating: 4.9,
          durationMinutes: 50,
          isFood: true,
          tag: 'Original Benne Dosa 🧈',
        ),
        const OneDayStop(
          name: 'Bathi Gudda & Hilltop Viewpoint',
          time: '09:30 AM',
          period: 'Panoramic Valley View',
          category: 'Sightseeing',
          highlight: 'Panoramic views over the textile and culinary capital, surrounding cotton plantations and the Tungabhadra river plains.',
          address: 'Bathi Village, Davanagere',
          lat: 14.4920,
          lng: 75.8900,
          rating: 4.5,
          durationMinutes: 75,
          isFood: false,
          tag: 'Scenic Hilltop 🌄',
        ),
        const OneDayStop(
          name: 'Harihareshwara Temple (Harihar)',
          time: '11:30 AM',
          period: 'Hoysala Architectural Marvel',
          category: 'Culture',
          highlight: 'Exquisite 1223 AD Hoysala stone temple on the banks of Tungabhadra river uniting Vishnu (Hari) and Shiva (Hara) in one idol.',
          address: 'Temple Street, Harihara, Davanagere',
          lat: 14.5128,
          lng: 75.8058,
          rating: 4.8,
          durationMinutes: 75,
          isFood: false,
          tag: '13th-Century Hoysala 🛕',
        ),
        const OneDayStop(
          name: 'Apoorva Heritage / Shanti Comforts',
          time: '01:15 PM',
          period: 'Regional Lunch & Mandakki Girmit',
          category: 'Food',
          highlight: 'Authentic Davanagere lunch with spicy Girmit (puffed rice with roasted gram paste), piping hot Mirchi Bajjis and curd rice.',
          address: 'Near Old Bus Stand, Davanagere',
          lat: 14.4650,
          lng: 75.9220,
          rating: 4.6,
          durationMinutes: 60,
          isFood: true,
          tag: 'Spicy Girmit & Mirchi 🌶️',
        ),
        const OneDayStop(
          name: 'Kondaji Chibbalagere Forest & Lake',
          time: '03:15 PM',
          period: 'Nature & Migratory Birds',
          category: 'Nature',
          highlight: 'Peaceful lake flanked by scrub forests and rolling hills, famous for pedal boating and sighting exotic migratory waterfowl.',
          address: 'Kondaji, Davanagere',
          lat: 14.5300,
          lng: 75.9800,
          rating: 4.6,
          durationMinutes: 75,
          isFood: false,
          tag: 'Boating Lake 🚣',
        ),
        const OneDayStop(
          name: 'Davanagere Glass House & Gardens',
          time: '05:30 PM',
          period: 'Botanical Glass Pavilion',
          category: 'Sightseeing',
          highlight: 'Spectacular modern glass dome pavilion surrounded by lush green lawns and musical evening fountains.',
          address: 'Kundwada Lake Road, Davanagere',
          lat: 14.4500,
          lng: 75.9100,
          rating: 4.6,
          durationMinutes: 60,
          isFood: false,
          tag: 'Glass Pavilion 🏛️',
        ),
        const OneDayStop(
          name: 'Ravi Benne Dosa Hotel',
          time: '07:15 PM',
          period: 'Evening Open Benne Dosa',
          category: 'Food',
          highlight: 'Signature Open Benne Dosa topped with spicy masala and melted butter, paired with filter coffee.',
          address: 'Church Road, Davanagere',
          lat: 14.4630,
          lng: 75.9200,
          rating: 4.8,
          durationMinutes: 45,
          isFood: true,
          tag: 'Open Benne Dosa 🥞',
        ),
      ],
    ),

    'shimoga': OneDayTripPlan(
      city: 'Shimoga',
      district: 'Shivamogga District',
      title: 'Gateway to Malnad & Kuvempu Heritage',
      tagline: 'Lush Western Ghats forests, tiger safari, Tunga river dams & rich Malnad culinary traditions.',
      estimatedDuration: '8.5 Hours (Full Day)',
      famousFoodHighlight: 'Meenakshi Bhavan Goli Baje, Malnad Akki Roti & Jackfruit Delicacies',
      themeColor: const Color(0xFF16A34A),
      cityIcon: '🌿',
      stops: [
        const OneDayStop(
          name: 'Hotel Meenakshi Bhavan',
          time: '08:00 AM',
          period: 'Morning Breakfast',
          category: 'Food',
          highlight: 'Iconic 50-year-old Malnad eatery: crisp Masala Dosa, hot fluffy Goli Baje, Chow Chow Bath & filter coffee.',
          address: 'Nehru Road, Durgigudi, Shimoga',
          lat: 13.9310,
          lng: 75.5670,
          rating: 4.8,
          durationMinutes: 45,
          isFood: true,
          tag: 'Malnad Goli Baje ☕',
        ),
        const OneDayStop(
          name: 'Tyavarekoppa Tiger & Lion Safari',
          time: '09:15 AM',
          period: 'Wildlife Safari',
          category: 'Nature',
          highlight: '200-hectare wildlife reserve with guided safari vans giving up-close encounters with majestic Bengal tigers and Asiatic lions.',
          address: 'Sagar Road, Tyavarekoppa, Shimoga',
          lat: 13.9850,
          lng: 75.5340,
          rating: 4.6,
          durationMinutes: 90,
          isFood: false,
          tag: 'Tiger Safari 🐅',
        ),
        const OneDayStop(
          name: 'Sacred Heart Cathedral',
          time: '11:30 AM',
          period: 'European Roman-Gothic Architecture',
          category: 'Culture',
          highlight: 'Second-largest church structure in India with striking Roman-Gothic architecture, marble altars and grand arches.',
          address: 'Balaraj Urs Road, Shimoga',
          lat: 13.9330,
          lng: 75.5720,
          rating: 4.6,
          durationMinutes: 50,
          isFood: false,
          tag: 'Gothic Cathedral ⛪',
        ),
        const OneDayStop(
          name: 'Malnad Kitchen (Hotel Harsha)',
          time: '01:00 PM',
          period: 'Traditional Malnad Feast',
          category: 'Food',
          highlight: 'Authentic Malnad Thali: Akki Rotti with Kaalu Saaru, Jackfruit papad, raw mango menaskai, and cooling Tambli.',
          address: 'Park Extension, Shimoga',
          lat: 13.9340,
          lng: 75.5650,
          rating: 4.7,
          durationMinutes: 60,
          isFood: true,
          tag: 'Authentic Malnad Oota 🍛',
        ),
        const OneDayStop(
          name: 'Gajanur Tunga Dam & Sakrebyle Elephant Camp',
          time: '02:45 PM',
          period: 'River Reservoir & Wildlife',
          category: 'Nature',
          highlight: 'Scenic reservoir on the Tunga River and nearby eco-camp where majestic elephants bathe in the river waters.',
          address: 'Gajanur, Shimoga',
          lat: 13.8600,
          lng: 75.5350,
          rating: 4.7,
          durationMinutes: 90,
          isFood: false,
          tag: 'Tunga Dam & Elephants 🐘',
        ),
        const OneDayStop(
          name: 'Mattur Living Sanskrit Village',
          time: '04:45 PM',
          period: 'Unique Cultural Living Heritage',
          category: 'Culture',
          highlight: 'World-renowned village where the ancient language of Sanskrit is spoken as the daily vernacular by all residents.',
          address: 'Mattur Village, Shimoga',
          lat: 13.9050,
          lng: 75.6020,
          rating: 4.7,
          durationMinutes: 60,
          isFood: false,
          tag: 'Living Sanskrit Heritage 📜',
        ),
        const OneDayStop(
          name: 'Mathura Hotel & Sweets',
          time: '06:30 PM',
          period: 'Evening Sweet Fritters & Chai',
          category: 'Food',
          highlight: 'Warm Halasinahannu (Jackfruit) sweet fritters, Khara Bath and freshly roasted Malnad cashews with filter coffee.',
          address: 'Gandhi Park Road, Shimoga',
          lat: 13.9300,
          lng: 75.5680,
          rating: 4.6,
          durationMinutes: 40,
          isFood: true,
          tag: 'Jackfruit Fritters 🍯',
        ),
      ],
    ),
  };

  /// Master map of pre-curated plans across major Karnataka hubs
  static Map<String, OneDayTripPlan> get curatedPlans => _curatedPlans;

  /// Returns all curated stops across all pre-curated plans
  static List<OneDayStop> getAllCuratedStops() {
    final List<OneDayStop> all = [];
    for (final plan in _curatedPlans.values) {
      all.addAll(plan.stops);
    }
    return all;
  }

  /// Retrieves a 1-day ready trip plan for any Karnataka city (curated or dynamically synthesized)
  static OneDayTripPlan getPlanForCity(String cityName) {
    final regionKey = KarnatakaPlacesRegistry.normalizeRegionKey(cityName);
    if (regionKey.isNotEmpty && _curatedPlans.containsKey(regionKey)) {
      return _curatedPlans[regionKey]!;
    }

    // Check direct lowercase match
    final clean = cityName.toLowerCase().trim();
    for (final entry in _curatedPlans.entries) {
      if (entry.key == clean || clean.contains(entry.key) || entry.value.city.toLowerCase().contains(clean)) {
        return entry.value;
      }
    }

    // Synthesize an authentic high-efficiency 1-day trip using KarnatakaPlacesRegistry
    return _synthesizePlanForCity(cityName);
  }

  /// Synthesizes an efficient, rich 1-day ready trip for ANY other Karnataka town
  static OneDayTripPlan _synthesizePlanForCity(String rawCityName) {
    final cleanCity = rawCityName.split(',').first.trim();
    final resolved = KarnatakaPlacesRegistry.resolvePlace(cleanCity);
    final lat = resolved?.lat ?? 13.0000;
    final lng = resolved?.lng ?? 76.0000;

    // Fetch places from KarnatakaPlacesRegistry
    final discover = KarnatakaPlacesRegistry.getDiscoverResponseForCity(
      tripId: 'dynamic_1day',
      destination: cleanCity,
      centerLat: lat,
      centerLng: lng,
    );

    final List<PlaceCard> allPlaces = discover.places;
    final List<PlaceCard> foodPlaces = allPlaces.where((p) => p.category == 'Food').toList();
    final List<PlaceCard> sightPlaces = allPlaces.where((p) => p.category != 'Food').toList();

    final List<OneDayStop> stops = [];

    // Stop 1: Morning Breakfast (Food)
    stops.add(OneDayStop(
      name: foodPlaces.isNotEmpty ? foodPlaces.first.name : '$cleanCity Traditional Heritage Tiffin',
      time: '08:00 AM',
      period: 'Morning Breakfast',
      category: 'Food',
      highlight: 'Authentic local breakfast: hot fluffy Idlis, crispy Vada, Masala Dosa and freshly brewed Karnataka filter coffee.',
      address: foodPlaces.isNotEmpty ? foodPlaces.first.address : 'Main Temple Road, $cleanCity',
      lat: foodPlaces.isNotEmpty ? foodPlaces.first.lat : lat + 0.005,
      lng: foodPlaces.isNotEmpty ? foodPlaces.first.lng : lng + 0.005,
      rating: 4.7,
      durationMinutes: 45,
      isFood: true,
      tag: 'Famous Breakfast 🥞',
    ));

    // Stop 2: Morning Landmark (Culture/Heritage)
    final sight1 = sightPlaces.isNotEmpty ? sightPlaces[0] : null;
    stops.add(OneDayStop(
      name: sight1?.name ?? '$cleanCity Historic Fort & Citadel',
      time: '09:15 AM',
      period: 'Morning Landmark',
      category: sight1?.category ?? 'Culture',
      highlight: 'Iconic heritage monument showcasing the timeless architecture, royal legends and rich history of $cleanCity.',
      address: sight1?.address ?? 'Fort Ridge, $cleanCity',
      lat: sight1?.lat ?? lat + 0.015,
      lng: sight1?.lng ?? lng - 0.010,
      rating: 4.8,
      durationMinutes: 90,
      isFood: false,
      tag: 'Iconic Monument 🏛️',
    ));

    // Stop 3: Authentic Local Lunch Feast (Food)
    final food2 = foodPlaces.length > 1 ? foodPlaces[1] : null;
    stops.add(OneDayStop(
      name: food2?.name ?? '$cleanCity Traditional Banana Leaf Oota',
      time: '12:30 PM',
      period: 'Authentic Lunch Feast',
      category: 'Food',
      highlight: 'Authentic regional lunch featuring aromatic local curries, crisp papads, spiced rasam, payasa and buttermilk.',
      address: food2?.address ?? 'Station Circle, $cleanCity',
      lat: food2?.lat ?? lat - 0.008,
      lng: food2?.lng ?? lng + 0.004,
      rating: 4.7,
      durationMinutes: 60,
      isFood: true,
      tag: 'Regional Feast 🍛',
    ));

    // Stop 4: Afternoon Exploration (Culture/Nature)
    final sight2 = sightPlaces.length > 1 ? sightPlaces[1] : null;
    stops.add(OneDayStop(
      name: sight2?.name ?? '$cleanCity Botanical Gardens & Temple',
      time: '02:30 PM',
      period: 'Afternoon Discovery',
      category: sight2?.category ?? 'Culture',
      highlight: 'Serene temple architecture and scenic garden landscapes providing a quiet, peaceful cultural journey.',
      address: sight2?.address ?? 'Heritage Quarter, $cleanCity',
      lat: sight2?.lat ?? lat - 0.020,
      lng: sight2?.lng ?? lng + 0.015,
      rating: 4.6,
      durationMinutes: 75,
      isFood: false,
      tag: 'Cultural Heritage 🛕',
    ));

    // Stop 5: Sunset Viewpoint (Sightseeing/Nature)
    final sight3 = sightPlaces.length > 2 ? sightPlaces[2] : null;
    stops.add(OneDayStop(
      name: sight3?.name ?? '$cleanCity Sunset Valley Lookout',
      time: '05:30 PM',
      period: 'Sunset Viewpoint',
      category: 'Sightseeing',
      highlight: 'Panoramic elevated viewpoint offering golden sunset vistas over the skyline and Western Ghats hills.',
      address: sight3?.address ?? 'Hilltop Road, near $cleanCity',
      lat: sight3?.lat ?? lat + 0.030,
      lng: sight3?.lng ?? lng - 0.025,
      rating: 4.8,
      durationMinutes: 60,
      isFood: false,
      tag: 'Golden Sunset 🌅',
    ));

    // Stop 6: Evening Street Food & Traditional Sweets (Food)
    final food3 = foodPlaces.length > 2 ? foodPlaces[2] : null;
    stops.add(OneDayStop(
      name: food3?.name ?? '$cleanCity Clock Tower Sweet Mart & Tea',
      time: '07:00 PM',
      period: 'Evening Treats & Tea',
      category: 'Food',
      highlight: 'Unwind with regional sweets, crispy evening bajjis and piping hot cardamom-spiced tea.',
      address: food3?.address ?? 'Central Market Street, $cleanCity',
      lat: food3?.lat ?? lat + 0.002,
      lng: food3?.lng ?? lng + 0.001,
      rating: 4.6,
      durationMinutes: 40,
      isFood: true,
      tag: 'Evening Treats ☕',
    ));

    return OneDayTripPlan(
      city: cleanCity,
      district: 'Karnataka',
      title: 'Highlights, Food & Sunset Trail',
      tagline: 'An efficient 1-day itinerary with iconic local dishes, heritage landmarks and scenic sunset.',
      estimatedDuration: '8.0 Hours (Full Day)',
      famousFoodHighlight: 'Traditional Tiffin, Regional Banana Leaf Meal & Evening Tea',
      themeColor: const Color(0xFF6366F1),
      cityIcon: '📍',
      stops: stops,
    );
  }

  /// Generates a structured, highly-efficient multi-day itinerary with ZERO time clashes
  /// and ZERO empty/dead time gaps for the exact number of days chosen by the user in regular group trips.
  static List<Map<String, dynamic>> buildMultiDayPlanForTrip({
    required String destination,
    required int numberOfDays,
    required List<String> selectedPlaces,
    List<String>? dateStrings,
    String? hotel,
    String? startPoint,
  }) {
    final int totalDays = math.max(1, numberOfDays);

    // Clean destination to find the city
    String cleanCity = destination.split(',').first.trim();
    cleanCity = cleanCity.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
    if (cleanCity.isEmpty) cleanCity = 'Mysuru';

    // Retrieve curated plan for this city
    final basePlan = getPlanForCity(cleanCity);

    // Filter valid user-selected places
    final List<String> userPlaces = [];
    for (final p in selectedPlaces) {
      final trimmed = p.trim();
      if (trimmed.isNotEmpty &&
          !trimmed.toLowerCase().startsWith('day ') &&
          !trimmed.toLowerCase().startsWith('stop_') &&
          !userPlaces.contains(trimmed)) {
        userPlaces.add(trimmed);
      }
    }

    // Separate base stops into food and sights
    final List<OneDayStop> baseFoodStops = basePlan.stops.where((s) => s.isFood).toList();
    final List<OneDayStop> baseSightStops = basePlan.stops.where((s) => !s.isFood).toList();

    // Pool of sights: User places first, then base sights, then registry sights
    final List<String> poolSights = [];
    poolSights.addAll(userPlaces);
    for (final s in baseSightStops) {
      if (!poolSights.contains(s.name)) {
        poolSights.add(s.name);
      }
    }
    final lowerClean = cleanCity.toLowerCase();
    final regPlaces = KarnatakaPlacesRegistry.destinations.where((d) =>
        d.name.toLowerCase().contains(lowerClean) ||
        d.keywords.any((k) => k.toLowerCase().contains(lowerClean)));
    for (final rp in regPlaces) {
      final name = rp.name.split(',').first.trim();
      if (!poolSights.contains(name)) {
        poolSights.add(name);
      }
    }
    if (poolSights.length < totalDays * 4) {
      poolSights.addAll([
        '$cleanCity Historic Fort & Ramparts',
        '$cleanCity Botanical Lake & Eco Park',
        '$cleanCity Royal Heritage Museum',
        '$cleanCity Hilltop Panorama & Sunset Lookout',
        '$cleanCity Sacred Temple & Ancient Gopura',
        '$cleanCity Nature Bird Sanctuary & Riverfront',
        '$cleanCity Handicraft & Silk Emporium',
        '$cleanCity Valley Viewpoint & Tea Plantation',
      ]);
    }

    // Distribute sights across the days (4 key sights per day)
    final List<List<String>> sightsByDay = List.generate(totalDays, (_) => []);
    int sightCursor = 0;
    for (int d = 0; d < totalDays; d++) {
      for (int slot = 0; slot < 4; slot++) {
        if (sightCursor < poolSights.length) {
          sightsByDay[d].add(poolSights[sightCursor]);
          sightCursor++;
        } else {
          sightsByDay[d].add('$cleanCity Attraction #${slot + 1}');
        }
      }
    }

    final List<Map<String, dynamic>> resultDays = [];

    for (int d = 0; d < totalDays; d++) {
      final dayNum = d + 1;
      final dateStr = (dateStrings != null && d < dateStrings.length && dateStrings[d].isNotEmpty)
          ? dateStrings[d]
          : 'Day $dayNum';
      final daySights = sightsByDay[d];

      final bStop = baseFoodStops.isNotEmpty ? baseFoodStops[d % baseFoodStops.length] : null;
      final lStop = baseFoodStops.length > 1 ? baseFoodStops[(d + 1) % baseFoodStops.length] : bStop;
      final tStop = baseFoodStops.length > 2 ? baseFoodStops[(d + 2) % baseFoodStops.length] : bStop;

      final breakfastName = (d == 0 && bStop != null)
          ? bStop.name
          : (d == 1 && cleanCity.toLowerCase() == 'mysuru'
              ? 'Gayatri Tiffin Room (GTR)'
              : (d == 1 && cleanCity.toLowerCase() == 'shimoga'
                  ? 'Sri Krishna Café (Durgigudi)'
                  : (bStop?.name ?? '$cleanCity Authentic Morning Tiffin Stall')));

      final lunchName = (d == 0 && lStop != null)
          ? lStop.name
          : (d == 1 && cleanCity.toLowerCase() == 'mysuru'
              ? 'Poojari Fish Land & Regional Meals'
              : (d == 1 && cleanCity.toLowerCase() == 'shimoga'
                  ? 'Hotel Shubham Pure Veg Thali'
                  : (lStop?.name ?? '$cleanCity Traditional Banana Leaf Meals')));

      final treatName = (d == 0 && tStop != null)
          ? tStop.name
          : (d == 1 && cleanCity.toLowerCase() == 'mysuru'
              ? 'Mahalaxmi Sweets & Filter Coffee'
              : (d == 1 && cleanCity.toLowerCase() == 'shimoga'
                  ? 'Malnad Tea Stall & Akki Roti Delicacies'
                  : (tStop?.name ?? '$cleanCity Traditional Sweet Mart & Filter Coffee')));

      final dinnerName = (cleanCity.toLowerCase() == 'mysuru')
          ? (d == 0 ? 'Gufha Cave Themed Restaurant' : 'The Green Hotel Garden Dining')
          : (cleanCity.toLowerCase() == 'shimoga'
              ? (d == 0 ? 'Harsha Grand Thali & Family Dining' : 'Rice Bowl Malnad Restaurant')
              : '$cleanCity Regional Dinner & Family Dining');

      final List<Map<String, String>> activities = [
        // 1. Breakfast (08:30 AM - 09:15 AM)
        {
          'place': breakfastName,
          'time': '08:30 AM - 09:15 AM',
          'period': 'Morning Breakfast ☕',
          'activity': 'Delicious regional breakfast (crisp dosas, idli-vada, fresh coconut chutney) with steaming filter coffee (45 mins).',
          'address': bStop?.address ?? 'Main Road, $cleanCity',
          'stopType': 'MEAL',
        },
        // 2. Morning Landmark (09:30 AM - 11:30 AM)
        {
          'place': daySights[0],
          'time': '09:30 AM - 11:30 AM',
          'period': 'Morning Landmark 🏛️',
          'activity': 'Explore premier heritage landmark, grand architecture & capture stunning morning photos • 15 mins travel to next.',
          'address': 'Historic District, $cleanCity',
          'stopType': 'VISIT',
        },
        // 3. Midday Wonder (11:45 AM - 01:00 PM)
        {
          'place': daySights[1],
          'time': '11:45 AM - 01:00 PM',
          'period': 'Midday Wonder 🌿',
          'activity': 'Scenic walk, peaceful cultural exhibits and nature exploration (1 hr 15 mins) • Short walk to lunch feast.',
          'address': 'Central Area, $cleanCity',
          'stopType': 'VISIT',
        },
        // 4. Authentic Lunch Feast (01:00 PM - 02:15 PM)
        {
          'place': lunchName,
          'time': '01:00 PM - 02:15 PM',
          'period': 'Authentic Lunch 🍛',
          'activity': 'Hearty regional cuisine & traditional multi-course thali served with ghee and local delicacies (1 hr 15 mins).',
          'address': lStop?.address ?? 'Market Square, $cleanCity',
          'stopType': 'MEAL',
        },
        // 5. Afternoon Landmark (02:30 PM - 04:30 PM)
        {
          'place': daySights[2],
          'time': '02:30 PM - 04:30 PM',
          'period': 'Afternoon Sight ✨',
          'activity': 'Deep dive into afternoon attractions, nature safari, museum galleries or scenic waterfalls (2 hrs) • 15 mins travel.',
          'address': 'Outskirts / Reserve, $cleanCity',
          'stopType': 'VISIT',
        },
        // 6. High Tea & Delicacies (04:45 PM - 05:30 PM)
        {
          'place': treatName,
          'time': '04:45 PM - 05:30 PM',
          'period': 'Local Treats 🫖',
          'activity': 'Unwind with local sweets, warm snacks (Bajjis, Benne Dosa or Mysore Pak) and fresh beverages (45 mins).',
          'address': tStop?.address ?? 'Promenade Road, $cleanCity',
          'stopType': 'BREAK',
        },
        // 7. Sunset Viewpoint (05:45 PM - 07:15 PM)
        {
          'place': daySights[3],
          'time': '05:45 PM - 07:15 PM',
          'period': 'Sunset Viewpoint 🌅',
          'activity': 'Spectacular golden hour panoramas over the Western Ghats / skyline and lively evening atmosphere (1 hr 30 mins).',
          'address': 'Lookout Point, near $cleanCity',
          'stopType': 'VISIT',
        },
        // 8. Dinner & Wind Down (07:30 PM - 09:00 PM)
        {
          'place': dinnerName,
          'time': '07:30 PM - 09:00 PM',
          'period': 'Dinner & Downtime 🌙',
          'activity': 'Relaxing evening dinner with friends, recap the day\'s highlights, and return to hotel by 09:15 PM for restful sleep.',
          'address': hotel ?? 'City Center, $cleanCity',
          'stopType': 'MEAL',
        },
      ];

      resultDays.add({
        'dayNumber': dayNum,
        'title': dateStr.contains('/') || dateStr.contains('-') ? 'Day $dayNum • $dateStr' : 'Day $dayNum • $dateStr',
        'date': dateStr,
        'summary': 'Day $dayNum: ${daySights[0]} & ${daySights[2]}',
        'activities': activities,
      });
    }

    return resultDays;
  }

  /// Looks up real GPS coordinates for any known curated stop across all Karnataka plans
  static ({double lat, double lng})? findStopCoordinate(String name) {
    final clean = name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (clean.isEmpty) return null;
    for (final plan in _curatedPlans.values) {
      for (final stop in plan.stops) {
        final stopClean = stop.name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (stopClean == clean ||
            (clean.length >= 6 && stopClean.contains(clean)) ||
            (stopClean.length >= 6 && clean.contains(stopClean))) {
          return (lat: stop.lat, lng: stop.lng);
        }
      }
    }
    return null;
  }
}
