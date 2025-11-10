import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../constants/constant.dart';
import '../services/firebase_settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseSettingsService _settingsService = FirebaseSettingsService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _powerRateController;

  bool _notificationEnabled = true;
  bool _isLoading = false;
  bool _hasChanges = false;
  String _lastUpdatedBy = 'System';
  DateTime _lastUpdated = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _powerRateController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final settings = await _settingsService.getSystemSettings();

      final powerRate = (settings['powerRate'] as num?)?.toDouble();

      setState(() {
        _powerRateController = TextEditingController(
          text: powerRate != null && powerRate > 0 ? powerRate.toString() : '',
        );
        _notificationEnabled = settings['notificationEnabled'] as bool;
        _lastUpdatedBy = settings['updatedBy'] as String;
        _lastUpdated = settings['lastUpdated'] as DateTime;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Failed to load settings: $e', AppColor.accentRed);
    }
  }

  void _onSettingChanged() {
    setState(() {
      _hasChanges = true;
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get current power rate before updating
      final currentSettings = await _settingsService.getSystemSettings();
      final previousPowerRate =
          (currentSettings['powerRate'] as num?)?.toDouble();

      final newPowerRate = double.parse(_powerRateController.text);
      final settings = {
        'powerRate': newPowerRate,
        'notificationEnabled': _notificationEnabled,
      };

      final success = await _settingsService.updateSystemSettings(settings);

      // Save power rate history if value changed
      if (success &&
          (previousPowerRate == null || previousPowerRate != newPowerRate)) {
        await _settingsService.savePowerRateHistory(
          previousPowerRate ?? 0.0,
          newPowerRate,
          'Updated via settings page',
        );
      }

      setState(() {
        _isLoading = false;
      });

      if (success) {
        setState(() {
          _hasChanges = false;
        });
        _showSnackBar('Settings saved successfully', AppColor.accentGreen);
        // Reload settings to get updated metadata
        await _loadSettings();
      } else {
        _showSnackBar('Failed to save settings', AppColor.accentRed);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error saving settings: $e', AppColor.accentRed);
    }
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
          Expanded(
            child: _isLoading ? _buildLoadingState() : _buildSettingsContent(),
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
                'System Settings',
                style: ResponsiveText.headline(context).copyWith(
                  color: AppColor.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Configure system parameters and preferences',
                style: ResponsiveText.body(
                  context,
                ).copyWith(color: AppColor.textSecondary),
              ),
            ],
          ),
          if (_hasChanges)
            ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Iconsax.tick_circle, size: 18),
              label: const Text('Save Changes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColor.accentGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColor.accentGreen),
          ),
          SizedBox(height: 16),
          Text(
            'Loading settings...',
            style: TextStyle(color: AppColor.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildEnergySettingsCard(),
            const SizedBox(height: 16),
            _buildNotificationSettingsCard(),
            const SizedBox(height: 16),
            _buildSystemInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildEnergySettingsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Iconsax.flash,
                  color: AppColor.accentGreen,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Energy Settings',
                  style: ResponsiveText.title(context).copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColor.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _powerRateController,
              label: 'Power Rate',
              hint: 'Enter power rate per kWh',
              suffix: '\₱/kWh',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter power rate';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                if (double.parse(value) <= 0) {
                  return 'Power rate must be greater than 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showPowerRateHistory(),
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text('View History'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColor.surface,
                      foregroundColor: AppColor.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showPowerRateDialog(),
                    icon: const Icon(Iconsax.edit, size: 16),
                    label: const Text('Quick Edit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColor.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // _buildTextField(
            //   controller: _targetThresholdController,
            //   label: 'Target Threshold',
            //   hint: 'Enter target energy threshold percentage',
            //   suffix: '%',
            //   validator: (value) {
            //     if (value == null || value.isEmpty) {
            //       return 'Please enter target threshold';
            //     }
            //     if (double.tryParse(value) == null) {
            //       return 'Please enter a valid number';
            //     }
            //     final threshold = double.parse(value);
            //     if (threshold < 0 || threshold > 100) {
            //       return 'Threshold must be between 0 and 100';
            //     }
            //     return null;
            //   },
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSettingsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Iconsax.notification,
                  color: AppColor.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Notification Settings',
                  style: ResponsiveText.title(context).copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColor.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSwitchTile(
              title: 'Enable Notifications',
              subtitle: 'Receive alerts for system events and updates',
              value: _notificationEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationEnabled = value;
                  _onSettingChanged();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Iconsax.info_circle,
                  color: AppColor.textSecondary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'System Information',
                  style: ResponsiveText.title(context).copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColor.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoRow('App Version', '1.0.0'),
            _buildInfoRow('Last Updated', _formatDateTime(_lastUpdated)),
            _buildInfoRow('Updated By', _lastUpdatedBy),
            _buildInfoRow('Database Status', 'Connected (Firebase)'),
            _buildInfoRow('Server Status', 'Online'),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showUpdateDialog();
                    },
                    icon: const Icon(Iconsax.refresh, size: 18),
                    label: const Text('Check for Updates'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColor.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showAboutDialog();
                    },
                    icon: const Icon(Iconsax.info_circle, size: 18),
                    label: const Text('About'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColor.surface,
                      foregroundColor: AppColor.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? suffix,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ResponsiveText.body(
            context,
          ).copyWith(fontWeight: FontWeight.w600, color: AppColor.textPrimary),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          onChanged: (_) => _onSettingChanged(),
          validator: validator,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColor.accentGreen,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: ResponsiveText.body(context).copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColor.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: ResponsiveText.caption(
                  context,
                ).copyWith(color: AppColor.textSecondary),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColor.accentGreen,
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatCurrency(double value) {
    return '₱${value.toStringAsFixed(2)}';
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Check for Updates',
              style: ResponsiveText.title(context),
            ),
            content: const Text(
              'You are running the latest version of EnergySmart Admin Dashboard.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'OK',
                  style: ResponsiveText.body(
                    context,
                  ).copyWith(color: AppColor.textSecondary),
                ),
              ),
            ],
          ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'About EnergySmart Admin',
              style: ResponsiveText.title(context),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EnergySmart Admin Dashboard',
                  style: ResponsiveText.body(
                    context,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Version 1.0.0'),
                const SizedBox(height: 8),
                Text(
                  'A comprehensive admin dashboard for managing energy consumption and monitoring system performance.',
                  style: ResponsiveText.body(
                    context,
                  ).copyWith(color: AppColor.textSecondary),
                ),
                const SizedBox(height: 16),
                Text(
                  'Built with Flutter and Firebase',
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

  void _showPowerRateHistory() async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Power Rate History',
              style: ResponsiveText.title(context),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _settingsService.getPowerRateHistory(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error loading history: ${snapshot.error}'),
                    );
                  }

                  final history = snapshot.data ?? [];

                  if (history.isEmpty) {
                    return const Center(
                      child: Text('No power rate history found'),
                    );
                  }

                  return ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final item = history[index];
                      final newValue =
                          (item['value'] as num?)?.toDouble() ?? 0.0;
                      final oldValue =
                          (item['oldValue'] as num?)?.toDouble() ?? newValue;
                      final difference = newValue - oldValue;
                      final increased = difference > 0;
                      final decreased = difference < 0;
                      final arrowIcon =
                          increased
                              ? Iconsax.arrow_up_1
                              : decreased
                              ? Iconsax.arrow_down_1
                              : Iconsax.minus;
                      final arrowColor =
                          increased
                              ? AppColor.accentGreen
                              : decreased
                              ? AppColor.accentRed
                              : AppColor.textSecondary;
                      final reasonRaw = item['reason'] as String? ?? '';
                      final reason =
                          reasonRaw.trim().isEmpty
                              ? 'No reason provided'
                              : reasonRaw;
                      final updatedBy =
                          item['updatedBy'] as String? ?? 'Unknown';
                      final timestamp = item['timestamp'] as DateTime?;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 60,
                                    decoration: BoxDecoration(
                                      color: AppColor.primary.withAlpha(24),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                      horizontal: 8,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _formatCurrency(oldValue),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColor.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Icon(
                                          arrowIcon,
                                          size: 14,
                                          color: arrowColor,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatCurrency(newValue),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            color: AppColor.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${_formatCurrency(oldValue)} → ${_formatCurrency(newValue)}',
                                          style: ResponsiveText.body(
                                            context,
                                          ).copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: AppColor.textPrimary,
                                          ),
                                        ),
                                        if (difference != 0)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Text(
                                              'Change: ${difference > 0 ? '+' : ''}${_formatCurrency(difference.abs())} (${difference > 0 ? 'Increase' : 'Decrease'})',
                                              style: ResponsiveText.caption(
                                                context,
                                              ).copyWith(
                                                color: AppColor.textSecondary,
                                              ),
                                            ),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(
                                            'Reason: $reason',
                                            style: ResponsiveText.caption(
                                              context,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(
                                            'Updated by: $updatedBy',
                                            style: ResponsiveText.caption(
                                              context,
                                            ).copyWith(
                                              color: AppColor.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (timestamp != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      _formatDateTime(timestamp),
                                      style: ResponsiveText.caption(
                                        context,
                                      ).copyWith(color: AppColor.textSecondary),
                                    ),
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      '—',
                                      style: ResponsiveText.caption(
                                        context,
                                      ).copyWith(color: AppColor.textSecondary),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showPowerRateDialog() async {
    // Get current power rate before showing dialog
    final currentSettings = await _settingsService.getSystemSettings();
    final currentPowerRate = (currentSettings['powerRate'] as num?)?.toDouble();

    final controller = TextEditingController(text: _powerRateController.text);
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Quick Edit Power Rate',
              style: ResponsiveText.title(context),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Power Rate (₱/kWh)',
                    border: OutlineInputBorder(),
                    prefixText: '₱',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason for change (optional)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Market rate adjustment',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newRate = double.tryParse(controller.text);
                  if (newRate != null && newRate > 0) {
                    final reason =
                        reasonController.text.trim().isEmpty
                            ? 'No reason provided'
                            : reasonController.text.trim();

                    final success = await _settingsService.updatePowerRate(
                      newRate,
                      oldValue: currentPowerRate,
                      reason: reason,
                    );

                    if (success) {
                      _powerRateController.text = newRate.toString();
                      _onSettingChanged();
                      _showSnackBar(
                        'Power rate updated successfully',
                        AppColor.accentGreen,
                      );
                      Navigator.of(context).pop();
                    } else {
                      _showSnackBar(
                        'Failed to update power rate',
                        AppColor.accentRed,
                      );
                    }
                  } else {
                    _showSnackBar(
                      'Please enter a valid power rate',
                      AppColor.accentRed,
                    );
                  }
                },
                child: const Text('Update'),
              ),
            ],
          ),
    );
  }
}
