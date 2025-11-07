import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

/// User model for Firebase Firestore
class FirebaseUser {
  final String id;
  final String name;
  final String email;
  final String role; // 'admin' or 'user'
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime lastSeen;
  final bool isOnline;

  // Conversation metadata fields (for chat support)
  final DateTime? lastMessageTime;
  final String? lastMessage;
  final int unreadCount;
  final bool hasMessages;
  final DateTime activityTimestamp;

  FirebaseUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.photoUrl,
    required this.createdAt,
    required this.lastSeen,
    this.isOnline = false,
    this.lastMessageTime,
    this.lastMessage,
    this.unreadCount = 0,
    this.hasMessages = false,
    DateTime? activityTimestamp,
  }) : activityTimestamp = activityTimestamp ?? lastMessageTime ?? lastSeen;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastSeen': Timestamp.fromDate(lastSeen),
      'isOnline': isOnline,
    };
  }

  factory FirebaseUser.fromJson(Map<String, dynamic> json) {
    // Support multiple photo URL fields: photoUrl, profilePhotoUrl, profile.photoUrl
    String? photoUrl;
    if (json['photoUrl'] != null) {
      photoUrl = json['photoUrl'] as String?;
    } else if (json['profilePhotoUrl'] != null) {
      photoUrl = json['profilePhotoUrl'] as String?;
    } else if (json['profile'] != null) {
      final profile = json['profile'] as Map<String, dynamic>?;
      photoUrl = profile?['photoUrl'] as String?;
    }

    // Extract email from root level or nested profile
    String? email = json['email'] as String?;
    if (email == null && json['profile'] != null) {
      final profile = json['profile'] as Map<String, dynamic>?;
      email = profile?['email'] as String?;
    }

    // Extract user ID - support both 'id' and 'uid' fields
    String userId = json['id'] ?? json['uid'] ?? '';

    // Extract name - combine firstName, middleName, lastName if available
    // Otherwise fallback to 'name' field, then email prefix, then 'Unknown User'
    String userName;
    final firstName = json['firstName'] as String?;
    final middleName = json['middleName'] as String?;
    final lastName = json['lastName'] as String?;

    if (firstName != null || middleName != null || lastName != null) {
      // Combine name parts with proper spacing
      final nameParts = <String>[];
      if (firstName != null && firstName.isNotEmpty) {
        nameParts.add(firstName);
      }
      if (middleName != null && middleName.isNotEmpty) {
        nameParts.add(middleName);
      }
      if (lastName != null && lastName.isNotEmpty) {
        nameParts.add(lastName);
      }
      userName = nameParts.join(' ');
    } else if (json['name'] != null && (json['name'] as String).isNotEmpty) {
      userName = json['name'] as String;
    } else if (email != null && email.isNotEmpty) {
      // Fallback to email prefix
      userName = email.split('@').first;
    } else {
      userName = 'Unknown User';
    }

    DateTime _parseDate(dynamic value, DateTime fallback) {
      if (value == null) return fallback;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) {
        if (value > 1000000000000) {
          return DateTime.fromMillisecondsSinceEpoch(value);
        }
        if (value > 1000000000) {
          return DateTime.fromMillisecondsSinceEpoch(value * 1000);
        }
      }
      if (value is double) {
        if (value > 1000000000000) {
          return DateTime.fromMillisecondsSinceEpoch(value.round());
        }
        if (value > 1000000000) {
          return DateTime.fromMillisecondsSinceEpoch((value * 1000).round());
        }
      }
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (_) {
          final parsed = int.tryParse(value);
          if (parsed != null) {
            return _parseDate(parsed, fallback);
          }
        }
      }
      return fallback;
    }

    // Extract conversation metadata (for chat support)
    final lastMessageTime =
        json['lastMessageTime'] != null
            ? _parseDate(json['lastMessageTime'], DateTime.now())
            : null;
    final lastMessage = json['lastMessage'] as String?;
    final unreadCount =
        json['unreadCount'] != null
            ? (json['unreadCount'] is int
                ? json['unreadCount'] as int
                : (json['unreadCount'] as num?)?.toInt() ?? 0)
            : 0;
    final hasMessages = json['hasMessages'] as bool? ?? false;

    final createdAt = _parseDate(json['createdAt'], DateTime.now());
    final lastSeen = _parseDate(json['lastSeen'], createdAt);
    final activityTimestamp = lastMessageTime ?? lastSeen;

    return FirebaseUser(
      id: userId,
      name: userName,
      email: email ?? '',
      role: json['role'] ?? 'user',
      photoUrl: photoUrl,
      createdAt: createdAt,
      lastSeen: lastSeen,
      isOnline:
          json['isOnline'] is bool
              ? json['isOnline'] as bool
              : json['isOnline']?.toString().toLowerCase() == 'true',
      lastMessageTime: lastMessageTime,
      lastMessage: lastMessage,
      unreadCount: unreadCount,
      hasMessages: hasMessages,
      activityTimestamp: activityTimestamp,
    );
  }

  FirebaseUser copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? lastSeen,
    bool? isOnline,
    DateTime? lastMessageTime,
    String? lastMessage,
    int? unreadCount,
    bool? hasMessages,
    DateTime? activityTimestamp,
  }) {
    return FirebaseUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
      isOnline: isOnline ?? this.isOnline,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      hasMessages: hasMessages ?? this.hasMessages,
      activityTimestamp: activityTimestamp ?? this.activityTimestamp,
    );
  }

  /// Convert to flutter_chat_types User
  types.User toChatUser() {
    return types.User(
      id: id,
      firstName: name.split(' ').first,
      lastName: name.split(' ').length > 1 ? name.split(' ').last : null,
      imageUrl: photoUrl,
      metadata: {'role': role, 'email': email, 'isOnline': isOnline},
    );
  }
}

/// Chat model for Firebase Firestore
class FirebaseChat {
  final String id;
  final List<String> participants;
  final String? lastMessage;
  final DateTime lastMessageTime;
  final DateTime createdAt;
  final Map<String, int> unreadCount; // userId -> count
  final String? subject;
  final ChatStatus status;
  final ChatPriority priority;
  final String? assignedAdminId;
  final Map<String, dynamic>? metadata;

  FirebaseChat({
    required this.id,
    required this.participants,
    this.lastMessage,
    required this.lastMessageTime,
    required this.createdAt,
    required this.unreadCount,
    this.subject,
    this.status = ChatStatus.active,
    this.priority = ChatPriority.normal,
    this.assignedAdminId,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'createdAt': Timestamp.fromDate(createdAt),
      'unreadCount': unreadCount,
      'subject': subject,
      'status': status.name,
      'priority': priority.name,
      'assignedAdminId': assignedAdminId,
      'metadata': metadata,
    };
  }

  factory FirebaseChat.fromJson(Map<String, dynamic> json) {
    return FirebaseChat(
      id: json['id'] ?? '',
      participants: List<String>.from(json['participants'] ?? []),
      lastMessage: json['lastMessage'],
      lastMessageTime:
          (json['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCount: Map<String, int>.from(json['unreadCount'] ?? {}),
      subject: json['subject'],
      status: ChatStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ChatStatus.active,
      ),
      priority: ChatPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => ChatPriority.normal,
      ),
      assignedAdminId: json['assignedAdminId'],
      metadata: json['metadata'],
    );
  }

  FirebaseChat copyWith({
    String? id,
    List<String>? participants,
    String? lastMessage,
    DateTime? lastMessageTime,
    DateTime? createdAt,
    Map<String, int>? unreadCount,
    String? subject,
    ChatStatus? status,
    ChatPriority? priority,
    String? assignedAdminId,
    Map<String, dynamic>? metadata,
  }) {
    return FirebaseChat(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      createdAt: createdAt ?? this.createdAt,
      unreadCount: unreadCount ?? this.unreadCount,
      subject: subject ?? this.subject,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assignedAdminId: assignedAdminId ?? this.assignedAdminId,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Message model for Firebase Firestore
class FirebaseChatMessage {
  final String id;
  final String chatId;
  final String senderId; // Primary: User ID or "admin"
  final String?
  sender; // Keep for backward compatibility (derived from senderId)
  final String text;
  final DateTime timestamp;
  final MessageType type;
  final MessageStatus status;
  final String? replyToId;
  final Map<String, dynamic>? metadata;
  final List<MessageAttachment>? attachments;

  FirebaseChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.sender,
    required this.text,
    required this.timestamp,
    this.type = MessageType.text,
    this.status = MessageStatus.sent,
    this.replyToId,
    this.metadata,
    this.attachments,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId, // Primary field (matches database structure)
      'text': text,
      'timestamp': Timestamp.fromDate(
        timestamp,
      ), // Primary field (matches database structure)
      'createdAt': Timestamp.fromDate(
        timestamp,
      ), // Keep createdAt for backward compatibility
      'type': type.name,
      'status': status.name,
      'replyToId': replyToId,
      'metadata': metadata,
      'attachments': attachments?.map((a) => a.toJson()).toList(),
      if (sender != null) 'sender': sender, // Keep for backward compatibility
    };
  }

  factory FirebaseChatMessage.fromJson(Map<String, dynamic> json) {
    // Priority: timestamp field first (matches database structure), then createdAt as fallback
    DateTime messageTimestamp;
    if (json['timestamp'] != null) {
      messageTimestamp =
          (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    } else if (json['createdAt'] != null) {
      messageTimestamp =
          (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    } else {
      messageTimestamp = DateTime.now();
    }

    // Handle senderId field: prioritize senderId (primary), fallback to sender for backward compatibility
    String senderIdValue;
    if (json['senderId'] != null) {
      senderIdValue = json['senderId'] as String;
    } else if (json['sender'] != null) {
      // For old messages, use sender as senderId
      senderIdValue = json['sender'] as String;
    } else {
      senderIdValue = 'unknown';
    }

    // Derive sender from senderId for backward compatibility
    final senderValue = json['sender'] as String? ?? senderIdValue;

    // Handle unsent messages - display "[Message unsent]" if metadata.unsent is true
    String messageText = json['text'] ?? '';
    final metadata = json['metadata'] as Map<String, dynamic>?;
    if (metadata != null && metadata['unsent'] == true) {
      messageText = '[Message unsent]';
    }

    return FirebaseChatMessage(
      id: json['id'] ?? '',
      chatId: json['chatId'] ?? '',
      senderId: senderIdValue, // Primary field
      sender: senderValue, // Keep for backward compatibility
      text: messageText,
      timestamp: messageTimestamp,
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MessageStatus.sent,
      ),
      replyToId: json['replyToId'],
      metadata: metadata,
      attachments:
          (json['attachments'] as List?)
              ?.map((a) => MessageAttachment.fromJson(a))
              .toList(),
    );
  }

  /// Convert to flutter_chat_types Message
  types.Message toChatMessage(types.User author) {
    switch (type) {
      case MessageType.text:
        return types.TextMessage(
          id: id,
          author: author,
          text: text,
          createdAt: timestamp.millisecondsSinceEpoch,
          status: _convertStatus(status),
          metadata: metadata,
          repliedMessage:
              replyToId != null
                  ? types.TextMessage(
                    id: replyToId!,
                    author: author,
                    text: 'Replied message',
                    createdAt: timestamp.millisecondsSinceEpoch,
                  )
                  : null,
        );
      case MessageType.image:
        return types.ImageMessage(
          id: id,
          author: author,
          name: attachments?.first.name ?? 'Image',
          size: attachments?.first.size ?? 0,
          uri: attachments?.first.url ?? '',
          createdAt: timestamp.millisecondsSinceEpoch,
          status: _convertStatus(status),
          metadata: metadata,
        );
      case MessageType.file:
        return types.FileMessage(
          id: id,
          author: author,
          name: attachments?.first.name ?? 'File',
          size: attachments?.first.size ?? 0,
          uri: attachments?.first.url ?? '',
          createdAt: timestamp.millisecondsSinceEpoch,
          status: _convertStatus(status),
          metadata: metadata,
        );
      case MessageType.system:
        return types.SystemMessage(
          id: id,
          text: text,
          createdAt: timestamp.millisecondsSinceEpoch,
          metadata: metadata,
        );
    }
  }

  types.Status? _convertStatus(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return types.Status.sending;
      case MessageStatus.sent:
        return types.Status.sent;
      case MessageStatus.delivered:
        return types.Status.delivered;
      case MessageStatus.seen:
        return types.Status.seen;
      case MessageStatus.error:
        return types.Status.error;
    }
  }
}

/// Message attachment model
/// Matches database structure: {type: "image", url: "...", name: "..."}
class MessageAttachment {
  final String name;
  final String url;
  final int? size;
  final String? mimeType;
  final String? type; // 'image', 'file', etc.

  MessageAttachment({
    required this.name,
    required this.url,
    this.size,
    this.mimeType,
    this.type,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'name': name, 'url': url};
    if (type != null) json['type'] = type;
    if (size != null) json['size'] = size;
    if (mimeType != null) json['mimeType'] = mimeType;
    return json;
  }

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      size: json['size'] as int?,
      mimeType: json['mimeType'] as String?,
      type: json['type'] as String?,
    );
  }
}

/// Enums
enum ChatStatus { active, archived, closed }

enum ChatPriority { low, normal, high, urgent }

enum MessageType { text, image, file, system }

enum MessageStatus { sending, sent, delivered, seen, error }

/// Chat statistics model
class ChatStatistics {
  final int totalChats;
  final int activeChats;
  final int unreadMessages;
  final double averageResponseTime;
  final Map<ChatPriority, int> priorityBreakdown;

  ChatStatistics({
    required this.totalChats,
    required this.activeChats,
    required this.unreadMessages,
    required this.averageResponseTime,
    required this.priorityBreakdown,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalChats': totalChats,
      'activeChats': activeChats,
      'unreadMessages': unreadMessages,
      'averageResponseTime': averageResponseTime,
      'priorityBreakdown': priorityBreakdown.map(
        (key, value) => MapEntry(key.name, value),
      ),
    };
  }

  factory ChatStatistics.fromJson(Map<String, dynamic> json) {
    return ChatStatistics(
      totalChats: json['totalChats'] ?? 0,
      activeChats: json['activeChats'] ?? 0,
      unreadMessages: json['unreadMessages'] ?? 0,
      averageResponseTime: (json['averageResponseTime'] ?? 0.0).toDouble(),
      priorityBreakdown:
          (json['priorityBreakdown'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              ChatPriority.values.firstWhere((e) => e.name == key),
              value as int,
            ),
          ) ??
          {},
    );
  }
}
