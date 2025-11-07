import 'package:flutter/material.dart';
import '../services/firebase_auth_service.dart';

/// Example showing how to set up the Super Admin functionality
class SuperAdminSetupExample extends StatefulWidget {
  const SuperAdminSetupExample({super.key});

  @override
  State<SuperAdminSetupExample> createState() => _SuperAdminSetupExampleState();
}

class _SuperAdminSetupExampleState extends State<SuperAdminSetupExample> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Super Admin Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create Super Admin Account',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _createSuperAdmin,
              child: const Text('Create Super Admin'),
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            const Text(
              'Quick Setup Examples',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _createTestSuperAdmin,
              child: const Text('Create Test Super Admin'),
            ),
            const SizedBox(height: 8),

            ElevatedButton(
              onPressed: _createTestAdmin,
              child: const Text('Create Test Regular Admin'),
            ),
            const SizedBox(height: 8),

            ElevatedButton(
              onPressed: _showCurrentUser,
              child: const Text('Show Current User Info'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createSuperAdmin() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _nameController.text.trim().isEmpty) {
      _showSnackBar('Please fill in all fields');
      return;
    }

    try {
      final superAdmin = await _authService.createSuperAdmin(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
      );

      if (superAdmin != null) {
        _showSnackBar('Super Admin created successfully: ${superAdmin.name}');
        _clearForm();
      }
    } catch (e) {
      _showSnackBar('Error creating Super Admin: $e');
    }
  }

  Future<void> _createTestSuperAdmin() async {
    try {
      final superAdmin = await _authService.createTestSuperAdmin(
        email: 'superadmin@energysmart.com',
        password: 'SuperAdmin123!',
      );

      if (superAdmin != null) {
        _showSnackBar('Test Super Admin created: ${superAdmin.email}');
      }
    } catch (e) {
      _showSnackBar('Error creating test Super Admin: $e');
    }
  }

  Future<void> _createTestAdmin() async {
    try {
      final admin = await _authService.createTestAdmin(
        email: 'admin@energysmart.com',
        password: 'Admin123!',
      );

      if (admin != null) {
        _showSnackBar('Test Admin created: ${admin.email}');
      }
    } catch (e) {
      _showSnackBar('Error creating test Admin: $e');
    }
  }

  Future<void> _showCurrentUser() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        final userData = await _authService.getUserById(currentUser.uid);
        if (userData != null) {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Current User Info'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Name: ${userData.name}'),
                      Text('Email: ${userData.email}'),
                      Text('Role: ${userData.role}'),
                      Text('Created: ${userData.createdAt}'),
                      Text('Last Seen: ${userData.lastSeen}'),
                      Text('Online: ${userData.isOnline}'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
          );
        } else {
          _showSnackBar('User data not found in Firestore');
        }
      } else {
        _showSnackBar('No user currently signed in');
      }
    } catch (e) {
      _showSnackBar('Error getting current user: $e');
    }
  }

  void _clearForm() {
    _emailController.clear();
    _passwordController.clear();
    _nameController.clear();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}

/// Instructions for setting up Super Admin functionality
class SuperAdminInstructions {
  static const String setupGuide = '''
# Super Admin Setup Guide

## 1. Initial Super Admin Creation

To create the first Super Admin account, you can use one of these methods:

### Method A: Using the Setup Example
1. Navigate to SuperAdminSetupExample screen
2. Fill in the Super Admin details
3. Click "Create Super Admin"

### Method B: Programmatically
```dart
final authService = FirebaseAuthService();
final superAdmin = await authService.createSuperAdmin(
  email: 'superadmin@yourdomain.com',
  password: 'SecurePassword123!',
  name: 'Super Administrator',
);
```

### Method C: Quick Test Setup
```dart
final authService = FirebaseAuthService();
final testSuperAdmin = await authService.createTestSuperAdmin(
  email: 'superadmin@energysmart.com',
  password: 'SuperAdmin123!',
);
```

## 2. Super Admin Capabilities

Super Admins have all regular admin capabilities plus:

- **Manage Admins**: Add, remove, and promote regular admins
- **Promote to Super Admin**: Elevate regular admins to super admin status
- **Full System Access**: Access to all administrative functions
- **Visual Distinction**: Red crown icon and "Super Administrator" title

## 3. Admin Management Workflow

1. **Super Admin logs in** → Gets red crown icon and special title
2. **Access Profile** → Click profile dropdown → "Manage Admins" option appears
3. **Add New Admin** → Fill form in "Manage Admins" tab
4. **Promote Admin** → Use context menu on admin list items
5. **Remove Admin** → Use context menu (requires backend implementation)

## 4. Security Considerations

- Super Admin accounts should be limited and carefully managed
- Use strong passwords and enable 2FA when available
- Regular audits of admin accounts
- Implement proper logging for admin actions

## 5. Firebase Security Rules

The Firestore rules automatically handle role-based access:
- Super admins can read/write all admin data
- Regular admins have limited access
- Users can only access their own data

## 6. UI/UX Features

- **Color Coding**: Super admins have red accents, regular admins have green
- **Icons**: Crown icon for super admins, profile icon for regular admins
- **Menu Options**: Super admins see additional "Manage Admins" option
- **Visual Hierarchy**: Clear distinction between admin levels

## 7. Development Testing

For development and testing, use the provided test methods:
- `createTestSuperAdmin()` - Creates superadmin@energysmart.com
- `createTestAdmin()` - Creates admin@energysmart.com
- Both use secure default passwords

Remember to change default credentials in production!
''';
}
