class ReviewModel {
  final int id;
  final int bookingId;
  final int userId;
  final String? userName;
  final int providerId;
  final int serviceId;
  final String? serviceName;
  final int rating;
  final String? comment;
  final String? providerResponse;
  final String? createdAt;

  ReviewModel({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.providerId,
    required this.serviceId,
    required this.rating,
    this.userName,
    this.serviceName,
    this.comment,
    this.providerResponse,
    this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: (json['id'] as num).toInt(),
      bookingId: (json['bookingId'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      userName: json['userName'] as String?,
      providerId: (json['providerId'] as num).toInt(),
      serviceId: (json['serviceId'] as num).toInt(),
      serviceName: json['serviceName'] as String?,
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
      providerResponse: json['providerResponse'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }
}
