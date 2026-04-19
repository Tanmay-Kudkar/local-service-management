class BookingModel {
  final int id;
  final int userId;
  final int serviceId;
  final String date;

  BookingModel({
    required this.id,
    required this.userId,
    required this.serviceId,
    required this.date,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] as int,
      userId: json['userId'] as int,
      serviceId: json['serviceId'] as int,
      date: json['date'] as String,
    );
  }
}