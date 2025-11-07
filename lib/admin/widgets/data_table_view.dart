import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../constants/constant.dart';

class DataTableView extends StatelessWidget {
  final String title;
  final List<String> columns;
  final List<Map<String, dynamic>> data;
  final List<DataTableAction>? actions;
  final bool isLoading;
  final String? searchHint;
  final Function(String)? onSearch;
  final VoidCallback? onRefresh;
  final Widget? emptyWidget;

  const DataTableView({
    super.key,
    required this.title,
    required this.columns,
    required this.data,
    this.actions,
    this.isLoading = false,
    this.searchHint,
    this.onSearch,
    this.onRefresh,
    this.emptyWidget,
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
            if (searchHint != null) ...[
              const SizedBox(height: 16),
              _buildSearchBar(context),
            ],
            const SizedBox(height: 20),
            Expanded(
              child:
                  isLoading ? _buildLoadingState() : _buildDataTable(context),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: ResponsiveText.title(
            context,
          ).copyWith(fontWeight: FontWeight.bold, color: AppColor.textPrimary),
        ),
        Row(
          children: [
            if (onRefresh != null)
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Iconsax.refresh),
                style: IconButton.styleFrom(
                  backgroundColor: AppColor.surface,
                  foregroundColor: AppColor.textPrimary,
                ),
              ),
            if (actions != null && actions!.isNotEmpty)
              PopupMenuButton<DataTableAction>(
                onSelected: (action) => action.onTap(),
                itemBuilder:
                    (context) =>
                        actions!.map((action) {
                          return PopupMenuItem(
                            value: action,
                            child: Row(
                              children: [
                                Icon(
                                  action.icon,
                                  size: 20,
                                  color: action.color,
                                ),
                                const SizedBox(width: 8),
                                Text(action.label),
                              ],
                            ),
                          );
                        }).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColor.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withAlpha(51),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Actions',
                        style: ResponsiveText.body(
                          context,
                        ).copyWith(color: AppColor.textPrimary),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Iconsax.arrow_down_2,
                        size: 16,
                        color: AppColor.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColor.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withAlpha(51)),
      ),
      child: TextField(
        onChanged: onSearch,
        decoration: InputDecoration(
          hintText: searchHint,
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
            'Loading data...',
            style: TextStyle(color: AppColor.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(BuildContext context) {
    if (data.isEmpty) {
      return _buildEmptyState(context);
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
        columns:
            columns.map((column) => DataColumn(label: Text(column))).toList(),
        rows:
            data
                .map(
                  (row) => DataRow(
                    cells:
                        columns
                            .map(
                              (column) => DataCell(
                                _buildCellContent(context, row, column),
                              ),
                            )
                            .toList(),
                  ),
                )
                .toList(),
      ),
    );
  }

  Widget _buildCellContent(
    BuildContext context,
    Map<String, dynamic> row,
    String column,
  ) {
    final value = row[column.toLowerCase().replaceAll(' ', '')];

    if (value == null) {
      return const Text('-');
    }

    // Handle different data types
    if (value is bool) {
      return _buildStatusChip(context, value ? 'Active' : 'Inactive', value);
    } else if (value is DateTime) {
      return Text(_formatDateTime(value));
    } else if (value is double) {
      return Text(value.toStringAsFixed(2));
    } else if (value is String && value.toLowerCase().contains('status')) {
      final status = row['status'] as String? ?? 'Unknown';
      return _buildStatusChip(
        context,
        status,
        status.toLowerCase() == 'active',
      );
    } else {
      return Text(value.toString());
    }
  }

  Widget _buildStatusChip(BuildContext context, String status, bool isActive) {
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

  Widget _buildEmptyState(BuildContext context) {
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
            'No data available',
            style: ResponsiveText.title(
              context,
            ).copyWith(color: AppColor.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'There are no records to display at the moment.',
            style: ResponsiveText.body(
              context,
            ).copyWith(color: AppColor.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (emptyWidget != null) ...[
            const SizedBox(height: 16),
            emptyWidget!,
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

class DataTableAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  DataTableAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = AppColor.textPrimary,
  });
}

class UserDataTable extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final bool isLoading;
  final Function(String)? onSearch;
  final VoidCallback? onRefresh;
  final Function(String)? onToggleStatus;
  final Function(String)? onViewProfile;

  const UserDataTable({
    super.key,
    required this.users,
    this.isLoading = false,
    this.onSearch,
    this.onRefresh,
    this.onToggleStatus,
    this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      DataTableAction(
        label: 'Export CSV',
        icon: Iconsax.document_download,
        onTap: () {
          // Handle export
        },
      ),
      DataTableAction(
        label: 'Bulk Actions',
        icon: Iconsax.more,
        onTap: () {
          // Handle bulk actions
        },
      ),
    ];

    return DataTableView(
      title: 'Users Management',
      columns: const [
        'Name',
        'Email',
        'Role',
        'Status',
        'Last Active',
        'Actions',
      ],
      data:
          users
              .map(
                (user) => {
                  'name': user['name'],
                  'email': user['email'],
                  'role': user['role'],
                  'status': user['status'],
                  'lastactive': user['lastActive'],
                  'actions': user['id'],
                },
              )
              .toList(),
      actions: actions,
      isLoading: isLoading,
      searchHint: 'Search users by name or email...',
      onSearch: onSearch,
      onRefresh: onRefresh,
      emptyWidget: ElevatedButton.icon(
        onPressed: () {
          // Handle add user
        },
        icon: const Icon(Iconsax.user_add),
        label: const Text('Add User'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColor.accentGreen,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}

class ReportsDataTable extends StatelessWidget {
  final List<Map<String, dynamic>> reports;
  final bool isLoading;
  final Function(String)? onSearch;
  final VoidCallback? onRefresh;
  final Function(String)? onDownload;
  final Function(String)? onDelete;

  const ReportsDataTable({
    super.key,
    required this.reports,
    this.isLoading = false,
    this.onSearch,
    this.onRefresh,
    this.onDownload,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      DataTableAction(
        label: 'Generate Report',
        icon: Iconsax.document_text,
        onTap: () {
          // Handle generate report
        },
      ),
      DataTableAction(
        label: 'Export All',
        icon: Iconsax.document_download,
        onTap: () {
          // Handle export all
        },
      ),
    ];

    return DataTableView(
      title: 'Reports & Logs',
      columns: const [
        'Type',
        'Period',
        'Generated At',
        'Status',
        'File Size',
        'Actions',
      ],
      data:
          reports
              .map(
                (report) => {
                  'type': report['type'],
                  'period': report['period'],
                  'generatedat': report['generatedAt'],
                  'status': report['status'],
                  'filesize': report['fileSize'],
                  'actions': report['id'],
                },
              )
              .toList(),
      actions: actions,
      isLoading: isLoading,
      searchHint: 'Search reports by type or period...',
      onSearch: onSearch,
      onRefresh: onRefresh,
      emptyWidget: ElevatedButton.icon(
        onPressed: () {
          // Handle generate new report
        },
        icon: const Icon(Iconsax.document_text),
        label: const Text('Generate New Report'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColor.accentGreen,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
