class DestinationItem {
  final String id;
  final String name;
  final String state;
  final String district;
  final String category;
  final double rating;
  final String imageUrl;
  final String description;
  final List<String> topAttractions;

  const DestinationItem({
    required this.id,
    required this.name,
    required this.state,
    required this.district,
    required this.category,
    required this.rating,
    required this.imageUrl,
    required this.description,
    this.topAttractions = const [],
  });

  static const List<DestinationItem> sampleDestinations = [
    DestinationItem(
      id: 'coorg',
      name: 'Coorg',
      state: 'Karnataka',
      district: 'Kodagu',
      category: 'Hill Station',
      rating: 4.8,
      imageUrl:
          'https://images.unsplash.com/photo-1590050752117-238cb0fb12b1?auto=format&fit=crop&w=600&q=80',
      description:
          'Known as the Scotland of India, famous for aromatic coffee estates, misty Western Ghat hills, and cascading waterfalls.',
      topAttractions: ['Abbey Falls', "Raja's Seat", 'Dubare Elephant Camp', 'Talakaveri'],
    ),
    DestinationItem(
      id: 'hampi',
      name: 'Hampi',
      state: 'Karnataka',
      district: 'Vijayanagara',
      category: 'Heritage',
      rating: 4.9,
      imageUrl:
          'https://images.unsplash.com/photo-1600100397608-f010f444c4e7?auto=format&fit=crop&w=600&q=80',
      description:
          'UNESCO World Heritage Site with mesmerizing ruins of the Vijayanagara Empire, granite boulder hills, and ancient monolithic temples.',
      topAttractions: ['Virupaksha Temple', 'Stone Chariot', 'Vittala Temple', 'Matanga Hill'],
    ),
    DestinationItem(
      id: 'mysuru',
      name: 'Mysuru',
      state: 'Karnataka',
      district: 'Mysuru',
      category: 'Heritage',
      rating: 4.8,
      imageUrl:
          'https://images.unsplash.com/photo-1599661046289-e31897846e41?auto=format&fit=crop&w=600&q=80',
      description:
          'The City of Palaces, renowned for the magnificent illuminated Mysore Palace, silk sarees, sandalwood, and royal heritage.',
      topAttractions: ['Mysore Palace', 'Chamundi Hill', 'Brindavan Gardens', 'St. Philomena Church'],
    ),
    DestinationItem(
      id: 'chikmagalur',
      name: 'Chikmagalur',
      state: 'Karnataka',
      district: 'Chikkamagaluru',
      category: 'Hill Station',
      rating: 4.8,
      imageUrl:
          'https://images.unsplash.com/photo-1544735716-392fe2489ffa?auto=format&fit=crop&w=600&q=80',
      description:
          'The birthplace of Indian coffee, offering verdant peaks like Mullayanagiri, tranquil nature trails, and breathtaking waterfalls.',
      topAttractions: ['Mullayanagiri Peak', 'Baba Budangiri', 'Hebbe Falls', 'Z Point'],
    ),
    DestinationItem(
      id: 'gokarna',
      name: 'Gokarna',
      state: 'Karnataka',
      district: 'Uttara Kannada',
      category: 'Beach',
      rating: 4.7,
      imageUrl:
          'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?auto=format&fit=crop&w=600&q=80',
      description:
          'A serene coastal gem blending pristine beaches like Om Beach with spiritual heritage and cliff-side sunset treks.',
      topAttractions: ['Om Beach', 'Kudle Beach', 'Mahabaleshwar Temple', 'Half Moon Beach'],
    ),
    DestinationItem(
      id: 'badami',
      name: 'Badami',
      state: 'Karnataka',
      district: 'Bagalkot',
      category: 'Heritage',
      rating: 4.7,
      imageUrl:
          'https://images.unsplash.com/photo-1615836245337-f5b9b2303f10?auto=format&fit=crop&w=600&q=80',
      description:
          'Famous for its 6th-century rock-cut cave temples carved into red sandstone cliffs surrounding the sacred Agastya Lake.',
      topAttractions: ['Badami Cave Temples', 'Agastya Lake', 'Bhutanatha Temples', 'Badami Fort'],
    ),
    DestinationItem(
      id: 'dandeli',
      name: 'Dandeli',
      state: 'Karnataka',
      district: 'Uttara Kannada',
      category: 'Adventure',
      rating: 4.7,
      imageUrl:
          'https://images.unsplash.com/photo-1544551763-46a013bb70d5?auto=format&fit=crop&w=600&q=80',
      description:
          'Karnataka’s ultimate adventure playground on the Kali River, famous for white-water rafting, wildlife sanctuaries, and jungle camps.',
      topAttractions: ['Kali River Rafting', 'Dandeli Wildlife Sanctuary', 'Syntheri Rocks', 'Shiroli Peak'],
    ),
    DestinationItem(
      id: 'kabini',
      name: 'Kabini',
      state: 'Karnataka',
      district: 'Mysuru',
      category: 'Wildlife',
      rating: 4.9,
      imageUrl:
          'https://images.unsplash.com/photo-1557050543-4d5f4e07ef46?auto=format&fit=crop&w=600&q=80',
      description:
          'One of the finest wildlife reserves in India, famous for boat safaris, majestic Asiatic elephants, and elusive black panthers.',
      topAttractions: ['Nagarhole National Park', 'Kabini River Safari', 'Kabini Dam', 'Elephant Corridor'],
    ),
    DestinationItem(
      id: 'jog_falls',
      name: 'Jog Falls',
      state: 'Karnataka',
      district: 'Shivamogga',
      category: 'Nature',
      rating: 4.8,
      imageUrl:
          'https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?auto=format&fit=crop&w=600&q=80',
      description:
          'The second-highest plunge waterfall in India, where the Sharavathi River dramatically drops 253 meters in four cascades.',
      topAttractions: ['Raja-Rani-Roarer-Rocket Falls', 'Sharavathi Valley', 'Watkins Platform', 'Linganamakki Dam'],
    ),
  ];
}
