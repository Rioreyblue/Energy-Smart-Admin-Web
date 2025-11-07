import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'onesignal_service.dart';
import '../../utils/logger.dart';

class AdminNotificationService {
  static final AdminNotificationService _instance =
      AdminNotificationService._internal();
  factory AdminNotificationService() => _instance;
  AdminNotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OneSignalService _oneSignalService = OneSignalService();

  /// Get current admin ID
  String? get _currentAdminId => _auth.currentUser?.uid;

  /// Stream of notifications for current admin
  Stream<List<Map<String, dynamic>>> getNotificationsStream() {
    if (_currentAdminId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('notifications')
        .where('adminId', isEqualTo: _currentAdminId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {'id': doc.id, ...data};
          }).toList();
        });
  }

  /// Get unread notifications count
  Stream<int> getUnreadCountStream() {
    if (_currentAdminId == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('notifications')
        .where('adminId', isEqualTo: _currentAdminId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Create a notification for a specific admin
  Future<void> createNotification({
    required String adminId,
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'adminId': adminId,
        'type': type,
        'title': title,
        'message': message,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'data': data ?? {},
      });
    } catch (e) {
      Logger.error('Error creating notification', e);
    }
  }

  /// Create notifications for all admins
  Future<void> createNotificationForAllAdmins({
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get all admin IDs
      final adminsSnapshot = await _firestore.collection('admins').get();
      final adminIds = adminsSnapshot.docs.map((doc) => doc.id).toList();

      // Create notification for each admin
      final batch = _firestore.batch();
      for (final adminId in adminIds) {
        final notificationRef = _firestore.collection('notifications').doc();
        batch.set(notificationRef, {
          'adminId': adminId,
          'type': type,
          'title': title,
          'message': message,
          'read': false,
          'timestamp': FieldValue.serverTimestamp(),
          'data': data ?? {},
        });
      }
      await batch.commit();

      // Send OneSignal push notifications to all admins
      await _sendPushNotificationToAllAdmins(title, message, data);
    } catch (e) {
      Logger.error('Error creating notifications for all admins', e);
    }
  }

  /// Send OneSignal push notification to all admins
  Future<void> _sendPushNotificationToAllAdmins(
    String title,
    String message,
    Map<String, dynamic>? data,
  ) async {
    try {
      // Get all admin OneSignal player IDs
      final adminsSnapshot = await _firestore.collection('admins').get();
      final playerIds = <String>[];

      for (final adminDoc in adminsSnapshot.docs) {
        final adminId = adminDoc.id;
        // Try to get player ID from admin document first
        final adminData = adminDoc.data();
        final playerId = adminData['oneSignalPlayerId'] as String?;

        // If not found in admin doc, try using service method (checks Firestore users and Realtime DB)
        final finalPlayerId =
            playerId ?? await _oneSignalService.getPlayerIdForUser(adminId);

        if (finalPlayerId != null) {
          playerIds.add(finalPlayerId);
        }
      }

      if (playerIds.isNotEmpty) {
        await _oneSignalService.sendNotificationToUsers(
          playerIds: playerIds,
          title: title,
          body: message,
          data: data,
        );
      }
    } catch (e) {
      Logger.error('Error sending push notifications to admins', e);
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
      });
    } catch (e) {
      Logger.error('Error marking notification as read', e);
    }
  }

  /// Mark all notifications as read for current admin
  Future<void> markAllAsRead() async {
    if (_currentAdminId == null) return;

    try {
      final notificationsSnapshot =
          await _firestore
              .collection('notifications')
              .where('adminId', isEqualTo: _currentAdminId)
              .where('read', isEqualTo: false)
              .get();

      final batch = _firestore.batch();
      for (final doc in notificationsSnapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      Logger.error('Error marking all notifications as read', e);
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      Logger.error('Error deleting notification', e);
    }
  }
}
