import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/dashboard_data_model.dart';
import '../../utils/logger.dart';

class FirestoreDashboardService {
  static final FirestoreDashboardService _instance =
      FirestoreDashboardService._internal();
  factory FirestoreDashboardService() => _instance;
  FirestoreDashboardService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  static const String _dashboardCollection = 'admin_dashboard';
  static const String _systemStatsDoc = 'system_stats';
  static const String _energyUsageCollection = 'energy_usage';
  static const String _deviceUsageCollection = 'device_usage';
  static const String _alertsCollection = 'alerts';
  static const String _userStatsDoc = 'user_stats';

  /// Get real-time dashboard statistics stream
  Stream<DashboardStats> getDashboardStatsStream() {
    return _firestore
        .collection(_dashboardCollection)
        .doc(_systemStatsDoc)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists) {
            return DashboardStats.fromFirestore(snapshot);
          } else {
            // Return default stats if document doesn't exist
            return _getDefaultDashboardStats();
          }
        });
  }

  /// Get dashboard statistics (one-time fetch)
  Future<DashboardStats> getDashboardStats() async {
    try {
      final doc =
          await _firestore
              .collection(_dashboardCollection)
              .doc(_systemStatsDoc)
              .get();

      if (doc.exists) {
        return DashboardStats.fromFirestore(doc);
      } else {
        // Create default stats if document doesn't exist
        final defaultStats = _getDefaultDashboardStats();
        await updateDashboardStats(defaultStats);
        return defaultStats;
      }
    } catch (e) {
      Logger.error('Error fetching dashboard stats', e);
      return _getDefaultDashboardStats();
    }
  }

  /// Update dashboard statistics
  Future<void> updateDashboardStats(DashboardStats stats) async {
    try {
      final currentUser = _auth.currentUser;
      final updatedStats = stats.copyWith(
        lastUpdated: DateTime.now(),
        updatedBy: currentUser?.email ?? 'System',
      );

      await _firestore
          .collection(_dashboardCollection)
          .doc(_systemStatsDoc)
          .set(updatedStats.toFirestore(), SetOptions(merge: true));

      Logger.info('Dashboard stats updated successfully');
    } catch (e) {
      Logger.error('Error updating dashboard stats', e);
      throw Exception('Failed to update dashboard statistics');
    }
  }

  /// Get energy usage data stream
  Stream<List<EnergyUsageData>> getEnergyUsageStream({
    String period = 'daily',
    int limit = 30,
  }) {
    return _firestore
        .collection(_energyUsageCollection)
        .where('period', isEqualTo: period)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => EnergyUsageData.fromFirestore(doc.data()))
              .toList();
        });
  }

  /// Get device usage data stream
  Stream<List<DeviceUsageData>> getDeviceUsageStream({int limit = 20}) {
    return _firestore
        .collection(_deviceUsageCollection)
        .orderBy('last_seen', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => DeviceUsageData.fromFirestore(doc.data()))
              .toList();
        });
  }

  /// Get alerts stream
  Stream<List<AlertData>> getAlertsStream({
    bool unreadOnly = false,
    int limit = 50,
  }) {
    Query query = _firestore
        .collection(_alertsCollection)
        .orderBy('created_at', descending: true);

    if (unreadOnly) {
      query = query.where('is_read', isEqualTo: false);
    }

    return query.limit(limit).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => AlertData.fromFirestore(doc)).toList();
    });
  }

  /// Get user statistics stream
  Stream<UserStats> getUserStatsStream() {
    return _firestore
        .collection(_dashboardCollection)
        .doc(_userStatsDoc)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists) {
            return UserStats.fromFirestore(snapshot);
          } else {
            return _getDefaultUserStats();
          }
        });
  }

  /// Initialize dashboard with sample data (for development)
  Future<void> initializeDashboardData() async {
    try {
      Logger.info('Initializing dashboard data...');

      // Initialize system stats
      final stats = _getDefaultDashboardStats();
      await updateDashboardStats(stats);

      // Initialize user stats
      await _initializeUserStats();

      // Initialize energy usage data
      await _initializeEnergyUsageData();

      // Initialize device usage data
      await _initializeDeviceUsageData();

      // Initialize alerts
      await _initializeAlerts();

      Logger.info('Dashboard data initialized successfully');
    } catch (e) {
      Logger.error('Error initializing dashboard data', e);
      throw Exception('Failed to initialize dashboard data');
    }
  }

  /// Update energy usage data (typically called by background processes)
  Future<void> addEnergyUsageData(EnergyUsageData data) async {
    try {
      await _firestore
          .collection(_energyUsageCollection)
          .add(data.toFirestore());
    } catch (e) {
      Logger.error('Error adding energy usage data', e);
    }
  }

  /// Add new alert
  Future<void> addAlert(AlertData alert) async {
    try {
      await _firestore.collection(_alertsCollection).add(alert.toFirestore());
    } catch (e) {
      Logger.error('Error adding alert', e);
    }
  }

  /// Mark alert as read
  Future<void> markAlertAsRead(String alertId) async {
    try {
      await _firestore.collection(_alertsCollection).doc(alertId).update({
        'is_read': true,
      });
    } catch (e) {
      Logger.error('Error marking alert as read', e);
    }
  }

  /// Simulate real-time data updates (for development/demo)
  Future<void> simulateRealTimeUpdates() async {
    final random = Random();

    // Update stats every 30 seconds
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        final currentStats = await getDashboardStats();
        final updatedStats = currentStats.copyWith(
          totalEnergyToday:
              currentStats.totalEnergyToday + random.nextDouble() * 10,
          activeDevices: currentStats.activeDevices + random.nextInt(5) - 2,
          totalAlerts: currentStats.totalAlerts + (random.nextBool() ? 1 : 0),
        );

        await updateDashboardStats(updatedStats);
      } catch (e) {
        Logger.error('Error in simulated update', e);
      }
    });
  }

  // Private helper methods
  DashboardStats _getDefaultDashboardStats() {
    return DashboardStats(
      currentRate: 6.50,
      totalUsers: 1247,
      activeDevices: 3421,
      totalEnergyToday: 12543.7,
      totalEnergyWeek: 87805.2,
      totalEnergyMonth: 345678.9,
      totalAlerts: 23,
      lastUpdated: DateTime.now(),
      updatedBy: 'System',
    );
  }

  UserStats _getDefaultUserStats() {
    return UserStats(
      totalUsers: 1247,
      activeUsers: 892,
      newUsersToday: 15,
      newUsersWeek: 89,
      newUsersMonth: 234,
      lastUpdated: DateTime.now(),
    );
  }

  Future<void> _initializeUserStats() async {
    final userStats = _getDefaultUserStats();
    await _firestore
        .collection(_dashboardCollection)
        .doc(_userStatsDoc)
        .set(userStats.toFirestore());
  }

  Future<void> _initializeEnergyUsageData() async {
    final random = Random();
    final now = DateTime.now();
    final batch = _firestore.batch();

    // Generate last 30 days of data
    for (int i = 29; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final baseUsage = 1200.0;
      final usage = baseUsage + (random.nextDouble() * 800 - 400);

      final data = EnergyUsageData(
        date: date,
        usage: usage,
        cost: usage * 6.50,
        period: 'daily',
      );

      final docRef = _firestore.collection(_energyUsageCollection).doc();

      batch.set(docRef, data.toFirestore());
    }

    await batch.commit();
  }

  Future<void> _initializeDeviceUsageData() async {
    final devices = [
      {'name': 'Air Conditioner Unit 1', 'type': 'HVAC'},
      {'name': 'Refrigerator Main', 'type': 'Appliance'},
      {'name': 'Washing Machine', 'type': 'Appliance'},
      {'name': 'Water Heater', 'type': 'Utility'},
      {'name': 'LED Lighting System', 'type': 'Lighting'},
      {'name': 'Smart TV Living Room', 'type': 'Electronics'},
      {'name': 'Desktop Computer', 'type': 'Electronics'},
      {'name': 'Microwave Oven', 'type': 'Appliance'},
    ];

    final random = Random();
    final batch = _firestore.batch();

    for (final device in devices) {
      final usage = 50.0 + random.nextDouble() * 200;
      final deviceData = DeviceUsageData(
        deviceName: device['name']!,
        deviceType: device['type']!,
        usage: usage,
        cost: usage * 6.50,
        isActive: random.nextBool(),
        lastSeen: DateTime.now().subtract(
          Duration(minutes: random.nextInt(1440)),
        ),
      );

      final docRef = _firestore.collection(_deviceUsageCollection).doc();

      batch.set(docRef, deviceData.toFirestore());
    }

    await batch.commit();
  }

  Future<void> _initializeAlerts() async {
    final alerts = [
      {
        'title': 'High Energy Usage Alert',
        'message': 'Energy consumption exceeded 2000 kWh threshold',
        'type': 'warning',
        'severity': 'high',
      },
      {
        'title': 'Device Offline',
        'message': 'Air Conditioner Unit 1 has been offline for 2 hours',
        'type': 'error',
        'severity': 'medium',
      },
      {
        'title': 'Peak Hour Usage',
        'message': 'High energy consumption detected during peak hours',
        'type': 'info',
        'severity': 'low',
      },
      {
        'title': 'System Update Available',
        'message': 'New firmware update available for smart devices',
        'type': 'info',
        'severity': 'low',
      },
    ];

    final random = Random();
    final batch = _firestore.batch();

    for (int i = 0; i < alerts.length; i++) {
      final alert = alerts[i];
      final alertData = AlertData(
        id: '',
        title: alert['title']!,
        message: alert['message']!,
        type: alert['type']!,
        severity: alert['severity']!,
        isRead: random.nextBool(),
        createdAt: DateTime.now().subtract(Duration(hours: random.nextInt(72))),
      );

      final docRef = _firestore.collection(_alertsCollection).doc();

      batch.set(docRef, alertData.toFirestore());
    }

    await batch.commit();
  }

  /// Clean up resources
  void dispose() {
    // Clean up any active timers or streams if needed
  }
}
