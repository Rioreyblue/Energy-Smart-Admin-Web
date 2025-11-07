import '../services/firebase_auth_service.dart';
import '../models/firebase_chat_models.dart';

/// Helper class for setting up admin users and troubleshooting
class AdminSetupHelper {
  static final FirebaseAuthService _authService = FirebaseAuthService();

  /// Quick setup for development - creates test admin accounts
  static Future<void> quickSetup() async {
    print('🚀 Starting Admin Quick Setup...');

    try {
      // Create Super Admin
      print('📝 Creating Super Admin...');
      final superAdmin = await _authService.createTestSuperAdmin(
        email: 'superadmin@energysmart.com',
        password: 'SuperAdmin123!',
      );

      if (superAdmin != null) {
        print('✅ Super Admin created: ${superAdmin.email}');
      }

      // Create Regular Admin
      print('📝 Creating Regular Admin...');
      final admin = await _authService.createTestAdmin(
        email: 'admin@energysmart.com',
        password: 'Admin123!',
      );

      if (admin != null) {
        print('✅ Regular Admin created: ${admin.email}');
      }

      print('🎉 Quick setup completed!');
      print('');
      print('📋 Login Credentials:');
      print('Super Admin: superadmin@energysmart.com / SuperAdmin123!');
      print('Regular Admin: admin@energysmart.com / Admin123!');
    } catch (e) {
      print('❌ Quick setup failed: $e');
    }
  }

  /// Fix missing user data for current user
  static Future<FirebaseUser?> fixCurrentUserData() async {
    try {
      print('🔧 Fixing current user data...');

      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        print('❌ No user currently signed in');
        return null;
      }

      // Ensure user data exists
      final userData = await _authService.ensureCurrentUserData();
      if (userData != null) {
        print('✅ User data fixed: ${userData.name} (${userData.email})');
        print('   Role: ${userData.role}');
        return userData;
      } else {
        print('❌ Failed to fix user data');
        return null;
      }
    } catch (e) {
      print('❌ Error fixing user data: $e');
      return null;
    }
  }

  /// Check current user status and data
  static Future<void> checkCurrentUser() async {
    try {
      print('🔍 Checking current user status...');

      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        print('❌ No user currently signed in');
        return;
      }

      print('📧 Firebase Auth User:');
      print('   UID: ${currentUser.uid}');
      print('   Email: ${currentUser.email}');
      print('   Display Name: ${currentUser.displayName}');
      print('   Email Verified: ${currentUser.emailVerified}');

      // Check Firestore data
      final userData = await _authService.getUserById(currentUser.uid);
      if (userData != null) {
        print('✅ Firestore User Data:');
        print('   Name: ${userData.name}');
        print('   Email: ${userData.email}');
        print('   Role: ${userData.role}');
        print('   Created: ${userData.createdAt}');
        print('   Last Seen: ${userData.lastSeen}');
        print('   Online: ${userData.isOnline}');
      } else {
        print('❌ No Firestore user data found');
        print('💡 Run fixCurrentUserData() to create missing data');
      }
    } catch (e) {
      print('❌ Error checking user: $e');
    }
  }

  /// Create a custom admin user
  static Future<FirebaseUser?> createCustomAdmin({
    required String email,
    required String password,
    required String name,
    bool isSuperAdmin = false,
  }) async {
    try {
      print('👤 Creating custom admin: $email');

      FirebaseUser? user;
      if (isSuperAdmin) {
        user = await _authService.createSuperAdmin(
          email: email,
          password: password,
          name: name,
        );
      } else {
        user = await _authService.createAdminUser(
          email: email,
          password: password,
          name: name,
        );
      }

      if (user != null) {
        print('✅ Admin created successfully');
        print('   Name: ${user.name}');
        print('   Email: ${user.email}');
        print('   Role: ${user.role}');
        return user;
      } else {
        print('❌ Failed to create admin');
        return null;
      }
    } catch (e) {
      print('❌ Error creating admin: $e');
      return null;
    }
  }

  /// List all admin users
  static Future<void> listAdminUsers() async {
    try {
      print('📋 Listing all admin users...');

      final adminUsers = await _authService.getAdminUsers();
      if (adminUsers.isEmpty) {
        print('❌ No admin users found');
        return;
      }

      print('✅ Found ${adminUsers.length} admin users:');
      for (int i = 0; i < adminUsers.length; i++) {
        final user = adminUsers[i];
        print('   ${i + 1}. ${user.name} (${user.email})');
        print('      Role: ${user.role}');
        print('      Created: ${user.createdAt}');
        print('      Last Seen: ${user.lastSeen}');
        print('');
      }
    } catch (e) {
      print('❌ Error listing admin users: $e');
    }
  }

  /// Troubleshoot common issues
  static Future<void> troubleshoot() async {
    print('🔧 Running Admin System Troubleshoot...');
    print('');

    // Check 1: Current user
    await checkCurrentUser();
    print('');

    // Check 2: Admin users
    await listAdminUsers();
    print('');

    // Check 3: Suggest fixes
    print('💡 Troubleshooting Tips:');
    print(
      '   1. If no user data found, run: AdminSetupHelper.fixCurrentUserData()',
    );
    print('   2. If no admin users exist, run: AdminSetupHelper.quickSetup()');
    print(
      '   3. If profile shows "user not found", ensure Firestore rules allow read/write',
    );
    print('   4. Check Firebase console for any authentication issues');
    print('   5. Verify internet connection and Firebase configuration');
  }

  /// Reset and recreate admin system
  static Future<void> resetAndSetup() async {
    print('🔄 Resetting and setting up admin system...');

    try {
      // Clear cache
      _authService.clearUserCache();
      print('✅ Cache cleared');

      // Fix current user if signed in
      await fixCurrentUserData();

      // Run quick setup
      await quickSetup();

      print('🎉 Reset and setup completed!');
    } catch (e) {
      print('❌ Reset failed: $e');
    }
  }
}
