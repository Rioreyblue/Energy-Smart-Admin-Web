import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/constant.dart';
import '../services/admin_notification_service.dart';
import '../services/firebase_auth_service.dart';
import '../models/firebase_chat_models.dart';
import '../auth/admin_auth_service.dart';
import '../auth/admin_login_screen.dart';
import '../screens/admin_profile_screen.dart';
import '../screens/users_screen.dart';
import '../screens/chat_support_screen.dart';
import '../../utils/logger.dart';

class TopNavbar extends StatefulWidget {
  final String adminName;
  final VoidCallback? onMenuToggle;
  final bool showMenuButton;

  const TopNavbar({
    super.key,
    required this.adminName,
    this.onMenuToggle,
    this.showMenuButton = false,
  });

  @override
  State<TopNavbar> createState() => _TopNavbarState();
}

class _TopNavbarState extends State<TopNavbar> {
  final AdminNotificationService _notificationService =
      AdminNotificationService();
  final FirebaseAuthService _firebaseAuthService = FirebaseAuthService();
  StreamSubscription<int>? _unreadCountSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _notificationsSubscription;
  int _unreadNotifications = 0;
  List<Map<String, dynamic>> _notifications = [];
  FirebaseUser? _currentUser;
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _loadCurrentUser();
  }

  void _loadNotifications() {
    // Listen to unread count
    _unreadCountSubscription = _notificationService
        .getUnreadCountStream()
        .listen((count) {
          if (mounted) {
            setState(() {
              _unreadNotifications = count;
            });
          }
        });

    // Listen to notifications list
    _notificationsSubscription = _notificationService
        .getNotificationsStream()
        .listen((notifications) {
          if (mounted) {
            setState(() {
              _notifications = notifications;
            });
          }
        });
  }

  @override
  void dispose() {
    _unreadCountSubscription?.cancel();
    _notificationsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    if (!mounted) return;

    try {
      final currentUser = _firebaseAuthService.currentUser;
      if (currentUser != null) {
        final userData = await _firebaseAuthService.ensureCurrentUserData();
        if (userData != null && mounted) {
          setState(() {
            _currentUser = userData;
            _isSuperAdmin = userData.role == 'super_admin';
          });
        } else if (mounted) {
          // Fallback: create basic user info from Firebase Auth
          setState(() {
            _currentUser = FirebaseUser(
              id: currentUser.uid,
              name:
                  currentUser.displayName ??
                  currentUser.email?.split('@')[0] ??
                  'Admin User',
              email: currentUser.email ?? 'admin@energysmart.com',
              role: 'admin',
              photoUrl: currentUser.photoURL,
              createdAt: DateTime.now(),
              lastSeen: DateTime.now(),
              isOnline: true,
            );
            _isSuperAdmin = false;
          });
        }
      }
    } catch (e) {
      Logger.error('Error loading current user', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withAlpha(26),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (widget.showMenuButton) ...[
            IconButton(
              onPressed: widget.onMenuToggle,
              icon: const Icon(Iconsax.menu),
              style: IconButton.styleFrom(
                backgroundColor: AppColor.surface,
                foregroundColor: AppColor.textPrimary,
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(child: _buildSearchBar()),
          const SizedBox(width: 16),
          _buildNotifications(),
          const SizedBox(width: 16),
          _buildProfileSection(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColor.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withAlpha(51)),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search users, reports, settings...',
          hintStyle: ResponsiveText.body(
            context,
          ).copyWith(color: AppColor.textSecondary),
          prefixIcon: const Icon(
            Icons.search,
            size: 20,
            color: AppColor.textSecondary,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
        ),
        style: ResponsiveText.body(context),
      ),
    );
  }

  Widget _buildNotifications() {
    return Stack(
      children: [
        IconButton(
          onPressed: _showNotifications,
          icon: const Icon(Iconsax.notification),
          style: IconButton.styleFrom(
            backgroundColor: AppColor.surface,
            foregroundColor: AppColor.textPrimary,
          ),
        ),
        if (_unreadNotifications > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColor.accentRed,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                _unreadNotifications.toString(),
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
    );
  }

  Widget _buildProfileSection() {
    return Row(
      children: [
        _buildProfileAvatar(),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _currentUser?.name ?? widget.adminName,
              style: ResponsiveText.body(context).copyWith(
                fontWeight: FontWeight.w600,
                color: AppColor.textPrimary,
              ),
            ),
            Text(
              _isSuperAdmin ? 'Super Administrator' : 'Administrator',
              style: ResponsiveText.caption(context).copyWith(
                color:
                    _isSuperAdmin ? AppColor.accentRed : AppColor.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          onSelected: _handleMenuSelection,
          itemBuilder:
              (context) => [
                const PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Iconsax.profile_circle, size: 20),
                      SizedBox(width: 8),
                      Text('Profile'),
                    ],
                  ),
                ),
                if (_isSuperAdmin)
                  const PopupMenuItem(
                    value: 'admin_management',
                    child: Row(
                      children: [
                        Icon(
                          Iconsax.people,
                          size: 20,
                          color: AppColor.accentRed,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Manage Admins',
                          style: TextStyle(color: AppColor.accentRed),
                        ),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Iconsax.setting_2, size: 20),
                      SizedBox(width: 8),
                      Text('Settings'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Iconsax.logout, size: 20, color: AppColor.accentRed),
                      SizedBox(width: 8),
                      Text(
                        'Logout',
                        style: TextStyle(color: AppColor.accentRed),
                      ),
                    ],
                  ),
                ),
              ],
          child: const Icon(
            Iconsax.arrow_down_2,
            size: 16,
            color: AppColor.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileAvatar() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _isSuperAdmin ? AppColor.accentRed : AppColor.accentGreen,
        shape: BoxShape.circle,
        border: Border.all(color: AppColor.surface, width: 2),
      ),
      child:
          _currentUser?.photoUrl != null
              ? ClipOval(
                child: Image.network(
                  _currentUser!.photoUrl!,
                  fit: BoxFit.cover,
                  width: 40,
                  height: 40,
                ),
              )
              : Icon(
                _isSuperAdmin ? Icons.star : Iconsax.profile_circle,
                color: Colors.white,
                size: 24,
              ),
    );
  }

  void _showNotifications() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Iconsax.notification, color: AppColor.accentGreen),
                const SizedBox(width: 8),
                Text('Notifications', style: ResponsiveText.title(context)),
                const Spacer(),
                if (_unreadNotifications > 0)
                  TextButton(
                    onPressed: () async {
                      await _notificationService.markAllAsRead();
                    },
                    child: Text(
                      'Mark all as read',
                      style: ResponsiveText.caption(
                        context,
                      ).copyWith(color: AppColor.primary),
                    ),
                  ),
              ],
            ),
            content: SizedBox(
              width: 400,
              height: 400,
              child:
                  _notifications.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Iconsax.notification_bing,
                              size: 48,
                              color: AppColor.textSecondary.withAlpha(77),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No notifications',
                              style: ResponsiveText.body(
                                context,
                              ).copyWith(color: AppColor.textSecondary),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          return _buildNotificationItem(notification);
                        },
                      ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Close',
                  style: ResponsiveText.body(
                    context,
                  ).copyWith(color: AppColor.textSecondary),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final type = notification['type'] as String;
    final isRead = notification['read'] == true;
    final timestamp = notification['timestamp'] as Timestamp?;
    final notificationId = notification['id'] as String;
    final data = notification['data'] as Map<String, dynamic>? ?? {};
    Color iconColor;
    IconData icon;

    switch (type) {
      case 'new_user':
        iconColor = AppColor.accentGreen;
        icon = Iconsax.user_add;
        break;
      case 'chat_message':
        iconColor = AppColor.primary;
        icon = Iconsax.message;
        break;
      case 'warning':
      case 'system_alert':
        iconColor = AppColor.accentRed;
        icon = Iconsax.warning_2;
        break;
      case 'success':
        iconColor = AppColor.accentGreen;
        icon = Iconsax.tick_circle;
        break;
      default:
        iconColor = AppColor.textSecondary;
        icon = Iconsax.info_circle;
    }

    return InkWell(
      onTap: () async {
        // Mark as read
        if (!isRead) {
          await _notificationService.markAsRead(notificationId);
        }

        // Navigate based on type
        Navigator.of(context).pop(); // Close notification dialog
        if (type == 'new_user' && data['userId'] != null) {
          // Navigate to users page
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (context) => const UsersScreen()));
        } else if (type == 'chat_message' && data['chatId'] != null) {
          // Navigate to chat screen
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ChatSupportScreen()),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isRead ? Colors.transparent : AppColor.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).dividerColor.withAlpha(26),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification['title'] ?? '',
                    style: ResponsiveText.body(context).copyWith(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification['message'] ?? '',
                    style: ResponsiveText.caption(context),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(timestamp),
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

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';

    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'profile':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const AdminProfileScreen()),
        );
        break;
      case 'admin_management':
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (context) => const AdminProfileScreen(),
              ),
            )
            .then(
              (_) => _loadCurrentUser(),
            ); // Refresh user data when returning
        break;
      case 'settings':
        // Handle settings navigation
        _showInfoSnackBar('Settings screen will be implemented');
        break;
      case 'logout':
        _showLogoutDialog();
        break;
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Logout', style: ResponsiveText.title(context)),
            content: Text(
              'Are you sure you want to logout?',
              style: ResponsiveText.body(context),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: ResponsiveText.body(
                    context,
                  ).copyWith(color: AppColor.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _signOut();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.accentRed,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'Logout',
                  style: ResponsiveText.body(
                    context,
                  ).copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _signOut() async {
    try {
      // Try Firebase auth first, fallback to admin auth service
      try {
        await _firebaseAuthService.signOut();
      } catch (e) {
        final authService = AdminAuthService();
        await authService.signOut();
      }

      if (mounted) {
        _showSuccessSnackBar('Successfully signed out');

        // Navigate to login screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error signing out: $e');
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AwesomeSnackbarContent(
          title: 'Success!',
          message: message,
          contentType: ContentType.success,
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AwesomeSnackbarContent(
          title: 'Error!',
          message: message,
          contentType: ContentType.failure,
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AwesomeSnackbarContent(
          title: 'Info',
          message: message,
          contentType: ContentType.help,
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}
