import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_message_model.dart';
import '../../utils/logger.dart';

class ChatService {
  ChatService._internal();
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final StreamController<List<ChatConversation>> _conversationsController =
      StreamController<List<ChatConversation>>.broadcast();
  final StreamController<ChatConversation?> _activeConversationController =
      StreamController<ChatConversation?>.broadcast();

  Stream<List<ChatConversation>> get conversationsStream =>
      _conversationsController.stream;
  Stream<ChatConversation?> get activeConversationStream =>
      _activeConversationController.stream;

  final Map<String, ChatConversation> _conversationCache = {};
  final Map<String, List<ChatMessage>> _messagesCache = {};
  final Map<String, _UserProfile> _userCache = {};
  final Map<String, _UserProfile> _adminCache = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _conversationsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _messagesSubscription;

  ChatConversation? _activeConversation;
  String? _activeConversationId;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    final adminId = _requireAdminId();
    await _listenToConversations(adminId);
    _initialized = true;
  }

  Future<void> refresh() async {
    final adminId = _requireAdminId();
    await _listenToConversations(adminId, forceRefresh: true);
  }

  ChatConversation? getConversationById(String id) => _conversationCache[id];

  Future<void> setActiveConversation(String conversationId) async {
    final adminId = _requireAdminId();
    _activeConversationId = conversationId;
    await _listenToMessages(conversationId, adminId);

    final conversation = _conversationCache[conversationId];
    if (conversation != null) {
      _activeConversation = conversation.copyWith(
        messages: _messagesCache[conversationId] ?? const [],
      );
      _activeConversationController.add(_activeConversation);
      await markConversationAsRead(conversationId);
    } else {
      _activeConversationController.add(null);
    }
  }

  Future<void> sendMessage({
    required String conversationId,
    required String content,
    ChatMessageType type = ChatMessageType.text,
    List<ChatAttachment>? attachments,
    Map<String, dynamic>? metadata,
  }) async {
    final admin = _auth.currentUser;
    if (admin == null) {
      throw StateError('Admin must be authenticated to send messages.');
    }

    final adminId = admin.uid;
    final chatRef = _firestore.collection('chats').doc(conversationId);
    final messageRef = chatRef.collection('messages').doc();

    final conversation = _conversationCache[conversationId];
    final userId = conversation?.userId;

    final preview = _buildPreviewFromMessage(type, content, attachments);
    final timestamp = FieldValue.serverTimestamp();

    final adminName = admin.displayName ?? admin.email ?? 'Admin';
    final payload = <String, dynamic>{
      'senderId': adminId,
      'senderName': adminName,
      'senderRole': 'admin',
      'senderEmail': admin.email,
      if (admin.photoURL != null) 'senderPhotoUrl': admin.photoURL,
      'text': content,
      'type': type.name,
      'status': ChatMessageStatus.sent.name,
      'timestamp': timestamp,
      'createdAt': timestamp,
      if (metadata != null) 'metadata': metadata,
      if (attachments != null && attachments.isNotEmpty)
        'attachments': attachments.map((a) => a.toJson()).toList(),
    };

    await messageRef.set(payload);

    final chatUpdates = <String, dynamic>{
      'lastMessage': preview,
      'lastMessageTime': timestamp,
      'updatedAt': timestamp,
      'status': ChatStatus.inProgress.name,
    };

    if (userId != null && userId.isNotEmpty) {
      chatUpdates['unreadCount.$userId'] = FieldValue.increment(1);
    }

    await chatRef.update(chatUpdates);
  }

  Future<void> updateConversationStatus(
    String conversationId,
    ChatStatus status,
  ) async {
    await _firestore.collection('chats').doc(conversationId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateConversationPriority(
    String conversationId,
    ChatPriority priority,
  ) async {
    await _firestore.collection('chats').doc(conversationId).update({
      'priority': priority.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> assignConversation(String conversationId, String adminId) async {
    final adminProfile = await _loadAdminProfile(adminId);
    await _firestore.collection('chats').doc(conversationId).update({
      'assignedAdminId': adminId,
      'assignedAdminName': adminProfile?.name ?? 'Admin',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unassignConversation(String conversationId) async {
    await _firestore.collection('chats').doc(conversationId).update({
      'assignedAdminId': FieldValue.delete(),
      'assignedAdminName': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markConversationAsRead(String conversationId) async {
    final adminId = _requireAdminId();
    final updates = <String, dynamic>{
      'unreadCount.admin': 0,
      'unreadCount.$adminId': 0,
    };
    await _firestore.collection('chats').doc(conversationId).update(updates);
  }

  int getUnreadConversationsCount(String adminId) {
    return _conversationCache.values
        .where((c) => (c.unreadCount[adminId] ?? 0) > 0)
        .length;
  }

  int getTotalUnreadMessagesCount(String adminId) {
    return _conversationCache.values.fold(
      0,
      (sum, c) => sum + (c.unreadCount[adminId] ?? 0),
    );
  }

  Future<void> dispose() async {
    await _conversationsSubscription?.cancel();
    await _messagesSubscription?.cancel();
    if (!_conversationsController.isClosed) {
      await _conversationsController.close();
    }
    if (!_activeConversationController.isClosed) {
      await _activeConversationController.close();
    }
    _conversationCache.clear();
    _messagesCache.clear();
    _userCache.clear();
    _adminCache.clear();
    _initialized = false;
  }

  // region -- Internal helpers -------------------------------------------------

  Future<void> _listenToConversations(
    String adminId, {
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      await _conversationsSubscription?.cancel();
    } else if (_conversationsSubscription != null) {
      return;
    }

    Query<Map<String, dynamic>> query;
    try {
      query = _firestore
          .collection('chats')
          .where('participants', arrayContainsAny: <String>[adminId, 'admin'])
          .orderBy('lastMessageTime', descending: true);
    } catch (_) {
      // Fallback to simple arrayContains to avoid composite index requirement
      query = _firestore
          .collection('chats')
          .where('participants', arrayContains: adminId)
          .orderBy('lastMessageTime', descending: true);
    }

    _conversationsSubscription = query.snapshots().listen(
      (snapshot) async {
        final futures = snapshot.docs.map(
          (doc) => _buildConversation(doc, adminId),
        );
        final conversations =
            (await Future.wait(futures)).whereType<ChatConversation>().toList()
              ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

        _conversationCache
          ..clear()
          ..addEntries(conversations.map((c) => MapEntry(c.id, c)));

        _conversationsController.add(conversations);

        if (_activeConversationId != null) {
          await setActiveConversation(_activeConversationId!);
        }
      },
      onError: (error) {
        _conversationsController.addError(error);
      },
    );
  }

  Future<ChatConversation?> _buildConversation(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String adminId,
  ) async {
    final data = doc.data();

    final createdAt = _toDateTime(data['createdAt']);
    final lastMessageTime =
        _toDateTime(data['lastMessageTime']) ?? createdAt ?? DateTime.now();
    final unreadMap =
        (data['unreadCount'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, (value as num).toInt()),
        ) ??
        const <String, int>{};

    final participants = List<String>.from(data['participants'] ?? []);
    final userId = _resolveUserId(participants, adminId) ?? data['userId'];

    final storedSenderName = (data['senderName'] as String?)?.trim();
    final storedSenderEmail = (data['senderEmail'] as String?)?.trim();
    final storedSenderPhoto = (data['senderPhotoUrl'] as String?)?.trim();

    final userProfile =
        userId != null
            ? (await _loadUserProfile(userId)) ?? const _UserProfile()
            : const _UserProfile();

    String? resolvedName = storedSenderName ?? userProfile.name;
    String? resolvedEmail = storedSenderEmail ?? userProfile.email;
    String? resolvedPhoto = storedSenderPhoto ?? userProfile.photoUrl;

    if (resolvedEmail == null ||
        resolvedEmail.isEmpty ||
        resolvedPhoto == null ||
        resolvedPhoto.isEmpty ||
        resolvedName == null ||
        resolvedName.isEmpty) {
      final latestMeta = await _fetchLatestMessageMetadata(doc.reference);
      resolvedName ??= latestMeta['senderName'];
      resolvedEmail ??= latestMeta['senderEmail'];
      resolvedPhoto ??= latestMeta['senderPhotoUrl'];
    }
    resolvedName =
        (resolvedName == null || resolvedName.isEmpty) ? 'User' : resolvedName;

    final metadataUpdates = <String, dynamic>{};
    if (resolvedName != storedSenderName) {
      metadataUpdates['senderName'] = resolvedName;
    }
    if (resolvedEmail != null && resolvedEmail != storedSenderEmail) {
      metadataUpdates['senderEmail'] = resolvedEmail;
    }
    if (resolvedPhoto != null && resolvedPhoto != storedSenderPhoto) {
      metadataUpdates['senderPhotoUrl'] = resolvedPhoto;
    }
    if (metadataUpdates.isNotEmpty) {
      await doc.reference.set(metadataUpdates, SetOptions(merge: true));
    }

    final assignedAdminId = data['assignedAdminId'] as String?;
    final assignedAdminName =
        data['assignedAdminName'] as String? ??
        (assignedAdminId != null
            ? (await _loadAdminProfile(assignedAdminId))?.name
            : null);

    return ChatConversation(
      id: doc.id,
      userId: userId ?? '',
      userName: resolvedName,
      userEmail: resolvedEmail,
      senderName: resolvedName,
      senderEmail: resolvedEmail,
      senderPhotoUrl: resolvedPhoto,
      subject: data['subject'] as String? ?? 'Support request',
      status: _parseStatus(data['status'] as String?),
      priority: _parsePriority(data['priority'] as String?),
      createdAt: createdAt ?? DateTime.now(),
      lastMessageAt: lastMessageTime,
      messages: _messagesCache[doc.id] ?? const [],
      unreadCount: unreadMap,
      assignedAdminId: assignedAdminId,
      assignedAdminName: assignedAdminName,
      lastMessagePreview: data['lastMessage'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Future<Map<String, String?>> _fetchLatestMessageMetadata(
    DocumentReference<Map<String, dynamic>> chatRef,
  ) async {
    try {
      final snapshot =
          await chatRef
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();
      if (snapshot.docs.isEmpty) return {};
      final data = snapshot.docs.first.data();
      return {
        'senderName': (data['senderName'] as String?)?.trim(),
        'senderEmail': (data['senderEmail'] as String?)?.trim(),
        'senderPhotoUrl': (data['senderPhotoUrl'] as String?)?.trim(),
      };
    } catch (e, stackTrace) {
      Logger.error(
        'Error fetching latest message metadata for chat ${chatRef.id}',
        e,
        stackTrace,
      );
      return {};
    }
  }

  Future<void> _listenToMessages(String chatId, String adminId) async {
    await _messagesSubscription?.cancel();

    final query = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false);

    _messagesSubscription = query.snapshots().listen((snapshot) async {
      final conversation = _conversationCache[chatId];
      final userProfile =
          conversation != null
              ? await _loadUserProfile(conversation.userId)
              : null;
      final adminProfile = await _loadAdminProfile(adminId);

      final messages =
          snapshot.docs.map((doc) {
            final data = doc.data();
            final senderId = data['senderId'] as String? ?? 'unknown';
            final senderRole =
                senderId == adminId || senderId == 'admin' ? 'admin' : 'user';

            final senderName =
                senderRole == 'admin'
                    ? (data['senderName'] as String?) ??
                        adminProfile?.name ??
                        'Admin'
                    : (data['senderName'] as String?) ??
                        userProfile?.name ??
                        'User';
            final senderEmail =
                (data['senderEmail'] as String?) ??
                (senderRole == 'admin'
                    ? adminProfile?.email
                    : userProfile?.email);
            final senderPhoto =
                (data['senderPhotoUrl'] as String?) ??
                (senderRole == 'admin'
                    ? adminProfile?.photoUrl
                    : userProfile?.photoUrl);

            return ChatMessage(
              id: doc.id,
              conversationId: chatId,
              senderId: senderId,
              senderName: senderName,
              senderRole: senderRole,
              senderEmail: senderEmail,
              senderPhotoUrl: senderPhoto,
              content: data['text'] as String? ?? '',
              type: _parseMessageType(data['type'] as String?),
              status: _parseMessageStatus(data['status'] as String?),
              timestamp: _toDateTime(data['timestamp']) ?? DateTime.now(),
              isRead:
                  senderRole == 'admin' ||
                  (_parseMessageStatus(data['status'] as String?)) ==
                      ChatMessageStatus.seen,
              metadata: (data['metadata'] as Map<String, dynamic>?),
              attachments:
                  (data['attachments'] as List?)
                      ?.map(
                        (a) => ChatAttachment.fromJson(
                          Map<String, dynamic>.from(a as Map),
                        ),
                      )
                      .toList(),
              replyToId: data['replyToId'] as String?,
            );
          }).toList();

      _messagesCache[chatId] = messages;

      final existing = _conversationCache[chatId];
      if (existing != null) {
        final updated = existing.copyWith(messages: messages);
        _conversationCache[chatId] = updated;
        if (_activeConversationId == chatId) {
          _activeConversation = updated;
          _activeConversationController.add(updated);
        }
      }

      await markConversationAsRead(chatId);
    }, onError: (error) => _activeConversationController.addError(error));
  }

  String _requireAdminId() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Admin must be authenticated to use chat services.');
    }
    return user.uid;
  }

  Future<_UserProfile?> _loadUserProfile(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final profile = _UserProfile.fromMap(
          doc.data() ?? {},
          fallbackId: doc.id,
        );
        _userCache[userId] = profile;
        return profile;
      }
    } catch (_) {}
    return null;
  }

  Future<_UserProfile?> _loadAdminProfile(String adminId) async {
    if (_adminCache.containsKey(adminId)) {
      return _adminCache[adminId];
    }

    try {
      final doc = await _firestore.collection('admins').doc(adminId).get();
      if (doc.exists) {
        final profile = _UserProfile.fromMap(
          doc.data() ?? {},
          fallbackId: doc.id,
        );
        _adminCache[adminId] = profile;
        return profile;
      }
    } catch (_) {}
    return null;
  }

  String? _resolveUserId(List<String> participants, String adminId) {
    for (final participant in participants) {
      if (participant == adminId || participant == 'admin') continue;
      return participant;
    }
    return null;
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  ChatStatus _parseStatus(String? value) {
    return ChatStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ChatStatus.open,
    );
  }

  ChatPriority _parsePriority(String? value) {
    return ChatPriority.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ChatPriority.normal,
    );
  }

  ChatMessageType _parseMessageType(String? value) {
    return ChatMessageType.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ChatMessageType.text,
    );
  }

  ChatMessageStatus _parseMessageStatus(String? value) {
    return ChatMessageStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ChatMessageStatus.sent,
    );
  }

  String _buildPreviewFromMessage(
    ChatMessageType type,
    String text,
    List<ChatAttachment>? attachments,
  ) {
    switch (type) {
      case ChatMessageType.text:
        return text.length > 100 ? '${text.substring(0, 100)}…' : text;
      case ChatMessageType.image:
        return attachments != null && attachments.isNotEmpty
            ? '📷 ${attachments.first.name}'
            : '📷 Image';
      case ChatMessageType.file:
        return attachments != null && attachments.isNotEmpty
            ? '📎 ${attachments.first.name}'
            : '📎 File';
      case ChatMessageType.system:
        return text;
    }
  }

  // endregion -----------------------------------------------------------------
}

class _UserProfile {
  final String? id;
  final String? name;
  final String? email;
  final String? photoUrl;

  const _UserProfile({this.id, this.name, this.email, this.photoUrl});

  factory _UserProfile.fromMap(
    Map<String, dynamic> data, {
    String? fallbackId,
  }) {
    final profileName =
        data['name'] as String? ??
        data['full_name'] as String? ??
        data['firstName'] as String?;
    final lastName = data['lastName'] as String?;
    final middleName = data['middleName'] as String?;

    final buffer = StringBuffer();
    if (profileName != null && profileName.isNotEmpty) {
      buffer.write(profileName);
    }
    if (middleName != null && middleName.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(middleName);
    }
    if (lastName != null && lastName.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(lastName);
    }

    final resolvedName =
        buffer.isNotEmpty
            ? buffer.toString()
            : (data['email'] as String?)?.split('@').first ??
                fallbackId ??
                'User';

    return _UserProfile(
      id: data['id'] as String? ?? fallbackId,
      name: resolvedName,
      email: data['email'] as String?,
      photoUrl: data['photoUrl'] as String? ?? data['photo_url'] as String?,
    );
  }
}
