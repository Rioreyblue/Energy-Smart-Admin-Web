import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../constants/constant.dart';
import '../utils/responsive_layout.dart';
import '../../utils/logger.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  StreamSubscription<DatabaseEvent>? _usersSubscription;

  // Track individual user status subscriptions
  final Map<String, StreamSubscription<DatabaseEvent>>
  _userStatusSubscriptions = {};
  // Track individual user account status subscriptions (for suspend/activate)
  final Map<String, StreamSubscription<DatabaseEvent>>
  _userAccountStatusSubscriptions = {};
  Timer? _statusRefreshTimer;

  // Time window for considering a user as online (in minutes)
  static const int _onlineTimeWindowMinutes = 2;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _listenToUsers();
    // Start periodic refresh timer to recalculate online status
    _statusRefreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _refreshOnlineStatus();
      }
    });
  }

  void _listenToUsers() {
    // Listen to users/ path in Realtime DB for real-time updates
    final usersRef = _database.ref('users');
    _usersSubscription = usersRef.onValue.listen(
      (event) {
        if (mounted && event.snapshot.value != null) {
          try {
            final data = event.snapshot.value as Map<dynamic, dynamic>?;
            if (data != null) {
              final List<Map<String, dynamic>> users = [];

              // Parse each user from Realtime DB
              final Set<String> currentUserIds = {};
              data.forEach((uid, userData) {
                if (userData is Map) {
                  final user = _transformUserData(uid, userData);
                  if (user != null) {
                    users.add(user);
                    currentUserIds.add(uid.toString());
                  }
                }
              });

              // Set up real-time listeners for each user's online status
              _setupUserStatusListeners(currentUserIds);
              // Set up real-time listeners for each user's account status
              _setupUserAccountStatusListeners(currentUserIds);

              setState(() {
                _users = users;
                _applyFilters();
                _isLoading = false;
              });
            } else {
              setState(() {
                _users = [];
                _filteredUsers = [];
                _isLoading = false;
              });
            }
          } catch (e) {
            Logger.error('Error parsing users data', e);
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          }
        } else {
          setState(() {
            _users = [];
            _filteredUsers = [];
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        Logger.error('Error listening to users', error);
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  Map<String, dynamic>? _transformUserData(
    dynamic uid,
    Map<dynamic, dynamic> userData,
  ) {
    try {
      // Extract basic fields
      final firstName = userData['firstName']?.toString() ?? '';
      final lastName = userData['lastName']?.toString() ?? '';
      final middleName = userData['middleName']?.toString() ?? '';

      // Combine name
      String fullName = firstName;
      if (middleName.isNotEmpty) {
        fullName += ' $middleName';
      }
      if (lastName.isNotEmpty) {
        fullName += ' $lastName';
      }
      fullName = fullName.trim();
      if (fullName.isEmpty) {
        fullName = 'Unknown User';
      }

      // Extract email
      final email = userData['email']?.toString() ?? '';

      // Determine status - prioritize status field, fallback to isApproved
      String status = 'Active';
      if (userData['status'] != null) {
        // Use status field if it exists
        final statusValue = userData['status'].toString();
        status =
            (statusValue == 'Active' || statusValue == 'Suspended')
                ? statusValue
                : 'Active';
      } else if (userData.containsKey('isApproved')) {
        // Fallback to isApproved field
        final isApproved = userData['isApproved'] == true;
        status = isApproved ? 'Active' : 'Suspended';
      }

      // Parse lastActive date - prioritize thisMonthUsage/lastUpdated
      DateTime? lastActive;

      // First, try to get from thisMonthUsage/lastUpdated (primary source)
      if (userData['thisMonthUsage'] is Map) {
        final thisMonthUsage = userData['thisMonthUsage'] as Map;
        final lastUpdated = thisMonthUsage['lastUpdated'];
        if (lastUpdated != null) {
          lastActive = _parseTimestamp(lastUpdated);
        }
      }

      // Fallback to todayUsage/lastUpdated if thisMonthUsage not available
      if (lastActive == null && userData['todayUsage'] is Map) {
        final todayUsage = userData['todayUsage'] as Map;
        final lastUpdated = todayUsage['lastUpdated'];
        if (lastUpdated != null) {
          lastActive = _parseTimestamp(lastUpdated);
        }
      }

      // Fallback to updatedAt if neither is available
      if (lastActive == null && userData['updatedAt'] != null) {
        lastActive = _parseTimestamp(userData['updatedAt']);
      }

      // Use createdAt as last resort
      if (lastActive == null && userData['createdAt'] != null) {
        lastActive = _parseTimestamp(userData['createdAt']);
      }

      // Default to now if no date found
      lastActive ??= DateTime.now();

      // Extract energy usage from thisMonthUsage.totalKwh
      double energyUsage = 0.0;
      if (userData['thisMonthUsage'] is Map) {
        final thisMonthUsage = userData['thisMonthUsage'] as Map;
        final totalKwh = thisMonthUsage['totalKwh'];
        if (totalKwh != null) {
          if (totalKwh is num) {
            energyUsage = totalKwh.toDouble();
          } else if (totalKwh is String) {
            energyUsage = double.tryParse(totalKwh) ?? 0.0;
          }
        }
      }

      // Extract energy cost from thisMonthUsage.totalCost
      double energyCost = 0.0;
      if (userData['thisMonthUsage'] is Map) {
        final thisMonthUsage = userData['thisMonthUsage'] as Map;
        final totalCost = thisMonthUsage['totalCost'];
        if (totalCost != null) {
          if (totalCost is num) {
            energyCost = totalCost.toDouble();
          } else if (totalCost is String) {
            energyCost = double.tryParse(totalCost) ?? 0.0;
          }
        }
      }

      // Count appliances
      int deviceCount = 0;
      if (userData['appliances'] is Map) {
        final appliances = userData['appliances'] as Map;
        deviceCount = appliances.length;
      }

      // Calculate online/offline status based on lastActive timestamp
      // User is online if they were active within the time window
      final bool isOnline = _calculateOnlineStatusFromTimestamp(lastActive);

      return {
        'id': uid.toString(),
        'name': fullName,
        'email': email,
        'role': 'User', // All users in Realtime DB are regular users
        'status': status,
        'lastActive': lastActive,
        'energyUsage': energyUsage,
        'energyCost': energyCost,
        'devices': deviceCount,
        'isOnline': isOnline,
        'uid': uid.toString(), // Store original uid for status updates
      };
    } catch (e) {
      Logger.error('Error transforming user data for $uid', e);
      return null;
    }
  }

  Future<void> _loadUsers() async {
    // This method is kept for refresh functionality
    // The real-time listener handles updates automatically
    if (_usersSubscription != null) {
      _usersSubscription!.cancel();
    }
    setState(() {
      _isLoading = true;
    });
    _listenToUsers();
  }

  DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;

    try {
      if (timestamp is int) {
        // Assume milliseconds if > 1e10, otherwise seconds
        if (timestamp > 10000000000) {
          return DateTime.fromMillisecondsSinceEpoch(timestamp);
        } else {
          return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
        }
      } else if (timestamp is String) {
        return DateTime.parse(timestamp);
      } else if (timestamp is DateTime) {
        return timestamp;
      }
    } catch (e) {
      Logger.debug('Error parsing timestamp: $timestamp', e);
    }
    return null;
  }

  bool _calculateOnlineStatusFromTimestamp(DateTime? lastUpdated) {
    if (lastUpdated == null) return false;

    final now = DateTime.now();
    final difference = now.difference(lastUpdated);

    // User is online if lastUpdated is within the time window
    return difference.inMinutes <= _onlineTimeWindowMinutes;
  }

  void _setupUserStatusListeners(Set<String> userIds) {
    // Cancel subscriptions for users that no longer exist
    final currentSubscriptions = _userStatusSubscriptions.keys.toSet();
    final removedUsers = currentSubscriptions.difference(userIds);

    for (final userId in removedUsers) {
      _userStatusSubscriptions[userId]?.cancel();
      _userStatusSubscriptions.remove(userId);
    }

    // Add listeners for new users
    for (final userId in userIds) {
      if (!_userStatusSubscriptions.containsKey(userId)) {
        final statusRef = _database.ref(
          'users/$userId/thisMonthUsage/lastUpdated',
        );
        final subscription = statusRef.onValue.listen(
          (event) {
            if (mounted) {
              _updateUserOnlineStatus(userId, event.snapshot.value);
            }
          },
          onError: (error) {
            Logger.debug(
              'Error listening to online status for user $userId: $error',
            );
          },
        );
        _userStatusSubscriptions[userId] = subscription;
      }
    }
  }

  void _setupUserAccountStatusListeners(Set<String> userIds) {
    // Cancel subscriptions for users that no longer exist
    final currentSubscriptions = _userAccountStatusSubscriptions.keys.toSet();
    final removedUsers = currentSubscriptions.difference(userIds);

    for (final userId in removedUsers) {
      _userAccountStatusSubscriptions[userId]?.cancel();
      _userAccountStatusSubscriptions.remove(userId);
    }

    // Add listeners for new users' account status
    for (final userId in userIds) {
      if (!_userAccountStatusSubscriptions.containsKey(userId)) {
        final statusRef = _database.ref('users/$userId/isApproved');
        final subscription = statusRef.onValue.listen(
          (event) {
            if (mounted) {
              _updateUserAccountStatus(userId, event.snapshot.value);
            }
          },
          onError: (error) {
            Logger.debug(
              'Error listening to account status for user $userId: $error',
            );
          },
        );
        _userAccountStatusSubscriptions[userId] = subscription;
      }
    }
  }

  void _updateUserAccountStatus(String userId, dynamic isApprovedValue) {
    // Find and update the user in the list
    final userIndex = _users.indexWhere((user) => user['id'] == userId);
    if (userIndex != -1) {
      bool isApproved = false;
      if (isApprovedValue is bool) {
        isApproved = isApprovedValue;
      } else if (isApprovedValue is String) {
        isApproved = isApprovedValue.toLowerCase() == 'true';
      } else if (isApprovedValue is int) {
        isApproved = isApprovedValue == 1;
      }

      final newStatus = isApproved ? 'Active' : 'Suspended';

      setState(() {
        _users[userIndex]['status'] = newStatus;
        _applyFilters();
      });
    }
  }

  void _updateUserOnlineStatus(String userId, dynamic lastUpdatedValue) {
    final lastUpdated = _parseTimestamp(lastUpdatedValue);
    final isOnline = _calculateOnlineStatusFromTimestamp(lastUpdated);

    // Find and update the user in the list
    final userIndex = _users.indexWhere((user) => user['id'] == userId);
    if (userIndex != -1) {
      setState(() {
        _users[userIndex]['isOnline'] = isOnline;
        if (lastUpdated != null) {
          _users[userIndex]['lastActive'] = lastUpdated;
        }
        _applyFilters();
      });
    }
  }

  void _refreshOnlineStatus() {
    // Recalculate online status for all users based on their lastActive timestamp
    setState(() {
      for (var i = 0; i < _users.length; i++) {
        final lastActive = _users[i]['lastActive'] as DateTime?;
        _users[i]['isOnline'] = _calculateOnlineStatusFromTimestamp(lastActive);
      }
      _applyFilters();
    });
  }

  @override
  void dispose() {
    _usersSubscription?.cancel();
    // Cancel all user status subscriptions
    for (var subscription in _userStatusSubscriptions.values) {
      subscription.cancel();
    }
    _userStatusSubscriptions.clear();
    // Cancel all user account status subscriptions
    for (var subscription in _userAccountStatusSubscriptions.values) {
      subscription.cancel();
    }
    _userAccountStatusSubscriptions.clear();
    _statusRefreshTimer?.cancel();
    super.dispose();
  }

  void _filterUsers(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = _users;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered.where((user) {
            final name = user['name'].toString().toLowerCase();
            final email = user['email'].toString().toLowerCase();
            final query = _searchQuery.toLowerCase();
            return name.contains(query) || email.contains(query);
          }).toList();
    }

    // Apply status filter
    if (_selectedFilter != 'All') {
      filtered =
          filtered.where((user) {
            return user['status'].toString() == _selectedFilter;
          }).toList();
    }

    setState(() {
      _filteredUsers = filtered;
    });
  }

  void _toggleUserStatus(String userId) {
    final userIndex = _users.indexWhere((user) => user['id'] == userId);
    if (userIndex == -1) return;

    final currentStatus = _users[userIndex]['status'] as String;
    final userName = _users[userIndex]['name'] as String;

    if (currentStatus == 'Active') {
      // Show confirmation dialog for suspension
      _showSuspendConfirmationDialog(userId, userName);
    } else {
      // Activate user directly (no confirmation needed)
      _activateUser(userId);
    }
  }

  void _suspendUser(String userId) async {
    final userIndex = _users.indexWhere((user) => user['id'] == userId);
    if (userIndex == -1) return;

    final currentStatus = _users[userIndex]['status'] as String;
    if (currentStatus == 'Suspended') {
      _showSnackBar('User is already suspended', AppColor.textSecondary);
      return;
    }

    // Optimistically update UI
    setState(() {
      _users[userIndex]['status'] = 'Suspended';
      _applyFilters();
    });

    try {
      final userRef = _database.ref('users/$userId');
      final now = DateTime.now().millisecondsSinceEpoch;

      // Update multiple fields atomically
      await userRef.update({
        'isApproved': false,
        'status': 'Suspended',
        'statusUpdatedAt': now,
      });

      _showSnackBar('User suspended successfully', AppColor.accentGreen);
    } catch (e) {
      Logger.error('Error suspending user', e);
      // Revert on failure
      setState(() {
        _users[userIndex]['status'] = currentStatus;
        _applyFilters();
      });
      _showSnackBar('Failed to suspend user', AppColor.accentRed);
    }
  }

  void _activateUser(String userId) async {
    final userIndex = _users.indexWhere((user) => user['id'] == userId);
    if (userIndex == -1) return;

    final currentStatus = _users[userIndex]['status'] as String;
    if (currentStatus == 'Active') {
      _showSnackBar('User is already active', AppColor.textSecondary);
      return;
    }

    // Optimistically update UI
    setState(() {
      _users[userIndex]['status'] = 'Active';
      _applyFilters();
    });

    try {
      final userRef = _database.ref('users/$userId');
      final now = DateTime.now().millisecondsSinceEpoch;

      // Update multiple fields atomically
      await userRef.update({
        'isApproved': true,
        'status': 'Active',
        'statusUpdatedAt': now,
      });

      _showSnackBar('User activated successfully', AppColor.accentGreen);
    } catch (e) {
      Logger.error('Error activating user', e);
      // Revert on failure
      setState(() {
        _users[userIndex]['status'] = currentStatus;
        _applyFilters();
      });
      _showSnackBar('Failed to activate user', AppColor.accentRed);
    }
  }

  void _showSuspendConfirmationDialog(String userId, String userName) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Iconsax.warning_2, color: AppColor.accentRed, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Suspend User',
                    style: ResponsiveText.title(context).copyWith(
                      color: AppColor.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to suspend this user?',
                  style: ResponsiveText.body(
                    context,
                  ).copyWith(color: AppColor.textPrimary),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColor.accentRed.withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColor.accentRed.withAlpha(77)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Iconsax.profile_circle,
                        color: AppColor.accentRed,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          userName,
                          style: ResponsiveText.body(context).copyWith(
                            color: AppColor.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Suspended users will not be able to access their account.',
                  style: ResponsiveText.caption(
                    context,
                  ).copyWith(color: AppColor.textSecondary),
                ),
              ],
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
                onPressed: () {
                  Navigator.of(context).pop();
                  _suspendUser(userId);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.accentRed,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'Suspend',
                  style: ResponsiveText.body(
                    context,
                  ).copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.surface,
      body: Column(
        children: [
          _buildHeader(),
          _buildFilters(),
          Expanded(child: _buildUsersTable()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Users Management',
                style: ResponsiveText.headline(context).copyWith(
                  color: AppColor.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage user accounts and permissions',
                style: ResponsiveText.body(
                  context,
                ).copyWith(color: AppColor.textSecondary),
              ),
            ],
          ),
          _buildActionButton(
            'Export PDF',
            Iconsax.document_download,
            AppColor.primary,
            () {
              _exportToPDF();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColor.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withAlpha(51),
                ),
              ),
              child: TextField(
                onChanged: _filterUsers,
                decoration: InputDecoration(
                  hintText: 'Search users by name or email...',
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
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColor.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).dividerColor.withAlpha(51),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFilter,
                items:
                    ['All', 'Active', 'Suspended'].map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(
                          status,
                          style: ResponsiveText.body(context),
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                    _applyFilters();
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTable() {
    return ResponsiveLayout(
      mobile: _buildMobileUsersList(),
      desktop: _buildDesktopUsersTable(),
    );
  }

  Widget _buildDesktopUsersTable() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Users (${_filteredUsers.length})',
                  style: ResponsiveText.title(context).copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColor.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: _loadUsers,
                  icon: const Icon(Iconsax.refresh),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColor.surface,
                    foregroundColor: AppColor.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColor.accentGreen,
                          ),
                        ),
                      )
                      : _buildDataTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    if (_filteredUsers.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(AppColor.surface),
        headingTextStyle: ResponsiveText.body(
          context,
        ).copyWith(fontWeight: FontWeight.bold, color: AppColor.textPrimary),
        dataTextStyle: ResponsiveText.body(
          context,
        ).copyWith(color: AppColor.textPrimary),
        columns: const [
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Email')),
          DataColumn(label: Text('Role')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Online/Offline')),
          DataColumn(label: Text('Last Active')),
          DataColumn(label: Text('Energy Usage')),
          DataColumn(label: Text('Energy Cost')),
          DataColumn(label: Text('Devices')),
          DataColumn(label: Text('Actions')),
        ],
        rows:
            _filteredUsers
                .map(
                  (user) => DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColor.accentGreen.withAlpha(
                                26,
                              ),
                              child: Text(
                                user['name']
                                    .toString()
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: ResponsiveText.caption(context).copyWith(
                                  color: AppColor.accentGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(user['name']),
                          ],
                        ),
                      ),
                      DataCell(Text(user['email'])),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                user['role'] == 'Admin'
                                    ? AppColor.primary.withAlpha(26)
                                    : AppColor.textSecondary.withAlpha(26),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            user['role'],
                            style: ResponsiveText.caption(context).copyWith(
                              color:
                                  user['role'] == 'Admin'
                                      ? AppColor.primary
                                      : AppColor.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      DataCell(_buildStatusChip(user['status'])),
                      DataCell(
                        _buildOnlineStatusChip(user['isOnline'] as bool),
                      ),
                      DataCell(Text(_formatLastActive(user['lastActive']))),
                      DataCell(
                        Text(
                          '${(user['energyUsage'] as double).toStringAsFixed(4)} kWh',
                        ),
                      ),
                      DataCell(
                        Text(
                          '₱${(user['energyCost'] as double).toStringAsFixed(2)}',
                        ),
                      ),
                      DataCell(Text('${user['devices']}')),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => _toggleUserStatus(user['id']),
                              icon: Icon(
                                user['status'] == 'Active'
                                    ? Iconsax.pause
                                    : Iconsax.play,
                                size: 16,
                                color:
                                    user['status'] == 'Active'
                                        ? AppColor.accentRed
                                        : AppColor.accentGreen,
                              ),
                              tooltip:
                                  user['status'] == 'Active'
                                      ? 'Suspend'
                                      : 'Activate',
                            ),
                            IconButton(
                              onPressed: () => _showUserDetails(user),
                              icon: const Icon(
                                Iconsax.eye,
                                size: 16,
                                color: AppColor.textSecondary,
                              ),
                              tooltip: 'View Details',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
      ),
    );
  }

  Widget _buildMobileUsersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _isLoading ? 3 : _filteredUsers.length,
      itemBuilder: (context, index) {
        if (_isLoading) {
          return _buildLoadingCard();
        }

        final user = _filteredUsers[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColor.accentGreen.withAlpha(26),
                  child: Text(
                    user['name'].toString().substring(0, 1).toUpperCase(),
                    style: ResponsiveText.body(context).copyWith(
                      color: AppColor.accentGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name'],
                        style: ResponsiveText.body(
                          context,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        user['email'],
                        style: ResponsiveText.caption(
                          context,
                        ).copyWith(color: AppColor.textSecondary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildStatusChip(user['status']),
                    const SizedBox(height: 4),
                    _buildOnlineStatusChip(user['isOnline'] as bool),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip('Role', user['role']),
                const SizedBox(width: 8),
                _buildInfoChip('Devices', '${user['devices']}'),
                const SizedBox(width: 8),
                _buildInfoChip(
                  'Usage',
                  '${(user['energyUsage'] as double).toStringAsFixed(4)} kWh',
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  'Cost',
                  '₱${(user['energyCost'] as double).toStringAsFixed(2)}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Last active: ${_formatLastActive(user['lastActive'])}',
                  style: ResponsiveText.caption(
                    context,
                  ).copyWith(color: AppColor.textSecondary),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _toggleUserStatus(user['id']),
                      icon: Icon(
                        user['status'] == 'Active'
                            ? Iconsax.pause
                            : Iconsax.play,
                        size: 16,
                        color:
                            user['status'] == 'Active'
                                ? AppColor.accentRed
                                : AppColor.accentGreen,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showUserDetails(user),
                      icon: const Icon(
                        Iconsax.eye,
                        size: 16,
                        color: AppColor.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColor.surface,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 16,
                        width: 120,
                        color: AppColor.surface,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 12,
                        width: 200,
                        color: AppColor.surface,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final isActive = status == 'Active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            isActive
                ? AppColor.accentGreen.withAlpha(26)
                : AppColor.accentRed.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppColor.accentGreen : AppColor.accentRed,
          width: 1,
        ),
      ),
      child: Text(
        status,
        style: ResponsiveText.caption(context).copyWith(
          color: isActive ? AppColor.accentGreen : AppColor.accentRed,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColor.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: ResponsiveText.caption(
          context,
        ).copyWith(color: AppColor.textSecondary),
      ),
    );
  }

  Widget _buildOnlineStatusChip(bool isOnline) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            isOnline
                ? AppColor.accentGreen.withAlpha(26)
                : AppColor.textSecondary.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOnline ? AppColor.accentGreen : AppColor.textSecondary,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnline ? Iconsax.tick_circle : Iconsax.close_circle,
            size: 12,
            color: isOnline ? AppColor.accentGreen : AppColor.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: ResponsiveText.caption(context).copyWith(
              color: isOnline ? AppColor.accentGreen : AppColor.textSecondary,
              fontWeight: FontWeight.w600,
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
            Iconsax.profile_2user,
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
            'Try adjusting your search or filter criteria.',
            style: ResponsiveText.body(
              context,
            ).copyWith(color: AppColor.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatLastActive(DateTime lastActive) {
    final now = DateTime.now();
    final difference = now.difference(lastActive);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('User Details', style: ResponsiveText.title(context)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Name', user['name']),
                _buildDetailRow('Email', user['email']),
                _buildDetailRow('Role', user['role']),
                _buildDetailRow('Status', user['status']),
                _buildDetailRow(
                  'Online/Offline',
                  (user['isOnline'] as bool) ? 'Online' : 'Offline',
                ),
                _buildDetailRow(
                  'Last Active',
                  _formatLastActive(user['lastActive']),
                ),
                _buildDetailRow(
                  'Energy Usage',
                  '${(user['energyUsage'] as double).toStringAsFixed(4)} kWh',
                ),
                _buildDetailRow(
                  'Energy Cost',
                  '₱${(user['energyCost'] as double).toStringAsFixed(2)}',
                ),
                _buildDetailRow('Devices', '${user['devices']}'),
              ],
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: ResponsiveText.body(context).copyWith(
                fontWeight: FontWeight.w600,
                color: AppColor.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: ResponsiveText.body(
                context,
              ).copyWith(color: AppColor.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToPDF() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Load logo from assets
      final ByteData logoData = await rootBundle.load(
        'assets/icon/update_icon.png',
      );
      final Uint8List logoBytes = logoData.buffer.asUint8List();
      final pw.ImageProvider logoImage = pw.MemoryImage(logoBytes);

      // Try to load Unicode-capable fonts for Peso (₱). Fallback if unavailable
      pw.ThemeData? pdfTheme;
      String currencySymbol = 'PHP ';
      try {
        final ByteData regularData = await rootBundle.load(
          'assets/fonts/NotoSans-Regular.ttf',
        );
        final ByteData boldData = await rootBundle.load(
          'assets/fonts/NotoSans-Bold.ttf',
        );
        final pw.Font regularFont = pw.Font.ttf(regularData);
        final pw.Font boldFont = pw.Font.ttf(boldData);
        pdfTheme = pw.ThemeData.withFont(base: regularFont, bold: boldFont);
        currencySymbol = '₱';
      } catch (_) {
        // If fonts are not bundled yet, continue with default theme and use "PHP "
      }

      // Create PDF document
      final pdf = pw.Document();

      // Add page with header and table
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          theme: pdfTheme,
          build: (pw.Context context) {
            return [
              // Header with logo
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      pw.Image(logoImage, width: 50, height: 50),
                      pw.SizedBox(width: 16),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'EnergySmart Admin',
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            'Users Report',
                            style: pw.TextStyle(
                              fontSize: 14,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Generated: ${DateTime.now().toString().split('.')[0]}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.Text(
                        'Total Users: ${_filteredUsers.length}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      _buildTableCell('Name', isHeader: true),
                      _buildTableCell('Email', isHeader: true),
                      _buildTableCell('Role', isHeader: true),
                      _buildTableCell('Status', isHeader: true),
                      _buildTableCell('Online/Offline', isHeader: true),
                      _buildTableCell('Last Active', isHeader: true),
                      _buildTableCell('Energy Usage', isHeader: true),
                      _buildTableCell('Energy Cost', isHeader: true),
                      _buildTableCell('Devices', isHeader: true),
                    ],
                  ),
                  // Data rows
                  ..._filteredUsers.map((user) {
                    return pw.TableRow(
                      children: [
                        _buildTableCell(user['name']),
                        _buildTableCell(user['email']),
                        _buildTableCell(user['role']),
                        _buildTableCell(user['status']),
                        _buildTableCell(
                          (user['isOnline'] as bool) ? 'Online' : 'Offline',
                        ),
                        _buildTableCell(_formatLastActive(user['lastActive'])),
                        _buildTableCell(
                          '${(user['energyUsage'] as double).toStringAsFixed(4)} kWh',
                        ),
                        _buildTableCell(
                          '$currencySymbol${(user['energyCost'] as double).toStringAsFixed(2)}',
                        ),
                        _buildTableCell('${user['devices']}'),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ];
          },
        ),
      );

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Share/save PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      if (mounted) {
        _showSnackBar('PDF exported successfully', AppColor.accentGreen);
      }
    } catch (e) {
      Logger.error('Error exporting PDF', e);
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _showSnackBar('Failed to export PDF: $e', AppColor.accentRed);
      }
    }
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
