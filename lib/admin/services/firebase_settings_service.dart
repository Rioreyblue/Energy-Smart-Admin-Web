import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/logger.dart';

class FirebaseSettingsService {
  static final FirebaseSettingsService _instance =
      FirebaseSettingsService._internal();
  factory FirebaseSettingsService() => _instance;
  FirebaseSettingsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  static const String _settingsCollection = 'admin_settings';
  static const String _settingsDocument = 'system_config';

  /// Get system settings from Firebase
  Future<Map<String, dynamic>> getSystemSettings() async {
    try {
      final doc =
          await _firestore
              .collection(_settingsCollection)
              .doc(_settingsDocument)
              .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return {
          'powerRate': data['powerRate'] ?? 6.50,
          'targetThreshold': data['targetThreshold'] ?? 85.0,
          'notificationEnabled': data['notificationEnabled'] ?? true,
          'autoReports': data['autoReports'] ?? true,
          'reportFrequency': data['reportFrequency'] ?? 'Weekly',
          'appVersion': data['appVersion'] ?? '1.0.0',
          'lastUpdated':
              (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'updatedBy': data['updatedBy'] ?? 'System',
        };
      } else {
        // Return default settings if document doesn't exist
        return _getDefaultSettings();
      }
    } catch (e) {
      Logger.error('Error getting system settings', e);
      return _getDefaultSettings();
    }
  }

  /// Update system settings in Firebase
  Future<bool> updateSystemSettings(Map<String, dynamic> settings) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        Logger.warning('No authenticated user found');
        return false;
      }

      // Add metadata
      final updatedSettings = {
        ...settings,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedBy': currentUser.email ?? 'Unknown',
        'updatedById': currentUser.uid,
      };

      await _firestore
          .collection(_settingsCollection)
          .doc(_settingsDocument)
          .set(updatedSettings, SetOptions(merge: true));

      Logger.info('System settings updated successfully');
      return true;
    } catch (e) {
      Logger.error('Error updating system settings', e);
      return false;
    }
  }

  /// Update only power rate
  Future<bool> updatePowerRate(
    double powerRate, {
    double? oldValue,
    String reason = 'No reason provided',
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        Logger.warning('No authenticated user found');
        return false;
      }

      // Get old value if not provided
      double oldPowerRate = oldValue ?? 6.50;
      if (oldValue == null) {
        try {
          final doc =
              await _firestore
                  .collection(_settingsCollection)
                  .doc(_settingsDocument)
                  .get();
          if (doc.exists && doc.data() != null) {
            oldPowerRate =
                (doc.data()!['powerRate'] as num?)?.toDouble() ?? 6.50;
          }
        } catch (e) {
          Logger.error('Error getting old power rate', e);
        }
      }

      // Only save history if value actually changed
      if (oldPowerRate != powerRate) {
        await savePowerRateHistory(oldPowerRate, powerRate, reason);
      }

      await _firestore
          .collection(_settingsCollection)
          .doc(_settingsDocument)
          .set({
            'powerRate': powerRate,
            'lastUpdated': FieldValue.serverTimestamp(),
            'updatedBy': currentUser.email ?? 'Unknown',
            'updatedById': currentUser.uid,
          }, SetOptions(merge: true));

      Logger.info('Power rate updated successfully: $powerRate');
      return true;
    } catch (e) {
      Logger.error('Error updating power rate', e);
      return false;
    }
  }

  /// Get power rate history
  Future<List<Map<String, dynamic>>> getPowerRateHistory() async {
    try {
      final snapshot =
          await _firestore
              .collection('${_settingsCollection}_history')
              .where('settingType', isEqualTo: 'powerRate')
              .orderBy('timestamp', descending: true)
              .limit(10)
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'value': data['value'],
          'timestamp': (data['timestamp'] as Timestamp).toDate(),
          'updatedBy': data['updatedBy'],
          'reason': data['reason'] ?? 'No reason provided',
        };
      }).toList();
    } catch (e) {
      Logger.error('Error getting power rate history', e);
      return [];
    }
  }

  /// Save power rate change to history
  Future<void> savePowerRateHistory(
    double oldValue,
    double newValue,
    String reason,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _firestore.collection('${_settingsCollection}_history').add({
        'settingType': 'powerRate',
        'oldValue': oldValue,
        'value': newValue,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'updatedBy': currentUser.email ?? 'Unknown',
        'updatedById': currentUser.uid,
      });
    } catch (e) {
      Logger.error('Error saving power rate history', e);
    }
  }

  /// Get default settings
  Map<String, dynamic> _getDefaultSettings() {
    return {
      'powerRate': 6.50,
      'targetThreshold': 85.0,
      'notificationEnabled': true,
      'autoReports': true,
      'reportFrequency': 'Weekly',
      'appVersion': '1.0.0',
      'lastUpdated': DateTime.now(),
      'updatedBy': 'System',
    };
  }

  /// Initialize default settings if they don't exist
  Future<void> initializeDefaultSettings() async {
    try {
      final doc =
          await _firestore
              .collection(_settingsCollection)
              .doc(_settingsDocument)
              .get();

      if (!doc.exists) {
        await _firestore
            .collection(_settingsCollection)
            .doc(_settingsDocument)
            .set(_getDefaultSettings());
        Logger.info('Default settings initialized');
      }
    } catch (e) {
      Logger.error('Error initializing default settings', e);
    }
  }

  /// Stream system settings for real-time updates
  Stream<Map<String, dynamic>> getSystemSettingsStream() {
    return _firestore
        .collection(_settingsCollection)
        .doc(_settingsDocument)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            final data = snapshot.data()!;
            return {
              'powerRate': data['powerRate'] ?? 6.50,
              'targetThreshold': data['targetThreshold'] ?? 85.0,
              'notificationEnabled': data['notificationEnabled'] ?? true,
              'autoReports': data['autoReports'] ?? true,
              'reportFrequency': data['reportFrequency'] ?? 'Weekly',
              'appVersion': data['appVersion'] ?? '1.0.0',
              'lastUpdated':
                  (data['lastUpdated'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
              'updatedBy': data['updatedBy'] ?? 'System',
            };
          } else {
            return _getDefaultSettings();
          }
        });
  }
}
