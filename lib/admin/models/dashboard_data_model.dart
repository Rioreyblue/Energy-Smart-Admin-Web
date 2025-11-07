import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for dashboard system statistics
class DashboardStats {
  final double currentRate;
  final int totalUsers;
  final int activeDevices;
  final double totalEnergyToday;
  final double totalEnergyWeek;
  final double totalEnergyMonth;
  final int totalAlerts;
  final DateTime lastUpdated;
  final String updatedBy;

  DashboardStats({
    required this.currentRate,
    required this.totalUsers,
    required this.activeDevices,
    required this.totalEnergyToday,
    required this.totalEnergyWeek,
    required this.totalEnergyMonth,
    required this.totalAlerts,
    required this.lastUpdated,
    required this.updatedBy,
  });

  factory DashboardStats.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return DashboardStats(
      currentRate: (data['current_rate'] ?? 6.50).toDouble(),
      totalUsers: data['total_users'] ?? 0,
      activeDevices: data['active_devices'] ?? 0,
      totalEnergyToday: (data['total_energy_today'] ?? 0.0).toDouble(),
      totalEnergyWeek: (data['total_energy_week'] ?? 0.0).toDouble(),
      totalEnergyMonth: (data['total_energy_month'] ?? 0.0).toDouble(),
      totalAlerts: data['total_alerts'] ?? 0,
      lastUpdated:
          (data['last_updated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedBy: data['updated_by'] ?? 'System',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'current_rate': currentRate,
      'total_users': totalUsers,
      'active_devices': activeDevices,
      'total_energy_today': totalEnergyToday,
      'total_energy_week': totalEnergyWeek,
      'total_energy_month': totalEnergyMonth,
      'total_alerts': totalAlerts,
      'last_updated': Timestamp.fromDate(lastUpdated),
      'updated_by': updatedBy,
    };
  }

  DashboardStats copyWith({
    double? currentRate,
    int? totalUsers,
    int? activeDevices,
    double? totalEnergyToday,
    double? totalEnergyWeek,
    double? totalEnergyMonth,
    int? totalAlerts,
    DateTime? lastUpdated,
    String? updatedBy,
  }) {
    return DashboardStats(
      currentRate: currentRate ?? this.currentRate,
      totalUsers: totalUsers ?? this.totalUsers,
      activeDevices: activeDevices ?? this.activeDevices,
      totalEnergyToday: totalEnergyToday ?? this.totalEnergyToday,
      totalEnergyWeek: totalEnergyWeek ?? this.totalEnergyWeek,
      totalEnergyMonth: totalEnergyMonth ?? this.totalEnergyMonth,
      totalAlerts: totalAlerts ?? this.totalAlerts,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}

/// Model for energy usage data points
class EnergyUsageData {
  final DateTime date;
  final double usage;
  final double cost;
  final String period; // 'daily', 'weekly', 'monthly'

  EnergyUsageData({
    required this.date,
    required this.usage,
    required this.cost,
    required this.period,
  });

  factory EnergyUsageData.fromFirestore(Map<String, dynamic> data) {
    return EnergyUsageData(
      date: (data['date'] as Timestamp).toDate(),
      usage: (data['usage'] ?? 0.0).toDouble(),
      cost: (data['cost'] ?? 0.0).toDouble(),
      period: data['period'] ?? 'daily',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'usage': usage,
      'cost': cost,
      'period': period,
    };
  }
}

/// Model for device usage data
class DeviceUsageData {
  final String deviceName;
  final String deviceType;
  final double usage;
  final double cost;
  final bool isActive;
  final DateTime lastSeen;

  DeviceUsageData({
    required this.deviceName,
    required this.deviceType,
    required this.usage,
    required this.cost,
    required this.isActive,
    required this.lastSeen,
  });

  factory DeviceUsageData.fromFirestore(Map<String, dynamic> data) {
    return DeviceUsageData(
      deviceName: data['device_name'] ?? 'Unknown Device',
      deviceType: data['device_type'] ?? 'Unknown',
      usage: (data['usage'] ?? 0.0).toDouble(),
      cost: (data['cost'] ?? 0.0).toDouble(),
      isActive: data['is_active'] ?? false,
      lastSeen: (data['last_seen'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'device_name': deviceName,
      'device_type': deviceType,
      'usage': usage,
      'cost': cost,
      'is_active': isActive,
      'last_seen': Timestamp.fromDate(lastSeen),
    };
  }
}

/// Model for alert data
class AlertData {
  final String id;
  final String title;
  final String message;
  final String type; // 'warning', 'error', 'info'
  final String severity; // 'low', 'medium', 'high', 'critical'
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  AlertData({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.severity,
    required this.isRead,
    required this.createdAt,
    this.metadata,
  });

  factory AlertData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return AlertData(
      id: doc.id,
      title: data['title'] ?? 'Alert',
      message: data['message'] ?? '',
      type: data['type'] ?? 'info',
      severity: data['severity'] ?? 'low',
      isRead: data['is_read'] ?? false,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'message': message,
      'type': type,
      'severity': severity,
      'is_read': isRead,
      'created_at': Timestamp.fromDate(createdAt),
      'metadata': metadata,
    };
  }
}

/// Model for user statistics
class UserStats {
  final int totalUsers;
  final int activeUsers;
  final int newUsersToday;
  final int newUsersWeek;
  final int newUsersMonth;
  final DateTime lastUpdated;

  UserStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.newUsersToday,
    required this.newUsersWeek,
    required this.newUsersMonth,
    required this.lastUpdated,
  });

  factory UserStats.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return UserStats(
      totalUsers: data['total_users'] ?? 0,
      activeUsers: data['active_users'] ?? 0,
      newUsersToday: data['new_users_today'] ?? 0,
      newUsersWeek: data['new_users_week'] ?? 0,
      newUsersMonth: data['new_users_month'] ?? 0,
      lastUpdated:
          (data['last_updated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'total_users': totalUsers,
      'active_users': activeUsers,
      'new_users_today': newUsersToday,
      'new_users_week': newUsersWeek,
      'new_users_month': newUsersMonth,
      'last_updated': Timestamp.fromDate(lastUpdated),
    };
  }
}
