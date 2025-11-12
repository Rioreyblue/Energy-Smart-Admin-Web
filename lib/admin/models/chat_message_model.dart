import '../utils/unread_count_utils.dart';

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'admin', 'user'
  final String? senderEmail;
  final String? senderPhotoUrl;
  final String content;
  final ChatMessageType type;
  final ChatMessageStatus status;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? metadata;
  final List<ChatAttachment>? attachments;
  final String? replyToId;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    this.senderEmail,
    this.senderPhotoUrl,
    required this.content,
    required this.type,
    required this.timestamp,
    this.status = ChatMessageStatus.sent,
    this.isRead = false,
    this.metadata,
    this.attachments,
    this.replyToId,
  });

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? senderRole,
    String? senderEmail,
    String? senderPhotoUrl,
    String? content,
    ChatMessageType? type,
    ChatMessageStatus? status,
    DateTime? timestamp,
    bool? isRead,
    Map<String, dynamic>? metadata,
    List<ChatAttachment>? attachments,
    String? replyToId,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      senderEmail: senderEmail ?? this.senderEmail,
      senderPhotoUrl: senderPhotoUrl ?? this.senderPhotoUrl,
      content: content ?? this.content,
      type: type ?? this.type,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
      attachments: attachments ?? this.attachments,
      replyToId: replyToId ?? this.replyToId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      if (senderEmail != null) 'senderEmail': senderEmail,
      if (senderPhotoUrl != null) 'senderPhotoUrl': senderPhotoUrl,
      'content': content,
      'type': type.name,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      if (metadata != null) 'metadata': metadata,
      if (attachments != null)
        'attachments': attachments!.map((a) => a.toJson()).toList(),
      if (replyToId != null) 'replyToId': replyToId,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      conversationId: json['conversationId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      senderRole: json['senderRole'] ?? 'user',
      senderEmail: json['senderEmail'] as String?,
      senderPhotoUrl: json['senderPhotoUrl'] as String?,
      content: json['content'] ?? '',
      type: ChatMessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ChatMessageType.text,
      ),
      status: ChatMessageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ChatMessageStatus.sent,
      ),
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      isRead: json['isRead'] ?? false,
      metadata: json['metadata'] as Map<String, dynamic>?,
      attachments: _parseAttachments(json),
      replyToId: json['replyToId'] as String?,
    );
  }

  static List<ChatAttachment>? _parseAttachments(Map<String, dynamic> json) {
    final raw = json['attachments'] ?? json['attachment'];
    if (raw == null) return null;

    final normalized = <Map<String, dynamic>>[];

    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          normalized.add(
            item.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
      }
    } else if (raw is Map) {
      normalized.add(raw.map((key, value) => MapEntry(key.toString(), value)));
    }

    if (normalized.isEmpty) return null;

    return normalized
        .map((item) => ChatAttachment.fromJson(item))
        .where((attachment) => attachment.url.isNotEmpty)
        .toList();
  }
}

enum ChatMessageType { text, image, file, system }

enum ChatMessageStatus { sending, sent, delivered, seen, error }

class ChatAttachment {
  final String name;
  final String url;
  final String? type;
  final int? size;
  final String? mimeType;

  const ChatAttachment({
    required this.name,
    required this.url,
    this.type,
    this.size,
    this.mimeType,
  });

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      name: (json['name'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      type: json['type']?.toString().toLowerCase(),
      size: (json['size'] as num?)?.toInt(),
      mimeType: json['mimeType']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      if (type != null) 'type': type,
      if (size != null) 'size': size,
      if (mimeType != null) 'mimeType': mimeType,
    };
  }
}

class ChatConversation {
  final String id;
  final String userId;
  final String userName;
  final String? userEmail;
  final String? senderName;
  final String? senderEmail;
  final String? senderPhotoUrl;
  final String? subject;
  final ChatStatus status;
  final ChatPriority priority;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final List<ChatMessage> messages;
  final Map<String, int> unreadCount;
  final String? assignedAdminId;
  final String? assignedAdminName;
  final String? lastMessagePreview;
  final Map<String, dynamic>? metadata;

  const ChatConversation({
    required this.id,
    required this.userId,
    required this.userName,
    this.userEmail,
    this.senderName,
    this.senderEmail,
    this.senderPhotoUrl,
    this.subject,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.lastMessageAt,
    required this.messages,
    this.unreadCount = const {},
    this.assignedAdminId,
    this.assignedAdminName,
    this.lastMessagePreview,
    this.metadata,
  });

  int unreadFor(String participantId) => unreadCount[participantId] ?? 0;

  ChatConversation copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userEmail,
    String? senderName,
    String? senderEmail,
    String? senderPhotoUrl,
    String? subject,
    ChatStatus? status,
    ChatPriority? priority,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    List<ChatMessage>? messages,
    Map<String, int>? unreadCount,
    String? assignedAdminId,
    String? assignedAdminName,
    String? lastMessagePreview,
    Map<String, dynamic>? metadata,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      senderName: senderName ?? this.senderName,
      senderEmail: senderEmail ?? this.senderEmail,
      senderPhotoUrl: senderPhotoUrl ?? this.senderPhotoUrl,
      subject: subject ?? this.subject,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      messages: messages ?? this.messages,
      unreadCount: unreadCount ?? this.unreadCount,
      assignedAdminId: assignedAdminId ?? this.assignedAdminId,
      assignedAdminName: assignedAdminName ?? this.assignedAdminName,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      if (senderName != null) 'senderName': senderName,
      if (senderEmail != null) 'senderEmail': senderEmail,
      if (senderPhotoUrl != null) 'senderPhotoUrl': senderPhotoUrl,
      'subject': subject,
      'status': status.name,
      'priority': priority.name,
      'createdAt': createdAt.toIso8601String(),
      'lastMessageAt': lastMessageAt.toIso8601String(),
      'messages': messages.map((m) => m.toJson()).toList(),
      'unreadCount': unreadCount,
      'assignedAdminId': assignedAdminId,
      'assignedAdminName': assignedAdminName,
      'lastMessagePreview': lastMessagePreview,
      if (metadata != null) 'metadata': metadata,
    };
  }

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      userEmail: json['userEmail'] as String?,
      senderName: json['senderName'] as String?,
      senderEmail: json['senderEmail'] as String?,
      senderPhotoUrl: json['senderPhotoUrl'] as String?,
      subject: json['subject'] as String?,
      status: ChatStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ChatStatus.open,
      ),
      priority: ChatPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => ChatPriority.normal,
      ),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      lastMessageAt:
          DateTime.tryParse(json['lastMessageAt'] ?? '') ?? DateTime.now(),
      messages:
          (json['messages'] as List?)
              ?.map(
                (m) =>
                    ChatMessage.fromJson(Map<String, dynamic>.from(m as Map)),
              )
              .toList() ??
          const [],
      unreadCount: normalizeUnreadCount(json['unreadCount']),
      assignedAdminId: json['assignedAdminId'] as String?,
      assignedAdminName: json['assignedAdminName'] as String?,
      lastMessagePreview: json['lastMessagePreview'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

enum ChatStatus { open, inProgress, resolved, closed }

enum ChatPriority { low, normal, high, urgent }
