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
          'powerRate': (data['powerRate'] as num?)?.toDouble(),
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
      double oldPowerRate = oldValue ?? 0.0;
      if (oldValue == null) {
        try {
          final doc =
              await _firestore
                  .collection(_settingsCollection)
                  .doc(_settingsDocument)
                  .get();
          if (doc.exists && doc.data() != null) {
            oldPowerRate =
                (doc.data()!['powerRate'] as num?)?.toDouble() ?? 0.0;
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
    final historyCollection = _firestore.collection(
      '${_settingsCollection}_history',
    );
    final entries = <Map<String, dynamic>>[];
    final seenIds = <String>{};

    Map<String, dynamic>? parseHistoryEntry(
      String id,
      Map<String, dynamic>? data,
    ) {
      if (data == null) return null;
      final dynamic timestampValue = data['timestamp'];
      DateTime? timestamp;
      if (timestampValue is Timestamp) {
        timestamp = timestampValue.toDate();
      } else if (timestampValue is DateTime) {
        timestamp = timestampValue;
      } else if (timestampValue is int) {
        timestamp = DateTime.fromMillisecondsSinceEpoch(timestampValue);
      } else if (timestampValue is String) {
        timestamp = DateTime.tryParse(timestampValue);
      }

      return {
        'id': id,
        'settingType': data['settingType'] ?? 'powerRate',
        'value': (data['value'] as num?)?.toDouble() ?? 0.0,
        'oldValue': (data['oldValue'] as num?)?.toDouble(),
        'timestamp': timestamp,
        'updatedBy': data['updatedBy'] ?? 'Unknown',
        'updatedById': data['updatedById'],
        'reason': data['reason'] ?? 'No reason provided',
      };
    }

    // Primary query: top-level documents
    try {
      final snapshot =
          await historyCollection.orderBy('timestamp', descending: true).get();
      for (final doc in snapshot.docs) {
        final parsed = parseHistoryEntry(doc.id, doc.data());
        if (parsed == null) continue;
        if (parsed['settingType'] != 'powerRate') continue;
        if (seenIds.add(parsed['id'] as String)) {
          entries.add(parsed);
        }
      }
    } catch (e) {
      Logger.debug(
        'Primary power rate history query failed, trying fallback: $e',
      );
    }

    // Fallback: specific document or nested subcollection
    if (entries.isEmpty) {
      try {
        final fallbackDoc =
            await historyCollection.doc('admin_settings_historyId').get();

        if (fallbackDoc.exists) {
          final parsed = parseHistoryEntry(fallbackDoc.id, fallbackDoc.data());
          if (parsed != null &&
              parsed['settingType'] == 'powerRate' &&
              seenIds.add(parsed['id'] as String)) {
            entries.add(parsed);
          }

          try {
            final subSnapshot =
                await historyCollection
                    .doc('admin_settings_historyId')
                    .collection('history')
                    .orderBy('timestamp', descending: true)
                    .get();
            for (final doc in subSnapshot.docs) {
              final parsed = parseHistoryEntry(doc.id, doc.data());
              if (parsed == null) continue;
              if (parsed['settingType'] != 'powerRate') continue;
              if (seenIds.add(parsed['id'] as String)) {
                entries.add(parsed);
              }
            }
          } catch (e) {
            Logger.debug(
              'No nested history subcollection found for fallback: $e',
            );
          }
        }
      } catch (e) {
        Logger.error('Error fetching fallback power rate history', e);
      }
    }

    entries.sort((a, b) {
      final aTime =
          (a['timestamp'] as DateTime?) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bTime =
          (b['timestamp'] as DateTime?) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return entries;
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
      'powerRate': null,
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
