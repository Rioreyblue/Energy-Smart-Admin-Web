class PowerRate {
  final String id;
  final double ratePerKwh;
  final String currency;
  final DateTime effectiveDate;
  final DateTime? endDate;
  final String description;
  final bool isActive;
  final String createdBy;
  final DateTime createdAt;

  PowerRate({
    required this.id,
    required this.ratePerKwh,
    this.currency = 'USD',
    required this.effectiveDate,
    this.endDate,
    this.description = '',
    this.isActive = true,
    required this.createdBy,
    required this.createdAt,
  });

  factory PowerRate.fromMap(Map<String, dynamic> map) {
    return PowerRate(
      id: map['id'] ?? '',
      ratePerKwh: (map['rate_per_kwh'] ?? 0.0).toDouble(),
      currency: map['currency'] ?? 'USD',
      effectiveDate: DateTime.fromMillisecondsSinceEpoch(
        map['effective_date'] ?? 0,
      ),
      endDate:
          map['end_date'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['end_date'])
              : null,
      description: map['description'] ?? '',
      isActive: map['is_active'] ?? true,
      createdBy: map['created_by'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rate_per_kwh': ratePerKwh,
      'currency': currency,
      'effective_date': effectiveDate.millisecondsSinceEpoch,
      'end_date': endDate?.millisecondsSinceEpoch,
      'description': description,
      'is_active': isActive,
      'created_by': createdBy,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  PowerRate copyWith({
    String? id,
    double? ratePerKwh,
    String? currency,
    DateTime? effectiveDate,
    DateTime? endDate,
    String? description,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return PowerRate(
      id: id ?? this.id,
      ratePerKwh: ratePerKwh ?? this.ratePerKwh,
      currency: currency ?? this.currency,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      endDate: endDate ?? this.endDate,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get formattedRate =>
      '\$${ratePerKwh.toStringAsFixed(2)}/$currency per kWh';
  bool get isCurrent =>
      isActive && (endDate == null || endDate!.isAfter(DateTime.now()));
}

class PowerRateHistory {
  final List<PowerRate> rates;
  final PowerRate? currentRate;
  final double averageRate;
  final int totalChanges;

  PowerRateHistory({
    required this.rates,
    this.currentRate,
    required this.averageRate,
    required this.totalChanges,
  });

  factory PowerRateHistory.fromRates(List<PowerRate> rates) {
    final activeRates = rates.where((rate) => rate.isActive).toList();
    final currentRate = activeRates.isNotEmpty ? activeRates.first : null;
    final averageRate =
        rates.isNotEmpty
            ? rates.map((rate) => rate.ratePerKwh).reduce((a, b) => a + b) /
                rates.length
            : 0.0;

    return PowerRateHistory(
      rates: rates,
      currentRate: currentRate,
      averageRate: averageRate,
      totalChanges: rates.length,
    );
  }
}

