import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import '../../constants/constant.dart';

class ChartOverview extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget chart;
  final List<ChartLegendItem>? legendItems;
  final VoidCallback? onViewAll;

  const ChartOverview({
    super.key,
    required this.title,
    this.subtitle,
    required this.chart,
    this.legendItems,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 20),
            SizedBox(height: 300, child: chart),
            if (legendItems != null && legendItems!.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildLegend(context),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: ResponsiveText.title(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColor.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: ResponsiveText.body(
                    context,
                  ).copyWith(color: AppColor.textSecondary),
                ),
              ],
            ],
          ),
        ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            child: Text(
              'View All',
              style: ResponsiveText.body(context).copyWith(
                color: AppColor.accentGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children:
          legendItems!.map((item) => _buildLegendItem(context, item)).toList(),
    );
  }

  Widget _buildLegendItem(BuildContext context, ChartLegendItem item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          item.label,
          style: ResponsiveText.caption(
            context,
          ).copyWith(color: AppColor.textSecondary),
        ),
      ],
    );
  }
}

class ChartLegendItem {
  final String label;
  final Color color;

  ChartLegendItem({required this.label, required this.color});
}

class EnergyUsageChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String? period;

  const EnergyUsageChart({super.key, required this.data, this.period});

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 200,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Theme.of(context).dividerColor.withAlpha(51),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= data.length) return const Text('');
                final date = data[value.toInt()]['date'] as DateTime;
                return Text(
                  _formatDate(date),
                  style: ResponsiveText.caption(
                    context,
                  ).copyWith(color: AppColor.textSecondary),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 200,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}',
                  style: ResponsiveText.caption(
                    context,
                  ).copyWith(color: AppColor.textSecondary),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: Theme.of(context).dividerColor.withAlpha(51),
            width: 1,
          ),
        ),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY:
            data
                .map((e) => e['usage'] as double)
                .reduce((a, b) => a > b ? a : b) *
            1.1,
        lineBarsData: [
          LineChartBarData(
            spots:
                data.asMap().entries.map((entry) {
                  return FlSpot(
                    entry.key.toDouble(),
                    entry.value['usage'] as double,
                  );
                }).toList(),
            isCurved: true,
            gradient: LinearGradient(
              colors: [
                AppColor.accentGreen.withAlpha(204),
                AppColor.lowConsumption.withAlpha(204),
              ],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: AppColor.accentGreen,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColor.accentGreen.withAlpha(77),
                  AppColor.accentGreen.withAlpha(13),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}';
  }
}

class HourlyUsageChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const HourlyUsageChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY:
            data
                .map((e) => e['usage'] as double)
                .reduce((a, b) => a > b ? a : b) *
            1.1,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (touchedSpot) => AppColor.primary.withAlpha(230),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${group.x.toInt()}:00\n${rod.toY.toStringAsFixed(1)} kWh',
                ResponsiveText.caption(context).copyWith(color: Colors.white),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() % 4 == 0) {
                  return Text(
                    '${value.toInt()}:00',
                    style: ResponsiveText.caption(
                      context,
                    ).copyWith(color: AppColor.textSecondary),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}',
                  style: ResponsiveText.caption(
                    context,
                  ).copyWith(color: AppColor.textSecondary),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups:
            data.map((item) {
              final hour = item['hour'] as int;
              final usage = item['usage'] as double;

              // Color based on usage level
              Color barColor;
              if (usage > 100) {
                barColor = AppColor.highConsumption;
              } else if (usage > 60) {
                barColor = AppColor.mediumConsumption;
              } else {
                barColor = AppColor.lowConsumption;
              }

              return BarChartGroupData(
                x: hour,
                barRods: [
                  BarChartRodData(
                    toY: usage,
                    color: barColor,
                    width: 16,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              );
            }).toList(),
      ),
    );
  }
}

class DeviceComparisonChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const DeviceComparisonChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            pieTouchData: PieTouchData(
              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                // Handle touch events
              },
            ),
            borderData: FlBorderData(show: false),
            sectionsSpace: 2,
            centerSpaceRadius: 60,
            sections:
                data.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final device = item['device'] as String;
                  final usage = item['usage'] as double;
                  final totalUsage = data.fold(
                    0.0,
                    (sum, item) => sum + (item['usage'] as double),
                  );
                  final percentage = (usage / totalUsage) * 100;

                  return PieChartSectionData(
                    color: _getDeviceColor(device),
                    value: usage,
                    title: '${percentage.toStringAsFixed(1)}%',
                    radius: 80,
                    titleStyle: ResponsiveText.caption(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    badgeWidget: _buildArrowLabel(
                      context,
                      device,
                      index,
                      data.length,
                      _getDeviceColor(device),
                    ),
                    badgePositionPercentageOffset: 1.3,
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildArrowLabel(
    BuildContext context,
    String device,
    int index,
    int totalItems,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.arrow_right_2, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              device,
              style: ResponsiveText.caption(context).copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getDeviceColor(String device) {
    switch (device.toLowerCase()) {
      case 'air conditioner':
        return AppColor.highConsumption;
      case 'refrigerator':
        return AppColor.mediumConsumption;
      case 'washing machine':
        return AppColor.lowConsumption;
      case 'water heater':
        return AppColor.accentGreen;
      case 'lighting':
        return AppColor.primary;
      case 'electronics':
        return AppColor.textSecondary;
      default:
        return AppColor.disabled;
    }
  }
}
