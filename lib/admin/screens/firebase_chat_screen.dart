import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../constants/constant.dart';
import '../models/firebase_chat_models.dart';
import '../services/firebase_chat_service.dart';
import '../utils/responsive_layout.dart';
import '../../utils/logger.dart';

class FirebaseChatScreen extends StatefulWidget {
  const FirebaseChatScreen({super.key});

  @override
  State<FirebaseChatScreen> createState() => _FirebaseChatScreenState();
}

class _FirebaseChatScreenState extends State<FirebaseChatScreen> {
  final FirebaseChatService _chatService = FirebaseChatService();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<FirebaseUser> _allUsers = [];
  List<FirebaseUser> _filteredUsers = [];
  List<FirebaseChat> _chats = [];
  List<FirebaseChatMessage> _messages = [];
  Map<String, FirebaseChat> _userChatsMap = {}; // Map userId -> chat
  FirebaseChat? _selectedChat;
  FirebaseUser? _selectedUser;
  bool _isLoading = true;
  bool _isUploadingImage = false;
  String? _errorMessage;
  String _searchQuery = '';
  final ImagePicker _imagePicker = ImagePicker();
  StreamSubscription<List<FirebaseUser>>? _usersSubscription;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _messageController.dispose();
    _usersSubscription?.cancel();
    _chatService.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterUsers();
    });
  }

  void _filterUsers() {
    if (_searchQuery.isEmpty) {
      _filteredUsers = List<FirebaseUser>.from(_allUsers);
    } else {
      _filteredUsers =
          _allUsers.where((user) {
            final name = user.name.toLowerCase();
            final email = user.email.toLowerCase();
            return name.contains(_searchQuery) || email.contains(_searchQuery);
          }).toList();
    }

    _filteredUsers = _sortUsersByActivity(_filteredUsers);
  }

  Future<void> _initializeChat() async {
    // Initialize service first
    try {
      await _chatService.initialize();
    } catch (e) {
      Logger.error('Error initializing chat', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    // Listen to all users stream
    _usersSubscription = _chatService.getAllUsersStream().listen(
      (users) {
        if (mounted) {
          setState(() {
            _allUsers = _sortUsersByActivity(users);
            _filterUsers();
            _isLoading = false;
          });
          _loadChatsForUsers();
        }
      },
      onError: (error) {
        Logger.error('Error loading users', error);
        if (mounted) {
          setState(() {
            _isLoading = false;
            _allUsers = [];
            _filteredUsers = [];
          });
        }
      },
    );

    // Listen to chats to update user chat map
    _chatService.chatsStream.listen((chats) {
      if (mounted) {
        setState(() {
          _chats = chats;
          _updateUserChatsMap();
        });
      }
    });

    // Listen to messages
    _chatService.messagesStream.listen(
      (messages) {
        if (mounted) {
          setState(() {
            _messages = messages;
            _errorMessage = null; // Clear error on success
          });
        }
      },
      onError: (error, stackTrace) {
        Logger.error('[ChatScreen] Error in messages stream', error);
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load messages: ${error.toString()}';
            _messages = [];
          });

          // Show error snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_errorMessage!),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () {
                  if (_selectedChat != null) {
                    _chatService.listenToMessages(_selectedChat!.id);
                  }
                },
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      },
    );

    // Initialize service
    try {
      await _chatService.initialize();
    } catch (e) {
      Logger.error('Error initializing chat', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }

    // Timeout fallback
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _updateUserChatsMap() {
    _userChatsMap.clear();
    for (final chat in _chats) {
      // Find the user ID (not 'admin' and not current admin user ID)
      final otherUserId = chat.participants.firstWhere(
        (id) => id != 'admin' && id != _chatService.currentUser?.id,
        orElse: () => '',
      );
      if (otherUserId.isNotEmpty) {
        _userChatsMap[otherUserId] = chat;
      }
    }

    _filterUsers();
  }

  List<FirebaseUser> _sortUsersByActivity(List<FirebaseUser> users) {
    final sortedUsers = List<FirebaseUser>.from(users);
    sortedUsers.sort((a, b) {
      final aTimestamp = _getUserActivityTimestamp(a);
      final bTimestamp = _getUserActivityTimestamp(b);
      return bTimestamp.compareTo(aTimestamp);
    });
    return sortedUsers;
  }

  DateTime _getUserActivityTimestamp(FirebaseUser user) {
    final chat = _userChatsMap[user.id];
    final chatTimestamp = chat?.lastMessageTime;
    if (chatTimestamp != null) {
      return chatTimestamp;
    }

    return user.lastMessageTime ?? user.lastSeen;
  }

  Future<void> _loadChatsForUsers() async {
    // Load existing chats to map them to users
    _updateUserChatsMap();
  }

  Future<void> _selectUser(FirebaseUser user) async {
    setState(() {
      _selectedUser = user;
      _isLoading = true;
    });

    try {
      // Get or create chat thread (per admin guide structure)
      final chatId = await _chatService.getOrCreateChatWithUser(user.id);

      // Get chat object from _userChatsMap or create a temporary one
      FirebaseChat chat =
          _userChatsMap[user.id] ??
          FirebaseChat(
            id: chatId,
            participants: [user.id, 'admin'],
            lastMessageTime: DateTime.now(),
            createdAt: DateTime.now(),
            unreadCount: {},
            status: ChatStatus.active,
            priority: ChatPriority.normal,
          );

      setState(() {
        _selectedChat = chat;
        _selectedUser = user;
      });

      // Listen to chat messages (per admin guide: chats/{chatId}/messages)
      _chatService.listenToUserMessages(user.id, chatId: chatId);
    } catch (e) {
      Logger.error('Error selecting user', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    return Scaffold(
      backgroundColor: AppColor.surface,
      body: ResponsiveLayout(
        mobile: _buildMobileLayout(),
        desktop: _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return _selectedChat == null ? _buildUsersList() : _buildChatView();
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        SizedBox(width: 350, child: _buildUsersList()),
        const VerticalDivider(width: 1),
        Expanded(
          child: _selectedChat == null ? _buildEmptyState() : _buildChatView(),
        ),
      ],
    );
  }

  Widget _buildUsersList() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          Expanded(
            child:
                _isLoading && _filteredUsers.isEmpty
                    ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColor.accentGreen,
                        ),
                      ),
                    )
                    : _filteredUsers.isEmpty
                    ? _buildEmptyUsers()
                    : ListView.builder(
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        final chat = _userChatsMap[user.id];
                        final unreadCount =
                            chat != null
                                ? (chat.unreadCount[_chatService
                                        .currentUser
                                        ?.id] ??
                                    0)
                                : 0;

                        return _buildUserListItem(user, chat, unreadCount);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search users...',
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          if (ResponsiveHelper.isMobile(context) && _selectedChat != null)
            IconButton(
              onPressed: () {
                setState(() {
                  _selectedChat = null;
                  _selectedUser = null;
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
                  '${_filteredUsers.length} users',
                  style: ResponsiveText.caption(
                    context,
                  ).copyWith(color: AppColor.textSecondary),
                ),
              ],
            ),
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

  Widget _buildChatView() {
    if (_selectedChat == null || _selectedUser == null) {
      return _buildEmptyState();
    }

    // Use the selected user directly
    final otherUser = _selectedUser;

    return Column(
      children: [
        _buildChatHeader(otherUser),
        // Error banner
        if (_errorMessage != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.red.shade50,
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (_selectedChat != null) {
                      setState(() => _errorMessage = null);
                      _chatService.listenToMessages(_selectedChat!.id);
                    }
                  },
                  child: const Text('Retry'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Container(
            color: Colors.grey.shade50,
            child:
                _messages.isEmpty && _errorMessage == null
                    ? _buildEmptyMessages()
                    : _messages.isEmpty && _errorMessage != null
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load messages',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              if (_selectedChat != null) {
                                setState(() => _errorMessage = null);
                                _chatService.listenToMessages(
                                  _selectedChat!.id,
                                );
                              }
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        // Check if message is from admin using senderId (per admin guide)
                        final isAdmin = message.senderId == 'admin';
                        return _buildMessageBubble(message, isAdmin);
                      },
                    ),
          ),
        ),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildChatHeader(FirebaseUser? otherUser) {
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
              onPressed: () => setState(() => _selectedChat = null),
              icon: const Icon(Iconsax.arrow_left_2),
            ),
          CircleAvatar(
            backgroundColor: AppColor.primary,
            backgroundImage:
                otherUser?.photoUrl != null
                    ? NetworkImage(otherUser!.photoUrl!)
                    : null,
            child:
                otherUser?.photoUrl == null
                    ? Text(
                      (otherUser?.name != null && otherUser!.name.isNotEmpty
                          ? otherUser.name
                              .split(' ')
                              .where((e) => e.isNotEmpty)
                              .map((e) => e[0])
                              .take(2)
                              .join()
                          : otherUser?.email != null &&
                              otherUser!.email.isNotEmpty
                          ? otherUser.email[0].toUpperCase()
                          : '?'),
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
                  otherUser?.name ?? 'Unknown User',
                  style: ResponsiveText.body(
                    context,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  otherUser?.email ?? '',
                  style: ResponsiveText.caption(
                    context,
                  ).copyWith(color: AppColor.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(FirebaseChatMessage message, bool isAdmin) {
    final isImageMessage = message.type == MessageType.image;
    final imageUrl =
        message.attachments?.isNotEmpty == true
            ? message.attachments!.first.url
            : null;

    return Align(
      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            isImageMessage
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color:
              isImageMessage
                  ? Colors.transparent
                  : (isAdmin ? AppColor.accentGreen : Colors.white),
          borderRadius: BorderRadius.circular(16),
          boxShadow:
              isImageMessage
                  ? []
                  : [
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
            if (isImageMessage && imageUrl != null)
              GestureDetector(
                onTap: () => _showFullSizeImage(imageUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder:
                            (context, url) => Container(
                              width: double.infinity,
                              height: 200,
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                        errorWidget:
                            (context, url, error) => Container(
                              width: double.infinity,
                              height: 200,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.error),
                            ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(128),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Iconsax.eye,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Text(
                message.text,
                style: ResponsiveText.body(context).copyWith(
                  fontStyle:
                      message.text == '[Message unsent]'
                          ? FontStyle.italic
                          : FontStyle.normal,
                  color:
                      message.text == '[Message unsent]'
                          ? Colors.grey.shade600
                          : (isAdmin ? Colors.white : AppColor.textPrimary),
                ),
              ),
            if (message.text.isNotEmpty && isImageMessage) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  message.text,
                  style: ResponsiveText.body(context).copyWith(
                    color: isAdmin ? Colors.white : AppColor.textPrimary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isImageMessage ? 12 : 0,
              ),
              child: Text(
                _formatTime(message.timestamp),
                style: ResponsiveText.caption(context).copyWith(
                  color:
                      isAdmin
                          ? Colors.white.withAlpha(179)
                          : AppColor.textSecondary,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _isUploadingImage ? null : _pickAndSendImage,
            icon:
                _isUploadingImage
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Iconsax.gallery),
            color: AppColor.accentGreen,
            style: IconButton.styleFrom(
              backgroundColor: AppColor.accentGreen.withAlpha(26),
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sendMessage,
            icon: const Icon(Iconsax.send_1),
            color: AppColor.accentGreen,
            style: IconButton.styleFrom(
              backgroundColor: AppColor.accentGreen.withAlpha(26),
              padding: const EdgeInsets.all(12),
            ),
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
        ],
      ),
    );
  }

  Widget _buildUserListItem(
    FirebaseUser user,
    FirebaseChat? chat,
    int unreadCount,
  ) {
    final isSelected = _selectedUser?.id == user.id;
    // Prioritize chat metadata (per admin guide structure)
    final lastMessage =
        chat?.lastMessage ?? user.lastMessage ?? 'No messages yet';
    final lastMessageTime =
        chat?.lastMessageTime ?? user.lastMessageTime ?? DateTime.now();
    // Get unread count from chat document (per admin guide structure)
    final chatUnreadCount =
        chat?.unreadCount != null ? (chat!.unreadCount['admin'] ?? 0) : 0;
    final displayUnreadCount =
        chatUnreadCount > 0 ? chatUnreadCount : unreadCount;

    return InkWell(
      onTap: () => _selectUser(user),
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
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColor.primary,
              backgroundImage:
                  user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
              child:
                  user.photoUrl == null
                      ? Text(
                        (user.name.isNotEmpty
                            ? user.name
                                .split(' ')
                                .where((e) => e.isNotEmpty)
                                .map((e) => e[0])
                                .take(2)
                                .join()
                            : user.email.isNotEmpty
                            ? user.email[0].toUpperCase()
                            : '?'),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.name,
                          style: ResponsiveText.body(context).copyWith(
                            fontWeight:
                                unreadCount > 0
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                            color: AppColor.textPrimary,
                          ),
                        ),
                      ),
                      if (displayUnreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColor.accentRed,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$displayUnreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMessage,
                    style: ResponsiveText.body(context).copyWith(
                      color: AppColor.textSecondary,
                      fontWeight:
                          displayUnreadCount > 0
                              ? FontWeight.w500
                              : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(lastMessageTime),
                    style: ResponsiveText.caption(
                      context,
                    ).copyWith(color: AppColor.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyUsers() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search,
            size: 64,
            color: AppColor.textSecondary.withAlpha(128),
          ),
          const SizedBox(height: 16),
          Text(
            'No users found',
            style: ResponsiveText.title(
              context,
            ).copyWith(color: AppColor.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Users will appear here when they register',
            style: ResponsiveText.body(
              context,
            ).copyWith(color: AppColor.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMessages() {
    return Center(
      child: Text(
        'No messages yet. Start the conversation!',
        style: ResponsiveText.body(
          context,
        ).copyWith(color: AppColor.textSecondary),
      ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || _selectedUser == null) return;

    // Use new structure: send message to user
    _chatService.sendMessageToUser(userId: _selectedUser!.id, text: text);

    _messageController.clear();
  }

  Future<void> _pickAndSendImage() async {
    if (_selectedUser == null) return;

    try {
      // Show option to pick from gallery or camera
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder:
            (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Iconsax.gallery),
                    title: const Text('Gallery'),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                  ListTile(
                    leading: const Icon(Iconsax.camera),
                    title: const Text('Camera'),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                ],
              ),
            ),
      );

      if (source == null) return;

      // Pick image
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (pickedFile == null) return;

      setState(() {
        _isUploadingImage = true;
      });

      // Send image using new structure
      await _chatService.sendImageMessageToUser(
        userId: _selectedUser!.id,
        imageFile: File(pickedFile.path),
        caption:
            _messageController.text.trim().isEmpty
                ? null
                : _messageController.text.trim(),
      );

      _messageController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image sent successfully'),
            backgroundColor: AppColor.accentGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      Logger.error('Error picking/sending image', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending image: $e'),
            backgroundColor: AppColor.accentRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  void _showFullSizeImage(String imageUrl) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      placeholder:
                          (context, url) => Container(
                            width: double.infinity,
                            height: 400,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      errorWidget:
                          (context, url, error) => Container(
                            width: double.infinity,
                            height: 400,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.error, size: 48),
                          ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withAlpha(128),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
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
