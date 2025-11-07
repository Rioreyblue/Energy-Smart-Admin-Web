import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/admin_user_model.dart';
import '../../utils/logger.dart';

class AdminAuthService {
  static final AdminAuthService _instance = AdminAuthService._internal();
  factory AdminAuthService() => _instance;
  AdminAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of authentication state changes
  Stream<AdminUser?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((User? user) async {
      if (user == null) return null;
      return await getAdminUserFromFirebaseUser(user);
    });
  }

  // Get current admin user
  AdminUser? get currentUser =>
      _auth.currentUser != null
          ? AdminUser(
            id: _auth.currentUser!.uid,
            email: _auth.currentUser!.email ?? '',
            role: 'admin', // Default role, will be updated from Firestore
            createdAt:
                _auth.currentUser!.metadata.creationTime ?? DateTime.now(),
            lastLogin: _auth.currentUser!.metadata.lastSignInTime,
            photoUrl: _auth.currentUser!.photoURL,
          )
          : null;

  // Sign in with email and password
  Future<AdminUser?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (result.user != null) {
        Logger.debug(
          'Firebase authentication successful for user: ${result.user!.uid}',
        );
        final adminUser = await getAdminUserFromFirebaseUser(result.user!);

        // Check if user is an admin
        if (adminUser == null) {
          Logger.debug(
            'Admin user not found in Firestore for user: ${result.user!.uid}',
          );
          await signOut();
          throw Exception(
            'Admin account not found. Please contact system administrator.',
          );
        }

        if (!adminUser.isAdmin) {
          Logger.debug(
            'User ${adminUser.email} does not have admin privileges. Role: ${adminUser.role}',
          );
          await signOut();
          throw Exception('Access denied. Admin privileges required.');
        }

        Logger.info(
          'Admin user authenticated successfully: ${adminUser.email}',
        );

        // Update last login time
        await _updateLastLogin(adminUser.id);

        return adminUser;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  // Register new admin (super admin only)
  Future<AdminUser?> registerAdmin({
    required String email,
    required String password,
    required String role,
    required Map<String, bool> permissions,
    String? photoUrl,
  }) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        final adminUser = AdminUser(
          id: result.user!.uid,
          email: email,
          role: role,
          createdAt: DateTime.now(),
          permissions: permissions,
          photoUrl: photoUrl ?? result.user!.photoURL,
        );

        // Save admin user to Firestore
        await _firestore
            .collection('admins')
            .doc(adminUser.id)
            .set(adminUser.toMap());

        return adminUser;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get admin user from Firestore
  Future<AdminUser?> getAdminUserFromFirebaseUser(User user) async {
    try {
      Logger.debug('Attempting to fetch admin document for user: ${user.uid}');
      Logger.debug('User email: ${user.email}');
      Logger.debug(
        'User authentication state: ${user.emailVerified ? 'verified' : 'unverified'}',
      );

      final DocumentSnapshot doc =
          await _firestore.collection('admins').doc(user.uid).get();

      Logger.debug('Document exists: ${doc.exists}');
      Logger.debug('Document metadata: ${doc.metadata}');

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        Logger.debug('Firestore document data for user ${user.uid}: $data');

        // Check if required fields exist
        if (data['email'] == null) {
          Logger.debug(
            'Warning: Email field is missing from Firestore document',
          );
        }
        if (data['role'] == null) {
          Logger.debug(
            'Warning: Role field is missing from Firestore document',
          );
        }

        final adminUser = AdminUser.fromMap(data);
        Logger.debug(
          'Successfully created AdminUser: ${adminUser.email} with role: ${adminUser.role}',
        );
        return adminUser;
      } else {
        Logger.debug('No admin document found for user: ${user.uid}');
        Logger.debug('This could be due to:');
        Logger.debug('1. Firestore security rules blocking access');
        Logger.debug('2. Document does not exist in the admins collection');
        Logger.debug('3. User does not have proper permissions');
        return null;
      }
    } catch (e) {
      Logger.error('Error fetching admin user', e);
      Logger.debug('Error type: ${e.runtimeType}');
      Logger.debug('User UID: ${user.uid}');
      Logger.debug('User email: ${user.email}');

      // Check if it's a permission error
      if (e.toString().contains('permission') ||
          e.toString().contains('denied')) {
        Logger.debug(
          '❌ PERMISSION DENIED: This is likely a Firestore security rules issue',
        );
        Logger.debug(
          'Please check your Firestore rules and ensure they allow access to the admins collection',
        );
      }

      return null;
    }
  }

  // Update last login time
  Future<void> _updateLastLogin(String adminId) async {
    try {
      await _firestore.collection('admins').doc(adminId).update({
        'last_login': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      Logger.error('Error updating last login', e);
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No admin account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Invalid email address format.';
      case 'user-disabled':
        return 'This admin account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'email-already-in-use':
        return 'An admin account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }

  // Check if current user is super admin
  Future<bool> isSuperAdmin() async {
    final user = currentUser;
    if (user == null) return false;

    final adminUser = await getAdminUserFromFirebaseUser(_auth.currentUser!);
    return adminUser?.isSuperAdmin ?? false;
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  // Update admin permissions (super admin only)
  Future<void> updateAdminPermissions({
    required String adminId,
    required Map<String, bool> permissions,
  }) async {
    try {
      await _firestore.collection('admins').doc(adminId).update({
        'permissions': permissions,
      });
    } catch (e) {
      throw Exception('Failed to update permissions: $e');
    }
  }

  // Delete admin account (super admin only)
  Future<void> deleteAdmin(String adminId) async {
    try {
      await _firestore.collection('admins').doc(adminId).delete();
    } catch (e) {
      throw Exception('Failed to delete admin: $e');
    }
  }

  // Create test admin account for development
  Future<AdminUser?> createTestAdmin({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (result.user != null) {
        final adminUser = AdminUser(
          id: result.user!.uid,
          email: email,
          role: 'admin',
          createdAt: DateTime.now(),
          permissions: {
            'view_dashboard': true,
            'manage_users': true,
            'manage_reports': true,
            'manage_settings': true,
            'manage_admins': false,
          },
        );

        // Save admin user to Firestore
        await _firestore
            .collection('admins')
            .doc(adminUser.id)
            .set(adminUser.toMap());

        return adminUser;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }
}
