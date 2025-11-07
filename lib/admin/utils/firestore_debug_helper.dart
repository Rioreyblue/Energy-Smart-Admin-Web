import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreDebugHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Debug the current user's Firestore document structure
  static Future<void> debugCurrentUserDocument() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('No user is currently signed in');
      return;
    }

    print('=== FIRESTORE DEBUG INFO ===');
    print('User UID: ${user.uid}');
    print('User Email: ${user.email}');
    print('User Creation Time: ${user.metadata.creationTime}');
    print('User Last Sign In: ${user.metadata.lastSignInTime}');
    print('');

    try {
      final doc = await _firestore.collection('admins').doc(user.uid).get();

      if (doc.exists) {
        print('✅ Admin document exists in Firestore');
        print('Document ID: ${doc.id}');
        print('Document data:');

        final data = doc.data() as Map<String, dynamic>;
        data.forEach((key, value) {
          print('  $key: $value (${value.runtimeType})');
        });

        print('');
        print('=== REQUIRED FIELDS CHECK ===');
        _checkRequiredField(data, 'id', user.uid);
        _checkRequiredField(data, 'email', user.email);
        _checkRequiredField(data, 'role', 'admin');
        _checkOptionalField(data, 'created_at');
        _checkOptionalField(data, 'last_login');
        _checkOptionalField(data, 'is_active');
        _checkOptionalField(data, 'permissions');
      } else {
        print('❌ Admin document does NOT exist in Firestore');
        print('This is likely why login is failing!');
        print('');
        print('To fix this, you need to create an admin document with:');
        print('  - id: ${user.uid}');
        print('  - email: ${user.email}');
        print('  - role: admin (or super_admin)');
        print('  - created_at: ${DateTime.now().millisecondsSinceEpoch}');
        print('  - is_active: true');
        print('  - permissions: {}');
      }
    } catch (e) {
      print('❌ Error accessing Firestore: $e');
    }
  }

  /// Check if a required field exists and has the expected value
  static void _checkRequiredField(
    Map<String, dynamic> data,
    String fieldName,
    dynamic expectedValue,
  ) {
    if (data.containsKey(fieldName)) {
      final value = data[fieldName];
      if (value == expectedValue) {
        print('✅ $fieldName: $value (correct)');
      } else {
        print('⚠️  $fieldName: $value (expected: $expectedValue)');
      }
    } else {
      print('❌ $fieldName: MISSING (required)');
    }
  }

  /// Check if an optional field exists
  static void _checkOptionalField(Map<String, dynamic> data, String fieldName) {
    if (data.containsKey(fieldName)) {
      print('✅ $fieldName: ${data[fieldName]} (present)');
    } else {
      print('⚠️  $fieldName: missing (optional)');
    }
  }

  /// Create a basic admin document for the current user
  static Future<void> createBasicAdminDocument() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('No user is currently signed in');
      return;
    }

    try {
      final adminData = {
        'id': user.uid,
        'email': user.email,
        'role': 'admin',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'is_active': true,
        'permissions': {},
      };

      await _firestore.collection('admins').doc(user.uid).set(adminData);
      print('✅ Basic admin document created successfully');
      print('Document data: $adminData');
    } catch (e) {
      print('❌ Error creating admin document: $e');
    }
  }

  /// List all admin documents in the collection
  static Future<void> listAllAdminDocuments() async {
    try {
      final snapshot = await _firestore.collection('admins').get();

      print('=== ALL ADMIN DOCUMENTS ===');
      print('Total documents: ${snapshot.docs.length}');
      print('');

      for (var doc in snapshot.docs) {
        print('Document ID: ${doc.id}');
        final data = doc.data();
        data.forEach((key, value) {
          print('  $key: $value');
        });
        print('---');
      }
    } catch (e) {
      print('❌ Error listing admin documents: $e');
    }
  }
}









