class ProviderEarningsOrderItemModel {
  final int bookingId;
  final String? serviceName;
  final double amount;
  final String? date;
  final String? status;

  ProviderEarningsOrderItemModel({
    required this.bookingId,
    required this.amount,
    this.serviceName,
    this.date,
    this.status,
  });

  factory ProviderEarningsOrderItemModel.fromJson(Map<String, dynamic> json) {
    return ProviderEarningsOrderItemModel(
      bookingId: (json['bookingId'] as num).toInt(),
      serviceName: json['serviceName'] as String?,
      amount: ((json['amount'] as num?) ?? 0).toDouble(),
      date: json['date'] as String?,
      status: json['status'] as String?,
    );
  }
}

class ProviderEarningsModel {
  final int providerId;
  final double totalEarnings;
  final double todayEarnings;
  final double thisMonthEarnings;
  final int pendingOrders;
  final int inProgressOrders;
  final int completedOrders;
  final int cancelledOrders;
  final double averageCompletedOrderValue;
  final List<ProviderEarningsOrderItemModel> recentCompletedOrders;

  ProviderEarningsModel({
    required this.providerId,
    required this.totalEarnings,
    required this.todayEarnings,
    required this.thisMonthEarnings,
    required this.pendingOrders,
    required this.inProgressOrders,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.averageCompletedOrderValue,
    required this.recentCompletedOrders,
  });

  factory ProviderEarningsModel.fromJson(Map<String, dynamic> json) {
    final recent = (json['recentCompletedOrders'] as List<dynamic>? ?? const [])
        .map((item) => ProviderEarningsOrderItemModel.fromJson(item as Map<String, dynamic>))
        .toList();

    return ProviderEarningsModel(
      providerId: (json['providerId'] as num).toInt(),
      totalEarnings: ((json['totalEarnings'] as num?) ?? 0).toDouble(),
      todayEarnings: ((json['todayEarnings'] as num?) ?? 0).toDouble(),
      thisMonthEarnings: ((json['thisMonthEarnings'] as num?) ?? 0).toDouble(),
      pendingOrders: (json['pendingOrders'] as num?)?.toInt() ?? 0,
      inProgressOrders: (json['inProgressOrders'] as num?)?.toInt() ?? 0,
      completedOrders: (json['completedOrders'] as num?)?.toInt() ?? 0,
      cancelledOrders: (json['cancelledOrders'] as num?)?.toInt() ?? 0,
      averageCompletedOrderValue:
          ((json['averageCompletedOrderValue'] as num?) ?? 0).toDouble(),
      recentCompletedOrders: recent,
    );
  }
}
