import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import '../../../constants/constant.dart';
import '../../../utils/logger.dart';
import '../models/firebase_chat_models.dart';
import '../services/admin_notification_service.dart';
import '../services/firebase_auth_service.dart';
import '../utils/responsive_layout.dart';
import '../widgets/summary_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final AdminNotificationService _notificationService =
      AdminNotificationService();
  final FirebaseAuthService _authService = FirebaseAuthService();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _firestoreUsersSubscription;

  // Time window for considering a device as "active" (in minutes)
  static const int _activeDeviceTimeWindowMinutes = 15;

  // Dynamic metrics from Firebase (real-time)
  int? _totalUsers;
  int? _activeDevices;
  double? _totalEnergyUsage;
  double? _powerRate;

  // Admin profile data
  FirebaseUser? _adminUser;
  DateTime? _lastUpdateTime;
  bool _profileImageError = false;

  // Stream subscriptions
  StreamSubscription<DatabaseEvent>? _usersSubscription;
  StreamSubscription<DatabaseEvent>? _devicesSubscription;
  StreamSubscription<DatabaseEvent>? _usersRealtimeSubscription;
  StreamSubscription<DatabaseEvent>? _energyUsageSubscription;
  StreamSubscription<DocumentSnapshot>? _powerRateSubscription;
  // Track subscriptions for each user's thisMonthUsage/totalKwh in Realtime DB
  final List<StreamSubscription<DatabaseEvent>> _energyUsageSubscriptions = [];
  // Track individual user energy usage values
  final Map<String, double> _userEnergyUsage = {};
  // Timer to update last update text
  Timer? _lastUpdateTimer;

  // Track known user IDs for new user detection
  final Set<String> _knownUserIds = {};
  final Map<String, int> _userTypeCounts = {};

  // Static placeholder data - no async loading
  final Map<String, dynamic> _dashboardStats = {
    'totalUsers': 1247,
    'activeDevices': 3421,
    'totalEnergyUsage': 45678.9,
    'currentPowerRate': 6.50,
    'monthlySavings': 1250.0,
    'carbonFootprint': 12.5,
  };

  @override
  void initState() {
    super.initState();
    _loadAdminProfile();
    _listenToUsers();
    _listenToUsersRealtime(); // Listen to Realtime DB for new user detection
    _listenToFirestoreUsers();
    _listenToActiveDevices();
    _listenToEnergyUsage();
    _listenToPowerRate();
    _updateLastUpdateTime();
    // Update last update text every minute
    _lastUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          // Trigger rebuild to update last update text
        });
      }
    });
  }

  Future<void> _loadAdminProfile() async {
    try {
      final userData = await _authService.ensureCurrentUserData();
      if (mounted) {
        setState(() {
          _adminUser = userData;
        });
      }
    } catch (e) {
      Logger.error('Error loading admin profile', e);
    }
  }

  void _updateLastUpdateTime() {
    setState(() {
      _lastUpdateTime = DateTime.now();
    });
  }

  String _getLastUpdateText() {
    if (_lastUpdateTime == null) return 'Never';
    final now = DateTime.now();
    final difference = now.difference(_lastUpdateTime!);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds} seconds ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    }
  }

  String _getSystemStatus() {
    // Check if system is operational based on data availability
    if (_totalUsers == null &&
        _totalEnergyUsage == null &&
        _activeDevices == null) {
      return 'Loading...';
    }
    // Check if we have recent data (within last 5 minutes)
    if (_lastUpdateTime != null) {
      final timeSinceUpdate = DateTime.now().difference(_lastUpdateTime!);
      if (timeSinceUpdate.inMinutes > 5) {
        return 'Data Stale';
      }
    }
    return 'All Systems Operational';
  }

  Color _getSystemStatusColor() {
    final status = _getSystemStatus();
    if (status == 'Loading...') {
      return AppColor.textSecondary;
    } else if (status == 'Data Stale') {
      return Colors.orange;
    }
    return AppColor.accentGreen;
  }

  void _listenToUsers() {
    // Set up real-time stream listener for users/ in Realtime DB
    final usersRef = _database.ref('users');
    _usersSubscription = usersRef.onValue.listen(
      (event) {
        if (mounted) {
          try {
            final value = event.snapshot.value;
            int userCount = 0;

            if (value != null) {
              // Handle both Map and List structures
              if (value is Map) {
                // If it's a Map, count the keys (UIDs)
                userCount = value.keys.length;
              } else if (value is List) {
                // If it's a List, count the elements
                userCount = value.length;
              } else {
                // If it's a single value, count as 1
                userCount = 1;
              }
            }

            setState(() {
              _totalUsers = userCount;
              _updateLastUpdateTime();
            });
          } catch (e) {
            Logger.error('Error counting users from Realtime DB', e);
            // Keep _totalUsers as null, will fallback to placeholder
          }
        }
      },
      onError: (error) {
        Logger.error('Error listening to users/ in Realtime DB', error);
        // Keep _totalUsers as null, will fallback to placeholder
      },
    );
  }

  void _listenToUsersRealtime() {
    // Listen to Realtime DB users/ path to detect new user registrations
    final usersRef = _database.ref('users');
    _usersRealtimeSubscription = usersRef.onValue.listen(
      (event) {
        if (mounted && event.snapshot.value != null) {
          try {
            final data = event.snapshot.value as Map<dynamic, dynamic>?;
            if (data != null) {
              final currentUserIds = data.keys.map((k) => k.toString()).toSet();

              // Detect new users
              final newUserIds = currentUserIds.difference(_knownUserIds);

              if (newUserIds.isNotEmpty && _knownUserIds.isNotEmpty) {
                // New users detected - create notifications
                for (final userId in newUserIds) {
                  _handleNewUser(userId, data[userId]);
                }
              }

              // Update known user IDs
              _knownUserIds.clear();
              _knownUserIds.addAll(currentUserIds);
            }
          } catch (e) {
            Logger.error('Error detecting new users', e);
          }
        } else if (mounted && event.snapshot.value == null) {
          // No users yet, initialize empty set
          _knownUserIds.clear();
        }
      },
      onError: (error) {
        Logger.error('Error listening to users in Realtime DB', error);
      },
    );
  }

  void _listenToFirestoreUsers() {
    _firestoreUsersSubscription?.cancel();
    _firestoreUsersSubscription = _firestore
        .collection('users')
        .snapshots()
        .listen(
          (snapshot) {
            final counts = <String, int>{};
            for (final doc in snapshot.docs) {
              final data = doc.data();
              final role = (data['role'] ?? data['userRole'] ?? '').toString();
              final isAdmin = role.toLowerCase() == 'admin';
              final isMarkedAdmin =
                  (data['isAdmin'] == true) ||
                  ((data['permissions'] is List) &&
                      (data['permissions'] as List)
                          .map((e) => e.toString().toLowerCase())
                          .contains('admin'));
              if (isAdmin || isMarkedAdmin) continue;

              final rawType =
                  (data['userType'] ?? data['type'] ?? data['role'] ?? '')
                      .toString();
              final normalizedType = _normalizeUserType(rawType);
              counts[normalizedType] = (counts[normalizedType] ?? 0) + 1;
            }

            if (mounted) {
              setState(() {
                _userTypeCounts
                  ..clear()
                  ..addAll(counts);
                _totalUsers = counts.values.fold<int>(
                  0,
                  (sum, value) => sum + value,
                );
                _updateLastUpdateTime();
              });
            }
          },
          onError: (error) {
            Logger.error('Error listening to Firestore users', error);
          },
        );
  }

  Future<void> _handleNewUser(String userId, dynamic userData) async {
    try {
      // Extract user information
      String userName = 'Unknown User';
      String userEmail = '';

      if (userData is Map) {
        final firstName = userData['firstName']?.toString() ?? '';
        final lastName = userData['lastName']?.toString() ?? '';
        final middleName = userData['middleName']?.toString() ?? '';

        userName = firstName;
        if (middleName.isNotEmpty) userName += ' $middleName';
        if (lastName.isNotEmpty) userName += ' $lastName';
        userName = userName.trim();
        if (userName.isEmpty) userName = 'Unknown User';

        userEmail = userData['email']?.toString() ?? '';
      }

      // Create notification for all admins
      await _notificationService.createNotificationForAllAdmins(
        type: 'new_user',
        title: 'New User Registered',
        userId: userId,
        userEmail: userEmail,
        userName: userName,
        extraData: {'source': 'realtime_db'},
      );

      Logger.info('New user notification created for: $userName');
    } catch (e) {
      Logger.error('Error handling new user', e);
    }
  }

  void _listenToActiveDevices() {
    // Listen to root users/ path in Realtime DB to count only active appliances
    // Active = isOn == true (boolean or string) AND (lastUpdate within time window OR no lastUpdate)
    final usersRef = _database.ref('users');
    _devicesSubscription = usersRef.onValue.listen(
      (event) {
        if (mounted && event.snapshot.value != null) {
          try {
            final data = event.snapshot.value as Map<dynamic, dynamic>?;
            if (data != null) {
              int totalActiveDevices = 0;
              int totalAppliances = 0;
              int devicesWithIsOnTrue = 0;
              int devicesExcludedByTime = 0;
              final now = DateTime.now();
              final timeWindow = Duration(
                minutes: _activeDeviceTimeWindowMinutes,
              );

              // Iterate through each user
              data.forEach((userId, userData) {
                if (userData is Map && userData.containsKey('appliances')) {
                  final appliances = userData['appliances'];
                  if (appliances is Map) {
                    // Iterate through each appliance
                    appliances.forEach((applianceId, applianceData) {
                      if (applianceData is Map) {
                        totalAppliances++;

                        // Check if device is turned on (handle both boolean and string)
                        final isOnValue = applianceData['isOn'];
                        bool isOn = false;

                        if (isOnValue is bool) {
                          isOn = isOnValue;
                        } else if (isOnValue is String) {
                          isOn = isOnValue.toLowerCase() == 'true';
                        } else if (isOnValue != null) {
                          // Try to parse as string and check
                          isOn = isOnValue.toString().toLowerCase() == 'true';
                        }

                        if (isOn) {
                          devicesWithIsOnTrue++;

                          // Check if lastUpdate exists and is recent
                          final lastUpdate = applianceData['lastUpdate'];
                          if (lastUpdate != null) {
                            DateTime? lastUpdateTime;

                            // Parse timestamp (handle both numeric and string formats)
                            if (lastUpdate is num) {
                              // Numeric timestamp (milliseconds or seconds)
                              final timestamp = lastUpdate.toInt();
                              // Assume milliseconds if > 1e10, otherwise seconds
                              if (timestamp > 10000000000) {
                                lastUpdateTime =
                                    DateTime.fromMillisecondsSinceEpoch(
                                      timestamp,
                                    );
                              } else {
                                lastUpdateTime =
                                    DateTime.fromMillisecondsSinceEpoch(
                                      timestamp * 1000,
                                    );
                              }
                            } else if (lastUpdate is String) {
                              // ISO string format
                              try {
                                lastUpdateTime = DateTime.parse(lastUpdate);
                              } catch (e) {
                                // Invalid date format, but device is on - count it anyway
                                Logger.debug(
                                  'Invalid lastUpdate format for appliance $applianceId: $lastUpdate. Counting as active.',
                                );
                                totalActiveDevices++;
                                return;
                              }
                            }

                            // Check if device was updated within time window
                            if (lastUpdateTime != null) {
                              final timeDifference = now.difference(
                                lastUpdateTime,
                              );
                              if (timeDifference <= timeWindow &&
                                  timeDifference.isNegative == false) {
                                totalActiveDevices++;
                              } else {
                                devicesExcludedByTime++;
                              }
                            } else {
                              // Could not parse timestamp, but device is on - count it
                              totalActiveDevices++;
                            }
                          } else {
                            // No lastUpdate, but device is on - count it anyway
                            totalActiveDevices++;
                          }
                        }
                        // If isOn is false or missing, exclude from count
                      }
                    });
                  }
                }
              });

              // Debug logging
              Logger.debug('Active Devices Debug:');
              Logger.debug('  Total appliances found: $totalAppliances');
              Logger.debug('  Devices with isOn=true: $devicesWithIsOnTrue');
              Logger.debug(
                '  Devices excluded by time window: $devicesExcludedByTime',
              );
              Logger.debug('  Final active devices count: $totalActiveDevices');

              setState(() {
                _activeDevices = totalActiveDevices;
                _updateLastUpdateTime();
              });
            } else {
              setState(() {
                _activeDevices = 0;
              });
            }
          } catch (e) {
            Logger.error('Error counting active devices', e);
            // Keep _activeDevices as null, will fallback to placeholder
          }
        } else {
          setState(() {
            _activeDevices = 0;
          });
        }
      },
      onError: (error) {
        Logger.error('Error listening to active devices', error);
        // Keep _activeDevices as null, will fallback to placeholder
      },
    );
  }

  void _listenToEnergyUsage() {
    // Listen to users path in Realtime DB, then for each user listen to their thisMonthUsage/totalKwh
    // Path: users/{uid}/thisMonthUsage/totalKwh
    final usersRef = _database.ref('users');
    _energyUsageSubscription = usersRef.onValue.listen(
      (event) {
        if (mounted) {
          try {
            // Cancel previous subscriptions
            for (var subscription in _energyUsageSubscriptions) {
              subscription.cancel();
            }
            _energyUsageSubscriptions.clear();
            _userEnergyUsage.clear();

            final data = event.snapshot.value;
            if (data == null || data is! Map) {
              setState(() {
                _totalEnergyUsage = 0.0;
              });
              return;
            }

            // Get all user IDs
            final userIds = data.keys.map((k) => k.toString()).toList();

            if (userIds.isEmpty) {
              setState(() {
                _totalEnergyUsage = 0.0;
              });
              return;
            }

            // Listen to each user's thisMonthUsage/totalKwh
            for (final userId in userIds) {
              final userEnergyRef = _database.ref(
                'users/$userId/thisMonthUsage/totalKwh',
              );
              final subscription = userEnergyRef.onValue.listen(
                (energyEvent) {
                  // When any user's energy usage changes, update their value and recalculate total
                  final value = energyEvent.snapshot.value;
                  double kwhValue = 0.0;

                  if (value != null) {
                    if (value is num) {
                      kwhValue = value.toDouble();
                    } else if (value is String) {
                      kwhValue = double.tryParse(value) ?? 0.0;
                    }
                  }

                  _userEnergyUsage[userId] = kwhValue;
                  _updateTotalEnergyUsage();
                },
                onError: (error) {
                  Logger.debug(
                    'Error listening to thisMonthUsage/totalKwh for user $userId: $error',
                  );
                  // Remove user from map if error occurs
                  _userEnergyUsage.remove(userId);
                  _updateTotalEnergyUsage();
                },
              );
              _energyUsageSubscriptions.add(subscription);

              // Initial value from the snapshot
              try {
                final userData = data[userId];
                if (userData is Map) {
                  final thisMonthUsage = userData['thisMonthUsage'];
                  if (thisMonthUsage is Map) {
                    final totalKwhValue = thisMonthUsage['totalKwh'];
                    if (totalKwhValue != null) {
                      if (totalKwhValue is num) {
                        _userEnergyUsage[userId] = totalKwhValue.toDouble();
                      } else if (totalKwhValue is String) {
                        _userEnergyUsage[userId] =
                            double.tryParse(totalKwhValue) ?? 0.0;
                      }
                    }
                  }
                }
              } catch (e) {
                Logger.debug(
                  'Error reading initial energy usage for user $userId',
                  e,
                );
              }
            }

            // Initial calculation
            _updateTotalEnergyUsage();
          } catch (e) {
            Logger.error('Error setting up energy usage listeners', e);
            // Keep _totalEnergyUsage as null, will fallback to placeholder
          }
        }
      },
      onError: (error) {
        Logger.error('Error listening to users for energy usage', error);
        // Keep _totalEnergyUsage as null, will fallback to placeholder
      },
    );
  }

  void _updateTotalEnergyUsage() {
    // Sum all user energy usage values
    double totalKwh = 0.0;
    for (final value in _userEnergyUsage.values) {
      totalKwh += value;
    }

    if (mounted) {
      setState(() {
        _totalEnergyUsage = totalKwh;
        _updateLastUpdateTime();
      });
    }
  }

  void _listenToPowerRate() {
    // Listen to admin_settings/system_config document for powerRate
    _powerRateSubscription = _firestore
        .doc('admin_settings/system_config')
        .snapshots()
        .listen(
          (snapshot) {
            if (mounted && snapshot.exists) {
              try {
                final data = snapshot.data();
                if (data != null && data.containsKey('powerRate')) {
                  final rate = data['powerRate'];
                  if (rate is num) {
                    setState(() {
                      _powerRate = rate.toDouble();
                      _updateLastUpdateTime();
                    });
                  }
                }
              } catch (e) {
                Logger.error('Error reading power rate', e);
                // Keep _powerRate as null, will fallback to placeholder
              }
            }
          },
          onError: (error) {
            Logger.error('Error listening to power rate', error);
            // Keep _powerRate as null, will fallback to placeholder
          },
        );
  }

  @override
  void dispose() {
    _usersSubscription?.cancel();
    _usersRealtimeSubscription?.cancel();
    _devicesSubscription?.cancel();
    _energyUsageSubscription?.cancel();
    _powerRateSubscription?.cancel();
    // Cancel all energy usage subscriptions
    for (var subscription in _energyUsageSubscriptions) {
      subscription.cancel();
    }
    _energyUsageSubscriptions.clear();
    _userEnergyUsage.clear();
    _firestoreUsersSubscription?.cancel();
    _lastUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(),
            const SizedBox(height: 24),
            _buildSummaryCards(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColor.primary.withAlpha(26),
            AppColor.accentGreen.withAlpha(13),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColor.primary.withAlpha(26)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, Admin!',
                  style: ResponsiveText.headline(context).copyWith(
                    color: AppColor.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Here\'s what\'s happening with your EnergySmart system today.',
                  style: ResponsiveText.body(
                    context,
                  ).copyWith(color: AppColor.textSecondary),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildQuickStat(
                      'System Status',
                      _getSystemStatus(),
                      _getSystemStatus() == 'All Systems Operational'
                          ? Iconsax.tick_circle
                          : _getSystemStatus() == 'Loading...'
                          ? Iconsax.refresh
                          : Iconsax.warning_2,
                      _getSystemStatusColor(),
                    ),
                    const SizedBox(width: 24),
                    _buildQuickStat(
                      'Last Update',
                      _getLastUpdateText(),
                      Iconsax.clock,
                      AppColor.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColor.accentGreen.withAlpha(26),
              borderRadius: BorderRadius.circular(999),
            ),
            child:
                _adminUser?.photoUrl != null &&
                        _adminUser!.photoUrl!.isNotEmpty &&
                        !_profileImageError
                    ? CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white,
                      backgroundImage: NetworkImage(_adminUser!.photoUrl!),
                      onBackgroundImageError: (exception, stackTrace) {
                        if (mounted) {
                          setState(() {
                            _profileImageError = true;
                          });
                        }
                      },
                      child: null,
                    )
                    : CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white,
                      child:
                          _adminUser?.name != null &&
                                  _adminUser!.name.isNotEmpty
                              ? Text(
                                _adminUser!.name[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AppColor.accentGreen,
                                ),
                              )
                              : const Icon(
                                Iconsax.profile_circle,
                                size: 48,
                                color: AppColor.accentGreen,
                              ),
                    ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.1, end: 0);
  }

  Widget _buildQuickStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: ResponsiveText.caption(
                context,
              ).copyWith(color: AppColor.textSecondary),
            ),
            Text(
              value,
              style: ResponsiveText.body(
                context,
              ).copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    // Use static placeholder data - no null checks needed
    final stats = _dashboardStats;
    final subtitle =
        _userTypeCounts.isEmpty
            ? 'Registered users'
            : _userTypeCounts.entries
                .map((entry) => '${entry.key}: ${entry.value}')
                .join(' · ');
    final cards = [
      SummaryCardTypes.users(
        value: '${_totalUsers ?? stats['totalUsers']}',
        subtitle: subtitle,
        trend: '+12%',
        trendColor: AppColor.accentGreen,
        onTap: () {
          // Navigate to users screen
        },
      ),
      SummaryCardTypes.devices(
        value: '${_activeDevices ?? stats['activeDevices']}',
        subtitle: 'Currently active',
        trend: '+8%',
        trendColor: AppColor.accentGreen,
        onTap: () {
          // Navigate to devices screen
        },
      ),
      SummaryCardTypes.energyUsage(
        value:
            '${(_totalEnergyUsage ?? stats['totalEnergyUsage']).toStringAsFixed(1)} kWh',
        subtitle: 'Total this month',
        trend: '-5%',
        trendColor: AppColor.accentGreen,
        onTap: () {
          // Navigate to energy usage screen
        },
      ),
      SummaryCardTypes.powerRate(
        value:
            '₱${(_powerRate ?? stats['currentPowerRate']).toStringAsFixed(4)}/kWh',
        subtitle: 'Current rate',
        trend: '+2%',
        trendColor: AppColor.mediumConsumption,
        onTap: () {
          // Navigate to settings screen
        },
      ),
    ];

    return ResponsiveGrid(
      children:
          cards
              .map(
                (card) => SummaryCard(
                  title: card.title,
                  value: card.value,
                  subtitle: card.subtitle,
                  icon: card.icon,
                  iconColor: card.iconColor,
                  backgroundColor: card.backgroundColor,
                  onTap: card.onTap,
                  trend: card.trend,
                  trendColor: card.trendColor,
                ),
              )
              .toList(),
    );
  }

  String _normalizeUserType(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Unknown';
    final lower = trimmed.toLowerCase();
    if (lower.contains('house')) return 'Household';
    if (lower.contains('business')) return 'Small Business';
    if (lower.contains('small')) return 'Small Business';
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }
}
