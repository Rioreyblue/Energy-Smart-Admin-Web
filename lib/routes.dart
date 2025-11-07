import 'package:flutter/material.dart';
import 'admin/screens/dashboard_screen.dart';
import 'admin/screens/users_screen.dart';
import 'admin/screens/analytics_screen.dart';
import 'admin/screens/reports_screen.dart';
import 'admin/screens/settings_screen.dart';

class AppRoutes {
  static const String dashboard = '/dashboard';
  static const String users = '/users';
  static const String analytics = '/analytics';
  static const String reports = '/reports';
  static const String settings = '/settings';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case dashboard:
        return MaterialPageRoute(
          builder: (_) => const DashboardScreen(),
          settings: settings,
        );
      case users:
        return MaterialPageRoute(
          builder: (_) => const UsersScreen(),
          settings: settings,
        );
      case analytics:
        return MaterialPageRoute(
          builder: (_) => const AnalyticsScreen(),
          settings: settings,
        );
      case reports:
        return MaterialPageRoute(
          builder: (_) => const ReportsScreen(),
          settings: settings,
        );
      case '/settings':
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(builder: (_) => const DashboardScreen());
    }
  }
}
