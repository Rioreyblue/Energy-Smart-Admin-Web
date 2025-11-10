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

enum _ConversationQuickFilter { all, active, closed, highPriority, unassigned }

class FirebaseChatScreen extends StatefulWidget {
  const FirebaseChatScreen({super.key});

  @override
  State<FirebaseChatScreen> createState() => _FirebaseChatScreenState();
}

class _FirebaseChatScreenState extends State<FirebaseChatScreen> {
  final FirebaseChatService _chatService = FirebaseChatService();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<AdminChatThread> _allThreads = [];
  List<AdminChatThread> _filteredThreads = [];
  List<FirebaseChatMessage> _messages = [];
  AdminChatThread? _selectedThread;
  bool _isLoadingThreads = true;
  bool _isMessagesLoading = false;
  bool _isUploadingImage = false;
  String? _errorMessage;
  String _searchQuery = '';
  final ImagePicker _imagePicker = ImagePicker();
  StreamSubscription<List<AdminChatThread>>? _conversationSubscription;
  StreamSubscription<List<FirebaseChatMessage>>? _messagesSubscription;
  _ConversationQuickFilter _activeFilter = _ConversationQuickFilter.active;
  List<FirebaseUser> _adminUsers = [];
  bool _isLoadingAdmins = false;
  bool _isUpdatingStatus = false;
  bool _isUpdatingPriority = false;
  bool _isUpdatingAssignee = false;
  bool _hasAutoSelectedConversation = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadAdminUsers({bool force = false}) async {
    if (_isLoadingAdmins) return;
    if (!force && _adminUsers.isNotEmpty) return;
    setState(() {
      _isLoadingAdmins = true;
    });
    try {
      final admins = await _chatService.fetchAdminUsers(includeCurrent: true);
      if (!mounted) return;
      setState(() {
        _adminUsers = admins;
      });
    } catch (e, stackTrace) {
      Logger.error('Error loading admin users', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load admin list'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAdmins = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _messageController.dispose();
    _conversationSubscription?.cancel();
    _conversationSubscription = null;
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _chatService.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchQuery = _searchController.text.trim().toLowerCase();
    _updateFilteredThreads();
  }

  void _updateFilteredThreads() {
    setState(() {
      _filteredThreads = _applyFilters(_allThreads);
    });
  }

  Future<void> _initializeChat() async {
    try {
      await _chatService.initialize();
    } catch (e) {
      Logger.error('Error initializing chat', e);
      if (mounted) {
        setState(() {
          _isLoadingThreads = false;
        });
      }
      return;
    }

    _conversationSubscription = _chatService.conversationsStream.listen(
      (threads) {
        if (!mounted) return;

        final previousSelectedId = _selectedThread?.id;
        final updatedSelected =
            _selectedThread != null
                ? _findThreadById(threads, _selectedThread!.id)
                : null;

        setState(() {
          _allThreads = threads;
          _filteredThreads = _applyFilters(threads);
          _selectedThread = updatedSelected;
          _isLoadingThreads = false;
          if (updatedSelected == null) {
            _messages = [];
            _errorMessage = null;
            _isMessagesLoading = false;
          }
        });

        if (updatedSelected != null &&
            updatedSelected.id != previousSelectedId) {
          _chatService.listenToUserMessages(
            updatedSelected.user.id,
            chatId: updatedSelected.id,
          );
        }

        if (_selectedThread == null &&
            !_hasAutoSelectedConversation &&
            _filteredThreads.isNotEmpty) {
          _hasAutoSelectedConversation = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _filteredThreads.isNotEmpty) {
              _selectConversation(_filteredThreads.first);
            }
          });
        }
      },
      onError: (error) {
        Logger.error('Error loading conversations', error);
        if (!mounted) return;
        setState(() {
          _isLoadingThreads = false;
          _allThreads = [];
          _filteredThreads = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load conversations'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );

    _loadAdminUsers();

    _messagesSubscription = _chatService.messagesStream.listen(
      (messages) {
        if (mounted) {
          setState(() {
            _messages = messages;
            _errorMessage = null;
            _isMessagesLoading = false;
          });
        }
      },
      onError: (error, stackTrace) {
        Logger.error('[ChatScreen] Error in messages stream', error);
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load messages: ${error.toString()}';
            _messages = [];
            _isMessagesLoading = false;
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
                  if (_selectedThread != null) {
                    _chatService.listenToMessages(_selectedThread!.id);
                  }
                },
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      },
    );

    // Timeout fallback
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted && _isLoadingThreads) {
        setState(() {
          _isLoadingThreads = false;
        });
      }
    });
  }

  List<AdminChatThread> _applyFilters(List<AdminChatThread> source) {
    var result = List<AdminChatThread>.from(source);

    switch (_activeFilter) {
      case _ConversationQuickFilter.active:
        result =
            result
                .where((thread) => thread.status == ChatStatus.active)
                .toList();
        break;
      case _ConversationQuickFilter.closed:
        result =
            result
                .where((thread) => thread.status == ChatStatus.closed)
                .toList();
        break;
      case _ConversationQuickFilter.highPriority:
        result =
            result
                .where(
                  (thread) =>
                      thread.priority == ChatPriority.high ||
                      thread.priority == ChatPriority.urgent,
                )
                .toList();
        break;
      case _ConversationQuickFilter.unassigned:
        result =
            result
                .where((thread) => thread.chat.assignedAdminId == null)
                .toList();
        break;
      case _ConversationQuickFilter.all:
        break;
    }

    if (_searchQuery.isNotEmpty) {
      result =
          result.where((thread) {
            final name = thread.user.name.toLowerCase();
            final email = thread.user.email.toLowerCase();
            final subject = thread.chat.subject?.toLowerCase() ?? '';
            return name.contains(_searchQuery) ||
                email.contains(_searchQuery) ||
                subject.contains(_searchQuery);
          }).toList();
    }

    result.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

    return result;
  }

  AdminChatThread? _findThreadById(List<AdminChatThread> threads, String id) {
    for (final thread in threads) {
      if (thread.id == id) {
        return thread;
      }
    }
    return null;
  }

  void _onFilterSelected(_ConversationQuickFilter filter) {
    setState(() {
      _activeFilter =
          _activeFilter == filter ? _ConversationQuickFilter.all : filter;
      _filteredThreads = _applyFilters(_allThreads);
    });
  }

  Future<void> _refreshConversations() async {
    setState(() {
      _isLoadingThreads = true;
    });
    try {
      await _chatService.refreshConversations();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingThreads = false;
        });
      }
    }
  }

  Future<void> _selectConversation(AdminChatThread thread) async {
    setState(() {
      _selectedThread = thread;
      _isMessagesLoading = true;
      _errorMessage = null;
      _messages = [];
    });
    _chatService.listenToUserMessages(thread.user.id, chatId: thread.id);
    await _chatService.ensureChatAssignedToCurrentAdmin(thread.id);
    try {
      await _chatService.markConversationAsRead(thread.id);
    } catch (e) {
      Logger.error('Error marking conversation ${thread.id} as read', e);
    }
  }

  Future<void> _updateChatStatus(String chatId, ChatStatus status) async {
    setState(() {
      _isUpdatingStatus = true;
    });
    try {
      await _chatService.updateChatStatus(chatId, status);
      await _chatService.refreshConversations();
    } catch (e) {
      Logger.error('Error updating chat status', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  Future<void> _updateChatPriority(String chatId, ChatPriority priority) async {
    setState(() {
      _isUpdatingPriority = true;
    });
    try {
      await _chatService.updateChatPriority(chatId, priority);
      await _chatService.refreshConversations();
    } catch (e) {
      Logger.error('Error updating chat priority', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update priority'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingPriority = false;
        });
      }
    }
  }

  Future<void> _updateChatAssignment(String chatId, String? adminId) async {
    setState(() {
      _isUpdatingAssignee = true;
    });
    try {
      if (adminId == null) {
        await _chatService.unassignChat(chatId);
      } else {
        await _chatService.assignChatToAdmin(chatId, adminId);
      }
      await _chatService.refreshConversations();
    } catch (e) {
      Logger.error('Error updating chat assignment', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update assignment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingAssignee = false;
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
    return _selectedThread == null
        ? _buildConversationList()
        : _buildChatView();
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        SizedBox(width: 360, child: _buildConversationList()),
        const VerticalDivider(width: 1),
        Expanded(
          child:
              _selectedThread == null ? _buildEmptyState() : _buildChatView(),
        ),
      ],
    );
  }

  Widget _buildConversationList() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          _buildQuickFilters(),
          Expanded(
            child:
                _isLoadingThreads && _filteredThreads.isEmpty
                    ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColor.accentGreen,
                        ),
                      ),
                    )
                    : _filteredThreads.isEmpty
                    ? _buildEmptyConversations()
                    : ListView.builder(
                      itemCount: _filteredThreads.length,
                      itemBuilder: (context, index) {
                        final thread = _filteredThreads[index];
                        return _buildConversationListItem(thread);
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

  Widget _buildQuickFilters() {
    const labels = {
      _ConversationQuickFilter.all: 'All',
      _ConversationQuickFilter.active: 'Active',
      _ConversationQuickFilter.closed: 'Closed',
      _ConversationQuickFilter.highPriority: 'High Priority',
      _ConversationQuickFilter.unassigned: 'Unassigned',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              labels.entries.map((entry) {
                final isSelected = _activeFilter == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: isSelected,
                    onSelected: (_) => _onFilterSelected(entry.key),
                    selectedColor: AppColor.accentGreen.withAlpha(51),
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(
                      color:
                          isSelected
                              ? AppColor.accentGreen
                              : AppColor.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
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
          if (ResponsiveHelper.isMobile(context) && _selectedThread != null)
            IconButton(
              onPressed: () {
                setState(() {
                  _selectedThread = null;
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
                  '${_filteredThreads.length} conversations',
                  style: ResponsiveText.caption(
                    context,
                  ).copyWith(color: AppColor.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _refreshConversations,
            icon: const Icon(Iconsax.refresh),
          ),
        ],
      ),
    );
  }

  Widget _buildChatView() {
    final thread = _selectedThread;
    if (thread == null) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildChatHeader(thread),
        _buildConversationControls(thread),
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
                    setState(() => _errorMessage = null);
                    _chatService.listenToMessages(thread.id);
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
                _isMessagesLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColor.accentGreen,
                        ),
                      ),
                    )
                    : _messages.isEmpty && _errorMessage == null
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
                              setState(() => _errorMessage = null);
                              _chatService.listenToMessages(thread.id);
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

  Widget _buildChatHeader(AdminChatThread thread) {
    final otherUser = thread.user;
    final assignedAdminName = thread.assignedAdmin?.name ?? 'Unassigned';
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
              onPressed: () => setState(() => _selectedThread = null),
              icon: const Icon(Iconsax.arrow_left_2),
            ),
          CircleAvatar(
            backgroundColor: AppColor.primary,
            backgroundImage:
                otherUser.photoUrl != null
                    ? NetworkImage(otherUser.photoUrl!)
                    : null,
            child:
                otherUser.photoUrl == null
                    ? Text(
                      (otherUser.name.isNotEmpty
                          ? otherUser.name
                              .split(' ')
                              .where((e) => e.isNotEmpty)
                              .map((e) => e[0])
                              .take(2)
                              .join()
                          : otherUser.email.isNotEmpty
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
                  otherUser.name,
                  style: ResponsiveText.body(
                    context,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  otherUser.email,
                  style: ResponsiveText.caption(
                    context,
                  ).copyWith(color: AppColor.textSecondary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildStatusChip(thread.status),
                    const SizedBox(width: 8),
                    _buildPriorityChip(thread.priority),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Assigned: $assignedAdminName',
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

  Widget _buildConversationControls(AdminChatThread thread) {
    final statusItems =
        ChatStatus.values
            .map(
              (status) => DropdownMenuItem<ChatStatus>(
                value: status,
                child: Text(_statusLabel(status)),
              ),
            )
            .toList();

    final priorityItems =
        ChatPriority.values
            .map(
              (priority) => DropdownMenuItem<ChatPriority>(
                value: priority,
                child: Text(_priorityLabel(priority)),
              ),
            )
            .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: _buildLabeledDropdown<ChatStatus>(
                  label: 'Status',
                  value: thread.status,
                  items: statusItems,
                  onChanged:
                      _isUpdatingStatus
                          ? null
                          : (value) {
                            if (value != null) {
                              _updateChatStatus(thread.id, value);
                            }
                          },
                  isLoading: _isUpdatingStatus,
                ),
              ),
              SizedBox(
                width: 220,
                child: _buildLabeledDropdown<ChatPriority>(
                  label: 'Priority',
                  value: thread.priority,
                  items: priorityItems,
                  onChanged:
                      _isUpdatingPriority
                          ? null
                          : (value) {
                            if (value != null) {
                              _updateChatPriority(thread.id, value);
                            }
                          },
                  isLoading: _isUpdatingPriority,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildAssignmentControls(thread),
        ],
      ),
    );
  }

  Widget _buildAssignmentControls(AdminChatThread thread) {
    final assignedAdminId = thread.chat.assignedAdminId ?? '';
    final adminItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(value: '', child: Text('Unassigned')),
      ..._adminUsers.map(
        (admin) =>
            DropdownMenuItem<String>(value: admin.id, child: Text(admin.name)),
      ),
    ];

    final isAssignedInList =
        assignedAdminId.isEmpty ||
        _adminUsers.any((admin) => admin.id == assignedAdminId);

    if (!isAssignedInList && assignedAdminId.isNotEmpty) {
      adminItems.add(
        DropdownMenuItem<String>(
          value: assignedAdminId,
          enabled: false,
          child: Text(
            thread.assignedAdmin?.name ?? 'Assigned (not available)',
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child:
              _isLoadingAdmins && _adminUsers.isEmpty
                  ? Row(
                    children: const [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Loading admins...'),
                    ],
                  )
                  : _buildLabeledDropdown<String>(
                    label: 'Assigned admin',
                    value: assignedAdminId,
                    items: adminItems,
                    onChanged:
                        _isUpdatingAssignee
                            ? null
                            : (value) => _updateChatAssignment(
                              thread.id,
                              value == null || value.isEmpty ? null : value,
                            ),
                    isLoading: _isUpdatingAssignee,
                  ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Iconsax.refresh),
          tooltip: 'Refresh admins',
          onPressed:
              _isLoadingAdmins ? null : () => _loadAdminUsers(force: true),
        ),
      ],
    );
  }

  Widget _buildLabeledDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
    bool isLoading = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ResponsiveText.caption(context).copyWith(
            color: AppColor.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                isExpanded: true,
                value: value,
                items: items,
                onChanged: onChanged,
                icon:
                    isLoading
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.expand_more, size: 18),
                style: ResponsiveText.body(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(ChatStatus status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(32),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPriorityChip(ChatPriority priority) {
    final color = _priorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(32),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _priorityLabel(priority).toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _statusLabel(ChatStatus status) {
    switch (status) {
      case ChatStatus.active:
        return 'Active';
      case ChatStatus.archived:
        return 'Archived';
      case ChatStatus.closed:
        return 'Closed';
    }
  }

  Color _statusColor(ChatStatus status) {
    switch (status) {
      case ChatStatus.active:
        return AppColor.accentGreen;
      case ChatStatus.archived:
        return Colors.orange;
      case ChatStatus.closed:
        return AppColor.accentRed;
    }
  }

  Color _priorityColor(ChatPriority priority) {
    switch (priority) {
      case ChatPriority.low:
        return Colors.blueGrey;
      case ChatPriority.normal:
        return AppColor.primary;
      case ChatPriority.high:
        return Colors.orange;
      case ChatPriority.urgent:
        return AppColor.accentRed;
    }
  }

  String _priorityLabel(ChatPriority priority) {
    switch (priority) {
      case ChatPriority.low:
        return 'Low';
      case ChatPriority.normal:
        return 'Normal';
      case ChatPriority.high:
        return 'High';
      case ChatPriority.urgent:
        return 'Urgent';
    }
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

  Widget _buildConversationListItem(AdminChatThread thread) {
    final user = thread.user;
    final isSelected = _selectedThread?.id == thread.id;
    final unreadCount = thread.unreadForAdmin;
    final lastMessage = thread.chat.lastMessage ?? 'No messages yet';
    final lastMessageTime = thread.chat.lastMessageTime;

    return InkWell(
      onTap: () => _selectConversation(thread),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColor.accentGreen.withAlpha(26) : null,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                      if (unreadCount > 0)
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
                            '$unreadCount',
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          style: ResponsiveText.body(context).copyWith(
                            color: AppColor.textSecondary,
                            fontWeight:
                                unreadCount > 0
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(lastMessageTime),
                        style: ResponsiveText.caption(
                          context,
                        ).copyWith(color: AppColor.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildStatusChip(thread.status),
                      _buildPriorityChip(thread.priority),
                      if (thread.chat.assignedAdminId == null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withAlpha(32),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'UNASSIGNED',
                            style: TextStyle(
                              color: Colors.blueGrey,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (thread.chat.assignedAdminId != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColor.primary.withAlpha(24),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            thread.assignedAdmin?.name.toUpperCase() ??
                                'ASSIGNED',
                            style: TextStyle(
                              color: AppColor.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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

  Widget _buildEmptyConversations() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: AppColor.textSecondary.withAlpha(128),
          ),
          const SizedBox(height: 16),
          Text(
            'No conversations found',
            style: ResponsiveText.title(
              context,
            ).copyWith(color: AppColor.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Chats will appear here when users contact support.',
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
    final thread = _selectedThread;
    if (text.isEmpty || thread == null) return;

    // Use new structure: send message to user
    _chatService.sendMessageToUser(userId: thread.user.id, text: text);

    _messageController.clear();
  }

  Future<void> _pickAndSendImage() async {
    final thread = _selectedThread;
    if (thread == null) return;

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
        userId: thread.user.id,
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
