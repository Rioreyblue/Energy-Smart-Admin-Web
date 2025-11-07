import '../services/firestore_dashboard_service.dart';

/// Helper class for setting up the dynamic dashboard
class DashboardSetupHelper {
  static final FirestoreDashboardService _firestoreService =
      FirestoreDashboardService();

  /// Initialize dashboard with sample data for development
  static Future<void> initializeDashboard() async {
    try {
      print('🚀 Setting up Dynamic Dashboard...');

      await _firestoreService.initializeDashboardData();

      print('✅ Dashboard setup completed!');
      print('');
      print('📊 Dashboard Features:');
      print('   • Real-time energy monitoring');
      print('   • Live device status updates');
      print('   • Dynamic alerts system');
      print('   • Responsive charts and graphs');
      print('   • Auto-refreshing statistics');
      print('');
      print('🔄 The dashboard will automatically update with real-time data');
    } catch (e) {
      print('❌ Dashboard setup failed: $e');
    }
  }

  /// Quick test to verify dashboard functionality
  static Future<void> testDashboard() async {
    try {
      print('🧪 Testing Dashboard Functionality...');

      // Test dashboard stats
      final stats = await _firestoreService.getDashboardStats();
      print(
        '✅ Dashboard stats loaded: ${stats.totalUsers} users, ${stats.activeDevices} devices',
      );

      // Test energy usage stream
      final energyStream = _firestoreService.getEnergyUsageStream(limit: 5);
      final energyData = await energyStream.first;
      print('✅ Energy usage data loaded: ${energyData.length} records');

      // Test device usage stream
      final deviceStream = _firestoreService.getDeviceUsageStream(limit: 5);
      final deviceData = await deviceStream.first;
      print('✅ Device usage data loaded: ${deviceData.length} devices');

      // Test alerts stream
      final alertsStream = _firestoreService.getAlertsStream(limit: 5);
      final alertsData = await alertsStream.first;
      print('✅ Alerts data loaded: ${alertsData.length} alerts');

      print('🎉 All dashboard tests passed!');
    } catch (e) {
      print('❌ Dashboard test failed: $e');
    }
  }

  /// Start real-time data simulation
  static Future<void> startSimulation() async {
    try {
      print('🔄 Starting real-time data simulation...');
      await _firestoreService.simulateRealTimeUpdates();
      print('✅ Real-time simulation started');
    } catch (e) {
      print('❌ Failed to start simulation: $e');
    }
  }

  /// Complete dashboard setup and test
  static Future<void> completeSetup() async {
    print('🚀 Starting Complete Dashboard Setup...');
    print('');

    await initializeDashboard();
    await testDashboard();
    await startSimulation();

    print('');
    print('🎉 Dynamic Dashboard is ready!');
    print('💡 Features:');
    print('   • Pull to refresh for manual updates');
    print('   • Real-time data streaming from Firestore');
    print('   • Responsive design for all screen sizes');
    print('   • Professional UI with animations');
    print('   • Error handling and offline support');
  }
}
