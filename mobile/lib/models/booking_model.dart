class BookingModel {
  final int id;
  final int userId;
  final int serviceId;
  final String? serviceName;
  final double? servicePrice;
  final int? providerId;
  final String? providerName;
  final String date;
  final String status;
  final String? trackingNote;
  final bool liveLocationSharingEnabled;
  final double? providerLatitude;
  final double? providerLongitude;
  final String? providerLocationUpdatedAt;
  final String? createdAt;
  final String? updatedAt;
  final bool reviewSubmitted;

  BookingModel({
    required this.id,
    required this.userId,
    required this.serviceId,
    required this.date,
    this.serviceName,
    this.servicePrice,
    this.providerId,
    this.providerName,
    this.status = 'PENDING',
    this.trackingNote,
    this.liveLocationSharingEnabled = false,
    this.providerLatitude,
    this.providerLongitude,
    this.providerLocationUpdatedAt,
    this.createdAt,
    this.updatedAt,
    this.reviewSubmitted = false,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] as int,
      userId: json['userId'] as int,
      serviceId: json['serviceId'] as int,
      date: json['date'] as String,
      serviceName: json['serviceName'] as String?,
      servicePrice: (json['servicePrice'] as num?)?.toDouble(),
      providerId: (json['providerId'] as num?)?.toInt(),
      providerName: json['providerName'] as String?,
      status: (json['status'] as String?) ?? 'PENDING',
      trackingNote: json['trackingNote'] as String?,
      liveLocationSharingEnabled:
          (json['liveLocationSharingEnabled'] as bool?) ?? false,
      providerLatitude: (json['providerLatitude'] as num?)?.toDouble(),
      providerLongitude: (json['providerLongitude'] as num?)?.toDouble(),
      providerLocationUpdatedAt: json['providerLocationUpdatedAt'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      reviewSubmitted: (json['reviewSubmitted'] as bool?) ?? false,
    );
  }
}