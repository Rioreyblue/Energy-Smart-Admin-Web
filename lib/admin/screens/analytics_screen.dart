import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/constant.dart';
import '../widgets/chart_overview.dart';
import '../widgets/summary_card.dart';
import '../utils/responsive_layout.dart';
import '../../utils/logger.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>>? _energyUsageData;
  List<Map<String, dynamic>>? _hourlyUsageData;
  List<Map<String, dynamic>>? _deviceComparisonData;
  Map<String, double>?
  _heatmapData; // Key: "day_hour" (e.g., "0_6" for Monday 6 AM)
  double? _averageEnergyConsumption;
  double? _averageDailyConsumption;
  int? _peakUsageHour;
  bool _isLoading = true;
  String _selectedPeriod = '7 days';

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch all users from Firestore
      final usersSnapshot = await _firestore.collection('users').get();

      if (usersSnapshot.docs.isEmpty) {
        setState(() {
          _energyUsageData = [];
          _hourlyUsageData = [];
          _deviceComparisonData = [];
          _heatmapData = {};
          _averageEnergyConsumption = 0.0;
          _averageDailyConsumption = 0.0;
          _peakUsageHour = null;
          _isLoading = false;
        });
        return;
      }

      // Fetch monitoring dataset for all users
      final List<Map<String, dynamic>> allUsersData = [];
      double totalKwh = 0.0;
      int userCount = 0;

      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        try {
          final referenceDoc =
              await _firestore
                  .doc('users/$userId/monitoring_dataset/reference')
                  .get();

          if (referenceDoc.exists) {
            final data = referenceDoc.data();
            if (data != null && data.containsKey('monthlyData')) {
              final monthlyDataArray = data['monthlyData'];
              List<Map<String, dynamic>> monthlyDataList = [];

              // Process the monthlyData array
              if (monthlyDataArray is List && monthlyDataArray.isNotEmpty) {
                for (var entry in monthlyDataArray) {
                  if (entry is Map) {
                    monthlyDataList.add(entry as Map<String, dynamic>);
                  }
                }
              } else if (monthlyDataArray is Map) {
                // If it's a single Map, convert to list
                monthlyDataList.add(monthlyDataArray as Map<String, dynamic>);
              }

              if (monthlyDataList.isNotEmpty) {
                // Calculate total Kwh for average energy consumption (use first entry or latest)
                // For average, we'll use the most recent entry's totalKwh
                final latestEntry = monthlyDataList.last;
                final totalKwhValue = latestEntry['totalKwh'];
                if (totalKwhValue != null) {
                  final kwh =
                      totalKwhValue is num
                          ? totalKwhValue.toDouble()
                          : double.tryParse(totalKwhValue.toString()) ?? 0.0;
                  totalKwh += kwh;
                  userCount++;
                }

                // Store the full monthlyData array for trend processing
                allUsersData.add({
                  'userId': userId,
                  'monthlyData': monthlyDataList,
                });
              }
            }
          }
        } catch (e) {
          Logger.debug('Error fetching data for user $userId: $e');
        }
      }

      // Calculate average energy consumption
      _averageEnergyConsumption = userCount > 0 ? totalKwh / userCount : 0.0;

      // Process data for charts
      _processEnergyUsageTrend(allUsersData);
      _processDeviceComparison(allUsersData);
      _processHourlyUsagePattern(allUsersData);
      _processHeatmapData(allUsersData);

      // Calculate average daily consumption
      _calculateAverageDailyConsumption();

      // Calculate peak usage hour
      _calculatePeakUsageHour();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Error loading analytics data', e);
      setState(() {
        _isLoading = false;
        _energyUsageData = [];
        _hourlyUsageData = [];
        _deviceComparisonData = [];
        _heatmapData = {};
        _averageEnergyConsumption = 0.0;
        _averageDailyConsumption = 0.0;
        _peakUsageHour = null;
      });
    }
  }

  void _calculateAverageDailyConsumption() {
    if (_energyUsageData == null || _energyUsageData!.isEmpty) {
      _averageDailyConsumption = 0.0;
      return;
    }

    // Calculate total usage and number of days
    double totalUsage = 0.0;
    for (var data in _energyUsageData!) {
      final usage = data['usage'] as double? ?? 0.0;
      totalUsage += usage;
    }

    // Get number of days based on selected period
    int daysInPeriod = 7;
    switch (_selectedPeriod) {
      case '7 days':
        daysInPeriod = 7;
        break;
      case '30 days':
        daysInPeriod = 30;
        break;
      case '90 days':
        daysInPeriod = 90;
        break;
      case '1 year':
        daysInPeriod = 365;
        break;
    }

    // Calculate average daily consumption
    _averageDailyConsumption =
        daysInPeriod > 0 ? totalUsage / daysInPeriod : 0.0;
  }

  void _calculatePeakUsageHour() {
    if (_hourlyUsageData == null || _hourlyUsageData!.isEmpty) {
      _peakUsageHour = null;
      return;
    }

    // Find hour with maximum usage
    double maxUsage = 0.0;
    int peakHour = 0;

    for (var data in _hourlyUsageData!) {
      final usage = data['usage'] as double? ?? 0.0;
      if (usage > maxUsage) {
        maxUsage = usage;
        peakHour = data['hour'] as int? ?? 0;
      }
    }

    _peakUsageHour = maxUsage > 0 ? peakHour : null;
  }

  void _processEnergyUsageTrend(List<Map<String, dynamic>> allUsersData) {
    // Group data by date based on selected period
    final Map<String, double> usageByDate = {};
    final now = DateTime.now();
    int daysToShow = 7;

    switch (_selectedPeriod) {
      case '7 days':
        daysToShow = 7;
        break;
      case '30 days':
        daysToShow = 30;
        break;
      case '90 days':
        daysToShow = 90;
        break;
      case '1 year':
        daysToShow = 365;
        break;
    }

    final cutoffDate = now.subtract(Duration(days: daysToShow));

    // Process all entries from all users' monthlyData arrays
    for (var userData in allUsersData) {
      final monthlyDataList =
          userData['monthlyData'] as List<Map<String, dynamic>>?;

      if (monthlyDataList == null || monthlyDataList.isEmpty) {
        continue;
      }

      // Iterate through all entries in the monthlyData array
      for (var entry in monthlyDataList) {
        // Extract date from entry
        final date = _extractDateFromEntry(entry);

        if (date == null) {
          Logger.debug('Skipping entry with no valid date: $entry');
          continue;
        }

        // Filter by selected period
        if (!date.isAfter(cutoffDate)) {
          continue;
        }

        // Extract totalKwh from entry
        final totalKwh = entry['totalKwh'];
        if (totalKwh == null) {
          Logger.debug('Skipping entry with no totalKwh: $entry');
          continue;
        }

        final kwh =
            totalKwh is num
                ? totalKwh.toDouble()
                : double.tryParse(totalKwh.toString()) ?? 0.0;

        if (kwh <= 0) {
          continue;
        }

        // Group by date (YYYY-MM-DD format)
        final dateKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        // Aggregate usage by date across all users
        usageByDate[dateKey] = (usageByDate[dateKey] ?? 0.0) + kwh;
      }
    }

    // Convert to list format for chart
    final List<Map<String, dynamic>> trendData = [];
    final sortedDates = usageByDate.keys.toList()..sort();

    for (var dateKey in sortedDates) {
      final parts = dateKey.split('-');
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      final usage = usageByDate[dateKey]!;

      trendData.add({
        'date': date,
        'usage': usage,
        'cost': usage * 6.50, // Assuming power rate of 6.50
      });
    }

    // If no data, create empty data points for the period
    if (trendData.isEmpty) {
      for (int i = daysToShow - 1; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        trendData.add({'date': date, 'usage': 0.0, 'cost': 0.0});
      }
    }

    _energyUsageData = trendData;
  }

  DateTime? _extractDateFromEntry(Map<String, dynamic> entry) {
    // Priority order: date, timestamp, lastUpdated, createdAt, updatedAt
    final dateFields = [
      'date',
      'timestamp',
      'lastUpdated',
      'createdAt',
      'updatedAt',
    ];

    for (var fieldName in dateFields) {
      if (!entry.containsKey(fieldName)) {
        continue;
      }

      final fieldValue = entry[fieldName];

      // Handle Timestamp type
      if (fieldValue is Timestamp) {
        return fieldValue.toDate();
      }

      // Handle DateTime type
      if (fieldValue is DateTime) {
        return fieldValue;
      }

      // Handle numeric timestamp (milliseconds since epoch)
      if (fieldValue is num) {
        try {
          return DateTime.fromMillisecondsSinceEpoch(fieldValue.toInt());
        } catch (e) {
          Logger.debug('Error parsing numeric timestamp: $e');
          continue;
        }
      }

      // Handle string timestamp
      if (fieldValue is String) {
        final numValue = int.tryParse(fieldValue);
        if (numValue != null) {
          try {
            return DateTime.fromMillisecondsSinceEpoch(numValue);
          } catch (e) {
            Logger.debug('Error parsing string timestamp: $e');
            continue;
          }
        }
      }
    }

    // No valid date found
    return null;
  }

  void _processDeviceComparison(List<Map<String, dynamic>> allUsersData) {
    // Aggregate appliances_001, appliances_002, appliances_003, appliances_004
    final Map<String, double> applianceUsage = {};
    final Map<String, double> applianceCost = {};
    final Map<String, String> applianceNames = {};

    for (var userData in allUsersData) {
      final monthlyDataList =
          userData['monthlyData'] as List<Map<String, dynamic>>?;

      if (monthlyDataList == null || monthlyDataList.isEmpty) {
        continue;
      }

      // Process all entries in the monthlyData array
      for (var monthlyData in monthlyDataList) {
        if (monthlyData.containsKey('appliances') &&
            monthlyData['appliances'] is Map) {
          final appliances = monthlyData['appliances'] as Map;

          appliances.forEach((applianceId, applianceData) {
            if (applianceData is Map) {
              final applianceIdStr = applianceId.toString();

              // Only process appliances_001 to appliances_004
              if (applianceIdStr.startsWith('appliances_00') &&
                  int.tryParse(applianceIdStr.replaceAll('appliances_', '')) !=
                      null &&
                  int.parse(applianceIdStr.replaceAll('appliances_', '')) <=
                      4) {
                final name =
                    applianceData['name']?.toString() ??
                    applianceData['label']?.toString() ??
                    applianceIdStr;

                final kwh = applianceData['kWh'] ?? applianceData['kwh'];
                final cost = applianceData['cost'];

                double usage = 0.0;
                if (kwh != null) {
                  usage =
                      kwh is num
                          ? kwh.toDouble()
                          : double.tryParse(kwh.toString()) ?? 0.0;
                }

                double applianceCostValue = 0.0;
                if (cost != null) {
                  applianceCostValue =
                      cost is num
                          ? cost.toDouble()
                          : double.tryParse(cost.toString()) ?? 0.0;
                } else if (usage > 0) {
                  applianceCostValue =
                      usage * 6.50; // Calculate cost if not available
                }

                applianceUsage[applianceIdStr] =
                    (applianceUsage[applianceIdStr] ?? 0.0) + usage;
                applianceCost[applianceIdStr] =
                    (applianceCost[applianceIdStr] ?? 0.0) + applianceCostValue;
                applianceNames[applianceIdStr] = name;
              }
            }
          });
        }
      }
    }

    // Convert to list format for chart
    final List<Map<String, dynamic>> deviceData = [];
    for (var applianceId in applianceUsage.keys) {
      deviceData.add({
        'device': applianceNames[applianceId] ?? applianceId,
        'usage': applianceUsage[applianceId]!,
        'cost': applianceCost[applianceId]!,
      });
    }

    // Sort by usage descending
    deviceData.sort(
      (a, b) => (b['usage'] as double).compareTo(a['usage'] as double),
    );

    _deviceComparisonData = deviceData;
  }

  void _processHourlyUsagePattern(List<Map<String, dynamic>> allUsersData) {
    // Initialize hourly usage map
    final Map<int, double> hourlyUsage = {};
    for (int hour = 0; hour < 24; hour++) {
      hourlyUsage[hour] = 0.0;
    }

    // Aggregate usage by hour
    for (var userData in allUsersData) {
      final monthlyDataList =
          userData['monthlyData'] as List<Map<String, dynamic>>?;

      if (monthlyDataList == null || monthlyDataList.isEmpty) {
        continue;
      }

      // Process all entries in the monthlyData array
      for (var entry in monthlyDataList) {
        final date = _extractDateFromEntry(entry);
        if (date == null) {
          continue;
        }

        final hour = date.hour;
        final totalKwh = entry['totalKwh'];
        if (totalKwh != null) {
          final kwh =
              totalKwh is num
                  ? totalKwh.toDouble()
                  : double.tryParse(totalKwh.toString()) ?? 0.0;

          // Distribute daily usage across hours (simplified - in real scenario would have hourly data)
          hourlyUsage[hour] = (hourlyUsage[hour] ?? 0.0) + (kwh / 24);
        }
      }
    }

    // Convert to list format for chart
    final List<Map<String, dynamic>> hourlyData = [];
    for (int hour = 0; hour < 24; hour++) {
      hourlyData.add({'hour': hour, 'usage': hourlyUsage[hour] ?? 0.0});
    }

    _hourlyUsageData = hourlyData;
  }

  void _processHeatmapData(List<Map<String, dynamic>> allUsersData) {
    // Initialize heatmap data: key format "day_hour" (0=Monday, 6=Sunday)
    final Map<String, double> heatmap = {};

    for (var userData in allUsersData) {
      final monthlyDataList =
          userData['monthlyData'] as List<Map<String, dynamic>>?;

      if (monthlyDataList == null || monthlyDataList.isEmpty) {
        continue;
      }

      // Process all entries in the monthlyData array
      for (var entry in monthlyDataList) {
        final date = _extractDateFromEntry(entry);
        if (date == null) {
          continue;
        }

        final dayOfWeek = date.weekday - 1; // 0 = Monday, 6 = Sunday
        final hour = date.hour;
        final key = '${dayOfWeek}_$hour';

        final totalKwh = entry['totalKwh'];
        if (totalKwh != null) {
          final kwh =
              totalKwh is num
                  ? totalKwh.toDouble()
                  : double.tryParse(totalKwh.toString()) ?? 0.0;

          heatmap[key] =
              (heatmap[key] ?? 0.0) + (kwh / 24); // Distribute across hours
        }
      }
    }

    _heatmapData = heatmap;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.surface,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPeriodSelector(),
                  const SizedBox(height: 24),
                  _buildAnalyticsCards(),
                  const SizedBox(height: 24),
                  _buildChartsSection(),
                ],
              ),
            ),
          ),
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
                'Analytics & Insights',
                style: ResponsiveText.headline(context).copyWith(
                  color: AppColor.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Detailed analysis of energy consumption patterns',
                style: ResponsiveText.body(
                  context,
                ).copyWith(color: AppColor.textSecondary),
              ),
            ],
          ),
          _buildActionButton(
            'Refresh Data',
            Iconsax.refresh,
            AppColor.accentGreen,
            _loadAnalyticsData,
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

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withAlpha(26)),
      ),
      child: Row(
        children: [
          const Icon(
            Iconsax.calendar_1,
            color: AppColor.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            'Analysis Period:',
            style: ResponsiveText.body(context).copyWith(
              fontWeight: FontWeight.w600,
              color: AppColor.textPrimary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    ['7 days', '30 days', '90 days', '1 year'].map((period) {
                      final isSelected = _selectedPeriod == period;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(period),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedPeriod = period;
                            });
                            _loadAnalyticsData();
                          },
                          selectedColor: AppColor.accentGreen.withAlpha(51),
                          checkmarkColor: AppColor.accentGreen,
                          labelStyle: ResponsiveText.body(context).copyWith(
                            color:
                                isSelected
                                    ? AppColor.accentGreen
                                    : AppColor.textSecondary,
                            fontWeight:
                                isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCards() {
    if (_isLoading) {
      return _buildLoadingCards();
    }

    final averageConsumption = _averageEnergyConsumption ?? 0.0;
    final formattedAverage = _formatNumber(averageConsumption);

    final averageDaily = _averageDailyConsumption ?? 0.0;
    final formattedDaily = _formatNumber(averageDaily);

    final peakHour = _peakUsageHour;
    final formattedPeakHour = peakHour != null ? _formatHour(peakHour) : 'N/A';

    // Get period subtitle
    String periodSubtitle = 'Last $_selectedPeriod';
    if (_selectedPeriod == '1 year') {
      periodSubtitle = 'Last year';
    }

    final cards = [
      SummaryCard(
        title: 'Average Energy Consumption',
        value: '$formattedAverage kWh',
        subtitle: 'Across all users',
        icon: Iconsax.flash,
        iconColor: AppColor.accentGreen,
        trend: null,
        trendColor: AppColor.accentGreen,
      ),
      SummaryCard(
        title: 'Average Daily Consumption',
        value: '$formattedDaily kWh',
        subtitle: periodSubtitle,
        icon: Iconsax.flash,
        iconColor: AppColor.accentGreen,
        trend: null,
        trendColor: AppColor.accentGreen,
      ),
      SummaryCard(
        title: 'Peak Usage Hour',
        value: formattedPeakHour,
        subtitle: 'Most active time',
        icon: Iconsax.clock,
        iconColor: AppColor.mediumConsumption,
        trend: null,
        trendColor: AppColor.mediumConsumption,
      ),
    ];

    return ResponsiveGrid(children: cards);
  }

  Widget _buildLoadingCards() {
    final loadingCards = List.generate(
      3,
      (index) => SummaryCard(
        title: 'Loading...',
        value: '---',
        icon: Iconsax.refresh,
        isLoading: true,
      ),
    );

    return ResponsiveGrid(children: loadingCards);
  }

  String _formatNumber(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(1);
  }

  String _formatHour(int hour) {
    // Convert 0-23 hour to 12-hour format with AM/PM
    if (hour == 0) {
      return '12:00 AM';
    } else if (hour < 12) {
      return '$hour:00 AM';
    } else if (hour == 12) {
      return '12:00 PM';
    } else {
      return '${hour - 12}:00 PM';
    }
  }

  Widget _buildChartsSection() {
    return ResponsiveLayout(
      mobile: Column(
        children: [
          _buildEnergyTrendChart(),
          const SizedBox(height: 16),
          _buildHourlyPatternChart(),
          const SizedBox(height: 16),
          _buildDeviceComparisonChart(),
          const SizedBox(height: 16),
          _buildUsageHeatmap(),
        ],
      ),
      desktop: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildEnergyTrendChart()),
              const SizedBox(width: 16),
              Expanded(flex: 1, child: _buildDeviceComparisonChart()),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 1, child: _buildHourlyPatternChart()),
              const SizedBox(width: 16),
              Expanded(flex: 1, child: _buildUsageHeatmap()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnergyTrendChart() {
    if (_isLoading || _energyUsageData == null) {
      return _buildLoadingChart('Energy Usage Trend');
    }

    return ChartOverview(
      title: 'Energy Usage Trend',
      subtitle: 'Consumption over time',
      chart: EnergyUsageChart(data: _energyUsageData!, period: _selectedPeriod),
      legendItems: [
        ChartLegendItem(
          label: 'Energy Usage (kWh)',
          color: AppColor.accentGreen,
        ),
      ],
      onViewAll: () {
        _showDetailedChart('Energy Usage Trend');
      },
    );
  }

  Widget _buildHourlyPatternChart() {
    if (_isLoading || _hourlyUsageData == null) {
      return _buildLoadingChart('Hourly Usage Pattern');
    }

    return ChartOverview(
      title: 'Hourly Usage Pattern',
      subtitle: 'Average consumption by hour',
      chart: HourlyUsageChart(data: _hourlyUsageData!),
      legendItems: [
        ChartLegendItem(label: 'Peak Hours', color: AppColor.highConsumption),
        ChartLegendItem(
          label: 'Normal Hours',
          color: AppColor.mediumConsumption,
        ),
        ChartLegendItem(
          label: 'Off-Peak Hours',
          color: AppColor.lowConsumption,
        ),
      ],
      onViewAll: () {
        _showDetailedChart('Hourly Usage Pattern');
      },
    );
  }

  Widget _buildDeviceComparisonChart() {
    if (_isLoading || _deviceComparisonData == null) {
      return _buildLoadingChart('Device Comparison');
    }

    return ChartOverview(
      title: 'Device Comparison',
      subtitle: 'Energy usage by device type',
      chart: DeviceComparisonChart(data: _deviceComparisonData!),
      onViewAll: () {
        _showDetailedChart('Device Comparison');
      },
    );
  }

  Widget _buildUsageHeatmap() {
    return ChartOverview(
      title: 'Usage Heatmap',
      subtitle: 'Weekly consumption patterns',
      chart: _buildHeatmapChart(),
      onViewAll: () {
        _showDetailedChart('Usage Heatmap');
      },
    );
  }

  Widget _buildHeatmapChart() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final hours = List.generate(24, (index) => index);

    // Calculate max usage for normalization
    double maxUsage = 0.0;
    if (_heatmapData != null && _heatmapData!.isNotEmpty) {
      maxUsage = _heatmapData!.values.reduce((a, b) => a > b ? a : b);
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Day labels
          Row(
            children: [
              const SizedBox(width: 40), // Space for hour labels
              ...days.map(
                (day) => Expanded(
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: ResponsiveText.caption(context).copyWith(
                      color: AppColor.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Heatmap grid
          Expanded(
            child: Row(
              children: [
                // Hour labels
                SizedBox(
                  width: 40,
                  child: Column(
                    children:
                        hours.where((h) => h % 4 == 0).map((hour) {
                          return Expanded(
                            child: Center(
                              child: Text(
                                '$hour:00',
                                style: ResponsiveText.caption(context).copyWith(
                                  color: AppColor.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),
                const SizedBox(width: 8),
                // Heatmap cells
                Expanded(
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          childAspectRatio: 1,
                        ),
                    itemCount: 24 * 7,
                    itemBuilder: (context, index) {
                      final hour = index ~/ 7;
                      final day = index % 7;
                      final key = '${day}_$hour';

                      // Get usage from heatmap data
                      final usage = _heatmapData?[key] ?? 0.0;

                      // Calculate intensity (0.0 to 1.0)
                      double intensity = 0.0;
                      if (maxUsage > 0) {
                        intensity = (usage / maxUsage).clamp(0.0, 1.0);
                      }

                      // Minimum intensity for visibility
                      if (intensity < 0.1 && usage > 0) {
                        intensity = 0.1;
                      }

                      return Container(
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: Color.lerp(
                            AppColor.lowConsumption.withAlpha(26),
                            AppColor.highConsumption,
                            intensity,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Less',
                style: ResponsiveText.caption(
                  context,
                ).copyWith(color: AppColor.textSecondary),
              ),
              const SizedBox(width: 8),
              ...List.generate(5, (index) {
                final intensity = index / 4.0;
                return Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      AppColor.lowConsumption.withAlpha(26),
                      AppColor.highConsumption,
                      intensity,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
              const SizedBox(width: 8),
              Text(
                'More',
                style: ResponsiveText.caption(
                  context,
                ).copyWith(color: AppColor.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingChart(String title) {
    return ChartOverview(
      title: title,
      chart: Container(
        height: 300,
        decoration: BoxDecoration(
          color: AppColor.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColor.accentGreen),
          ),
        ),
      ),
    );
  }

  void _showDetailedChart(String chartTitle) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        chartTitle,
                        style: ResponsiveText.title(
                          context,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Iconsax.close_circle),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(child: _buildDetailedChartContent(chartTitle)),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildDetailedChartContent(String chartTitle) {
    switch (chartTitle) {
      case 'Energy Usage Trend':
        return EnergyUsageChart(
          data: _energyUsageData ?? [],
          period: _selectedPeriod,
        );
      case 'Hourly Usage Pattern':
        return HourlyUsageChart(data: _hourlyUsageData ?? []);
      case 'Device Comparison':
        return DeviceComparisonChart(data: _deviceComparisonData ?? []);
      case 'Usage Heatmap':
        return _buildHeatmapChart();
      default:
        return const Center(child: Text('Chart not available'));
    }
  }
}
