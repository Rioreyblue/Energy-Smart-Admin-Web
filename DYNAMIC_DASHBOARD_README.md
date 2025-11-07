# 🚀 Dynamic Firestore Dashboard - EnergySmart Admin

A comprehensive, real-time dashboard implementation for the EnergySmart Admin system that dynamically fetches and displays live data from Firestore Database.

## ✨ Features

### 🔄 Real-Time Data Integration
- **Live Data Streaming**: Uses Firestore `StreamBuilder` for real-time updates
- **Automatic Refresh**: Dashboard updates automatically when data changes
- **Pull-to-Refresh**: Manual refresh capability with visual feedback
- **Error Handling**: Graceful error handling with user-friendly messages
- **Offline Support**: Handles connection issues and displays appropriate states

### 📊 Professional Dashboard UI
- **Grid-Based Layout**: Responsive card layout for key metrics
- **Modern Design**: Consistent colors, typography, and gradients
- **Smooth Animations**: Professional animations using `flutter_animate`
- **Responsive Design**: Optimized for web, tablet, and mobile screens
- **Loading States**: Beautiful loading indicators and skeleton screens

### 📈 Dynamic Data Display
- **System Statistics**: Real-time power rates, user counts, device status
- **Energy Usage**: Live energy consumption tracking and trends
- **Device Monitoring**: Active device status and usage patterns
- **Alert System**: Dynamic alerts with severity levels and notifications
- **Interactive Charts**: Real-time charts and graphs with live data

## 🏗️ Architecture

### Core Components

```
lib/admin/
├── models/
│   └── dashboard_data_model.dart          # Data models for Firestore
├── services/
│   └── firestore_dashboard_service.dart   # Firestore integration service
├── dashboard/
│   └── dashboard_controller.dart          # State management controller
├── screens/
│   └── dynamic_dashboard_screen.dart      # Main dashboard UI
├── utils/
│   └── dashboard_setup_helper.dart        # Setup and initialization
└── examples/
    └── dynamic_dashboard_example.dart     # Usage examples
```

### Data Models

#### `DashboardStats`
```dart
class DashboardStats {
  final double currentRate;        // Current power rate (₱/kWh)
  final int totalUsers;           // Total registered users
  final int activeDevices;        // Currently active devices
  final double totalEnergyToday;  // Today's energy usage
  final double totalEnergyWeek;   // Weekly energy usage
  final double totalEnergyMonth;  // Monthly energy usage
  final int totalAlerts;          // Total system alerts
  final DateTime lastUpdated;     // Last update timestamp
  final String updatedBy;         // Updated by user/system
}
```

#### `EnergyUsageData`
```dart
class EnergyUsageData {
  final DateTime date;            // Usage date
  final double usage;             // Energy usage (kWh)
  final double cost;              // Cost in Philippine Peso
  final String period;            // Period type (daily/weekly/monthly)
}
```

#### `DeviceUsageData`
```dart
class DeviceUsageData {
  final String deviceName;        // Device name
  final String deviceType;        // Device category
  final double usage;             // Device energy usage
  final double cost;              // Device energy cost
  final bool isActive;            // Device status
  final DateTime lastSeen;        // Last activity timestamp
}
```

#### `AlertData`
```dart
class AlertData {
  final String id;                // Alert ID
  final String title;             // Alert title
  final String message;           // Alert message
  final String type;              // Alert type (warning/error/info)
  final String severity;          // Severity (low/medium/high/critical)
  final bool isRead;              // Read status
  final DateTime createdAt;       // Creation timestamp
  final Map<String, dynamic>? metadata; // Additional data
}
```

## 🔧 Firestore Database Structure

```
Firestore Collections:
├── admin_dashboard/
│   └── system_stats (document)
│       ├── current_rate: 6.50
│       ├── total_users: 1247
│       ├── active_devices: 3421
│       ├── total_energy_today: 12543.7
│       ├── total_energy_week: 87805.2
│       ├── total_energy_month: 345678.9
│       ├── total_alerts: 23
│       ├── last_updated: timestamp
│       └── updated_by: "admin@energysmart.com"
│
├── energy_usage/ (collection)
│   └── [auto-generated-id] (documents)
│       ├── date: timestamp
│       ├── usage: 1200.5
│       ├── cost: 7802.5
│       └── period: "daily"
│
├── device_usage/ (collection)
│   └── [auto-generated-id] (documents)
│       ├── device_name: "Air Conditioner Unit 1"
│       ├── device_type: "HVAC"
│       ├── usage: 150.2
│       ├── cost: 976.3
│       ├── is_active: true
│       └── last_seen: timestamp
│
└── alerts/ (collection)
    └── [auto-generated-id] (documents)
        ├── title: "High Energy Usage Alert"
        ├── message: "Energy consumption exceeded threshold"
        ├── type: "warning"
        ├── severity: "high"
        ├── is_read: false
        ├── created_at: timestamp
        └── metadata: {...}
```

## 🚀 Quick Start

### 1. Initialize the Dashboard

```dart
import 'package:your_app/admin/utils/dashboard_setup_helper.dart';

// Initialize dashboard with sample data
await DashboardSetupHelper.completeSetup();
```

### 2. Use in Your App

```dart
import 'package:your_app/admin/screens/dynamic_dashboard_screen.dart';

class MainAdminScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DynamicDashboardScreen(), // Real-time dashboard
    );
  }
}
```

### 3. Manual Data Operations

```dart
import 'package:your_app/admin/services/firestore_dashboard_service.dart';

final service = FirestoreDashboardService();

// Add custom alert
await service.addAlert(AlertData(
  id: '',
  title: 'Custom Alert',
  message: 'This is a custom alert',
  type: 'info',
  severity: 'medium',
  isRead: false,
  createdAt: DateTime.now(),
));

// Update dashboard stats
final stats = await service.getDashboardStats();
final updatedStats = stats.copyWith(
  totalUsers: stats.totalUsers + 10,
  totalEnergyToday: stats.totalEnergyToday + 100.0,
);
await service.updateDashboardStats(updatedStats);
```

## 📱 Dashboard Features

### Real-Time Summary Cards
- **Total Users**: Live count of registered users with growth trend
- **Active Devices**: Currently online devices with status indicators
- **Energy Usage**: Real-time energy consumption with cost calculations
- **Power Rate**: Current electricity rate in Philippine Peso (₱/kWh)

### Dynamic Alerts Section
- **Real-Time Alerts**: Live alert notifications with severity indicators
- **Alert Categories**: Critical, High, Medium, Low priority levels
- **Interactive Actions**: Mark as read, dismiss, view details
- **Visual Indicators**: Color-coded alerts with appropriate icons

### Interactive Charts
- **Energy Usage Trend**: Line chart showing daily/weekly/monthly usage
- **Device Usage**: Bar chart displaying device-wise consumption
- **Cost Analysis**: Real-time cost calculations and projections
- **Responsive Charts**: Adapts to different screen sizes

### Recent Activity Feed
- **Device Status**: Live device online/offline status updates
- **Usage Patterns**: Real-time device usage monitoring
- **System Events**: Live system activity and changes
- **Timestamp Tracking**: Accurate time tracking for all activities

## 🎨 UI/UX Features

### Professional Design
- **Consistent Branding**: Uses `constants.dart` color scheme
- **Modern Typography**: Google Fonts integration
- **Smooth Animations**: Professional fade-in and slide animations
- **Loading States**: Beautiful loading indicators and skeleton screens

### Responsive Layout
- **Mobile Optimized**: Perfect layout for mobile devices
- **Tablet Support**: Optimized grid layout for tablets
- **Web Ready**: Full desktop web support with responsive design
- **Cross-Platform**: Works seamlessly across all Flutter platforms

### Interactive Elements
- **Pull-to-Refresh**: Intuitive refresh gesture
- **Touch Feedback**: Haptic feedback and visual responses
- **Error Handling**: User-friendly error messages and recovery options
- **Accessibility**: Screen reader support and accessibility features

## 🔐 Security & Performance

### Firebase Security
- **Authentication Required**: Only authenticated admins can access
- **Role-Based Access**: Different access levels for admin roles
- **Secure Rules**: Firestore security rules for data protection
- **Real-Time Validation**: Server-side data validation

### Performance Optimization
- **Stream Management**: Efficient stream subscription handling
- **Memory Management**: Proper disposal of resources
- **Caching Strategy**: Smart caching for frequently accessed data
- **Batch Operations**: Efficient batch writes for bulk operations

## 🧪 Testing & Development

### Setup Helper
```dart
// Complete setup with testing
await DashboardSetupHelper.completeSetup();

// Individual operations
await DashboardSetupHelper.initializeDashboard();
await DashboardSetupHelper.testDashboard();
await DashboardSetupHelper.startSimulation();
```

### Real-Time Simulation
The dashboard includes a simulation mode for development and testing:
- **Automatic Updates**: Simulates real device data changes
- **Random Data**: Generates realistic energy usage patterns
- **Alert Simulation**: Creates sample alerts for testing
- **Performance Testing**: Stress tests with high-frequency updates

## 📊 Data Flow

```
User Action → Dashboard Controller → Firestore Service → Firestore DB
     ↑                                                        ↓
UI Updates ← Stream Listener ← Real-time Stream ← Data Changes
```

### Stream Management
1. **Dashboard Controller** manages all data streams
2. **Firestore Service** provides stream interfaces
3. **UI Components** listen to controller changes
4. **Automatic Updates** trigger UI refreshes

## 🔧 Configuration

### Dependencies Required
```yaml
dependencies:
  cloud_firestore: ^6.0.3
  firebase_auth: ^6.1.1
  firebase_core: ^4.2.0
  flutter_animate: ^4.5.0
  intl: ^0.19.0
  iconsax: ^0.0.8
```

### Firebase Setup
1. **Enable Firestore**: Enable Firestore Database in Firebase Console
2. **Security Rules**: Configure appropriate security rules
3. **Indexes**: Create composite indexes for complex queries
4. **Authentication**: Set up Firebase Authentication

## 🚀 Deployment

### Production Checklist
- [ ] Configure Firestore security rules
- [ ] Set up proper authentication
- [ ] Enable Firestore indexes
- [ ] Configure environment variables
- [ ] Test real-time functionality
- [ ] Verify responsive design
- [ ] Test error handling
- [ ] Performance optimization

## 📈 Future Enhancements

### Planned Features
- **Advanced Analytics**: More detailed energy analytics
- **Export Functionality**: PDF/Excel export capabilities
- **Custom Dashboards**: User-customizable dashboard layouts
- **Push Notifications**: Real-time push notifications for alerts
- **Advanced Filtering**: Complex data filtering and search
- **Data Visualization**: More chart types and visualizations

### Scalability
- **Horizontal Scaling**: Support for multiple admin instances
- **Data Partitioning**: Efficient data partitioning strategies
- **Caching Layer**: Redis/Memcached integration
- **CDN Integration**: Static asset optimization
- **Performance Monitoring**: Real-time performance tracking

## 🤝 Contributing

### Development Setup
1. Clone the repository
2. Install dependencies: `flutter pub get`
3. Configure Firebase project
4. Run initialization: `DashboardSetupHelper.completeSetup()`
5. Start development server: `flutter run`

### Code Style
- Follow Dart/Flutter style guidelines
- Use meaningful variable names
- Add comprehensive documentation
- Write unit tests for new features
- Ensure responsive design compatibility

---

## 📞 Support

For technical support or questions about the Dynamic Firestore Dashboard:

- **Documentation**: Refer to inline code documentation
- **Examples**: Check `dynamic_dashboard_example.dart`
- **Testing**: Use `DashboardSetupHelper` for testing
- **Issues**: Report bugs through proper channels

---

**Built with ❤️ for EnergySmart Admin System**

*Real-time dashboard powered by Firebase Firestore and Flutter*



