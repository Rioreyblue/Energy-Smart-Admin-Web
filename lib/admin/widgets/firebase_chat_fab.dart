import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../constants/constant.dart';
import '../services/firebase_chat_service.dart';
import '../models/firebase_chat_models.dart';
import '../../utils/logger.dart';

class FirebaseChatFAB extends StatefulWidget {
  final Function(int) onNavigateToChat;

  const FirebaseChatFAB({super.key, required this.onNavigateToChat});

  @override
  State<FirebaseChatFAB> createState() => _FirebaseChatFABState();
}

class _FirebaseChatFABState extends State<FirebaseChatFAB>
    with SingleTickerProviderStateMixin {
  final FirebaseChatService _chatService = FirebaseChatService();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  ChatStatistics? _statistics;
  int _unreadCount = 0;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeChatService();
  }

  void _setupAnimations() {
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
  }

  Future<void> _initializeChatService() async {
    try {
      await _chatService.initialize();

      // Listen to statistics stream
      _chatService.statisticsStream.listen((statistics) {
        if (mounted) {
          final newUnreadCount = statistics.unreadMessages;

          setState(() {
            _statistics = statistics;
            _isInitialized = true;
          });

          // Animate when new messages arrive
          if (newUnreadCount > _unreadCount) {
            _animateButton();
          }

          _unreadCount = newUnreadCount;
        }
      });
    } catch (e) {
      Logger.error('Error initializing Firebase chat service', e);
      setState(() {
        _isInitialized =
            true; // Still show the button even if initialization fails
      });
    }
  }

  void _animateButton() {
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _chatService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const SizedBox.shrink(); // Don't show until initialized
    }

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
                    widget.onNavigateToChat(
                      4,
                    ); // Index 4 is Firebase Chat Support
                  },
                  backgroundColor: AppColor.accentGreen,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  heroTag: "firebase_chat_fab", // Unique hero tag
                  tooltip: 'Chat Support',
                  child: const Icon(Iconsax.message, size: 24),
                ),
                if (_statistics != null && _statistics!.unreadMessages > 0)
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
                        _statistics!.unreadMessages > 99
                            ? '99+'
                            : '${_statistics!.unreadMessages}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                // Priority indicator for urgent messages
                if (_statistics != null &&
                    (_statistics!.priorityBreakdown[ChatPriority.urgent] ?? 0) >
                        0)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColor.mediumConsumption,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Iconsax.warning_2,
                        size: 12,
                        color: Colors.white,
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

/// Enhanced chat statistics widget for dashboard
class ChatStatisticsCard extends StatefulWidget {
  const ChatStatisticsCard({super.key});

  @override
  State<ChatStatisticsCard> createState() => _ChatStatisticsCardState();
}

class _ChatStatisticsCardState extends State<ChatStatisticsCard> {
  final FirebaseChatService _chatService = FirebaseChatService();
  ChatStatistics? _statistics;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      await _chatService.initialize();

      _chatService.statisticsStream.listen((statistics) {
        if (mounted) {
          setState(() {
            _statistics = statistics;
          });
        }
      });
    } catch (e) {
      Logger.error('Error initializing chat statistics', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_statistics == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColor.accentGreen),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Iconsax.message,
                  color: AppColor.accentGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Chat Support',
                  style: ResponsiveText.body(context).copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColor.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  'Total Chats',
                  '${_statistics!.totalChats}',
                  AppColor.primary,
                ),
                _buildStatItem(
                  'Active',
                  '${_statistics!.activeChats}',
                  AppColor.accentGreen,
                ),
                _buildStatItem(
                  'Unread',
                  '${_statistics!.unreadMessages}',
                  AppColor.accentRed,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPriorityBreakdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: ResponsiveText.title(
            context,
          ).copyWith(fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style: ResponsiveText.caption(
            context,
          ).copyWith(color: AppColor.textSecondary),
        ),
      ],
    );
  }

  Widget _buildPriorityBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Priority Breakdown',
          style: ResponsiveText.caption(context).copyWith(
            fontWeight: FontWeight.w600,
            color: AppColor.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children:
              ChatPriority.values.map((priority) {
                final count = _statistics!.priorityBreakdown[priority] ?? 0;
                if (count == 0) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _getPriorityColor(priority),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${priority.name.toUpperCase()}: $count',
                        style: ResponsiveText.caption(
                          context,
                        ).copyWith(fontSize: 10, color: AppColor.textSecondary),
                      ),
                    ],
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Color _getPriorityColor(ChatPriority priority) {
    switch (priority) {
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

  @override
  void dispose() {
    _chatService.dispose();
    super.dispose();
  }
}
