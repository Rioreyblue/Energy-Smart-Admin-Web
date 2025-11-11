import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../constants/constant.dart';
import '../models/chat_message_model.dart';
import '../services/chat_service.dart';

class FloatingChatButton extends StatefulWidget {
  final VoidCallback onPressed;

  const FloatingChatButton({super.key, required this.onPressed});

  @override
  State<FloatingChatButton> createState() => _FloatingChatButtonState();
}

class _FloatingChatButtonState extends State<FloatingChatButton>
    with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  StreamSubscription<List<ChatConversation>>? _conversationSubscription;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  int _unreadCount = 0;
  String? _adminId;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _initializeListener();
  }

  void _animateButton() {
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
  }

  Future<void> _initializeListener() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _chatService.initialize();

    _adminId = user.uid;
    _setUnreadCount();

    _conversationSubscription = _chatService.conversationsStream.listen((
      conversations,
    ) {
      if (!mounted || _adminId == null) return;

      final newUnreadCount = _chatService.getTotalUnreadMessagesCount(
        _adminId!,
      );
      if (newUnreadCount != _unreadCount) {
        final previousCount = _unreadCount;
        setState(() {
          _unreadCount = newUnreadCount;
        });

        // Animate when new messages arrive
        if (newUnreadCount > previousCount) {
          _animateButton();
        }
      }
    });
  }

  void _setUnreadCount() {
    if (_adminId == null) return;
    final count = _chatService.getTotalUnreadMessagesCount(_adminId!);
    if (count != _unreadCount && mounted) {
      setState(() {
        _unreadCount = count;
      });
    }
  }

  @override
  void dispose() {
    _conversationSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: Stack(
              children: [
                FloatingActionButton(
                  onPressed: () {
                    _animateButton();
                    widget.onPressed();
                  },
                  backgroundColor: AppColor.accentGreen,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  child: const Icon(Iconsax.message, size: 24),
                ),
                if (_unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColor.accentRed,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      child: Text(
                        _unreadCount > 99 ? '99+' : '$_unreadCount',
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
          ),
        );
      },
    );
  }
}

class ChatSupportFAB extends StatelessWidget {
  final Function(int) onNavigateToChat;

  const ChatSupportFAB({super.key, required this.onNavigateToChat});

  @override
  Widget build(BuildContext context) {
    return FloatingChatButton(
      onPressed: () => onNavigateToChat(4), // Index 4 is Chat Support
    );
  }
}
