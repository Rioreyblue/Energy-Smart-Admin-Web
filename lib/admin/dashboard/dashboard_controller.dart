import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/dashboard_data_model.dart';
import '../services/firestore_dashboard_service.dart';
import '../../utils/logger.dart';

class DashboardController extends ChangeNotifier {
  final FirestoreDashboardService _firestoreService =
      FirestoreDashboardService();

  // State variables
  DashboardStats? _dashboardStats;
  List<EnergyUsageData> _energyUsageData = [];
  List<DeviceUsageData> _deviceUsageData = [];
  List<AlertData> _alerts = [];
  UserStats? _userStats;

  bool _isLoading = true;
  String? _error;
  DateTime? _lastRefresh;

  // Stream subscriptions
  StreamSubscription<DashboardStats>? _statsSubscription;
  StreamSubscription<List<EnergyUsageData>>? _energySubscription;
  StreamSubscription<List<DeviceUsageData>>? _deviceSubscription;
  StreamSubscription<List<AlertData>>? _alertsSubscription;
  StreamSubscription<UserStats>? _userStatsSubscription;

  // Getters
  DashboardStats? get dashboardStats => _dashboardStats;
  List<EnergyUsageData> get energyUsageData => _energyUsageData;
  List<DeviceUsageData> get deviceUsageData => _deviceUsageData;
  List<AlertData> get alerts => _alerts;
  UserStats? get userStats => _userStats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastRefresh => _lastRefresh;

  // Computed properties
  int get unreadAlertsCount => _alerts.where((alert) => !alert.isRead).length;

  List<AlertData> get criticalAlerts =>
      _alerts
          .where((alert) => alert.severity == 'critical' && !alert.isRead)
          .toList();

  double get todayEnergyUsage => _dashboardStats?.totalEnergyToday ?? 0.0;

  double get monthlyEnergyUsage => _dashboardStats?.totalEnergyMonth ?? 0.0;

  String get energyTrend {
    if (_energyUsageData.length < 2) return '0%';

    final today = _energyUsageData.first.usage;
    final yesterday = _energyUsageData[1].usage;
    final change = ((today - yesterday) / yesterday * 100);

    return '${change.toStringAsFixed(1)}%';
  }

  bool get energyTrendIsPositive {
    if (_energyUsageData.length < 2) return false;
    return _energyUsageData.first.usage > _energyUsageData[1].usage;
  }

  /// Initialize the dashboard controller
  Future<void> initialize() async {
    try {
      _setLoading(true);
      _clearError();

      // Initialize Firestore data if needed
      await _firestoreService.initializeDashboardData();

      // Start listening to real-time streams
      _startListening();

      _lastRefresh = DateTime.now();
    } catch (e) {
      _setError('Failed to initialize dashboard: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Start listening to real-time data streams
  void _startListening() {
    // Listen to dashboard stats
    _statsSubscription = _firestoreService.getDashboardStatsStream().listen(
      (stats) {
        _dashboardStats = stats;
        _lastRefresh = DateTime.now();
        notifyListeners();
      },
      onError: (error) {
        _setError('Error loading dashboard stats: $error');
      },
    );

    // Listen to energy usage data
    _energySubscription = _firestoreService
        .getEnergyUsageStream(period: 'daily', limit: 30)
        .listen(
          (data) {
            _energyUsageData = data;
            notifyListeners();
          },
          onError: (error) {
            Logger.error('Error loading energy usage data', error);
          },
        );

    // Listen to device usage data
    _deviceSubscription = _firestoreService
        .getDeviceUsageStream(limit: 20)
        .listen(
          (data) {
            _deviceUsageData = data;
            notifyListeners();
          },
          onError: (error) {
            Logger.error('Error loading device usage data', error);
          },
        );

    // Listen to alerts
    _alertsSubscription = _firestoreService
        .getAlertsStream(limit: 50)
        .listen(
          (data) {
            _alerts = data;
            notifyListeners();
          },
          onError: (error) {
            Logger.error('Error loading alerts', error);
          },
        );

    // Listen to user stats
    _userStatsSubscription = _firestoreService.getUserStatsStream().listen(
      (stats) {
        _userStats = stats;
        notifyListeners();
      },
      onError: (error) {
        Logger.error('Error loading user stats', error);
      },
    );
  }

  /// Refresh all data manually
  Future<void> refresh() async {
    try {
      _setLoading(true);
      _clearError();

      // Stop current subscriptions
      await _stopListening();

      // Restart listening
      _startListening();

      _lastRefresh = DateTime.now();
    } catch (e) {
      _setError('Failed to refresh dashboard: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Update dashboard statistics
  Future<void> updateDashboardStats(DashboardStats stats) async {
    try {
      await _firestoreService.updateDashboardStats(stats);
      // The stream will automatically update the UI
    } catch (e) {
      _setError('Failed to update dashboard stats: $e');
    }
  }

  /// Add new alert
  Future<void> addAlert({
    required String title,
    required String message,
    required String type,
    required String severity,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final alert = AlertData(
        id: '',
        title: title,
        message: message,
        type: type,
        severity: severity,
        isRead: false,
        createdAt: DateTime.now(),
        metadata: metadata,
      );

      await _firestoreService.addAlert(alert);
    } catch (e) {
      _setError('Failed to add alert: $e');
    }
  }

  /// Mark alert as read
  Future<void> markAlertAsRead(String alertId) async {
    try {
      await _firestoreService.markAlertAsRead(alertId);
    } catch (e) {
      _setError('Failed to mark alert as read: $e');
    }
  }

  /// Get energy usage data for specific period
  Future<List<EnergyUsageData>> getEnergyUsageForPeriod(String period) async {
    try {
      final stream = _firestoreService.getEnergyUsageStream(
        period: period,
        limit: 30,
      );
      return await stream.first;
    } catch (e) {
      _setError('Failed to load energy usage data: $e');
      return [];
    }
  }

  /// Start real-time simulation (for demo purposes)
  void startSimulation() {
    _firestoreService.simulateRealTimeUpdates();
  }

  /// Get formatted energy trend
  String getFormattedEnergyTrend() {
    final trend = energyTrend;
    final isPositive = energyTrendIsPositive;
    return '${isPositive ? '+' : ''}$trend';
  }

  /// Get device statistics
  Map<String, int> getDeviceTypeStats() {
    final stats = <String, int>{};
    for (final device in _deviceUsageData) {
      stats[device.deviceType] = (stats[device.deviceType] ?? 0) + 1;
    }
    return stats;
  }

  /// Get active devices count
  int get activeDevicesCount =>
      _deviceUsageData.where((device) => device.isActive).length;

  /// Get total energy cost for today
  double get todayEnergyCost =>
      (_dashboardStats?.totalEnergyToday ?? 0.0) *
      (_dashboardStats?.currentRate ?? 6.50);

  /// Get alerts by severity
  List<AlertData> getAlertsBySeverity(String severity) =>
      _alerts.where((alert) => alert.severity == severity).toList();

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    Logger.error('Dashboard Controller Error', error);
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _stopListening() async {
    await _statsSubscription?.cancel();
    await _energySubscription?.cancel();
    await _deviceSubscription?.cancel();
    await _alertsSubscription?.cancel();
    await _userStatsSubscription?.cancel();
  }

  @override
  void dispose() {
    _stopListening();
    _firestoreService.dispose();
    super.dispose();
  }
}
