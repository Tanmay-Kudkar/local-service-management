class ServiceModel {
  final int id;
  final String name;
  final double price;
  final String? description;
  final int? providerId;

  ServiceModel({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.providerId,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] as int,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      description: json['description'] as String?,
      providerId: (json['providerId'] as num?)?.toInt(),
    );
  }
}