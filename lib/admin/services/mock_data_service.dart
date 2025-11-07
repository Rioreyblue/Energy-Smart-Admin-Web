import 'dart:math';

class MockDataService {
  static final MockDataService _instance = MockDataService._internal();
  factory MockDataService() => _instance;
  MockDataService._internal();

  // Mock User Data
  List<Map<String, dynamic>> getUsers() {
    return [
      {
        'id': '1',
        'name': 'condes angeline',
        'email': 'condesangeline@gmail.com',
        'role': 'Admin',
        'status': 'Active',
        'lastActive': DateTime.now().subtract(const Duration(hours: 2)),
        'energyUsage': 1250.5,
        'devices': 3,
      },
      {
        'id': '2',
        'name': 'carl james',
        'email': 'carljames@gmail.com',
        'role': 'User',
        'status': 'Active',
        'lastActive': DateTime.now().subtract(const Duration(minutes: 30)),
        'energyUsage': 890.2,
        'devices': 2,
      },
      {
        'id': '3',
        'name': 'kris ly bactol',
        'email': 'krislybactol@gmail.com',
        'role': 'User',
        'status': 'Suspended',
        'lastActive': DateTime.now().subtract(const Duration(days: 5)),
        'energyUsage': 2100.8,
        'devices': 4,
      },
      {
        'id': '4',
        'name': 'reyfrancisco',
        'email': 'franciscorey@gmail.com',
        'role': 'User',
        'status': 'Active',
        'lastActive': DateTime.now().subtract(const Duration(hours: 1)),
        'energyUsage': 675.3,
        'devices': 1,
      },
      // {
      //   'id': '5',
      //   'name': 'David Brown',
      //   'email': 'david.brown@example.com',
      //   'role': 'User',
      //   'status': 'Active',
      //   'lastActive': DateTime.now().subtract(const Duration(minutes: 15)),
      //   'energyUsage': 1450.7,
      //   'devices': 3,
      // },
    ];
  }

  // Mock Dashboard Statistics
  Map<String, dynamic> getDashboardStats() {
    return {
      'totalUsers': 1247,
      'activeDevices': 3421,
      'totalEnergyUsage': 45678.9, // kWh
      'currentPowerRate': 6.50, // ₱/kWh (Philippine Peso)
    };
  }

  // Mock Energy Usage Data for Charts
  List<Map<String, dynamic>> getEnergyUsageData() {
    final random = Random();
    final now = DateTime.now();
    List<Map<String, dynamic>> data = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      data.add({
        'date': date,
        'usage':
            1200 + random.nextInt(800) - 400, // Random usage between 800-1600
        'cost':
            (1200 + random.nextInt(800) - 400) *
            6.50, // Cost in Philippine Peso
      });
    }
    return data;
  }

  // Mock Hourly Usage Data
  List<Map<String, dynamic>> getHourlyUsageData() {
    final random = Random();
    List<Map<String, dynamic>> data = [];

    for (int hour = 0; hour < 24; hour++) {
      // Simulate higher usage during peak hours (6-9 AM, 6-9 PM)
      double baseUsage = 50;
      if ((hour >= 6 && hour <= 9) || (hour >= 18 && hour <= 21)) {
        baseUsage = 120;
      } else if (hour >= 22 || hour <= 5) {
        baseUsage = 30;
      }

      data.add({'hour': hour, 'usage': baseUsage + random.nextInt(40) - 20});
    }
    return data;
  }

  // Mock Device Comparison Data
  List<Map<String, dynamic>> getDeviceComparisonData() {
    return [
      {'device': 'Air Conditioner', 'usage': 45.2, 'cost': 293.80}, // ₱6.50/kWh
      {'device': 'Refrigerator', 'usage': 12.8, 'cost': 83.20},
      {'device': 'Washing Machine', 'usage': 8.5, 'cost': 55.25},
      {'device': 'Water Heater', 'usage': 15.3, 'cost': 99.45},
      {'device': 'Lighting', 'usage': 6.7, 'cost': 43.55},
      {'device': 'Electronics', 'usage': 4.2, 'cost': 27.30},
    ];
  }

  // Mock Reports Data
  List<Map<String, dynamic>> getReportsData() {
    return [
      {
        'id': '1',
        'type': 'Energy Report',
        'period': 'Daily',
        'generatedAt': DateTime.now().subtract(const Duration(hours: 2)),
        'status': 'Completed',
        'fileSize': '2.3 MB',
      },
      {
        'id': '2',
        'type': 'Usage Analytics',
        'period': 'Weekly',
        'generatedAt': DateTime.now().subtract(const Duration(days: 1)),
        'status': 'Completed',
        'fileSize': '5.7 MB',
      },
      {
        'id': '3',
        'type': 'Device Performance',
        'period': 'Monthly',
        'generatedAt': DateTime.now().subtract(const Duration(days: 3)),
        'status': 'Processing',
        'fileSize': '12.1 MB',
      },
      {
        'id': '4',
        'type': 'Cost Analysis',
        'period': 'Monthly',
        'generatedAt': DateTime.now().subtract(const Duration(days: 7)),
        'status': 'Completed',
        'fileSize': '8.9 MB',
      },
    ];
  }

  // Mock System Settings
  Map<String, dynamic> getSystemSettings() {
    return {
      'powerRate': 6.50, // Philippine Peso per kWh
      'targetThreshold': 85.0,
      'notificationEnabled': true,
      'autoReports': true,
      'reportFrequency': 'Weekly',
      'appVersion': '1.0.0',
      'lastUpdated': DateTime.now().subtract(const Duration(hours: 1)),
    };
  }

  // Mock Notifications
  List<Map<String, dynamic>> getNotifications() {
    return [
      {
        'id': '1',
        'title': 'High Energy Usage Alert',
        'message': 'User Mike Wilson exceeded 2000 kWh threshold',
        'type': 'warning',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 15)),
        'read': false,
      },
      {
        'id': '2',
        'title': 'System Update Available',
        'message': 'New version 1.0.1 is ready for installation',
        'type': 'info',
        'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
        'read': true,
      },
      {
        'id': '3',
        'title': 'Weekly Report Generated',
        'message': 'Energy usage report for last week is ready',
        'type': 'success',
        'timestamp': DateTime.now().subtract(const Duration(hours: 4)),
        'read': false,
      },
    ];
  }

  // Mock methods for user actions
  Future<bool> toggleUserStatus(String userId) async {
    // Simulate API call delay
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  Future<bool> updateSystemSettings(Map<String, dynamic> settings) async {
    // Simulate API call delay
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  Future<bool> generateReport(String reportType) async {
    // Simulate report generation delay
    await Future.delayed(const Duration(seconds: 2));
    return true;
  }
}
