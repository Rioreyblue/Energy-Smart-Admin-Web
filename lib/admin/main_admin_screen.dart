import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../constants/constant.dart';
import 'widgets/sidebar_menu.dart';
import 'widgets/top_navbar.dart';
import 'widgets/floating_chat_button.dart';
import 'screens/dashboard_screen.dart';
import 'screens/users_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/chat_support_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/responsive_layout.dart';

class MainAdminScreen extends StatefulWidget {
  const MainAdminScreen({super.key});

  @override
  State<MainAdminScreen> createState() => _MainAdminScreenState();
}

class _MainAdminScreenState extends State<MainAdminScreen> {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const UsersScreen(),
    const AnalyticsScreen(),
    const ReportsScreen(),
    const ChatSupportScreen(), // Use the refactored Firestore-backed chat
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.surface,
      body: ResponsiveLayout(
        mobile: _buildMobileLayout(),
        desktop: _buildDesktopLayout(),
      ),
      floatingActionButton:
          _selectedIndex !=
                  4 // Don't show FAB on chat screen
              ? ChatSupportFAB(
                onNavigateToChat: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
              )
              : null,
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        TopNavbar(
          adminName: 'Admin User',
          onMenuToggle: () {
            setState(() {
              _isSidebarCollapsed = !_isSidebarCollapsed;
            });
          },
          showMenuButton: true,
        ),
        Expanded(
          child: Row(
            children: [
              if (_isSidebarCollapsed)
                Container(
                  width: 80,
                  height: double.infinity,
                  color: Theme.of(context).colorScheme.surface,
                  child: SidebarMenu(
                    selectedIndex: _selectedIndex,
                    onItemSelected: _onItemSelected,
                    isCollapsed: true,
                  ),
                ),
              Expanded(child: _buildCurrentScreen()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        SidebarMenu(
          selectedIndex: _selectedIndex,
          onItemSelected: _onItemSelected,
          isCollapsed: _isSidebarCollapsed,
        ),
        Expanded(
          child: Column(
            children: [
              TopNavbar(
                adminName: 'Admin User',
                onMenuToggle: () {
                  setState(() {
                    _isSidebarCollapsed = !_isSidebarCollapsed;
                  });
                },
                showMenuButton: false,
              ),
              Expanded(child: _buildCurrentScreen()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentScreen() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(_selectedIndex),
        child: _screens[_selectedIndex],
      ),
    );
  }

  void _onItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Close sidebar on mobile after selection
    if (ResponsiveHelper.isMobile(context)) {
      setState(() {
        _isSidebarCollapsed = false;
      });
    }
  }
}

class AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;

  const AdminAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: AppColor.textPrimary,
      elevation: 0,
      leading:
          showBackButton
              ? IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Iconsax.arrow_left_2),
              )
              : null,
      title: Text(
        title,
        style: ResponsiveText.title(
          context,
        ).copyWith(fontWeight: FontWeight.bold, color: AppColor.textPrimary),
      ),
      actions: actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: Theme.of(context).dividerColor.withAlpha(26),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);
}
