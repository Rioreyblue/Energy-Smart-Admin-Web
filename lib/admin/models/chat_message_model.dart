class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'admin', 'user'
  final String content;
  final ChatMessageType type;
  final DateTime timestamp;
  final bool isRead;
  final List<String>? attachments;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.content,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.attachments,
  });

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? senderRole,
    String? content,
    ChatMessageType? type,
    DateTime? timestamp,
    bool? isRead,
    List<String>? attachments,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      attachments: attachments ?? this.attachments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'content': content,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'attachments': attachments,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      conversationId: json['conversationId'],
      senderId: json['senderId'],
      senderName: json['senderName'],
      senderRole: json['senderRole'],
      content: json['content'],
      type: ChatMessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ChatMessageType.text,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['isRead'] ?? false,
      attachments: json['attachments']?.cast<String>(),
    );
  }
}

enum ChatMessageType { text, image, file, system }

class ChatConversation {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String subject;
  final ChatStatus status;
  final ChatPriority priority;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final List<ChatMessage> messages;
  final int unreadCount;
  final String? assignedAdminId;
  final String? assignedAdminName;

  ChatConversation({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.subject,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.lastMessageAt,
    required this.messages,
    this.unreadCount = 0,
    this.assignedAdminId,
    this.assignedAdminName,
  });

  ChatConversation copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userEmail,
    String? subject,
    ChatStatus? status,
    ChatPriority? priority,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    List<ChatMessage>? messages,
    int? unreadCount,
    String? assignedAdminId,
    String? assignedAdminName,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      subject: subject ?? this.subject,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      messages: messages ?? this.messages,
      unreadCount: unreadCount ?? this.unreadCount,
      assignedAdminId: assignedAdminId ?? this.assignedAdminId,
      assignedAdminName: assignedAdminName ?? this.assignedAdminName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'subject': subject,
      'status': status.name,
      'priority': priority.name,
      'createdAt': createdAt.toIso8601String(),
      'lastMessageAt': lastMessageAt.toIso8601String(),
      'messages': messages.map((m) => m.toJson()).toList(),
      'unreadCount': unreadCount,
      'assignedAdminId': assignedAdminId,
      'assignedAdminName': assignedAdminName,
    };
  }

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'],
      userId: json['userId'],
      userName: json['userName'],
      userEmail: json['userEmail'],
      subject: json['subject'],
      status: ChatStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ChatStatus.open,
      ),
      priority: ChatPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => ChatPriority.normal,
      ),
      createdAt: DateTime.parse(json['createdAt']),
      lastMessageAt: DateTime.parse(json['lastMessageAt']),
      messages:
          (json['messages'] as List)
              .map((m) => ChatMessage.fromJson(m))
              .toList(),
      unreadCount: json['unreadCount'] ?? 0,
      assignedAdminId: json['assignedAdminId'],
      assignedAdminName: json['assignedAdminName'],
    );
  }
}

enum ChatStatus { open, inProgress, resolved, closed }

enum ChatPriority { low, normal, high, urgent }
