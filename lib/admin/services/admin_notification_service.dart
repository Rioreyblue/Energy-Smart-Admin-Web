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

  Future<Map<String, dynamic>> _fetchUserProfile(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final profileDoc = await userRef.collection('profile').doc('main').get();
      final userDoc = await userRef.get();

      final profileData = profileDoc.data() ?? {};
      final userData = userDoc.data() ?? {};

      final sections = profileData['sections'] as Map<String, dynamic>? ?? {};

      String? lookupSectionValue(String key) {
        final section = sections[key] as Map<String, dynamic>? ?? {};
        final value = section['value'];
        return value is String ? value : null;
      }

      String combineName(Map<String, dynamic> data) {
        final firstName = data['firstName']?.toString() ?? '';
        final middleName = data['middleName']?.toString() ?? '';
        final lastName = data['lastName']?.toString() ?? '';
        final parts =
            [
              firstName,
              middleName,
              lastName,
            ].where((part) => part.trim().isNotEmpty).toList();
        return parts.isNotEmpty ? parts.join(' ').trim() : '';
      }

      String? normalize(String? value) =>
          (value != null && value.trim().isNotEmpty) ? value.trim() : null;

      final sectionName = normalize(lookupSectionValue('name'));
      final profileName = normalize(profileData['name'] as String?);
      final combinedName = normalize(combineName(userData));
      final fallbackName = normalize(
        (userData['email'] as String?)?.split('@').first,
      );

      final name =
          sectionName ?? profileName ?? combinedName ?? fallbackName ?? '';

      final email =
          normalize(lookupSectionValue('email')) ??
          normalize(profileData['email'] as String?) ??
          normalize(userData['email'] as String?) ??
          '';

      final userType =
          normalize(lookupSectionValue('type')) ??
          normalize(profileData['type'] as String?) ??
          normalize(userData['type'] as String?) ??
          normalize(userData['role'] as String?) ??
          '';

      return {'name': name, 'email': email, 'type': userType};
    } catch (e, stackTrace) {
      Logger.error('Error fetching user profile for $userId', e, stackTrace);
      return {};
    }
  }

  Future<String> _buildNewUserMessage(String? name, String? userType) async {
    final displayName =
        (name?.trim().isNotEmpty ?? false) ? name!.trim() : 'A user';
    final displayType =
        (userType?.trim().isNotEmpty ?? false)
            ? userType!.trim()
            : 'EnergySmart';
    return '$displayName has joined $displayType';
  }

  /// Create notifications for all admins
  Future<void> createNotificationForAllAdmins({
    required String type,
    required String title,
    required String userId,
    required String userEmail,
    String? userName,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final profile = await _fetchUserProfile(userId);
      final resolvedName =
          (profile['name'] as String?)?.trim().isNotEmpty ?? false
              ? (profile['name'] as String).trim()
              : (userName?.trim().isNotEmpty ?? false)
              ? userName!.trim()
              : userEmail;
      final resolvedEmail =
          (profile['email'] as String?)?.trim().isNotEmpty ?? false
              ? (profile['email'] as String).trim()
              : userEmail;
      final resolvedType = profile['type'] as String?;

      final message = await _buildNewUserMessage(resolvedName, resolvedType);
      final data = {
        'userId': userId,
        'userEmail': resolvedEmail,
        'userName': resolvedName,
        'userType': resolvedType,
        'type': type,
        ...?extraData,
      };

      final adminsSnapshot = await _firestore.collection('admins').get();
      final batch = _firestore.batch();
      for (final adminDoc in adminsSnapshot.docs) {
        final notificationRef = _firestore.collection('notifications').doc();
        batch.set(notificationRef, {
          'adminId': adminDoc.id,
          'type': type,
          'title': title,
          'message': message,
          'read': false,
          'timestamp': FieldValue.serverTimestamp(),
          'data': data,
        });
      }
      await batch.commit();

      await _sendPushNotificationToAllAdmins(title, message, data);
    } catch (e, stackTrace) {
      Logger.error(
        'Error creating notifications for all admins',
        e,
        stackTrace,
      );
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
