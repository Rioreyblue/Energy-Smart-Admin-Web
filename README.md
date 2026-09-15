```markdown
# EnergySmart Admin Dashboard

A web-based administration portal built with **Flutter Web** and **Firebase** for central management, user administration, and system-wide analytics of the EnergySmart IoT ecosystem.

---

## Capstone Project Overview

**Project Title:** EnergySmart Admin Portal: Centralized Management Dashboard for Smart Energy Systems

**Abstract / Description:**
This web application provides system administrators with real-time infrastructure oversight for the EnergySmart platform. Built exclusively for web targets using Flutter Web, it centralizes user lifecycle management, dynamic electricity rate configuration, and network-wide energy consumption analytics. The platform bridges Firebase services with responsive web data visualizations to streamline system governance across modern desktop and tablet web browsers.

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
| :--- | :--- |
| Flutter Web (3.x+) | Web application framework |
| Dart | Programming language |
| Web Browsers | Target platforms (Chrome, Firefox, Edge, Safari) |
| Firebase Auth / Firestore | User authentication and real-time database |
| FL Chart / Syncfusion | Advanced web data visualization |

---

## Prerequisites

| Tool | Version |
| :--- | :--- |
| Flutter SDK | 3.7.2+ |
| Dart SDK | Included with Flutter |
| Google Chrome | Latest |
| Firebase Console | Web app integration configured |

> ⚠️ **Web Configuration Note:**
> Ensure Flutter Web support is enabled on your machine before running:
> ```bash
> flutter config --enable-web
> ```
> Verify your setup by executing `flutter doctor`.

---

## Setup Instructions

### 1. Clone the repository

```bash
git clone [https://github.com/Rioreyblue/Energy-Smart-Admin.git](https://github.com/Rioreyblue/Energy-Smart-Admin.git)
cd Energy-Smart-Admin

```

### 2. Install dependencies

```bash
flutter pub get

```

### 3. Launch the web application

Run locally on Google Chrome:

```bash
flutter run -d chrome

```

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
