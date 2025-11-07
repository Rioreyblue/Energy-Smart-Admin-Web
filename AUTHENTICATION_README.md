# EnergySmart Admin Authentication System

## 🔐 Overview

This document describes the complete authentication system implemented for the EnergySmart Admin Dashboard. The system provides secure admin access with role-based permissions and Firebase integration.

## 🏗️ Architecture

### Authentication Flow
```
User Access → AdminAuthWrapper → Firebase Auth Check → Admin Role Verification → Dashboard Access
```

### Key Components

1. **AdminAuthWrapper** - Main authentication controller
2. **AdminLoginScreen** - Login interface with validation
3. **AdminRegisterScreen** - Admin registration (super-admin only)
4. **AdminAuthService** - Firebase authentication service
5. **AdminUser Model** - User data structure with permissions

## 📁 File Structure

```
lib/admin/auth/
├── admin_auth_wrapper.dart      # Authentication flow controller
├── admin_login_screen.dart      # Login UI and logic
├── admin_register_screen.dart   # Registration UI (super-admin only)
└── admin_auth_service.dart      # Firebase authentication service

lib/admin/models/
├── admin_user_model.dart        # User data model with permissions
├── energy_usage_model.dart      # Energy usage data model
└── power_rate_model.dart        # Power rate configuration model

lib/admin/widgets/
└── custom_text_field.dart       # Reusable form components

lib/admin/utils/
└── validators.dart              # Input validation utilities
```

## 🔧 Setup Instructions

### 1. Firebase Configuration

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable Authentication with Email/Password
3. Set up Firestore Database
4. Update `lib/firebase_options.dart` with your project credentials:

```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'your-actual-api-key',
  appId: 'your-actual-app-id',
  messagingSenderId: 'your-actual-sender-id',
  projectId: 'your-actual-project-id',
  authDomain: 'your-actual-project-id.firebaseapp.com',
  storageBucket: 'your-actual-project-id.appspot.com',
  measurementId: 'your-actual-measurement-id',
);
```

### 2. Firestore Security Rules

Set up the following security rules in Firestore:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Admin collection - only authenticated admins can read/write
    match /admins/{adminId} {
      allow read, write: if request.auth != null && 
        request.auth.uid == adminId;
    }
    
    // Admin settings - only super admins can modify
    match /admin_settings/{document} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        exists(/databases/$(database)/documents/admins/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/admins/$(request.auth.uid)).data.role == 'super_admin';
    }
  }
}
```

### 3. Initial Super Admin Setup

To create the first super admin, you'll need to:

1. Register through the app interface (if you have super admin access)
2. Or manually add to Firestore:

```javascript
// In Firestore console, create document in /admins/{userId}
{
  "email": "admin@energysmart.com",
  "role": "super_admin",
  "created_at": 1640995200000, // timestamp
  "is_active": true,
  "permissions": {
    "view_dashboard": true,
    "manage_users": true,
    "manage_reports": true,
    "manage_settings": true,
    "manage_admins": true
  }
}
```

## 🚀 Features

### Authentication Features

- **Email/Password Login** - Secure admin authentication
- **Role-Based Access** - Admin and Super Admin roles
- **Permission System** - Granular permission control
- **Password Reset** - Email-based password recovery
- **Session Management** - Automatic session handling
- **Logout Functionality** - Secure sign-out with cleanup

### UI Features

- **Responsive Design** - Works on desktop, tablet, and mobile
- **Material 3 Design** - Modern, consistent UI
- **Form Validation** - Real-time input validation
- **Error Handling** - User-friendly error messages
- **Loading States** - Visual feedback during operations
- **Success Notifications** - Confirmation messages

### Security Features

- **Firebase Authentication** - Industry-standard security
- **Input Validation** - Client and server-side validation
- **Role Verification** - Server-side role checking
- **Permission Checks** - Feature-level access control
- **Secure Logout** - Complete session cleanup

## 📱 Usage

### Login Process

1. Navigate to the admin dashboard
2. Enter admin email and password
3. System validates credentials with Firebase
4. Checks admin role in Firestore
5. Redirects to dashboard on success

### Registration Process (Super Admin Only)

1. Super admin accesses registration screen
2. Fills out admin details and permissions
3. System creates Firebase user account
4. Creates admin document in Firestore
5. New admin can now login

### Permission System

The system supports the following permissions:

- `view_dashboard` - Access to main dashboard
- `manage_users` - User management features
- `manage_reports` - Report generation and management
- `manage_settings` - System configuration
- `manage_admins` - Admin account management

## 🔒 Security Considerations

### Best Practices Implemented

1. **Input Validation** - All inputs are validated client and server-side
2. **Role Verification** - Admin status is verified on every request
3. **Permission Checks** - Features are protected by permission checks
4. **Secure Storage** - Sensitive data is stored securely in Firestore
5. **Session Management** - Proper session handling and cleanup

### Security Rules

- Only authenticated users can access admin features
- Users can only modify their own admin profile
- Super admins have additional privileges
- All data access is logged and auditable

## 🐛 Troubleshooting

### Common Issues

1. **Firebase Not Initialized**
   - Ensure Firebase is properly configured
   - Check `firebase_options.dart` has correct credentials

2. **Authentication Fails**
   - Verify Firebase Auth is enabled
   - Check email/password are correct
   - Ensure user exists in Firestore admins collection

3. **Permission Denied**
   - Verify user has admin role in Firestore
   - Check Firestore security rules
   - Ensure user account is active

4. **UI Not Loading**
   - Check for console errors
   - Verify all dependencies are installed
   - Ensure proper import paths

### Debug Mode

Enable debug logging by adding this to your main.dart:

```dart
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kDebugMode) {
    // Enable debug logging
    FirebaseAuth.instance.setSettings(
      appVerificationDisabledForTesting: true,
    );
  }
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const EnergySmartAdminApp());
}
```

## 🔄 Future Enhancements

### Planned Features

1. **Two-Factor Authentication** - Additional security layer
2. **Audit Logging** - Track all admin actions
3. **Session Timeout** - Automatic logout after inactivity
4. **Bulk Admin Management** - CSV import/export
5. **Advanced Permissions** - More granular control
6. **SSO Integration** - Single sign-on support

### Integration Points

- **Firebase Functions** - Server-side validation
- **Cloud Storage** - File uploads and management
- **Push Notifications** - Security alerts
- **Analytics** - Usage tracking and monitoring

## 📞 Support

For technical support or questions about the authentication system:

1. Check this documentation first
2. Review Firebase console for errors
3. Check browser console for client-side issues
4. Contact the development team for advanced issues

## 📄 License

This authentication system is part of the EnergySmart Admin Dashboard and follows the same licensing terms as the main project.
