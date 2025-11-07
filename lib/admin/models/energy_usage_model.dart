class EnergyUsage {
  final String id;
  final String deviceId;
  final String userId;
  final double kwh;
  final double cost;
  final DateTime timestamp;
  final String period; // 'hourly', 'daily', 'weekly', 'monthly'
  final Map<String, dynamic> metadata;

  EnergyUsage({
    required this.id,
    required this.deviceId,
    required this.userId,
    required this.kwh,
    required this.cost,
    required this.timestamp,
    required this.period,
    this.metadata = const {},
  });

  factory EnergyUsage.fromMap(Map<String, dynamic> map) {
    return EnergyUsage(
      id: map['id'] ?? '',
      deviceId: map['device_id'] ?? '',
      userId: map['user_id'] ?? '',
      kwh: (map['kwh'] ?? 0.0).toDouble(),
      cost: (map['cost'] ?? 0.0).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      period: map['period'] ?? 'hourly',
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'user_id': userId,
      'kwh': kwh,
      'cost': cost,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'period': period,
      'metadata': metadata,
    };
  }

  EnergyUsage copyWith({
    String? id,
    String? deviceId,
    String? userId,
    double? kwh,
    double? cost,
    DateTime? timestamp,
    String? period,
    Map<String, dynamic>? metadata,
  }) {
    return EnergyUsage(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      kwh: kwh ?? this.kwh,
      cost: cost ?? this.cost,
      timestamp: timestamp ?? this.timestamp,
      period: period ?? this.period,
      metadata: metadata ?? this.metadata,
    );
  }
}

class EnergyUsageSummary {
  final double totalKwh;
  final double totalCost;
  final double averageKwh;
  final double averageCost;
  final int totalRecords;
  final DateTime startDate;
  final DateTime endDate;

  EnergyUsageSummary({
    required this.totalKwh,
    required this.totalCost,
    required this.averageKwh,
    required this.averageCost,
    required this.totalRecords,
    required this.startDate,
    required this.endDate,
  });

  factory EnergyUsageSummary.fromMap(Map<String, dynamic> map) {
    return EnergyUsageSummary(
      totalKwh: (map['total_kwh'] ?? 0.0).toDouble(),
      totalCost: (map['total_cost'] ?? 0.0).toDouble(),
      averageKwh: (map['average_kwh'] ?? 0.0).toDouble(),
      averageCost: (map['average_cost'] ?? 0.0).toDouble(),
      totalRecords: map['total_records'] ?? 0,
      startDate: DateTime.fromMillisecondsSinceEpoch(map['start_date'] ?? 0),
      endDate: DateTime.fromMillisecondsSinceEpoch(map['end_date'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'total_kwh': totalKwh,
      'total_cost': totalCost,
      'average_kwh': averageKwh,
      'average_cost': averageCost,
      'total_records': totalRecords,
      'start_date': startDate.millisecondsSinceEpoch,
      'end_date': endDate.millisecondsSinceEpoch,
    };
  }
}

