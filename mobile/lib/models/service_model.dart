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
  final String? providerProfileImageBase64;
  final String? providerProfileImageContentType;
  final int? providerExperienceYears;
  final String? providerSkills;
  final String? providerBio;
  final bool providerVerified;
  final double providerRatingAverage;
  final int providerTotalReviews;
  final bool providerLiveLocationSharingEnabled;
  final double? providerLiveLatitude;
  final double? providerLiveLongitude;
  final String? providerLiveLocationUpdatedAt;
  final double? providerDistanceKm;
  final bool available;

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
    this.providerProfileImageBase64,
    this.providerProfileImageContentType,
    this.providerExperienceYears,
    this.providerSkills,
    this.providerBio,
    this.providerVerified = false,
    this.providerRatingAverage = 0,
    this.providerTotalReviews = 0,
    this.providerLiveLocationSharingEnabled = false,
    this.providerLiveLatitude,
    this.providerLiveLongitude,
    this.providerLiveLocationUpdatedAt,
    this.providerDistanceKm,
    this.available = true,
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
      providerProfileImageBase64: json['providerProfileImageBase64'] as String?,
      providerProfileImageContentType: json['providerProfileImageContentType'] as String?,
      providerExperienceYears: (json['providerExperienceYears'] as num?)?.toInt(),
      providerSkills: json['providerSkills'] as String?,
      providerBio: json['providerBio'] as String?,
      providerVerified: (json['providerVerified'] as bool?) ?? false,
      providerRatingAverage: ((json['providerRatingAverage'] as num?) ?? 0).toDouble(),
      providerTotalReviews: (json['providerTotalReviews'] as num?)?.toInt() ?? 0,
      providerLiveLocationSharingEnabled:
          (json['providerLiveLocationSharingEnabled'] as bool?) ?? false,
      providerLiveLatitude: (json['providerLiveLatitude'] as num?)?.toDouble(),
      providerLiveLongitude: (json['providerLiveLongitude'] as num?)?.toDouble(),
      providerLiveLocationUpdatedAt: json['providerLiveLocationUpdatedAt'] as String?,
      providerDistanceKm: (json['providerDistanceKm'] as num?)?.toDouble(),
      available: (json['available'] as bool?) ?? true,
    );
  }
}