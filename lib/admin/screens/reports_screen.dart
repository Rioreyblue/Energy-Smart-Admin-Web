import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../constants/constant.dart';
import '../utils/responsive_layout.dart';
import '../../utils/logger.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<DatabaseEvent>? _usersSubscription;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  bool _isGeneratingInvoice = false;
  String _searchQuery = '';
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _listenToUsers();
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
              data.forEach((uid, userData) {
                if (userData is Map) {
                  final user = _transformUserSummary(uid, userData);
                  if (user != null) {
                    users.add(user);
                  }
                }
              });

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

  Map<String, dynamic>? _transformUserSummary(
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

      // Extract energy usage and cost from todayUsage
      double energyUsage = 0.0;
      double energyCost = 0.0;
      if (userData['todayUsage'] is Map) {
        final todayUsage = userData['todayUsage'] as Map;
        final totalKwh = todayUsage['totalKwh'];
        final totalCost = todayUsage['totalCost'];

        if (totalKwh != null) {
          if (totalKwh is num) {
            energyUsage = totalKwh.toDouble();
          } else if (totalKwh is String) {
            energyUsage = double.tryParse(totalKwh) ?? 0.0;
          }
        }

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

      return {
        'id': uid.toString(),
        'uid': uid.toString(),
        'name': fullName,
        'email': email,
        'energyUsage': energyUsage,
        'energyCost': energyCost,
        'devices': deviceCount,
      };
    } catch (e) {
      Logger.error('Error transforming user summary for $uid', e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchUserInvoiceData(String userId) async {
    try {
      // Fetch user info from Realtime DB
      final userSnapshot = await _database.ref('users/$userId').get();
      if (!userSnapshot.exists) {
        return null;
      }

      final userData = userSnapshot.value as Map<dynamic, dynamic>?;
      if (userData == null) {
        return null;
      }

      // Extract user information
      final firstName = userData['firstName']?.toString() ?? '';
      final lastName = userData['lastName']?.toString() ?? '';
      final middleName = userData['middleName']?.toString() ?? '';
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

      final email = userData['email']?.toString() ?? '';
      final address = userData['address']?.toString() ?? '';
      final energyProvider = userData['energyProvider']?.toString() ?? '';
      final mobileNumber = userData['mobileNumber']?.toString() ?? '';
      final userType = userData['userType']?.toString() ?? '';

      // Count appliances from Realtime DB
      int applianceCount = 0;
      try {
        final appliancesSnapshot =
            await _database.ref('users/$userId/appliances').get();
        if (appliancesSnapshot.exists) {
          final appliancesData = appliancesSnapshot.value;
          if (appliancesData is Map) {
            applianceCount = appliancesData.length;
          }
        }
      } catch (e) {
        Logger.error('Error counting appliances from Realtime DB', e);
      }

      // Fetch energy usage and appliances from Firestore monthlyData
      double monthlyKwh = 0.0;
      List<Map<String, dynamic>> appliances = [];
      Map<String, dynamic>? monthlyDataFirstElement;

      try {
        final monthlyDataDoc =
            await _firestore
                .doc('users/$userId/monitoring_dataset/reference/monthlyData')
                .get();

        if (monthlyDataDoc.exists) {
          final data = monthlyDataDoc.data();
          if (data != null) {
            if (data.containsKey('monthlyData') &&
                data['monthlyData'] is List) {
              final monthlyDataArray = data['monthlyData'] as List;
              if (monthlyDataArray.isNotEmpty && monthlyDataArray[0] is Map) {
                monthlyDataFirstElement =
                    monthlyDataArray[0] as Map<String, dynamic>;

                // Extract totalKwh from first element
                if (monthlyDataFirstElement.containsKey('totalKwh')) {
                  final kwh = monthlyDataFirstElement['totalKwh'];
                  if (kwh is num) {
                    monthlyKwh = kwh.toDouble();
                  }
                }

                // Extract appliances from first element
                if (monthlyDataFirstElement.containsKey('appliances') &&
                    monthlyDataFirstElement['appliances'] is Map) {
                  final appliancesMap =
                      monthlyDataFirstElement['appliances'] as Map;
                  appliancesMap.forEach((applianceId, applianceData) {
                    if (applianceData is Map) {
                      final applianceName =
                          applianceData['name']?.toString() ??
                          applianceId.toString();
                      final kwh = applianceData['kWh'] ?? applianceData['kwh'];
                      final cost = applianceData['cost'];

                      double applianceKwh = 0.0;
                      if (kwh != null) {
                        if (kwh is num) {
                          applianceKwh = kwh.toDouble();
                        } else if (kwh is String) {
                          applianceKwh = double.tryParse(kwh) ?? 0.0;
                        }
                      }

                      double applianceCost = 0.0;
                      if (cost != null) {
                        if (cost is num) {
                          applianceCost = cost.toDouble();
                        } else if (cost is String) {
                          applianceCost = double.tryParse(cost) ?? 0.0;
                        }
                      }

                      // If cost is not available, calculate from kWh and power rate
                      if (applianceCost == 0.0 && applianceKwh > 0) {
                        // We'll calculate cost later when we have power rate
                      }

                      appliances.add({
                        'id': applianceId.toString(),
                        'name': applianceName,
                        'kwh': applianceKwh,
                        'cost': applianceCost,
                      });
                    }
                  });
                }
              }
            } else if (data.containsKey('totalKwh')) {
              final kwh = data['totalKwh'];
              if (kwh is num) {
                monthlyKwh = kwh.toDouble();
              }
            }
          }
        }
      } catch (e) {
        Logger.error('Error fetching monthlyData from Firestore', e);
      }

      // Fetch Today's Usage from Realtime DB
      double totalCost = 0.0;
      double todayKwh = 0.0;
      String totalUsageTime = '0 hours';
      DateTime? todayDate;
      DateTime? lastUpdate;
      DateTime? billingDate;

      try {
        final todayUsageSnapshot =
            await _database.ref('users/$userId/todayUsage').get();
        if (todayUsageSnapshot.exists) {
          final todayUsageData = todayUsageSnapshot.value;
          if (todayUsageData is Map) {
            // Extract totalKwh
            final totalKwhValue = todayUsageData['totalKwh'];
            if (totalKwhValue != null) {
              if (totalKwhValue is num) {
                todayKwh = totalKwhValue.toDouble();
              } else if (totalKwhValue is String) {
                todayKwh = double.tryParse(totalKwhValue) ?? 0.0;
              }
            }

            // Extract totalUsageTime
            final totalUsageTimeValue = todayUsageData['totalUsageTime'];
            if (totalUsageTimeValue != null) {
              if (totalUsageTimeValue is num) {
                final hours = totalUsageTimeValue.toDouble();
                totalUsageTime = '${hours.toStringAsFixed(2)} hours';
              } else if (totalUsageTimeValue is String) {
                totalUsageTime = totalUsageTimeValue;
              }
            }

            // Extract date
            final dateValue = todayUsageData['date'];
            if (dateValue != null) {
              if (dateValue is String) {
                try {
                  todayDate = DateTime.parse(dateValue);
                } catch (e) {
                  todayDate = DateTime.now();
                }
              } else if (dateValue is num) {
                todayDate = DateTime.fromMillisecondsSinceEpoch(
                  dateValue.toInt(),
                );
              }
            }

            // Extract lastUpdate
            final lastUpdateValue = todayUsageData['lastUpdate'];
            if (lastUpdateValue != null) {
              if (lastUpdateValue is String) {
                try {
                  lastUpdate = DateTime.parse(lastUpdateValue);
                } catch (e) {
                  lastUpdate = DateTime.now();
                }
              } else if (lastUpdateValue is num) {
                lastUpdate = DateTime.fromMillisecondsSinceEpoch(
                  lastUpdateValue.toInt(),
                );
              }
            }

            // Use lastUpdate as billingDate if available
            billingDate = lastUpdate ?? todayDate;
          }
        }
      } catch (e) {
        Logger.error('Error fetching todayUsage from Realtime DB', e);
      }

      // Fallback to userData['todayUsage'] if available (for backward compatibility)
      if (todayKwh == 0.0 && userData['todayUsage'] is Map) {
        final todayUsage = userData['todayUsage'] as Map;
        final totalCostValue = todayUsage['totalCost'];
        final totalKwhValue = todayUsage['totalKwh'];
        final lastUpdated = todayUsage['lastUpdated']?.toString();

        if (totalCostValue != null) {
          if (totalCostValue is num) {
            totalCost = totalCostValue.toDouble();
          } else if (totalCostValue is String) {
            totalCost = double.tryParse(totalCostValue) ?? 0.0;
          }
        }

        if (totalKwhValue != null) {
          if (totalKwhValue is num) {
            todayKwh = totalKwhValue.toDouble();
          } else if (totalKwhValue is String) {
            todayKwh = double.tryParse(totalKwhValue) ?? 0.0;
          }
        }

        if (lastUpdated != null && lastUpdated.isNotEmpty) {
          try {
            billingDate = DateTime.parse(lastUpdated);
            lastUpdate = billingDate;
          } catch (e) {
            billingDate = DateTime.now();
            lastUpdate = billingDate;
          }
        }
      }

      // Use monthlyKwh if available, otherwise use todayKwh
      final energyKwh = monthlyKwh > 0 ? monthlyKwh : todayKwh;

      // Fetch power rate from Firestore
      double powerRate = 6.50; // Default
      try {
        final powerRateDoc =
            await _firestore.doc('admin_settings/system_config').get();
        if (powerRateDoc.exists) {
          final data = powerRateDoc.data();
          if (data != null && data.containsKey('powerRate')) {
            final rate = data['powerRate'];
            if (rate is num) {
              powerRate = rate.toDouble();
            }
          }
        }
      } catch (e) {
        Logger.error('Error fetching power rate', e);
      }

      // Calculate appliance costs if not already set
      for (var appliance in appliances) {
        if ((appliance['cost'] as double) == 0.0 &&
            (appliance['kwh'] as double) > 0) {
          appliance['cost'] = (appliance['kwh'] as double) * powerRate;
        }
      }

      // Generate invoice number
      final invoiceNumber =
          'INV-${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${userId.substring(0, 8).toUpperCase()}';

      return {
        'userId': userId,
        'invoiceNumber': invoiceNumber,
        'invoiceDate': DateTime.now(),
        'billingDate': billingDate ?? DateTime.now(),
        'customer': {
          'name': fullName,
          'email': email,
          'address': address,
          'energyProvider': energyProvider,
          'mobileNumber': mobileNumber,
          'userType': userType,
          'applianceCount': applianceCount,
        },
        'todayUsage': {
          'totalKwh': todayKwh,
          'totalUsageTime': totalUsageTime,
          'date': todayDate ?? DateTime.now(),
          'lastUpdate': lastUpdate ?? DateTime.now(),
        },
        'energy': {
          'kwh': energyKwh,
          'cost': totalCost > 0 ? totalCost : (energyKwh * powerRate),
          'powerRate': powerRate,
        },
        'appliances': appliances,
        'summary': {
          'totalKwh': energyKwh,
          'totalCost': totalCost > 0 ? totalCost : (energyKwh * powerRate),
          'applianceCount': appliances.length,
        },
      };
    } catch (e) {
      Logger.error('Error fetching invoice data for user $userId', e);
      return null;
    }
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

    // Apply status filter (if needed in future)
    if (_selectedFilter != 'All') {
      // Filter logic can be added here if needed
    }

    setState(() {
      _filteredUsers = filtered;
    });
  }

  Future<void> _generateInvoice(String userId) async {
    setState(() {
      _isGeneratingInvoice = true;
    });

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final invoiceData = await _fetchUserInvoiceData(userId);
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        if (invoiceData != null) {
          setState(() {
            _isGeneratingInvoice = false;
          });
          _showInvoiceDialog(invoiceData);
        } else {
          setState(() {
            _isGeneratingInvoice = false;
          });
          _showSnackBar('Failed to generate invoice', AppColor.accentRed);
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        setState(() {
          _isGeneratingInvoice = false;
        });
        _showSnackBar('Error: $e', AppColor.accentRed);
      }
    }
  }

  void _showInvoiceDialog(Map<String, dynamic> invoiceData) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              width: double.maxFinite,
              constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColor.primary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Energy Consumption Invoice',
                          style: ResponsiveText.title(context).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Iconsax.close_circle,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Invoice Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: _buildInvoiceView(invoiceData),
                    ),
                  ),
                  // Footer Actions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Close',
                            style: ResponsiveText.body(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _generateInvoicePDF(invoiceData);
                          },
                          icon: const Icon(Iconsax.document_download, size: 18),
                          label: const Text('Export PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColor.accentGreen,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildInvoiceView(Map<String, dynamic> invoiceData) {
    final customer = invoiceData['customer'] as Map<String, dynamic>;
    final energy = invoiceData['energy'] as Map<String, dynamic>;
    final appliances = invoiceData['appliances'] as List<dynamic>;
    final invoiceDate = invoiceData['invoiceDate'] as DateTime;
    final billingDate = invoiceData['billingDate'] as DateTime;
    final invoiceNumber = invoiceData['invoiceNumber'] as String;

    // Calculate appliances totals
    double totalAppliancesKwh = 0.0;
    double totalAppliancesCost = 0.0;
    for (var appliance in appliances) {
      final app = appliance as Map<String, dynamic>;
      totalAppliancesKwh += (app['kwh'] as double? ?? 0.0);
      totalAppliancesCost += (app['cost'] as double? ?? 0.0);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Invoice Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: AppColor.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(32),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Iconsax.flash, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EnergySmart',
                            style: ResponsiveText.headline(context).copyWith(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              fontSize: 26,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Energy Consumption Invoice',
                            style: ResponsiveText.body(context).copyWith(
                              color: Colors.white.withAlpha(230),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(48),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'INVOICE',
                      style: ResponsiveText.body(context).copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Invoice #:',
                          style: ResponsiveText.caption(context).copyWith(
                            color: Colors.white.withAlpha(210),
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          invoiceNumber,
                          style: ResponsiveText.body(context).copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Date: ${_formatDate(invoiceDate)}',
                          style: ResponsiveText.caption(context).copyWith(
                            color: Colors.white.withAlpha(220),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Customer Information
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bill To:',
                    style: ResponsiveText.title(
                      context,
                    ).copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(12),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColor.primary.withAlpha(26),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Iconsax.profile_circle,
                                color: AppColor.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                customer['name'] ?? 'Unknown User',
                                style: ResponsiveText.body(context).copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: AppColor.textPrimary,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, thickness: 1),
                        const SizedBox(height: 12),
                        if ((customer['email'] as String?)?.isNotEmpty ??
                            false) ...[
                          _buildCustomerInfoRow('Email', customer['email']),
                          const SizedBox(height: 12),
                        ],
                        if ((customer['address'] as String?)?.isNotEmpty ??
                            false) ...[
                          _buildCustomerInfoRow('Address', customer['address']),
                          const SizedBox(height: 12),
                        ],
                        if ((customer['mobileNumber'] as String?)?.isNotEmpty ??
                            false) ...[
                          _buildCustomerInfoRow(
                            'Mobile',
                            customer['mobileNumber'],
                          ),
                          const SizedBox(height: 12),
                        ],
                        if ((customer['energyProvider'] as String?)
                                ?.isNotEmpty ??
                            false) ...[
                          _buildCustomerInfoRow(
                            'Energy Provider',
                            customer['energyProvider'],
                          ),
                          const SizedBox(height: 12),
                        ],
                        if ((customer['userType'] as String?)?.isNotEmpty ??
                            false) ...[
                          _buildCustomerInfoRow(
                            'User Type',
                            customer['userType'],
                          ),
                          const SizedBox(height: 12),
                        ],
                        if ((customer['applianceCount'] as int?) != null) ...[
                          const Divider(height: 20, thickness: 1),
                          _buildCustomerInfoRow(
                            'Number of Appliances (includes IoT modification)',
                            '${customer['applianceCount']}',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Billing Period:',
                    style: ResponsiveText.title(
                      context,
                    ).copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDate(billingDate),
                          style: ResponsiveText.body(
                            context,
                          ).copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Today's Usage Section
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColor.primary.withAlpha(18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Iconsax.flash, color: AppColor.primary, size: 24),
            ),
            const SizedBox(width: 10),
            Text(
              "Today's Usage",
              style: ResponsiveText.title(context).copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              _buildTodayUsageRow(
                'Total kWh',
                '${((invoiceData['todayUsage'] as Map<String, dynamic>)['totalKwh'] as double? ?? 0.0).toStringAsFixed(4)}',
                'kWh',
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 16),
              _buildTodayUsageRow(
                'Total Usage Time',
                (invoiceData['todayUsage']
                            as Map<String, dynamic>)['totalUsageTime']
                        as String? ??
                    '0 hours',
                '',
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 16),
              _buildTodayUsageRow(
                'Date',
                _formatDate(
                  (invoiceData['todayUsage'] as Map<String, dynamic>)['date']
                          as DateTime? ??
                      DateTime.now(),
                ),
                '',
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 16),
              _buildTodayUsageRow(
                'Last Updated',
                _formatDateTime(
                  (invoiceData['todayUsage']
                              as Map<String, dynamic>)['lastUpdate']
                          as DateTime? ??
                      DateTime.now(),
                ),
                '',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Appliances Summary Table
        if (appliances.isNotEmpty) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColor.accentGreen.withAlpha(18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Iconsax.chart,
                  color: AppColor.accentGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Appliances Summary',
                style: ResponsiveText.title(context).copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Table(
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
                verticalInside: BorderSide(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
                top: BorderSide(color: Colors.grey.shade300, width: 2),
                bottom: BorderSide(color: Colors.grey.shade300, width: 2),
                left: BorderSide(color: Colors.grey.shade300, width: 2),
                right: BorderSide(color: Colors.grey.shade300, width: 2),
              ),
              children: [
                // Header
                TableRow(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColor.accentGreen.withAlpha(38),
                        AppColor.accentGreen.withAlpha(20),
                      ],
                    ),
                  ),
                  children: [
                    _buildTableCell('Metric', isHeader: true),
                    _buildTableCell('Value', isHeader: true, alignRight: true),
                  ],
                ),
                // Total kWh
                TableRow(
                  children: [
                    _buildTableCell('Total kWh', isHeader: false),
                    _buildTableCell(
                      '${totalAppliancesKwh.toStringAsFixed(4)} kWh',
                      isHeader: false,
                      alignRight: true,
                    ),
                  ],
                ),
                // Total Cost
                TableRow(
                  children: [
                    _buildTableCell('Total Cost', isHeader: false),
                    _buildTableCell(
                      '₱${totalAppliancesCost.toStringAsFixed(2)}',
                      isHeader: false,
                      alignRight: true,
                    ),
                  ],
                ),
                // Current Rate
                TableRow(
                  children: [
                    _buildTableCell('Current Rate', isHeader: false),
                    _buildTableCell(
                      '₱${(energy['powerRate'] as double).toStringAsFixed(3)}/kWh',
                      isHeader: false,
                      alignRight: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Appliances Breakdown - Enhanced Table
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColor.primary.withAlpha(18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Iconsax.element_4,
                  color: AppColor.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Appliances Breakdown',
                style: ResponsiveText.title(context).copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Table(
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
                verticalInside: BorderSide(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
                top: BorderSide(color: Colors.grey.shade300, width: 2),
                bottom: BorderSide(color: Colors.grey.shade300, width: 2),
                left: BorderSide(color: Colors.grey.shade300, width: 2),
                right: BorderSide(color: Colors.grey.shade300, width: 2),
              ),
              children: [
                // Header
                TableRow(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColor.primary.withAlpha(38),
                        AppColor.primary.withAlpha(20),
                      ],
                    ),
                  ),
                  children: [
                    _buildTableCell('Appliance', isHeader: true),
                    _buildTableCell(
                      'Consumption (kWh)',
                      isHeader: true,
                      alignRight: true,
                    ),
                    _buildTableCell('Cost', isHeader: true, alignRight: true),
                  ],
                ),
                // Data rows with alternating colors
                ...appliances.asMap().entries.map((entry) {
                  final index = entry.key;
                  final appliance = entry.value as Map<String, dynamic>;
                  final isEven = index % 2 == 0;
                  return TableRow(
                    decoration: BoxDecoration(
                      color: isEven ? Colors.white : Colors.grey.shade50,
                    ),
                    children: [
                      _buildTableCell(appliance['name'] ?? 'Unknown'),
                      _buildTableCell(
                        '${(appliance['kwh'] as double).toStringAsFixed(4)}',
                        alignRight: true,
                      ),
                      _buildTableCell(
                        '₱${(appliance['cost'] as double).toStringAsFixed(2)}',
                        alignRight: true,
                      ),
                    ],
                  );
                }).toList(),
                // Total row
                TableRow(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColor.accentGreen.withAlpha(51),
                        AppColor.accentGreen.withAlpha(26),
                      ],
                    ),
                    border: Border(
                      top: BorderSide(
                        color: AppColor.accentGreen.withAlpha(77),
                        width: 2,
                      ),
                    ),
                  ),
                  children: [
                    _buildTableCell('Total', isHeader: true),
                    _buildTableCell(
                      '${totalAppliancesKwh.toStringAsFixed(4)}',
                      isHeader: true,
                      alignRight: true,
                    ),
                    _buildTableCell(
                      '₱${totalAppliancesCost.toStringAsFixed(2)}',
                      isHeader: true,
                      alignRight: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Energy Summary
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColor.accentGreen.withAlpha(64)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Energy Consumption:',
                    style: ResponsiveText.body(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  Text(
                    '${(energy['kwh'] as double).toStringAsFixed(4)} kWh',
                    style: ResponsiveText.body(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColor.accentGreen,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Power Rate:',
                    style: ResponsiveText.body(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  Text(
                    '₱${(energy['powerRate'] as double).toStringAsFixed(3)}/kWh',
                    style: ResponsiveText.body(context).copyWith(fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Divider(
                height: 1,
                thickness: 1.5,
                color: AppColor.accentGreen.withAlpha(128),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColor.accentGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Cost:',
                      style: ResponsiveText.title(context).copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontSize: 20,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      '₱${(energy['cost'] as double).toStringAsFixed(2)}',
                      style: ResponsiveText.title(context).copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontSize: 24,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Footer - Enhanced Design
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          child: Column(
            children: [
              Text(
                'Thank you for using EnergySmart!',
                style: ResponsiveText.body(context).copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColor.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'For inquiries, please contact our support team.',
                style: ResponsiveText.caption(
                  context,
                ).copyWith(color: AppColor.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    bool alignRight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style:
            isHeader
                ? ResponsiveText.body(
                  context,
                ).copyWith(fontWeight: FontWeight.bold, fontSize: 14)
                : ResponsiveText.body(context).copyWith(fontSize: 13),
      ),
    );
  }

  Widget _buildCustomerInfoRow(String label, dynamic value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: ResponsiveText.body(context).copyWith(
                fontWeight: FontWeight.w700,
                color: AppColor.textSecondary,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? '',
              style: ResponsiveText.body(context).copyWith(
                color: AppColor.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayUsageRow(String label, String value, String unit) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: ResponsiveText.body(context).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppColor.textSecondary,
          ),
        ),
        Text(
          '$value${unit.isNotEmpty ? ' $unit' : ''}',
          style: ResponsiveText.body(context).copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: AppColor.primary,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _generateInvoicePDF(Map<String, dynamic> invoiceData) async {
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

      // Try to load Unicode-capable fonts for Peso (₱)
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
        // If fonts are not bundled yet, continue with default theme
      }

      final customer = invoiceData['customer'] as Map<String, dynamic>;
      final energy = invoiceData['energy'] as Map<String, dynamic>;
      final appliances = invoiceData['appliances'] as List<dynamic>;
      final invoiceDate = invoiceData['invoiceDate'] as DateTime;
      final billingDate = invoiceData['billingDate'] as DateTime;
      final invoiceNumber = invoiceData['invoiceNumber'] as String;

      // Calculate appliances totals
      double totalAppliancesKwh = 0.0;
      double totalAppliancesCost = 0.0;
      for (var appliance in appliances) {
        final app = appliance as Map<String, dynamic>;
        totalAppliancesKwh += (app['kwh'] as double? ?? 0.0);
        totalAppliancesCost += (app['cost'] as double? ?? 0.0);
      }

      final applianceItems = appliances
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      final displayedAppliances =
          applianceItems.length > 8
              ? applianceItems.sublist(0, 8)
              : applianceItems;
      final hasMoreAppliances =
          applianceItems.length > displayedAppliances.length;

      // Create PDF document
      final pdf = pw.Document();

      // Add page with invoice
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          theme: pdfTheme,
          build: (pw.Context context) {
            return [
              // Header - Enhanced Design with Logo
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Row(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(8),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.grey200,
                              borderRadius: pw.BorderRadius.circular(8),
                            ),
                            child: pw.Image(logoImage, width: 36, height: 36),
                          ),
                          pw.SizedBox(width: 12),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'EnergySmart',
                                  style: pw.TextStyle(
                                    fontSize: 20,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  'Energy Consumption Invoice',
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    color: PdfColors.grey200,
                                    fontWeight: pw.FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey200,
                            borderRadius: pw.BorderRadius.circular(14),
                          ),
                          child: pw.Text(
                            'INVOICE',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blueGrey800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey200,
                            borderRadius: pw.BorderRadius.circular(8),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                'Invoice #:',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.blueGrey700,
                                ),
                              ),
                              pw.SizedBox(height: 1),
                              pw.Text(
                                invoiceNumber,
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blueGrey900,
                                ),
                              ),
                              pw.SizedBox(height: 3),
                              pw.Text(
                                'Date: ${_formatDate(invoiceDate)}',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.blueGrey600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 18),

              // Customer Information - Enhanced Layout
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Bill To:',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 12),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(14),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.circular(10),
                            border: pw.Border.all(
                              color: PdfColors.grey300,
                              width: 1,
                            ),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Row(
                                children: [
                                  pw.Container(
                                    padding: const pw.EdgeInsets.all(6),
                                    decoration: pw.BoxDecoration(
                                      color: PdfColors.blueGrey50,
                                      borderRadius: pw.BorderRadius.circular(6),
                                    ),
                                    child: pw.Text(
                                      '👤',
                                      style: pw.TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  pw.SizedBox(width: 8),
                                  pw.Expanded(
                                    child: pw.Text(
                                      customer['name'] ?? 'Unknown User',
                                      style: pw.TextStyle(
                                        fontSize: 15,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              pw.SizedBox(height: 12),
                              if ((customer['email'] as String?)?.isNotEmpty ??
                                  false) ...[
                                pw.Text(
                                  'Email: ${customer['email']}',
                                  style: pw.TextStyle(
                                    fontSize: 11,
                                    color: PdfColors.grey700,
                                    fontWeight: pw.FontWeight.normal,
                                  ),
                                ),
                                pw.SizedBox(height: 8),
                              ],
                              if ((customer['address'] as String?)
                                      ?.isNotEmpty ??
                                  false) ...[
                                pw.Text(
                                  'Address: ${customer['address']}',
                                  style: pw.TextStyle(
                                    fontSize: 11,
                                    color: PdfColors.grey700,
                                    fontWeight: pw.FontWeight.normal,
                                  ),
                                ),
                                pw.SizedBox(height: 8),
                              ],
                              if ((customer['mobileNumber'] as String?)
                                      ?.isNotEmpty ??
                                  false) ...[
                                pw.Text(
                                  'Mobile: ${customer['mobileNumber']}',
                                  style: pw.TextStyle(
                                    fontSize: 11,
                                    color: PdfColors.grey700,
                                    fontWeight: pw.FontWeight.normal,
                                  ),
                                ),
                                pw.SizedBox(height: 8),
                              ],
                              if ((customer['energyProvider'] as String?)
                                      ?.isNotEmpty ??
                                  false) ...[
                                pw.Text(
                                  'Energy Provider: ${customer['energyProvider']}',
                                  style: pw.TextStyle(
                                    fontSize: 11,
                                    color: PdfColors.grey700,
                                    fontWeight: pw.FontWeight.normal,
                                  ),
                                ),
                                pw.SizedBox(height: 8),
                              ],
                              if ((customer['userType'] as String?)
                                      ?.isNotEmpty ??
                                  false) ...[
                                pw.Text(
                                  'User Type: ${customer['userType']}',
                                  style: pw.TextStyle(
                                    fontSize: 11,
                                    color: PdfColors.grey700,
                                    fontWeight: pw.FontWeight.normal,
                                  ),
                                ),
                                pw.SizedBox(height: 8),
                              ],
                              if ((customer['applianceCount'] as int?) !=
                                  null) ...[
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: pw.Text(
                                    'Number of Appliances (includes IoT modification): ${customer['applianceCount']}',
                                    style: pw.TextStyle(
                                      fontSize: 11,
                                      color: PdfColors.grey700,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Billing Period:',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 12),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.circular(8),
                            border: pw.Border.all(
                              color: PdfColors.grey300,
                              width: 1,
                            ),
                          ),
                          child: pw.Text(
                            _formatDate(billingDate),
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 18),

              // Today's Usage Section - Enhanced
              pw.Text(
                "Today's Usage",
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(10),
                  border: pw.Border.all(color: PdfColors.grey300, width: 1),
                ),
                child: pw.Column(
                  children: [
                    _buildPDFUsageRow(
                      'Total kWh',
                      '${((invoiceData['todayUsage'] as Map<String, dynamic>)['totalKwh'] as double? ?? 0.0).toStringAsFixed(4)} kWh',
                    ),
                    pw.SizedBox(height: 12),
                    pw.Divider(height: 1, thickness: 1),
                    pw.SizedBox(height: 12),
                    _buildPDFUsageRow(
                      'Total Usage Time',
                      (invoiceData['todayUsage']
                                  as Map<String, dynamic>)['totalUsageTime']
                              as String? ??
                          '0 hours',
                    ),
                    pw.SizedBox(height: 12),
                    pw.Divider(height: 1, thickness: 1),
                    pw.SizedBox(height: 12),
                    _buildPDFUsageRow(
                      'Date',
                      _formatDate(
                        (invoiceData['todayUsage']
                                    as Map<String, dynamic>)['date']
                                as DateTime? ??
                            DateTime.now(),
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Divider(height: 1, thickness: 1),
                    pw.SizedBox(height: 12),
                    _buildPDFUsageRow(
                      'Last Updated',
                      _formatDateTime(
                        (invoiceData['todayUsage']
                                    as Map<String, dynamic>)['lastUpdate']
                                as DateTime? ??
                            DateTime.now(),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Appliances Summary Table
              if (appliances.isNotEmpty) ...[
                pw.Text(
                  'Appliances Summary',
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey300,
                    width: 2,
                  ),
                  children: [
                    // Header
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _buildPDFTableCell('Metric', isHeader: true),
                        _buildPDFTableCell(
                          'Value',
                          isHeader: true,
                          alignRight: true,
                        ),
                      ],
                    ),
                    // Total kWh
                    pw.TableRow(
                      children: [
                        _buildPDFTableCell('Total kWh', isHeader: false),
                        _buildPDFTableCell(
                          '${totalAppliancesKwh.toStringAsFixed(4)} kWh',
                          isHeader: false,
                          alignRight: true,
                        ),
                      ],
                    ),
                    // Total Cost
                    pw.TableRow(
                      children: [
                        _buildPDFTableCell('Total Cost', isHeader: false),
                        _buildPDFTableCell(
                          '$currencySymbol${totalAppliancesCost.toStringAsFixed(2)}',
                          isHeader: false,
                          alignRight: true,
                        ),
                      ],
                    ),
                    // Current Rate
                    pw.TableRow(
                      children: [
                        _buildPDFTableCell('Current Rate', isHeader: false),
                        _buildPDFTableCell(
                          '$currencySymbol${(energy['powerRate'] as double).toStringAsFixed(3)}/kWh',
                          isHeader: false,
                          alignRight: true,
                        ),
                      ],
                    ),
                  ],
                ),
                if (hasMoreAppliances)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 4),
                    child: pw.Text(
                      'Additional appliances not shown (total ${applianceItems.length}).',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ),
                pw.SizedBox(height: 20),

                // Appliances Breakdown - Enhanced Table
                pw.Text(
                  'Appliances Breakdown',
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey300,
                    width: 2,
                  ),
                  children: [
                    // Header
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _buildPDFTableCell('Appliance', isHeader: true),
                        _buildPDFTableCell(
                          'Consumption (kWh)',
                          isHeader: true,
                          alignRight: true,
                        ),
                        _buildPDFTableCell(
                          'Cost',
                          isHeader: true,
                          alignRight: true,
                        ),
                      ],
                    ),
                    // Data rows with alternating colors
                    ...displayedAppliances.asMap().entries.map((entry) {
                      final index = entry.key;
                      final appliance = entry.value;
                      final isEven = index % 2 == 0;
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: isEven ? PdfColors.white : PdfColors.grey100,
                        ),
                        children: [
                          _buildPDFTableCell(appliance['name'] ?? 'Unknown'),
                          _buildPDFTableCell(
                            '${(appliance['kwh'] as double).toStringAsFixed(4)}',
                            alignRight: true,
                          ),
                          _buildPDFTableCell(
                            '$currencySymbol${(appliance['cost'] as double).toStringAsFixed(2)}',
                            alignRight: true,
                          ),
                        ],
                      );
                    }).toList(),
                    // Total row
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        _buildPDFTableCell('Total', isHeader: true),
                        _buildPDFTableCell(
                          '${totalAppliancesKwh.toStringAsFixed(4)}',
                          isHeader: true,
                          alignRight: true,
                        ),
                        _buildPDFTableCell(
                          '$currencySymbol${totalAppliancesCost.toStringAsFixed(2)}',
                          isHeader: true,
                          alignRight: true,
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
              ],

              // Energy Summary
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.grey300, width: 1),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Total Energy Consumption',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey800,
                          ),
                        ),
                        pw.Text(
                          '${(energy['kwh'] as double).toStringAsFixed(4)} kWh',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey900,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Power Rate',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey700,
                          ),
                        ),
                        pw.Text(
                          '$currencySymbol${(energy['powerRate'] as double).toStringAsFixed(3)}/kWh',
                          style: pw.TextStyle(
                            fontSize: 11,
                            color: PdfColors.blueGrey700,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blueGrey700,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Total Cost',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.Text(
                            '$currencySymbol${(energy['cost'] as double).toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Footer
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Thank you for using EnergySmart!',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'For inquiries, please contact our support team.',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
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
        _showSnackBar(
          'Invoice PDF exported successfully',
          AppColor.accentGreen,
        );
      }
    } catch (e) {
      Logger.error('Error exporting invoice PDF', e);
      if (mounted) {
        Navigator.of(context).pop();
        _showSnackBar('Failed to export PDF: $e', AppColor.accentRed);
      }
    }
  }

  pw.Widget _buildPDFTableCell(
    String text, {
    bool isHeader = false,
    bool alignRight = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(10),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: isHeader ? 13 : 12,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.grey800 : PdfColors.grey700,
        ),
      ),
    );
  }

  pw.Widget _buildPDFUsageRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          '$label:',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
      ],
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
  void dispose() {
    _usersSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.surface,
      body: Column(
        children: [
          _buildHeader(),
          _buildFilters(),
          Expanded(child: _buildUsersList()),
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
                'Energy Consumption Invoices',
                style: ResponsiveText.headline(context).copyWith(
                  color: AppColor.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Generate and export user energy consumption invoices',
                style: ResponsiveText.body(
                  context,
                ).copyWith(color: AppColor.textSecondary),
              ),
            ],
          ),
        ],
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
        ],
      ),
    );
  }

  Widget _buildUsersList() {
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
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                    });
                    _listenToUsers();
                  },
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
          DataColumn(label: Text('Energy Usage (kWh)')),
          DataColumn(label: Text('Energy Cost')),
          DataColumn(label: Text('Devices')),
          DataColumn(label: Text('Actions')),
        ],
        rows:
            _filteredUsers.map((user) {
              return DataRow(
                cells: [
                  DataCell(Text(user['name'] ?? 'Unknown')),
                  DataCell(Text(user['email'] ?? '')),
                  DataCell(
                    Text(
                      '${(user['energyUsage'] as double).toStringAsFixed(4)}',
                    ),
                  ),
                  DataCell(
                    Text(
                      '₱${(user['energyCost'] as double).toStringAsFixed(2)}',
                    ),
                  ),
                  DataCell(Text('${user['devices']}')),
                  DataCell(
                    ElevatedButton.icon(
                      onPressed:
                          _isGeneratingInvoice
                              ? null
                              : () => _generateInvoice(user['uid']),
                      icon: const Icon(Iconsax.document_text, size: 16),
                      label: const Text('Generate Invoice'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColor.accentGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
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
                    (user['name'] ?? '?')
                        .toString()
                        .substring(0, 1)
                        .toUpperCase(),
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
                        user['name'] ?? 'Unknown',
                        style: ResponsiveText.body(
                          context,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        user['email'] ?? '',
                        style: ResponsiveText.caption(
                          context,
                        ).copyWith(color: AppColor.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(
                  'Usage',
                  '${(user['energyUsage'] as double).toStringAsFixed(4)} kWh',
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  'Cost',
                  '₱${(user['energyCost'] as double).toStringAsFixed(2)}',
                ),
                const SizedBox(width: 8),
                _buildInfoChip('Devices', '${user['devices']}'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _isGeneratingInvoice
                        ? null
                        : () => _generateInvoice(user['uid']),
                icon: const Icon(Iconsax.document_text, size: 18),
                label: const Text('Generate Invoice'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.accentGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.document_text,
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
            'Try adjusting your search criteria.',
            style: ResponsiveText.body(
              context,
            ).copyWith(color: AppColor.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
