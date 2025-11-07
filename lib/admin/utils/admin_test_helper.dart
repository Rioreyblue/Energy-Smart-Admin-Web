import '../services/firebase_auth_service.dart';
import '../models/firebase_chat_models.dart';

/// Helper class for testing admin functionality
class AdminTestHelper {
  static final FirebaseAuthService _authService = FirebaseAuthService();

  /// Create a test super admin for development
  static Future<FirebaseUser?> createTestSuperAdmin() async {
    try {
      return await _authService.createTestSuperAdmin(
        email: 'superadmin@energysmart.com',
        password: 'SuperAdmin123!',
      );
    } catch (e) {
      print('Error creating test super admin: $e');
      return null;
    }
  }

  /// Create a test regular admin for development
  static Future<FirebaseUser?> createTestAdmin() async {
    try {
      return await _authService.createTestAdmin(
        email: 'admin@energysmart.com',
        password: 'Admin123!',
      );
    } catch (e) {
      print('Error creating test admin: $e');
      return null;
    }
  }

  /// Test admin functionality
  static Future<void> testAdminFunctionality() async {
    print('🧪 Testing Admin Functionality...');

    try {
      // Test 1: Create Super Admin
      print('📝 Test 1: Creating Super Admin...');
      final superAdmin = await createTestSuperAdmin();
      if (superAdmin != null) {
        print('✅ Super Admin created: ${superAdmin.email}');
      } else {
        print('❌ Failed to create Super Admin');
      }

      // Test 2: Create Regular Admin
      print('📝 Test 2: Creating Regular Admin...');
      final admin = await createTestAdmin();
      if (admin != null) {
        print('✅ Regular Admin created: ${admin.email}');
      } else {
        print('❌ Failed to create Regular Admin');
      }

      // Test 3: Get Admin Users
      print('📝 Test 3: Fetching Admin Users...');
      final adminUsers = await _authService.getAdminUsers();
      print('✅ Found ${adminUsers.length} admin users');
      for (final user in adminUsers) {
        print('   - ${user.name} (${user.email}) - ${user.role}');
      }

      print('🎉 Admin functionality tests completed!');
    } catch (e) {
      print('❌ Test failed: $e');
    }
  }

  /// Validate admin profile functionality
  static Future<bool> validateProfileFunctionality() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        print('❌ No user signed in');
        return false;
      }

      // Test user data retrieval
      final userData = await _authService.getUserById(currentUser.uid);
      if (userData == null) {
        print('❌ Failed to retrieve user data');
        return false;
      }

      print('✅ Profile functionality validated');
      print('   - User: ${userData.name}');
      print('   - Email: ${userData.email}');
      print('   - Role: ${userData.role}');

      return true;
    } catch (e) {
      print('❌ Profile validation failed: $e');
      return false;
    }
  }

  /// Test password change functionality (requires current user)
  static Future<bool> testPasswordChange({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      print('✅ Password change test successful');
      return true;
    } catch (e) {
      print('❌ Password change test failed: $e');
      return false;
    }
  }

  /// Test admin management functionality
  static Future<bool> testAdminManagement() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        print('❌ No user signed in');
        return false;
      }

      final userData = await _authService.getUserById(currentUser.uid);
      if (userData?.role != 'super_admin') {
        print('❌ Current user is not a super admin');
        return false;
      }

      // Test admin user creation
      final testAdmin = await _authService.createAdminUser(
        email:
            'test.admin.${DateTime.now().millisecondsSinceEpoch}@energysmart.com',
        password: 'TestAdmin123!',
        name: 'Test Admin User',
      );

      if (testAdmin != null) {
        print('✅ Admin creation test successful');

        // Test admin promotion
        await _authService.updateUserProfile(
          userId: testAdmin.id,
          additionalData: {'role': 'super_admin'},
        );
        print('✅ Admin promotion test successful');

        // Test admin removal (convert back to user)
        await _authService.removeAdminUser(testAdmin.id);
        print('✅ Admin removal test successful');

        return true;
      } else {
        print('❌ Failed to create test admin');
        return false;
      }
    } catch (e) {
      print('❌ Admin management test failed: $e');
      return false;
    }
  }

  /// Run all tests
  static Future<void> runAllTests() async {
    print('🚀 Starting Admin System Tests...\n');

    await testAdminFunctionality();
    print('');

    final profileValid = await validateProfileFunctionality();
    print('');

    if (profileValid) {
      final adminManagementValid = await testAdminManagement();
      print('');

      if (adminManagementValid) {
        print('🎉 All tests passed! Admin system is fully functional.');
      } else {
        print('⚠️  Some admin management tests failed.');
      }
    } else {
      print('⚠️  Profile functionality tests failed.');
    }
  }
}
