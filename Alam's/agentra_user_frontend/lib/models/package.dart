import '../config/api_config.dart';
class Package {
  final String id;
  final String title;
  final String description;
  final String location;
  final double price;
  final String duration;

  final String? province;
  final String? departureCity;
  final String? departureTime;
  final String? departureLocation;

  final String? image;
  final List<String>? images;

  final double? rating;
  final int? totalReviews;

  final int availableSeats;

  final DateTime? startDate;
  final DateTime? endDate;
  final List<DateTime>? availableDates;

  DateTime? get departureDate => startDate;
  DateTime? get returnDate => endDate;

  bool get isExpired {
    if (returnDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final retDay = DateTime(returnDate!.year, returnDate!.month, returnDate!.day);
    return retDay.isBefore(today);
  }

  final bool? isFeatured;
  final bool? hasDiscount;
  final double? discountPercentage;

  final bool? includesTransport;
  final bool? includesAccommodation;
  final bool? includesMeals;

  final String? notIncluded;
  final String? tripHighlights;

  final List<Map<String, dynamic>>? itinerary;

  final String agentName;
  final String? cancellationPolicy;

  Package({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.price,
    required this.duration,
    this.province,
    this.departureCity,
    this.image,
    this.images,
    this.rating,
    this.totalReviews,
    required this.availableSeats,
    this.startDate,
    this.endDate,
    this.availableDates,
    this.isFeatured,
    this.hasDiscount,
    this.discountPercentage,
    this.includesTransport,
    this.includesAccommodation,
    this.includesMeals,
    this.notIncluded,
    this.tripHighlights,
    this.itinerary,
    this.departureTime,
    this.departureLocation,
    required this.agentName,
    this.cancellationPolicy,
  });

factory Package.fromJson(Map<String, dynamic> json) {
  return Package(
    id: json['_id'] ?? '',
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    location: json['location'] ?? '',
    price: (json['price'] ?? 0).toDouble(),
    duration: json['duration'] ?? '',

    province: json['province'],
    departureCity: json['departureCity'],

    image: ApiConfig.getImageUrl(json['image']),
    images: json['images'] != null
        ? List<String>.from(json['images'].map((i) => ApiConfig.getImageUrl(i)))
        : null,

    rating: json['rating'] != null
        ? (json['rating'] as num).toDouble()
        : null,

    totalReviews: json['totalReviews'],

    availableSeats: json['availableSeats'] ?? 0,

    startDate: json['startDate'] != null
        ? DateTime.parse(json['startDate'])
        : (json['departureDate'] != null
            ? DateTime.tryParse(json['departureDate'].toString())
            : null),

    endDate: json['endDate'] != null
        ? DateTime.parse(json['endDate'])
        : (json['returnDate'] != null
            ? DateTime.tryParse(json['returnDate'].toString())
            : null),

    availableDates: json['availableDates'] != null
        ? List<DateTime>.from(
            json['availableDates'].map((d) => DateTime.parse(d)))
        : null,

    isFeatured: json['isFeatured'],
    hasDiscount: json['hasDiscount'],
    discountPercentage:
        (json['discountPercentage'] as num?)?.toDouble(),

    includesTransport: json['includes']?['transport'],
    includesAccommodation: json['includes']?['accommodation'],
    includesMeals: json['includes']?['meals'],

    notIncluded: json['notIncluded'],
    tripHighlights: json['tripHighlights'],

    itinerary: json['itinerary'] != null
        ? List<Map<String, dynamic>>.from(json['itinerary'])
        : null,
    departureTime: json['departureTime'],
    departureLocation: json['departureLocation'],

    agentName: (json['agentId'] is Map)
        ? (json['agentId']['businessName'] ??
            json['agentId']['fullName'] ??
            'Unknown')
        : 'Unknown',
    cancellationPolicy: (json['agentId'] is Map)
        ? (json['agentId']['cancellationPolicy'] ?? '')
        : '',
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

      'province': province,
      'departureCity': departureCity,

      'image': image,
      'images': images,

      'rating': rating,
      'totalReviews': totalReviews,

      'availableSeats': availableSeats,

      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'availableDates':
          availableDates?.map((d) => d.toIso8601String()).toList(),

      'isFeatured': isFeatured,
      'hasDiscount': hasDiscount,
      'discountPercentage': discountPercentage,

      'includes': {
        'transport': includesTransport,
        'accommodation': includesAccommodation,
        'meals': includesMeals,
      },

      'notIncluded': notIncluded,
      'tripHighlights': tripHighlights,
      'itinerary': itinerary,
      'departureTime': departureTime,
      'departureLocation': departureLocation,

      'agentName': agentName,
    };
  }
}