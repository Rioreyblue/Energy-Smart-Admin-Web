import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreTestHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Test basic Firestore connection and permissions
  static Future<void> testFirestoreConnection() async {
    print('=== FIRESTORE CONNECTION TEST ===');

    final user = _auth.currentUser;
    if (user == null) {
      print('❌ No user is currently signed in');
      return;
    }

    print('✅ User is signed in: ${user.email}');
    print('User UID: ${user.uid}');
    print('');

    // Test 1: Try to read from admins collection
    print('Test 1: Reading from admins collection...');
    try {
      final doc = await _firestore.collection('admins').doc(user.uid).get();
      if (doc.exists) {
        print('✅ Successfully read admin document');
        print('Document data: ${doc.data()}');
      } else {
        print('⚠️  Admin document does not exist');
      }
    } catch (e) {
      print('❌ Failed to read admin document: $e');
      if (e.toString().contains('permission') ||
          e.toString().contains('denied')) {
        print('   This is a Firestore security rules issue!');
      }
    }

    print('');

    // Test 2: Try to write to admins collection
    print('Test 2: Writing to admins collection...');
    try {
      final testData = {
        'test_field': 'test_value',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _firestore.collection('admins').doc(user.uid).update(testData);
      print('✅ Successfully wrote to admin document');

      // Clean up test data
      await _firestore.collection('admins').doc(user.uid).update({
        'test_field': FieldValue.delete(),
        'timestamp': FieldValue.delete(),
      });
      print('✅ Cleaned up test data');
    } catch (e) {
      print('❌ Failed to write to admin document: $e');
      if (e.toString().contains('permission') ||
          e.toString().contains('denied')) {
        print('   This is a Firestore security rules issue!');
      }
    }

    print('');

    // Test 3: Test basic Firestore functionality
    print('Test 3: Testing basic Firestore functionality...');
    try {
      // Try to create a test document in a temporary collection
      await _firestore.collection('_test').doc('connection_test').set({
        'test': true,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      print('✅ Successfully created test document');

      // Clean up test document
      await _firestore.collection('_test').doc('connection_test').delete();
      print('✅ Successfully cleaned up test document');
    } catch (e) {
      print('❌ Failed basic Firestore test: $e');
    }

    print('');
    print('=== TEST COMPLETE ==');
  }

  /// Create a test admin document with proper structure
  static Future<void> createTestAdminDocument() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ No user is currently signed in');
      return;
    }

    print('Creating test admin document...');

    try {
      final adminData = {
        'id': user.uid,
        'email': user.email,
        'role': 'admin',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'is_active': true,
        'permissions': {
          'manage_users': true,
          'manage_devices': true,
          'view_analytics': true,
          'manage_settings': true,
        },
        'last_login': null,
      };

      await _firestore.collection('admins').doc(user.uid).set(adminData);
      print('✅ Test admin document created successfully');
      print('Document data: $adminData');
    } catch (e) {
      print('❌ Failed to create test admin document: $e');
      if (e.toString().contains('permission') ||
          e.toString().contains('denied')) {
        print('   This is a Firestore security rules issue!');
        print(
          '   Please update your Firestore rules to allow admin document creation',
        );
      }
    }
  }
}
