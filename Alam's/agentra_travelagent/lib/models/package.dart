class Package {
  final String id;
  final String title;
  final String description;
  final String location;
  final double price;
  final String duration;
  final String? image;
  final double? rating;
  final int availableSeats;
  final String agentName;
  final String? province;
  final String? departureCity;
  final String? departureTime;
  final String? departureLocation;
  final String? notIncluded;
  final String? tripHighlights;
  final bool includesTransport;
  final bool includesAccommodation;
  final bool includesMeals;
  final bool isFeatured;
  final bool hasDiscount;
  final double discountPercentage;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<DateTime> availableDates;
  final List<Map<String, dynamic>> itinerary;

  Package({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.price,
    required this.duration,
    this.image,
    this.rating,
    required this.availableSeats,
    required this.agentName,
    this.province,
    this.departureCity,
    this.departureTime,
    this.departureLocation,
    this.notIncluded,
    this.tripHighlights,
    this.includesTransport = false,
    this.includesAccommodation = false,
    this.includesMeals = false,
    this.isFeatured = false,
    this.hasDiscount = false,
    this.discountPercentage = 0,
    this.startDate,
    this.endDate,
    this.availableDates = const [],
    this.itinerary = const [],
  });

  factory Package.fromJson(Map<String, dynamic> json) {
    final includes = json['includes'] ?? {};
    return Package(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      location: json['location'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      duration: json['duration'] ?? '',
      image: json['image'],
      rating: json['rating'] != null
          ? (json['rating'] as num).toDouble()
          : null,
      availableSeats: json['availableSeats'] ?? 0,
      agentName: json['agentName'] ?? 'Unknown',
      province: json['province'],
      departureCity: json['departureCity'],
      departureTime: json['departureTime'],
      departureLocation: json['departureLocation'],
      notIncluded: json['notIncluded'],
      tripHighlights: json['tripHighlights'],
      includesTransport: includes['transport'] ?? false,
      includesAccommodation: includes['accommodation'] ?? false,
      includesMeals: includes['meals'] ?? false,
      isFeatured: json['isFeatured'] ?? false,
      hasDiscount: json['hasDiscount'] ?? false,
      discountPercentage: (json['discountPercentage'] ?? 0).toDouble(),
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'])
          : null,
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'])
          : null,
      availableDates: (json['availableDates'] as List<dynamic>? ?? [])
          .map((d) => DateTime.tryParse(d.toString()) ?? DateTime.now())
          .toList(),
      itinerary: (json['itinerary'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'description': description,
      'location': location,
      'price': price,
      'duration': duration,
      'image': image,
      'rating': rating,
      'availableSeats': availableSeats,
      'agentName': agentName,
      'province': province,
      'departureCity': departureCity,
      'departureTime': departureTime,
      'departureLocation': departureLocation,
      'notIncluded': notIncluded,
      'tripHighlights': tripHighlights,
      'includes': {
        'transport': includesTransport,
        'accommodation': includesAccommodation,
        'meals': includesMeals,
      },
      'isFeatured': isFeatured,
      'hasDiscount': hasDiscount,
      'discountPercentage': discountPercentage,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'availableDates': availableDates.map((d) => d.toIso8601String()).toList(),
      'itinerary': itinerary,
    };
  }
}
