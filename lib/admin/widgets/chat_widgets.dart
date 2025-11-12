import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../constants/constant.dart';
import '../models/chat_message_model.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isAdmin;

  const ChatBubble({super.key, required this.message, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment:
            isAdmin ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isAdmin) ...[
            _buildAvatar(message.senderPhotoUrl),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isAdmin ? AppColor.accentGreen : Colors.grey.shade100,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isAdmin ? 16 : 4),
                      bottomRight: Radius.circular(isAdmin ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(13),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isAdmin)
                        Text(
                          message.senderName,
                          style: ResponsiveText.caption(context).copyWith(
                            color: AppColor.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (!isAdmin) const SizedBox(height: 4),
                      Text(
                        message.content.isEmpty
                            ? (message.metadata?['placeholder'] as String?) ??
                                '[Message unavailable]'
                            : message.content,
                        style: ResponsiveText.body(context).copyWith(
                          color: isAdmin ? Colors.white : AppColor.textPrimary,
                          fontStyle:
                              message.metadata?['unsent'] == true
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                        ),
                      ),
                      if (message.attachments != null &&
                          message.attachments!.isNotEmpty)
                        ..._buildAttachments(),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.timestamp),
                      style: ResponsiveText.caption(
                        context,
                      ).copyWith(color: AppColor.textSecondary, fontSize: 11),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 4),
                      Icon(_statusIcon, size: 12, color: _statusColor),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isAdmin) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl, {String? fallbackInitials}) {
    final initials =
        fallbackInitials ??
        message.senderName.split(' ').map((e) => e[0]).take(2).join();
    return CircleAvatar(
      radius: 16,
      backgroundColor: isAdmin ? AppColor.accentGreen : AppColor.primary,
      backgroundImage:
          photoUrl != null && photoUrl.isNotEmpty
              ? NetworkImage(photoUrl)
              : null,
      child:
          (photoUrl == null || photoUrl.isEmpty)
              ? Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              )
              : null,
    );
  }

  List<Widget> _buildAttachments() {
    return message.attachments!.map((attachment) {
      final isImage =
          attachment.type == 'image' ||
          (attachment.mimeType?.startsWith('image/') ?? false);
      final icon = isImage ? Iconsax.image : Iconsax.document;
      final name =
          attachment.name.isNotEmpty ? attachment.name : attachment.url;

      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isAdmin ? Colors.white.withAlpha(25) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isAdmin ? Colors.white : AppColor.textPrimary,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 160,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isAdmin ? Colors.white : AppColor.textPrimary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  IconData get _statusIcon {
    switch (message.status) {
      case ChatMessageStatus.sending:
        return Iconsax.clock;
      case ChatMessageStatus.sent:
        return Iconsax.tick_square;
      case ChatMessageStatus.delivered:
        return Iconsax.tick_square;
      case ChatMessageStatus.seen:
        return Iconsax.tick_circle;
      case ChatMessageStatus.error:
        return Iconsax.info_circle;
    }
  }

  Color get _statusColor {
    switch (message.status) {
      case ChatMessageStatus.seen:
        return AppColor.accentGreen;
      case ChatMessageStatus.error:
        return AppColor.accentRed;
      default:
        return AppColor.textSecondary;
    }
  }
}

class ChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final bool isEnabled;

  const ChatInput({
    super.key,
    required this.onSendMessage,
    this.isEnabled = true,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  bool _isTyping = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: widget.isEnabled,
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                hintStyle: TextStyle(color: AppColor.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColor.accentGreen),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _isTyping = value.trim().isNotEmpty;
                });
              },
              onSubmitted: _sendMessage,
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: IconButton(
              onPressed:
                  _isTyping && widget.isEnabled
                      ? () => _sendMessage(_controller.text)
                      : null,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      _isTyping && widget.isEnabled
                          ? AppColor.accentGreen
                          : AppColor.disabled,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.send_1,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage(String message) {
    if (message.trim().isNotEmpty && widget.isEnabled) {
      widget.onSendMessage(message.trim());
      _controller.clear();
      setState(() {
        _isTyping = false;
      });
    }
  }
}

class ConversationListItem extends StatelessWidget {
  final ChatConversation conversation;
  final String? adminId;
  final bool isSelected;
  final VoidCallback onTap;

  const ConversationListItem({
    super.key,
    required this.conversation,
    required this.adminId,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = conversation.senderName ?? conversation.userName;
    final displayEmail =
        conversation.senderEmail ?? conversation.userEmail ?? '';
    final photoUrl = conversation.senderPhotoUrl;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColor.accentGreen.withAlpha(26) : null,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _getPriorityColor(),
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
                if (_unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColor.accentRed,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Text(
                        _unreadCount > 9 ? '9+' : '$_unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: ResponsiveText.body(context).copyWith(
                            fontWeight:
                                _unreadCount > 0
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                          ),
                        ),
                      ),
                      _buildStatusChip(),
                    ],
                  ),
                  if (displayEmail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      displayEmail,
                      style: ResponsiveText.caption(
                        context,
                      ).copyWith(color: AppColor.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    conversation.lastMessagePreview ??
                        conversation.subject ??
                        'No messages yet',
                    style: ResponsiveText.body(context).copyWith(
                      color: AppColor.textSecondary,
                      fontWeight:
                          _unreadCount > 0
                              ? FontWeight.w500
                              : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatTime(conversation.lastMessageAt),
                        style: ResponsiveText.caption(
                          context,
                        ).copyWith(color: AppColor.textSecondary, fontSize: 11),
                      ),
                      if (conversation.assignedAdminName != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Iconsax.user,
                          size: 12,
                          color: AppColor.textSecondary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          conversation.assignedAdminName!,
                          style: ResponsiveText.caption(context).copyWith(
                            color: AppColor.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    Color color;
    String text;

    switch (conversation.status) {
      case ChatStatus.open:
        color = AppColor.mediumConsumption;
        text = 'Open';
        break;
      case ChatStatus.inProgress:
        color = AppColor.primary;
        text = 'In Progress';
        break;
      case ChatStatus.resolved:
        color = AppColor.accentGreen;
        text = 'Resolved';
        break;
      case ChatStatus.closed:
        color = AppColor.textSecondary;
        text = 'Closed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getPriorityColor() {
    switch (conversation.priority) {
      case ChatPriority.low:
        return AppColor.lowConsumption;
      case ChatPriority.normal:
        return AppColor.primary;
      case ChatPriority.high:
        return AppColor.mediumConsumption;
      case ChatPriority.urgent:
        return AppColor.accentRed;
    }
  }

  int get _unreadCount {
    final key = adminId ?? 'admin';
    return conversation.unreadFor(key);
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
