import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../constants/constant.dart';
import '../models/chat_message_model.dart';
import '../services/chat_service.dart';
import '../utils/responsive_layout.dart';
import '../widgets/chat_widgets.dart';

class ChatSupportScreen extends StatefulWidget {
  const ChatSupportScreen({super.key});

  @override
  State<ChatSupportScreen> createState() => _ChatSupportScreenState();
}

class _ChatSupportScreenState extends State<ChatSupportScreen> {
  final ChatService _chatService = ChatService();
  List<ChatConversation> _conversations = [];
  ChatConversation? _selectedConversation;
  bool _isLoading = true;
  Object? _error;
  String? _adminId;
  StreamSubscription<List<ChatConversation>>? _conversationSub;
  StreamSubscription<ChatConversation?>? _activeConversationSub;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _adminId = FirebaseAuth.instance.currentUser?.uid;
      await _chatService.initialize();

      _conversationSub?.cancel();
      _conversationSub = _chatService.conversationsStream.listen(
        (conversations) {
          if (!mounted) return;
          setState(() {
            _conversations = conversations;
            _isLoading = false;
          });
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _error = error;
            _isLoading = false;
          });
        },
      );

      _activeConversationSub?.cancel();
      _activeConversationSub = _chatService.activeConversationStream.listen(
        (conversation) {
          if (!mounted) return;
          setState(() {
            _selectedConversation = conversation;
          });
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _error = error;
          });
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColor.surface,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColor.accentGreen),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColor.surface,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Iconsax.warning_2,
                size: 48,
                color: AppColor.accentRed,
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to load conversations',
                style: ResponsiveText.title(context),
              ),
              const SizedBox(height: 8),
              Text(
                '$_error',
                style: ResponsiveText.body(
                  context,
                ).copyWith(color: AppColor.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _initializeChat,
                icon: const Icon(Iconsax.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColor.surface,
      body: ResponsiveLayout(
        mobile: _buildMobileLayout(),
        desktop: _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return _selectedConversation == null
        ? _buildConversationsList()
        : _buildChatView();
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        SizedBox(width: 350, child: _buildConversationsList()),
        const VerticalDivider(width: 1),
        Expanded(
          child:
              _selectedConversation == null
                  ? _buildEmptyState()
                  : _buildChatView(),
        ),
      ],
    );
  }

  Widget _buildConversationsList() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildConversationsHeader(),
          _buildFilterTabs(),
          Expanded(
            child:
                _conversations.isEmpty
                    ? _buildEmptyConversations()
                    : ListView.builder(
                      itemCount: _conversations.length,
                      itemBuilder: (context, index) {
                        final conversation = _conversations[index];
                        return ConversationListItem(
                          conversation: conversation,
                          adminId: _adminId,
                          isSelected:
                              _selectedConversation?.id == conversation.id,
                          onTap: () => _selectConversation(conversation),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          if (ResponsiveHelper.isMobile(context) &&
              _selectedConversation != null)
            IconButton(
              onPressed: () {
                setState(() {
                  _selectedConversation = null;
                });
              },
              icon: const Icon(Iconsax.arrow_left_2),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chat Support',
                  style: ResponsiveText.title(
                    context,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_conversations.length} conversations',
                  style: ResponsiveText.caption(
                    context,
                  ).copyWith(color: AppColor.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _showFilterOptions,
            icon: const Icon(Iconsax.filter),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _initializeChat();
            },
            icon: const Icon(Iconsax.refresh),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildFilterChip('All', _conversations.length, true),
          const SizedBox(width: 8),
          _buildFilterChip(
            'Open',
            _conversations.where((c) => c.status == ChatStatus.open).length,
            false,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'Unread',
            _conversations.where((c) => _unreadCountFor(c) > 0).length,
            false,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int count, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? AppColor.accentGreen.withAlpha(26) : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColor.accentGreen : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColor.accentGreen : AppColor.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 12,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:
                    isSelected ? AppColor.accentGreen : AppColor.textSecondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChatView() {
    if (_selectedConversation == null) {
      return _buildEmptyState();
    }

    final messages = _selectedConversation!.messages;

    return Column(
      children: [
        _buildChatHeader(),
        Expanded(
          child: Container(
            color: Colors.grey.shade50,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return ChatBubble(
                  message: message,
                  isAdmin: message.senderRole == 'admin',
                );
              },
            ),
          ),
        ),
        ChatInput(
          onSendMessage: _sendMessage,
          isEnabled: _selectedConversation!.status != ChatStatus.closed,
        ),
      ],
    );
  }

  Widget _buildChatHeader() {
    final conversation = _selectedConversation!;
    final displayName = conversation.senderName ?? conversation.userName;
    final displayEmail =
        conversation.senderEmail ?? conversation.userEmail ?? '';
    final photoUrl = conversation.senderPhotoUrl;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          if (ResponsiveHelper.isMobile(context))
            IconButton(
              onPressed: () {
                setState(() {
                  _selectedConversation = null;
                });
              },
              icon: const Icon(Iconsax.arrow_left_2),
            ),
          CircleAvatar(
            backgroundColor: AppColor.primary,
            backgroundImage:
                photoUrl != null && photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
            child:
                (photoUrl == null || photoUrl.isEmpty)
                    ? Text(
                      displayName
                          .split(' ')
                          .where((e) => e.isNotEmpty)
                          .map((e) => e[0])
                          .take(2)
                          .join()
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                    : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: ResponsiveText.body(
                    context,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                if (displayEmail.isNotEmpty)
                  Text(
                    displayEmail,
                    style: ResponsiveText.caption(
                      context,
                    ).copyWith(color: AppColor.textSecondary),
                  ),
                if (conversation.subject != null)
                  Text(
                    conversation.subject!,
                    style: ResponsiveText.caption(
                      context,
                    ).copyWith(color: AppColor.textSecondary),
                  ),
                if (displayEmail.isEmpty && conversation.subject == null)
                  Text(
                    'Support conversation',
                    style: ResponsiveText.caption(
                      context,
                    ).copyWith(color: AppColor.textSecondary),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: _handleChatAction,
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'status',
                    child: Row(
                      children: [
                        const Icon(Iconsax.status, size: 16),
                        const SizedBox(width: 8),
                        const Text('Change Status'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'priority',
                    child: Row(
                      children: [
                        const Icon(Iconsax.flag, size: 16),
                        const SizedBox(width: 8),
                        const Text('Change Priority'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'assign',
                    child: Row(
                      children: [
                        const Icon(Iconsax.user, size: 16),
                        const SizedBox(width: 8),
                        const Text('Assign to Admin'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.message,
            size: 64,
            color: AppColor.textSecondary.withAlpha(128),
          ),
          const SizedBox(height: 16),
          Text(
            'Select a conversation',
            style: ResponsiveText.title(
              context,
            ).copyWith(color: AppColor.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a conversation from the list to start chatting',
            style: ResponsiveText.body(
              context,
            ).copyWith(color: AppColor.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyConversations() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.message_question,
            size: 64,
            color: AppColor.textSecondary.withAlpha(128),
          ),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: ResponsiveText.title(
              context,
            ).copyWith(color: AppColor.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Customer support conversations will appear here',
            style: ResponsiveText.body(
              context,
            ).copyWith(color: AppColor.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _selectConversation(ChatConversation conversation) {
    _chatService.setActiveConversation(conversation.id);
  }

  Future<void> _sendMessage(String message) async {
    final conversation = _selectedConversation;
    if (conversation == null) return;
    await _chatService.sendMessage(
      conversationId: conversation.id,
      content: message,
    );
  }

  void _handleChatAction(String action) {
    if (_selectedConversation == null) return;

    switch (action) {
      case 'status':
        _showStatusDialog();
        break;
      case 'priority':
        _showPriorityDialog();
        break;
      case 'assign':
        _showAssignDialog();
        break;
    }
  }

  void _showStatusDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Change Status'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  ChatStatus.values.map((status) {
                    return RadioListTile<ChatStatus>(
                      title: Text(status.name.toUpperCase()),
                      value: status,
                      groupValue: _selectedConversation!.status,
                      onChanged: (value) async {
                        if (value == null) return;
                        Navigator.pop(context);
                        await _chatService.updateConversationStatus(
                          _selectedConversation!.id,
                          value,
                        );
                      },
                    );
                  }).toList(),
            ),
          ),
    );
  }

  void _showPriorityDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Change Priority'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  ChatPriority.values.map((priority) {
                    return RadioListTile<ChatPriority>(
                      title: Text(priority.name.toUpperCase()),
                      value: priority,
                      groupValue: _selectedConversation!.priority,
                      onChanged: (value) async {
                        if (value == null) return;
                        Navigator.pop(context);
                        await _chatService.updateConversationPriority(
                          _selectedConversation!.id,
                          value,
                        );
                      },
                    );
                  }).toList(),
            ),
          ),
    );
  }

  void _showAssignDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Assign to Admin'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_adminId != null)
                  ListTile(
                    leading: const Icon(Iconsax.user_add),
                    title: const Text('Assign to me'),
                    subtitle: const Text('Take ownership of this chat'),
                    onTap: () async {
                      Navigator.pop(context);
                      await _chatService.assignConversation(
                        _selectedConversation!.id,
                        _adminId!,
                      );
                    },
                  ),
                if (_selectedConversation!.assignedAdminId != null)
                  ListTile(
                    leading: const Icon(Iconsax.user_remove),
                    title: const Text('Unassign conversation'),
                    onTap: () async {
                      Navigator.pop(context);
                      await _chatService.unassignConversation(
                        _selectedConversation!.id,
                      );
                    },
                  ),
                const SizedBox(height: 8),
                const Text(
                  'More assignment options will be available once admin management is enabled.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Iconsax.status),
                  title: const Text('Filter by Status'),
                  onTap: () {
                    Navigator.pop(context);
                    // Implement status filter
                  },
                ),
                ListTile(
                  leading: const Icon(Iconsax.flag),
                  title: const Text('Filter by Priority'),
                  onTap: () {
                    Navigator.pop(context);
                    // Implement priority filter
                  },
                ),
                ListTile(
                  leading: const Icon(Iconsax.calendar),
                  title: const Text('Filter by Date'),
                  onTap: () {
                    Navigator.pop(context);
                    // Implement date filter
                  },
                ),
              ],
            ),
          ),
    );
  }

  @override
  void dispose() {
    _conversationSub?.cancel();
    _activeConversationSub?.cancel();
    _chatService.dispose();
    super.dispose();
  }

  int _unreadCountFor(ChatConversation conversation) {
    final adminKey = _adminId ?? 'admin';
    return conversation.unreadFor(adminKey);
  }
}
