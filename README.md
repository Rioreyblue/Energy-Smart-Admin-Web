# EnergySmart Admin Dashboard – System Management Portal

A web-based administration and telemetry management portal built with **Flutter Web**, **Dart**, and **Firebase** for central management, user administration, and real-time energy analytics of the EnergySmart IoT ecosystem.

---

## Features

* 📊 System Analytics – Track total active users, connected hardware, aggregate load, and network metrics in real time
* 📈 Interactive Visualizations – Analyze consumption trends, peak hourly usage, and device load patterns using dynamic charts
* 👥 User Administration – Manage user accounts, role-based access control (Admin/Super Admin), and account statuses
* ⚙️ System Configuration – Dynamically update utility electricity rates, warning thresholds, and notification schedules
* 📱 Web-Responsive Layout – Optimized navigation breakpoints tailored for desktop, tablet, and web viewports

---

## Tech Stack

| Technology | Purpose |
| --- | --- |
| Flutter Web (3.x+) | Single-page web application framework |
| Dart | Programming language |
| Web Browsers | Target deployment platforms (Chrome, Firefox, Edge, Safari) |
| Firebase Auth / Firestore | User authentication and real-time database |
| FL Chart / Syncfusion | Advanced web data visualization |

---

## Prerequisites

| Tool | Version |
| --- | --- |
| Flutter SDK | 3.7.2+ |
| Dart | Included with Flutter |
| Google Chrome / Modern Browser | Latest |
| Firebase Console | Web app integration configured |

> ⚠️ **Important Environment Setup:**
> Before attempting to run this application, ensure that **Flutter Web** support is fully enabled in your local environment.
> Verify that all required dependencies and web toolchain components pass system checks by running:
> ```bash
> flutter config --enable-web
> flutter doctor
> 
> ```
> 
> 
> Fix any missing checks until all core items display a checkmark (`[✓]`).

---

## Setup Instructions

### 1. Clone the repository

```bash
git clone https://github.com/Rioreyblue/Energy-Smart-Admin.git

```

### 2. Install dependencies

Navigate to the project directory and fetch packages:

```bash
cd Energy-Smart-Admin
flutter pub get

```

### 3. Launch the application

Run locally on Google Chrome (or your default browser):

```bash
flutter run -d chrome

```

> 💡 Make sure your web browser is installed and configured before executing `flutter run -d chrome`.

---

## Project Structure

```text
lib/
├── admin/
│   ├── auth/              # Authentication system
│   │   ├── admin_auth_wrapper.dart
│   │   ├── admin_login_screen.dart
│   │   ├── admin_register_screen.dart
│   │   └── admin_auth_service.dart
│   ├── models/            # Data models
│   │   ├── admin_user_model.dart
│   │   ├── energy_usage_model.dart
│   │   └── power_rate_model.dart
│   ├── screens/           # Main admin screens
│   │   ├── dashboard_screen.dart
│   │   ├── users_screen.dart
│   │   ├── analytics_screen.dart
│   │   ├── reports_screen.dart
│   │   └── settings_screen.dart
│   ├── widgets/           # Reusable UI components
│   │   ├── sidebar_menu.dart
│   │   ├── top_navbar.dart
│   │   ├── summary_card.dart
│   │   ├── chart_overview.dart
│   │   ├── data_table_view.dart
│   │   └── custom_text_field.dart
│   ├── services/          # Business logic and data
│   │   ├── mock_data_service.dart
│   │   └── auth_service.dart
│   └── utils/             # Utility functions
│       └── responsive_layout.dart
├── constants/
│   └── constant.dart      # App constants and themes
├── main.dart              # App entry point
└── routes.dart            # Navigation routing

```

---

## Support & Inquiries

For questions, access requests, or administrative credentials:

* **Developer Email:** franciscorey8383@gmail.com
* **Issues:** Open an issue directly in the repository
