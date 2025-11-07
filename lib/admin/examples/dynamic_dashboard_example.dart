import 'package:flutter/material.dart';
import '../utils/dashboard_setup_helper.dart';
import '../services/firestore_dashboard_service.dart';
import '../models/dashboard_data_model.dart';

/// Example demonstrating the Dynamic Firestore Dashboard
class DynamicDashboardExample extends StatelessWidget {
  const DynamicDashboardExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dynamic Dashboard Setup'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dynamic Firestore Dashboard',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'This example demonstrates how to set up and use the dynamic dashboard with real-time Firestore data.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            _buildSetupCard(context),
            const SizedBox(height: 16),
            _buildFeaturesCard(),
            const SizedBox(height: 16),
            _buildUsageCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.settings, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Setup Dashboard',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Initialize the dashboard with sample data and start real-time updates.',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _initializeDashboard(context),
                  icon: const Icon(Icons.rocket_launch),
                  label: const Text('Initialize Dashboard'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _testDashboard(context),
                  icon: const Icon(Icons.science),
                  label: const Text('Test Dashboard'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.star, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Features',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildFeatureItem('Real-time data streaming from Firestore'),
            _buildFeatureItem('Professional UI with animations'),
            _buildFeatureItem('Responsive design for all screen sizes'),
            _buildFeatureItem('Pull-to-refresh functionality'),
            _buildFeatureItem('Error handling and offline support'),
            _buildFeatureItem('Dynamic alerts and notifications'),
            _buildFeatureItem('Interactive charts and graphs'),
            _buildFeatureItem('Device usage monitoring'),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(feature)),
        ],
      ),
    );
  }

  Widget _buildUsageCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.code, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Usage Example',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('''
// 1. Initialize the dashboard
await DashboardSetupHelper.completeSetup();

// 2. Use in your app
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MainAdminScreen(), // Uses DynamicDashboardScreen
    );
  }
}

// 3. The dashboard automatically:
// - Connects to Firestore
// - Streams real-time data
// - Updates UI automatically
// - Handles errors gracefully
''', style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initializeDashboard(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Initializing dashboard...'),
                ],
              ),
            ),
      );

      // Initialize dashboard
      await DashboardSetupHelper.completeSetup();

      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dashboard initialized successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _testDashboard(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Testing dashboard...'),
                ],
              ),
            ),
      );

      // Test dashboard
      await DashboardSetupHelper.testDashboard();

      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();

      // Show test results
      if (context.mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Dashboard Test Results'),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Dashboard stats loaded'),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Energy usage data loaded'),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Device usage data loaded'),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Alerts data loaded'),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'All dashboard components are working correctly!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Example of how to manually interact with the dashboard service
class DashboardServiceExample {
  static final FirestoreDashboardService _service = FirestoreDashboardService();

  /// Example: Add a custom alert
  static Future<void> addCustomAlert() async {
    final alert = AlertData(
      id: '',
      title: 'Custom Alert',
      message: 'This is a custom alert added programmatically',
      type: 'info',
      severity: 'medium',
      isRead: false,
      createdAt: DateTime.now(),
      metadata: {'source': 'manual', 'category': 'test'},
    );

    await _service.addAlert(alert);
    print('Custom alert added successfully');
  }

  /// Example: Update dashboard stats
  static Future<void> updateCustomStats() async {
    final currentStats = await _service.getDashboardStats();
    final updatedStats = currentStats.copyWith(
      totalUsers: currentStats.totalUsers + 10,
      activeDevices: currentStats.activeDevices + 5,
      totalEnergyToday: currentStats.totalEnergyToday + 100.0,
    );

    await _service.updateDashboardStats(updatedStats);
    print('Dashboard stats updated successfully');
  }

  /// Example: Listen to real-time data
  static void listenToRealTimeData() {
    // Listen to dashboard stats
    _service.getDashboardStatsStream().listen((stats) {
      print(
        'Dashboard stats updated: ${stats.totalUsers} users, ${stats.activeDevices} devices',
      );
    });

    // Listen to alerts
    _service.getAlertsStream(unreadOnly: true).listen((alerts) {
      print('Unread alerts: ${alerts.length}');
      for (final alert in alerts) {
        print('- ${alert.title}: ${alert.message}');
      }
    });

    // Listen to energy usage
    _service.getEnergyUsageStream(limit: 5).listen((energyData) {
      print('Latest energy usage: ${energyData.length} records');
      if (energyData.isNotEmpty) {
        final latest = energyData.first;
        print(
          '- Latest: ${latest.usage.toStringAsFixed(1)} kWh on ${latest.date}',
        );
      }
    });
  }
}
