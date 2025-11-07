import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../constants/constant.dart';
import '../utils/responsive_layout.dart';

class SidebarMenu extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool isCollapsed;

  const SidebarMenu({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.isCollapsed = false,
  });

  @override
  State<SidebarMenu> createState() => _SidebarMenuState();
}

class _SidebarMenuState extends State<SidebarMenu> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width:
          widget.isCollapsed ? 80 : ResponsiveHelper.getSidebarWidth(context),
      height: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor.withAlpha(26),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildMenuItems()),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child:
          widget.isCollapsed
              ? const Icon(Iconsax.flash, size: 32, color: AppColor.accentGreen)
              : Row(
                children: [
                  const Icon(
                    Iconsax.flash,
                    size: 32,
                    color: AppColor.accentGreen,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EnergySmart',
                          style: ResponsiveText.title(context).copyWith(
                            color: AppColor.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Admin Panel',
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

  Widget _buildMenuItems() {
    final menuItems = [
      _MenuItem(icon: Iconsax.home, label: 'Dashboard', index: 0),
      _MenuItem(icon: Iconsax.profile_2user, label: 'Users', index: 1),
      _MenuItem(icon: Iconsax.chart_2, label: 'Analytics', index: 2),
      _MenuItem(icon: Iconsax.document_text, label: 'Invoice', index: 3),
      _MenuItem(icon: Iconsax.message, label: 'Chat Support', index: 4),
      _MenuItem(icon: Iconsax.setting_2, label: 'Settings', index: 5),
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: menuItems.length,
      itemBuilder: (context, index) {
        final item = menuItems[index];
        final isSelected = widget.selectedIndex == item.index;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: _MenuItemWidget(
            item: item,
            isSelected: isSelected,
            isCollapsed: widget.isCollapsed,
            onTap: () => widget.onItemSelected(item.index),
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child:
          widget.isCollapsed
              ? const Icon(Iconsax.logout, size: 24, color: AppColor.accentRed)
              : InkWell(
                onTap: () {
                  // Handle logout
                  _showLogoutDialog();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Iconsax.logout,
                        size: 20,
                        color: AppColor.accentRed,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Logout',
                        style: ResponsiveText.body(context).copyWith(
                          color: AppColor.accentRed,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
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
                onPressed: () {
                  Navigator.of(context).pop();
                  // Handle logout logic here
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
}

class _MenuItem {
  final IconData icon;
  final String label;
  final int index;

  _MenuItem({required this.icon, required this.label, required this.index});
}

class _MenuItemWidget extends StatelessWidget {
  final _MenuItem item;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;

  const _MenuItemWidget({
    required this.item,
    required this.isSelected,
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isCollapsed ? 8 : 12,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColor.accentGreen.withAlpha(26)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border:
              isSelected
                  ? Border.all(
                    color: AppColor.accentGreen.withAlpha(77),
                    width: 1,
                  )
                  : null,
        ),
        child:
            isCollapsed
                ? Icon(
                  item.icon,
                  size: 24,
                  color:
                      isSelected
                          ? AppColor.accentGreen
                          : AppColor.textSecondary,
                )
                : Row(
                  children: [
                    Icon(
                      item.icon,
                      size: 20,
                      color:
                          isSelected
                              ? AppColor.accentGreen
                              : AppColor.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.label,
                        style: ResponsiveText.body(context).copyWith(
                          color:
                              isSelected
                                  ? AppColor.accentGreen
                                  : AppColor.textPrimary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
