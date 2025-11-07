import 'package:flutter/material.dart';
import '../services/firebase_chat_service.dart';
import '../services/firebase_auth_service.dart';
import '../models/firebase_chat_models.dart';

/// Example implementation showing how to use the Firebase Chat System
class FirebaseChatExample extends StatefulWidget {
  const FirebaseChatExample({super.key});

  @override
  State<FirebaseChatExample> createState() => _FirebaseChatExampleState();
}

class _FirebaseChatExampleState extends State<FirebaseChatExample> {
  final FirebaseChatService _chatService = FirebaseChatService();
  final FirebaseAuthService _authService = FirebaseAuthService();

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize chat service
      await _chatService.initialize();

      // Listen to real-time updates
      _setupListeners();
    } catch (e) {
      print('Error initializing services: $e');
    }
  }

  void _setupListeners() {
    // Listen to chats
    _chatService.chatsStream.listen((chats) {
      print('Received ${chats.length} chats');
      for (final chat in chats) {
        print('Chat: ${chat.subject} - Status: ${chat.status.name}');
      }
    });

    // Listen to statistics
    _chatService.statisticsStream.listen((stats) {
      print(
        'Statistics: ${stats.totalChats} total, ${stats.unreadMessages} unread',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Chat Example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Firebase Chat System Examples',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Authentication Examples
            _buildSection('Authentication', [
              ElevatedButton(
                onPressed: _signInExample,
                child: const Text('Sign In as Admin'),
              ),
              ElevatedButton(
                onPressed: _createAdminExample,
                child: const Text('Create Test Admin'),
              ),
              ElevatedButton(
                onPressed: _signOutExample,
                child: const Text('Sign Out'),
              ),
            ]),

            const SizedBox(height: 20),

            // Chat Examples
            _buildSection('Chat Operations', [
              ElevatedButton(
                onPressed: _createChatExample,
                child: const Text('Create Test Chat'),
              ),
              ElevatedButton(
                onPressed: _sendMessageExample,
                child: const Text('Send Test Message'),
              ),
              ElevatedButton(
                onPressed: _updateChatStatusExample,
                child: const Text('Update Chat Status'),
              ),
            ]),

            const SizedBox(height: 20),

            // Statistics Example
            _buildSection('Statistics', [
              ElevatedButton(
                onPressed: _showStatisticsExample,
                child: const Text('Show Chat Statistics'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        ...children.map(
          (child) =>
              Padding(padding: const EdgeInsets.only(bottom: 8), child: child),
        ),
      ],
    );
  }

  // Authentication Examples
  Future<void> _signInExample() async {
    try {
      final user = await _authService.signInWithEmailAndPassword(
        email: 'admin@test.com',
        password: 'password123',
      );

      if (user != null) {
        _showSnackBar('Signed in as ${user.name}');
      }
    } catch (e) {
      _showSnackBar('Sign in failed: $e');
    }
  }

  Future<void> _createAdminExample() async {
    try {
      final admin = await _authService.createTestAdmin(
        email: 'testadmin@energysmart.com',
        password: 'securePassword123',
      );

      if (admin != null) {
        _showSnackBar('Created admin: ${admin.name}');
      }
    } catch (e) {
      _showSnackBar('Admin creation failed: $e');
    }
  }

  Future<void> _signOutExample() async {
    try {
      await _authService.signOut();
      _showSnackBar('Signed out successfully');
    } catch (e) {
      _showSnackBar('Sign out failed: $e');
    }
  }

  // Chat Examples
  Future<void> _createChatExample() async {
    try {
      final chatId = await _chatService.createChat(
        userId: 'test_user_123',
        subject: 'Test Support Request',
        priority: ChatPriority.normal,
      );

      _showSnackBar('Created chat: $chatId');
    } catch (e) {
      _showSnackBar('Chat creation failed: $e');
    }
  }

  Future<void> _sendMessageExample() async {
    try {
      // This would use an actual chat ID in practice
      await _chatService.sendMessage(
        chatId: 'example_chat_id',
        text: 'Hello! This is a test message from the admin.',
      );

      _showSnackBar('Message sent successfully');
    } catch (e) {
      _showSnackBar('Message sending failed: $e');
    }
  }

  Future<void> _updateChatStatusExample() async {
    try {
      await _chatService.updateChatStatus('example_chat_id', ChatStatus.closed);

      _showSnackBar('Chat status updated to closed');
    } catch (e) {
      _showSnackBar('Status update failed: $e');
    }
  }

  // Statistics Example
  void _showStatisticsExample() {
    // Listen to statistics stream and show in dialog
    _chatService.statisticsStream.take(1).listen((stats) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Chat Statistics'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Chats: ${stats.totalChats}'),
                  Text('Active Chats: ${stats.activeChats}'),
                  Text('Unread Messages: ${stats.unreadMessages}'),
                  Text(
                    'Average Response Time: ${stats.averageResponseTime.toStringAsFixed(2)} minutes',
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Priority Breakdown:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...stats.priorityBreakdown.entries.map(
                    (entry) =>
                        Text('${entry.key.name.toUpperCase()}: ${entry.value}'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _chatService.dispose();
    super.dispose();
  }
}

/// Example of how to integrate Firebase Chat into existing screens
class ChatIntegrationExample {
  /// Add this to your dashboard to show chat statistics
  static Widget buildChatStatisticsCard() {
    return StreamBuilder<ChatStatistics>(
      stream: FirebaseChatService().statisticsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final stats = snapshot.data!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chat Support',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem('Total', '${stats.totalChats}'),
                    _buildStatItem('Active', '${stats.activeChats}'),
                    _buildStatItem('Unread', '${stats.unreadMessages}'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(label),
      ],
    );
  }

  /// Add this to show real-time chat notifications
  static Widget buildChatNotificationListener() {
    return StreamBuilder<List<FirebaseChat>>(
      stream: FirebaseChatService().chatsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final chats = snapshot.data!;
        final unreadCount = chats.fold<int>(
          0,
          (sum, chat) =>
              sum + (chat.unreadCount.values.fold(0, (a, b) => a + b)),
        );

        if (unreadCount > 0) {
          // Show notification or update UI
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('You have $unreadCount unread messages'),
                action: SnackBarAction(
                  label: 'View',
                  onPressed: () {
                    // Navigate to chat screen
                  },
                ),
              ),
            );
          });
        }

        return const SizedBox.shrink();
      },
    );
  }
}
