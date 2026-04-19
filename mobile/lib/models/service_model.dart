class ServiceModel {
  final int id;
  final String name;
  final double price;

  ServiceModel({required this.id, required this.name, required this.price});

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] as int,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
    );
  }
}