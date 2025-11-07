import 'package:flutter/material.dart';

/// EnergySmart App Constants
/// Consistent with admin system design and functionality
class AppConstants {
  // App Information
  static const String appName = 'EnergySmart';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Smart Energy Monitoring & Management';

  // API & Database
  static const String firestoreUsersCollection = 'users';
  static const String firestoreDevicesCollection = 'devices';
  static const String firestoreEnergyCollection = 'energy_usage';
  static const String firestoreNotificationsCollection = 'notifications';
  static const String firestoreChatCollection = 'chats';
  static const String firestoreAdminCollection = 'admin';

  // Realtime Database Paths
  static const String realtimeDevicesPath = 'devices';
  static const String realtimeSensorsPath = 'sensors';
  static const String realtimeEnergyPath = 'energy_trends';
  static const String realtimeAlertsPath = 'alerts';

  // Shared Preferences Keys
  static const String keyUserId = 'user_id';
  static const String keyUserEmail = 'user_email';
  static const String keyUserName = 'user_name';
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyThemeMode = 'theme_mode';
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keyEnergyThreshold = 'energy_threshold';

  // Default Values
  static const double defaultEnergyThreshold = 500.0; // ₱500 per month
  static const double defaultPowerRate = 6.50; // ₱6.50 per kWh
  static const int defaultNotificationHour = 20; // 8 PM
  static const int maxRecentActivities = 10;
  static const int maxChatMessages = 100;

  // UI Constants
  static const double borderRadius = 12.0;
  static const double cardElevation = 2.0;
  static const double buttonHeight = 48.0;
  static const double inputFieldHeight = 56.0;

  // Padding & Margins
  static const EdgeInsets screenPadding = EdgeInsets.all(16.0);
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: 24.0,
    vertical: 12.0,
  );

  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;

  // Animation Durations
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  // Energy Consumption Thresholds
  static const double lowConsumptionThreshold = 100.0; // ₱100
  static const double mediumConsumptionThreshold = 300.0; // ₱300
  static const double highConsumptionThreshold = 500.0; // ₱500

  // Device Types
  static const List<String> deviceTypes = [
    'Light',
    'Fan',
    'Outlet',
    'Air Conditioner',
    'Water Heater',
    'Refrigerator',
    'Television',
    'Computer',
  ];

  // Device Status
  static const String deviceStatusOnline = 'online';
  static const String deviceStatusOffline = 'offline';
  static const String deviceStatusError = 'error';

  // Notification Types
  static const String notificationTypeEnergyThreshold = 'energy_threshold';
  static const String notificationTypeDeviceStatus = 'device_status';
  static const String notificationTypeSystemUpdate = 'system_update';
  static const String notificationTypeBillReminder = 'bill_reminder';
  static const String notificationTypeChat = 'chat_message';

  // Chart Periods
  static const String chartPeriodDaily = 'daily';
  static const String chartPeriodWeekly = 'weekly';
  static const String chartPeriodMonthly = 'monthly';

  // Energy Tips Categories
  static const List<String> tipCategories = [
    'Usage Optimization',
    'Energy Saving',
    'Safety Tips',
    'Cost Reduction',
    'Device Maintenance',
  ];

  // Validation Rules
  static const int minPasswordLength = 6;
  static const int maxNameLength = 50;
  static const int maxMessageLength = 500;

  // Regular Expressions
  static const String emailRegex = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
  static const String phoneRegex = r'^(\+63|0)[0-9]{10}$';

  // Error Messages
  static const String errorInvalidEmail = 'Please enter a valid email address';
  static const String errorPasswordTooShort =
      'Password must be at least 6 characters';
  static const String errorPasswordMismatch = 'Passwords do not match';
  static const String errorRequiredField = 'This field is required';
  static const String errorNetworkConnection =
      'Please check your internet connection';
  static const String errorServerError = 'Server error. Please try again later';
  static const String errorUnknown = 'An unexpected error occurred';

  // Success Messages
  static const String successLogin = 'Login successful';
  static const String successRegister = 'Registration successful';
  static const String successProfileUpdate = 'Profile updated successfully';
  static const String successPasswordReset = 'Password reset email sent';
  static const String successDeviceControl = 'Device updated successfully';
  static const String successGoalSet = 'Energy goal set successfully';

  // Loading Messages
  static const String loadingLogin = 'Signing in...';
  static const String loadingRegister = 'Creating account...';
  static const String loadingData = 'Loading data...';
  static const String loadingDevices = 'Loading devices...';
  static const String loadingChart = 'Loading chart data...';

  // Empty State Messages
  static const String emptyDevices = 'No devices found';
  static const String emptyNotifications = 'No notifications';
  static const String emptyActivity = 'No recent activity';
  static const String emptyChat = 'No messages yet';
  static const String emptyTips = 'No tips available';

  // Currency & Formatting
  static const String currency = '₱';
  static const String energyUnit = 'kWh';
  static const String powerUnit = 'W';
  static const String voltageUnit = 'V';
  static const String currentUnit = 'A';

  // Date Formats
  static const String dateFormatFull = 'MMMM dd, yyyy';
  static const String dateFormatShort = 'MMM dd';
  static const String timeFormat12 = 'h:mm a';
  static const String timeFormat24 = 'HH:mm';
  static const String dateTimeFormat = 'MMM dd, yyyy h:mm a';

  // Navigation Routes
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeHome = '/home';
  static const String routeMonitoring = '/monitoring';
  static const String routeGoals = '/goals';
  static const String routeTips = '/tips';
  static const String routeSettings = '/settings';
  static const String routeChat = '/chat';
  static const String routeProfile = '/profile';
  static const String routeOnboarding = '/onboarding';

  // Bottom Navigation Items
  static const List<Map<String, dynamic>> bottomNavItems = [
    {'label': 'Home', 'icon': 'home', 'route': routeHome},
    {'label': 'Monitor', 'icon': 'chart', 'route': routeMonitoring},
    {'label': 'Goals', 'icon': 'target', 'route': routeGoals},
    {'label': 'Tips', 'icon': 'bulb', 'route': routeTips},
    {'label': 'Settings', 'icon': 'settings', 'route': routeSettings},
  ];

  // Quick Control Devices
  static const List<Map<String, dynamic>> quickControlDevices = [
    {
      'id': 'light_1',
      'name': 'Living Room Light',
      'icon': 'bulb',
      'type': 'Light',
    },
    {'id': 'light_2', 'name': 'Bedroom Light', 'icon': 'bulb', 'type': 'Light'},
    {'id': 'fan_1', 'name': 'Ceiling Fan', 'icon': 'fan', 'type': 'Fan'},
    {
      'id': 'outlet_1',
      'name': 'Power Outlet',
      'icon': 'outlet',
      'type': 'Outlet',
    },
  ];

  // Lottie Animation Assets
  static const String lottieLoading = 'assets/animations/loading.json';
  static const String lottieSuccess = 'assets/animations/success.json';
  static const String lottieError = 'assets/animations/error.json';
  static const String lottieEmpty = 'assets/animations/empty.json';
  static const String lottieEnergy = 'assets/animations/energy.json';
  static const String lottieOnboarding1 = 'assets/animations/onboarding_1.json';
  static const String lottieOnboarding2 = 'assets/animations/onboarding_2.json';
  static const String lottieOnboarding3 = 'assets/animations/onboarding_3.json';

  // Image Assets
  static const String imageLogo = 'assets/images/logo.png';
  static const String imageLogoWhite = 'assets/images/logo_white.png';
  static const String imageBackground = 'assets/images/background.png';
  static const String imageAvatar = 'assets/images/default_avatar.png';

  // Icon Assets
  static const String iconApp = 'assets/icons/app_icon.png';
  static const String iconNotification = 'assets/icons/notification.png';

  // Feature Flags
  static const bool enableBiometricAuth = true;
  static const bool enablePushNotifications = true;
  static const bool enableRealTimeSync = true;
  static const bool enableOfflineMode = false;
  static const bool enableAnalytics = true;
  static const bool enableCrashReporting = true;

  // Development Settings
  static const bool isDebugMode = true;
  static const bool enableLogging = true;
  static const bool showPerformanceOverlay = false;
}

/// Responsive Breakpoints
class Breakpoints {
  static const double mobile = 480;
  static const double tablet = 768;
  static const double desktop = 1024;
  static const double largeDesktop = 1440;
}

/// App Dimensions
class AppDimensions {
  // Icon Sizes
  static const double iconXS = 16.0;
  static const double iconS = 20.0;
  static const double iconM = 24.0;
  static const double iconL = 32.0;
  static const double iconXL = 48.0;

  // Avatar Sizes
  static const double avatarS = 32.0;
  static const double avatarM = 48.0;
  static const double avatarL = 64.0;
  static const double avatarXL = 96.0;

  // Card Sizes
  static const double cardMinHeight = 120.0;
  static const double cardMaxHeight = 300.0;
  static const double cardMaxWidth = 400.0;

  // Chart Sizes
  static const double chartHeight = 250.0;
  static const double chartMinHeight = 200.0;
  static const double chartMaxHeight = 400.0;
}

