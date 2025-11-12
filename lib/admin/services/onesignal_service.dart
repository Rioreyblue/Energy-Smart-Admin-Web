import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../constants/onesignal_config.dart';
import '../../utils/logger.dart';

class OneSignalService {
  static final OneSignalService _instance = OneSignalService._internal();
  factory OneSignalService() => _instance;
  OneSignalService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  String? _playerId;

  /// Initialize OneSignal SDK
  Future<void> initialize() async {
    if (kIsWeb) {
      Logger.info(
        'OneSignal web initialization handled via web/index.html script.',
      );
      return;
    }

    try {
      // Set App ID
      OneSignal.initialize(OneSignalConfig.appId);

      // Request permission for notifications
      OneSignal.Notifications.requestPermission(true);

      // Get player ID
      final deviceState = await OneSignal.User.pushSubscription.id;
      if (deviceState != null) {
        _playerId = deviceState;
        Logger.debug('OneSignal Player ID: $_playerId');

        // Store player ID in user profile
        await _storePlayerId(_playerId!);
      }

      // Listen for player ID changes
      OneSignal.User.pushSubscription.addObserver((state) {
        if (state.current.id != null) {
          _playerId = state.current.id;
          _storePlayerId(_playerId!);
        }
      });

      // Handle notification opened
      OneSignal.Notifications.addClickListener((event) {
        Logger.info('Notification opened: ${event.notification.body}');
        // Handle notification click - could navigate to chat
      });

      Logger.info('OneSignal initialized successfully');
    } catch (e) {
      Logger.error('OneSignal initialization error', e);
    }
  }

  /// Store OneSignal player ID in user profile
  Future<void> _storePlayerId(String playerId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Store in Firestore
      await _firestore.collection('users').doc(user.uid).set({
        'oneSignalPlayerId': playerId,
      }, SetOptions(merge: true));

      final playerDocRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('onesignalPlayers')
          .doc(playerId);

      final existingPlayerDoc = await playerDocRef.get();

      await playerDocRef.set({
        'playerId': playerId,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!existingPlayerDoc.exists)
          'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      Logger.debug(
        'OneSignal Player ID stored in subcollection: user=${user.uid}, playerId=$playerId',
      );

      // Also store in Realtime DB
      await _database.ref('users/${user.uid}/oneSignalPlayerId').set(playerId);

      Logger.debug('OneSignal Player ID stored: $playerId');
    } catch (e) {
      Logger.error('Error storing OneSignal Player ID', e);
    }
  }

  /// Get current player ID
  String? get playerId => _playerId;

  /// Get OneSignal player ID for a user
  Future<String?> getPlayerIdForUser(String userId) async {
    try {
      final playersCollection = _firestore
          .collection('users')
          .doc(userId)
          .collection('onesignalPlayers');

      try {
        final snapshot =
            await playersCollection
                .orderBy('updatedAt', descending: true)
                .limit(1)
                .get();

        if (snapshot.docs.isNotEmpty) {
          final data = snapshot.docs.first.data();
          final playerId =
              (data['playerId'] ?? snapshot.docs.first.id)?.toString();
          if (playerId != null && playerId.isNotEmpty) {
            Logger.debug(
              'Fetched OneSignal player ID from subcollection for user $userId: $playerId',
            );
            return playerId;
          }
        }
      } catch (e) {
        Logger.warning(
          'Primary OneSignal players query failed for user $userId: $e. Falling back to full collection scan.',
        );
        final fallbackSnapshot = await playersCollection.limit(1).get();
        if (fallbackSnapshot.docs.isNotEmpty) {
          final data = fallbackSnapshot.docs.first.data();
          final playerId =
              (data['playerId'] ?? fallbackSnapshot.docs.first.id)?.toString();
          if (playerId != null && playerId.isNotEmpty) {
            Logger.debug(
              'Fetched OneSignal player ID via fallback for user $userId: $playerId',
            );
            return playerId;
          }
        }
      }

      // Try Firestore first
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final playerId = userDoc.data()?['oneSignalPlayerId'] as String?;
        if (playerId != null) return playerId;
      }

      // Try Realtime DB
      final snapshot =
          await _database.ref('users/$userId/oneSignalPlayerId').get();
      if (snapshot.exists) {
        return snapshot.value as String?;
      }

      return null;
    } catch (e) {
      Logger.error('Error getting player ID for user $userId', e);
      return null;
    }
  }

  /// Send push notification to specific user
  Future<bool> sendNotificationToUser({
    required String playerId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // OneSignal REST API uses Basic auth with empty username and REST API key as password
      final credentials = base64Encode(
        utf8.encode('${OneSignalConfig.restApiKey}:'),
      );
      final iconUrl = OneSignalConfig.notificationIconUrl;
      final response = await http.post(
        Uri.parse(OneSignalConfig.apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $credentials',
        },
        body: jsonEncode({
          'app_id': OneSignalConfig.appId,
          'include_player_ids': [playerId],
          'headings': {'en': title},
          'contents': {'en': body},
          'data': data ?? {},
          'android_small_icon': OneSignalConfig.androidSmallIcon,
          if (iconUrl != null) 'large_icon': iconUrl,
          if (iconUrl != null) 'big_picture': iconUrl,
        }),
      );

      if (response.statusCode == 200) {
        Logger.info('Notification sent successfully');
        return true;
      } else {
        Logger.error('Failed to send notification: ${response.statusCode}');
        Logger.debug('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      Logger.error('Error sending notification', e);
      return false;
    }
  }

  /// Send push notification to multiple users
  Future<bool> sendNotificationToUsers({
    required List<String> playerIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (playerIds.isEmpty) return false;

    try {
      // OneSignal REST API uses Basic auth with empty username and REST API key as password
      final credentials = base64Encode(
        utf8.encode('${OneSignalConfig.restApiKey}:'),
      );
      final iconUrl = OneSignalConfig.notificationIconUrl;
      final response = await http.post(
        Uri.parse(OneSignalConfig.apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $credentials',
        },
        body: jsonEncode({
          'app_id': OneSignalConfig.appId,
          'include_player_ids': playerIds,
          'headings': {'en': title},
          'contents': {'en': body},
          'data': data ?? {},
          'android_small_icon': OneSignalConfig.androidSmallIcon,
          if (iconUrl != null) 'large_icon': iconUrl,
          if (iconUrl != null) 'big_picture': iconUrl,
        }),
      );

      if (response.statusCode == 200) {
        Logger.info('Notification sent to ${playerIds.length} users');
        return true;
      } else {
        Logger.error('Failed to send notification: ${response.statusCode}');
        Logger.debug('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      Logger.error('Error sending notification', e);
      return false;
    }
  }
}
