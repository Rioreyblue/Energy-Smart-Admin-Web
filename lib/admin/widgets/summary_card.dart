import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../constants/constant.dart';

class SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final bool isLoading;
  final String? trend;
  final Color? trendColor;

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.iconColor,
    this.backgroundColor,
    this.onTap,
    this.isLoading = false,
    this.trend,
    this.trendColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient:
                backgroundColor != null
                    ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        backgroundColor!.withAlpha(26),
                        backgroundColor!.withAlpha(13),
                      ],
                    )
                    : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (iconColor ?? AppColor.accentGreen).withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor ?? AppColor.accentGreen,
                      size: 24,
                    ),
                  ),
                  if (trend != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (trendColor ?? AppColor.accentGreen).withAlpha(
                          26,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            trend!.startsWith('+')
                                ? Iconsax.arrow_up_2
                                : Iconsax.arrow_down_2,
                            size: 12,
                            color: trendColor ?? AppColor.accentGreen,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            trend!,
                            style: ResponsiveText.caption(context).copyWith(
                              color: trendColor ?? AppColor.accentGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: ResponsiveText.body(context).copyWith(
                  color: AppColor.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              if (isLoading)
                Container(
                  height: 32,
                  width: 120,
                  decoration: BoxDecoration(
                    color: AppColor.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColor.accentGreen,
                        ),
                      ),
                    ),
                  ),
                )
              else
                Text(
                  value,
                  style: ResponsiveText.headline(context).copyWith(
                    color: AppColor.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: ResponsiveText.caption(
                    context,
                  ).copyWith(color: AppColor.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }
}

class SummaryCardGrid extends StatelessWidget {
  final List<SummaryCardData> cards;
  final int? crossAxisCount;

  const SummaryCardGrid({super.key, required this.cards, this.crossAxisCount});

  @override
  Widget build(BuildContext context) {
    final columns = crossAxisCount ?? _getResponsiveColumns(context);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return SummaryCard(
          title: card.title,
          value: card.value,
          subtitle: card.subtitle,
          icon: card.icon,
          iconColor: card.iconColor,
          backgroundColor: card.backgroundColor,
          onTap: card.onTap,
          isLoading: card.isLoading,
          trend: card.trend,
          trendColor: card.trendColor,
        );
      },
    );
  }

  int _getResponsiveColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 4;
    if (width > 900) return 3;
    if (width > 600) return 2;
    return 1;
  }
}

class SummaryCardData {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final bool isLoading;
  final String? trend;
  final Color? trendColor;

  SummaryCardData({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.iconColor,
    this.backgroundColor,
    this.onTap,
    this.isLoading = false,
    this.trend,
    this.trendColor,
  });
}

// Predefined card types for common use cases
class SummaryCardTypes {
  static SummaryCardData users({
    required String value,
    String? subtitle,
    String? trend,
    Color? trendColor,
    bool isLoading = false,
    VoidCallback? onTap,
  }) {
    return SummaryCardData(
      title: 'Total Users',
      value: value,
      subtitle: subtitle,
      icon: Iconsax.profile_2user,
      iconColor: AppColor.primary,
      backgroundColor: AppColor.primary,
      trend: trend,
      trendColor: trendColor,
      isLoading: isLoading,
      onTap: onTap,
    );
  }

  static SummaryCardData devices({
    required String value,
    String? subtitle,
    String? trend,
    Color? trendColor,
    bool isLoading = false,
    VoidCallback? onTap,
  }) {
    return SummaryCardData(
      title: 'Active Devices',
      value: value,
      subtitle: subtitle,
      icon: Iconsax.flash,
      iconColor: AppColor.accentGreen,
      backgroundColor: AppColor.accentGreen,
      trend: trend,
      trendColor: trendColor,
      isLoading: isLoading,
      onTap: onTap,
    );
  }

  static SummaryCardData energyUsage({
    required String value,
    String? subtitle,
    String? trend,
    Color? trendColor,
    bool isLoading = false,
    VoidCallback? onTap,
  }) {
    return SummaryCardData(
      title: 'Energy Usage',
      value: value,
      subtitle: subtitle,
      icon: Iconsax.flash,
      iconColor: AppColor.mediumConsumption,
      backgroundColor: AppColor.mediumConsumption,
      trend: trend,
      trendColor: trendColor,
      isLoading: isLoading,
      onTap: onTap,
    );
  }

  static SummaryCardData powerRate({
    required String value,
    String? subtitle,
    String? trend,
    Color? trendColor,
    bool isLoading = false,
    VoidCallback? onTap,
  }) {
    return SummaryCardData(
      title: 'Power Rate',
      value: value,
      subtitle: subtitle,
      icon: Iconsax.dollar_circle,
      iconColor: AppColor.lowConsumption,
      backgroundColor: AppColor.lowConsumption,
      trend: trend,
      trendColor: trendColor,
      isLoading: isLoading,
      onTap: onTap,
    );
  }

  static SummaryCardData savings({
    required String value,
    String? subtitle,
    String? trend,
    Color? trendColor,
    bool isLoading = false,
    VoidCallback? onTap,
  }) {
    return SummaryCardData(
      title: 'Monthly Savings',
      value: value,
      subtitle: subtitle,
      icon: Iconsax.wallet_3,
      iconColor: AppColor.accentGreen,
      backgroundColor: AppColor.accentGreen,
      trend: trend,
      trendColor: trendColor,
      isLoading: isLoading,
      onTap: onTap,
    );
  }

  static SummaryCardData carbonFootprint({
    required String value,
    String? subtitle,
    String? trend,
    Color? trendColor,
    bool isLoading = false,
    VoidCallback? onTap,
  }) {
    return SummaryCardData(
      title: 'Carbon Footprint',
      value: value,
      subtitle: subtitle,
      icon: Iconsax.tree,
      iconColor: AppColor.lowConsumption,
      backgroundColor: AppColor.lowConsumption,
      trend: trend,
      trendColor: trendColor,
      isLoading: isLoading,
      onTap: onTap,
    );
  }
}
