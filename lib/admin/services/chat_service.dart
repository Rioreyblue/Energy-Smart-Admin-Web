import 'dart:async';
import 'dart:math';
import '../models/chat_message_model.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final StreamController<List<ChatConversation>> _conversationsController =
      StreamController<List<ChatConversation>>.broadcast();
  final StreamController<ChatConversation> _activeConversationController =
      StreamController<ChatConversation>.broadcast();

  Stream<List<ChatConversation>> get conversationsStream =>
      _conversationsController.stream;
  Stream<ChatConversation> get activeConversationStream =>
      _activeConversationController.stream;

  List<ChatConversation> _conversations = [];
  ChatConversation? _activeConversation;

  // Initialize with mock data
  void initialize() {
    _conversations = _generateMockConversations();
    _conversationsController.add(_conversations);
  }

  // Get all conversations
  List<ChatConversation> getConversations() {
    return _conversations;
  }

  // Get conversation by ID
  ChatConversation? getConversationById(String id) {
    try {
      return _conversations.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  // Set active conversation
  void setActiveConversation(String conversationId) {
    final conversation = getConversationById(conversationId);
    if (conversation != null) {
      _activeConversation = conversation;
      _activeConversationController.add(conversation);

      // Mark messages as read
      _markMessagesAsRead(conversationId);
    }
  }

  // Send message
  Future<void> sendMessage({
    required String conversationId,
    required String content,
    ChatMessageType type = ChatMessageType.text,
    List<String>? attachments,
  }) async {
    final conversation = getConversationById(conversationId);
    if (conversation == null) return;

    final message = ChatMessage(
      id: _generateId(),
      conversationId: conversationId,
      senderId: 'admin_001',
      senderName: 'Admin User',
      senderRole: 'admin',
      content: content,
      type: type,
      timestamp: DateTime.now(),
      isRead: true,
      attachments: attachments,
    );

    // Add message to conversation
    final updatedMessages = [...conversation.messages, message];
    final updatedConversation = conversation.copyWith(
      messages: updatedMessages,
      lastMessageAt: DateTime.now(),
      status: ChatStatus.inProgress,
    );

    // Update conversations list
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      _conversations[index] = updatedConversation;
      _conversationsController.add(_conversations);

      if (_activeConversation?.id == conversationId) {
        _activeConversation = updatedConversation;
        _activeConversationController.add(updatedConversation);
      }
    }

    // Simulate user response after a delay
    _simulateUserResponse(conversationId);
  }

  // Update conversation status
  Future<void> updateConversationStatus(
    String conversationId,
    ChatStatus status,
  ) async {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      _conversations[index] = _conversations[index].copyWith(status: status);
      _conversationsController.add(_conversations);

      if (_activeConversation?.id == conversationId) {
        _activeConversation = _conversations[index];
        _activeConversationController.add(_conversations[index]);
      }
    }
  }

  // Update conversation priority
  Future<void> updateConversationPriority(
    String conversationId,
    ChatPriority priority,
  ) async {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      _conversations[index] = _conversations[index].copyWith(
        priority: priority,
      );
      _conversationsController.add(_conversations);

      if (_activeConversation?.id == conversationId) {
        _activeConversation = _conversations[index];
        _activeConversationController.add(_conversations[index]);
      }
    }
  }

  // Assign conversation to admin
  Future<void> assignConversation(
    String conversationId,
    String adminId,
    String adminName,
  ) async {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      _conversations[index] = _conversations[index].copyWith(
        assignedAdminId: adminId,
        assignedAdminName: adminName,
      );
      _conversationsController.add(_conversations);

      if (_activeConversation?.id == conversationId) {
        _activeConversation = _conversations[index];
        _activeConversationController.add(_conversations[index]);
      }
    }
  }

  // Mark messages as read
  void _markMessagesAsRead(String conversationId) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      final conversation = _conversations[index];
      final updatedMessages =
          conversation.messages.map((m) {
            if (m.senderRole != 'admin' && !m.isRead) {
              return m.copyWith(isRead: true);
            }
            return m;
          }).toList();

      _conversations[index] = conversation.copyWith(
        messages: updatedMessages,
        unreadCount: 0,
      );
      _conversationsController.add(_conversations);
    }
  }

  // Get unread conversations count
  int getUnreadConversationsCount() {
    return _conversations.where((c) => c.unreadCount > 0).length;
  }

  // Get total unread messages count
  int getTotalUnreadMessagesCount() {
    return _conversations.fold(0, (sum, c) => sum + c.unreadCount);
  }

  // Simulate user response
  void _simulateUserResponse(String conversationId) {
    Timer(const Duration(seconds: 3), () {
      final responses = [
        "Thank you for your help!",
        "That makes sense, let me try that.",
        "I'm still having issues with this.",
        "Could you provide more details?",
        "Perfect, that solved my problem!",
        "I need to check something first.",
      ];

      final conversation = getConversationById(conversationId);
      if (conversation == null) return;

      final message = ChatMessage(
        id: _generateId(),
        conversationId: conversationId,
        senderId: conversation.userId,
        senderName: conversation.userName,
        senderRole: 'user',
        content: responses[Random().nextInt(responses.length)],
        type: ChatMessageType.text,
        timestamp: DateTime.now(),
        isRead: false,
      );

      final updatedMessages = [...conversation.messages, message];
      final updatedConversation = conversation.copyWith(
        messages: updatedMessages,
        lastMessageAt: DateTime.now(),
        unreadCount: conversation.unreadCount + 1,
      );

      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index != -1) {
        _conversations[index] = updatedConversation;
        _conversationsController.add(_conversations);

        if (_activeConversation?.id == conversationId) {
          _activeConversation = updatedConversation;
          _activeConversationController.add(updatedConversation);
        }
      }
    });
  }

  // Generate mock conversations
  List<ChatConversation> _generateMockConversations() {
    final now = DateTime.now();
    return [
      ChatConversation(
        id: 'conv_001',
        userId: 'user_001',
        userName: 'John Doe',
        userEmail: 'john.doe@example.com',
        subject: 'Energy Usage Query',
        status: ChatStatus.open,
        priority: ChatPriority.normal,
        createdAt: now.subtract(const Duration(hours: 2)),
        lastMessageAt: now.subtract(const Duration(minutes: 30)),
        unreadCount: 2,
        messages: [
          ChatMessage(
            id: 'msg_001',
            conversationId: 'conv_001',
            senderId: 'user_001',
            senderName: 'John Doe',
            senderRole: 'user',
            content: 'Hi, I have a question about my energy usage data.',
            type: ChatMessageType.text,
            timestamp: now.subtract(const Duration(hours: 2)),
            isRead: true,
          ),
          ChatMessage(
            id: 'msg_002',
            conversationId: 'conv_001',
            senderId: 'user_001',
            senderName: 'John Doe',
            senderRole: 'user',
            content: 'My dashboard shows unusual spikes in consumption.',
            type: ChatMessageType.text,
            timestamp: now.subtract(const Duration(minutes: 30)),
            isRead: false,
          ),
        ],
      ),
      ChatConversation(
        id: 'conv_002',
        userId: 'user_002',
        userName: 'Jane Smith',
        userEmail: 'jane.smith@example.com',
        subject: 'Billing Issue',
        status: ChatStatus.inProgress,
        priority: ChatPriority.high,
        createdAt: now.subtract(const Duration(hours: 4)),
        lastMessageAt: now.subtract(const Duration(minutes: 15)),
        unreadCount: 1,
        assignedAdminId: 'admin_001',
        assignedAdminName: 'Admin User',
        messages: [
          ChatMessage(
            id: 'msg_003',
            conversationId: 'conv_002',
            senderId: 'user_002',
            senderName: 'Jane Smith',
            senderRole: 'user',
            content: 'There seems to be an error in my billing calculation.',
            type: ChatMessageType.text,
            timestamp: now.subtract(const Duration(hours: 4)),
            isRead: true,
          ),
          ChatMessage(
            id: 'msg_004',
            conversationId: 'conv_002',
            senderId: 'admin_001',
            senderName: 'Admin User',
            senderRole: 'admin',
            content:
                'I\'ll look into this right away. Can you provide your account details?',
            type: ChatMessageType.text,
            timestamp: now.subtract(const Duration(hours: 3, minutes: 30)),
            isRead: true,
          ),
          ChatMessage(
            id: 'msg_005',
            conversationId: 'conv_002',
            senderId: 'user_002',
            senderName: 'Jane Smith',
            senderRole: 'user',
            content: 'Sure, my account ID is ES-12345.',
            type: ChatMessageType.text,
            timestamp: now.subtract(const Duration(minutes: 15)),
            isRead: false,
          ),
        ],
      ),
      ChatConversation(
        id: 'conv_003',
        userId: 'user_003',
        userName: 'Mike Johnson',
        userEmail: 'mike.johnson@example.com',
        subject: 'Device Connection Problem',
        status: ChatStatus.resolved,
        priority: ChatPriority.normal,
        createdAt: now.subtract(const Duration(days: 1)),
        lastMessageAt: now.subtract(const Duration(hours: 6)),
        unreadCount: 0,
        assignedAdminId: 'admin_001',
        assignedAdminName: 'Admin User',
        messages: [
          ChatMessage(
            id: 'msg_006',
            conversationId: 'conv_003',
            senderId: 'user_003',
            senderName: 'Mike Johnson',
            senderRole: 'user',
            content: 'My smart meter is not connecting to the system.',
            type: ChatMessageType.text,
            timestamp: now.subtract(const Duration(days: 1)),
            isRead: true,
          ),
          ChatMessage(
            id: 'msg_007',
            conversationId: 'conv_003',
            senderId: 'admin_001',
            senderName: 'Admin User',
            senderRole: 'admin',
            content:
                'Let me help you troubleshoot this. Please try restarting your device.',
            type: ChatMessageType.text,
            timestamp: now.subtract(const Duration(hours: 20)),
            isRead: true,
          ),
          ChatMessage(
            id: 'msg_008',
            conversationId: 'conv_003',
            senderId: 'user_003',
            senderName: 'Mike Johnson',
            senderRole: 'user',
            content: 'That worked! Thank you so much.',
            type: ChatMessageType.text,
            timestamp: now.subtract(const Duration(hours: 6)),
            isRead: true,
          ),
        ],
      ),
    ];
  }

  String _generateId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  void dispose() {
    _conversationsController.close();
    _activeConversationController.close();
  }
}
