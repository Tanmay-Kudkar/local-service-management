class ServiceModel {
  final int id;
  final String name;
  final double price;
  final String? description;
  final int? providerId;
  final String? providerName;
  final String? providerContactNumber;
  final String? providerAddress;
  final String? providerCity;
  final String? providerState;
  final String? providerPincode;
  final String? providerProfileImageUrl;
  final int? providerExperienceYears;
  final String? providerSkills;
  final String? providerBio;
  final bool providerVerified;
  final double providerRatingAverage;
  final int providerTotalReviews;

  ServiceModel({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.providerId,
    this.providerName,
    this.providerContactNumber,
    this.providerAddress,
    this.providerCity,
    this.providerState,
    this.providerPincode,
    this.providerProfileImageUrl,
    this.providerExperienceYears,
    this.providerSkills,
    this.providerBio,
    this.providerVerified = false,
    this.providerRatingAverage = 0,
    this.providerTotalReviews = 0,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] as int,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      description: json['description'] as String?,
      providerId: (json['providerId'] as num?)?.toInt(),
      providerName: json['providerName'] as String?,
      providerContactNumber: json['providerContactNumber'] as String?,
      providerAddress: json['providerAddress'] as String?,
      providerCity: json['providerCity'] as String?,
      providerState: json['providerState'] as String?,
      providerPincode: json['providerPincode'] as String?,
      providerProfileImageUrl: json['providerProfileImageUrl'] as String?,
      providerExperienceYears: (json['providerExperienceYears'] as num?)?.toInt(),
      providerSkills: json['providerSkills'] as String?,
      providerBio: json['providerBio'] as String?,
      providerVerified: (json['providerVerified'] as bool?) ?? false,
      providerRatingAverage: ((json['providerRatingAverage'] as num?) ?? 0).toDouble(),
      providerTotalReviews: (json['providerTotalReviews'] as num?)?.toInt() ?? 0,
    );
  }
}