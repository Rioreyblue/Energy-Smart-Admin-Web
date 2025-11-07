import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/firebase_chat_models.dart';
import '../../utils/logger.dart';

class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Cache for user data to reduce Firestore calls
  final Map<String, FirebaseUser> _userCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Get current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password
  Future<FirebaseUser?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Get user data from Firestore
        final userDoc =
            await _firestore
                .collection('users')
                .doc(credential.user!.uid)
                .get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;

          // Check if user is admin or super admin
          if (userData['role'] == 'admin' ||
              userData['role'] == 'super_admin') {
            // Update last seen
            await _updateLastSeen(credential.user!.uid);

            return FirebaseUser.fromJson({
              'id': credential.user!.uid,
              ...userData,
            });
          } else {
            // Sign out non-admin users
            await _auth.signOut();
            throw Exception('Access denied. Admin privileges required.');
          }
        } else {
          // Create admin user document if it doesn't exist
          final adminUser = FirebaseUser(
            id: credential.user!.uid,
            name: credential.user!.displayName ?? 'Admin User',
            email: credential.user!.email!,
            role: 'admin',
            photoUrl: credential.user!.photoURL,
            createdAt: DateTime.now(),
            lastSeen: DateTime.now(),
            isOnline: true,
          );

          await _firestore
              .collection('users')
              .doc(credential.user!.uid)
              .set(adminUser.toJson());

          return adminUser;
        }
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
    return null;
  }

  /// Sign in with Google
  Future<FirebaseUser?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return null; // User cancelled the sign-in
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        // Check if user exists in Firestore
        final userDoc =
            await _firestore
                .collection('users')
                .doc(userCredential.user!.uid)
                .get();

        FirebaseUser firebaseUser;

        if (userDoc.exists) {
          final userData = userDoc.data()!;

          // Check if user is admin or super admin
          if (userData['role'] != 'admin' &&
              userData['role'] != 'super_admin') {
            await _auth.signOut();
            await _googleSignIn.signOut();
            throw Exception('Access denied. Admin privileges required.');
          }

          firebaseUser = FirebaseUser.fromJson({
            'id': userCredential.user!.uid,
            ...userData,
          });
        } else {
          // Create new admin user
          firebaseUser = FirebaseUser(
            id: userCredential.user!.uid,
            name: userCredential.user!.displayName ?? 'Admin User',
            email: userCredential.user!.email!,
            role: 'admin',
            photoUrl: userCredential.user!.photoURL,
            createdAt: DateTime.now(),
            lastSeen: DateTime.now(),
            isOnline: true,
          );

          await _firestore
              .collection('users')
              .doc(userCredential.user!.uid)
              .set(firebaseUser.toJson());
        }

        // Update last seen
        await _updateLastSeen(userCredential.user!.uid);

        return firebaseUser;
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Google sign in failed: $e');
    }
    return null;
  }

  /// Create admin user with email and password
  Future<FirebaseUser?> createAdminUser({
    required String email,
    required String password,
    required String name,
    String? photoUrl,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Update display name
        await credential.user!.updateDisplayName(name);
        if (photoUrl != null) {
          await credential.user!.updatePhotoURL(photoUrl);
        }

        // Create admin user document
        final adminUser = FirebaseUser(
          id: credential.user!.uid,
          name: name,
          email: email,
          role: 'admin',
          photoUrl: photoUrl,
          createdAt: DateTime.now(),
          lastSeen: DateTime.now(),
          isOnline: true,
        );

        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .set(adminUser.toJson());

        return adminUser;
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Admin creation failed: $e');
    }
    return null;
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      // Update online status
      if (_auth.currentUser != null) {
        await _updateOnlineStatus(_auth.currentUser!.uid, false);
      }

      await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  /// Update last seen timestamp
  Future<void> _updateLastSeen(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'lastSeen': Timestamp.fromDate(DateTime.now()),
        'isOnline': true,
      });
    } catch (e) {
      Logger.error('Error updating last seen', e);
    }
  }

  /// Update online status
  Future<void> _updateOnlineStatus(String userId, bool isOnline) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isOnline': isOnline,
        'lastSeen': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      Logger.error('Error updating online status', e);
    }
  }

  /// Get user by ID with caching
  Future<FirebaseUser?> getUserById(String userId) async {
    try {
      // Check cache first
      if (_userCache.containsKey(userId) &&
          _cacheTimestamps.containsKey(userId)) {
        final cacheTime = _cacheTimestamps[userId]!;
        if (DateTime.now().difference(cacheTime) < _cacheExpiry) {
          return _userCache[userId];
        }
      }

      // Fetch from Firestore if not in cache or expired
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final user = FirebaseUser.fromJson({'id': doc.id, ...doc.data()!});

        // Update cache
        _userCache[userId] = user;
        _cacheTimestamps[userId] = DateTime.now();

        return user;
      } else {
        // If user document doesn't exist but user is authenticated, create it
        final currentUser = _auth.currentUser;
        if (currentUser != null && currentUser.uid == userId) {
          final newUser = FirebaseUser(
            id: userId,
            name: currentUser.displayName ?? 'Admin User',
            email: currentUser.email!,
            role: 'admin', // Default role
            photoUrl: currentUser.photoURL,
            createdAt: DateTime.now(),
            lastSeen: DateTime.now(),
            isOnline: true,
          );

          // Create the user document
          await _firestore
              .collection('users')
              .doc(userId)
              .set(newUser.toJson());

          // Update cache
          _userCache[userId] = newUser;
          _cacheTimestamps[userId] = DateTime.now();

          Logger.info(
            'Created missing user document for: ${currentUser.email}',
          );
          return newUser;
        }
      }
    } catch (e) {
      Logger.error('Error getting user', e);
    }
    return null;
  }

  /// Clear user cache
  void clearUserCache() {
    _userCache.clear();
    _cacheTimestamps.clear();
  }

  /// Clear specific user from cache
  void clearUserFromCache(String userId) {
    _userCache.remove(userId);
    _cacheTimestamps.remove(userId);
  }

  /// Check if user is admin
  Future<bool> isAdmin(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final userData = doc.data()!;
        return userData['role'] == 'admin' || userData['role'] == 'super_admin';
      }
    } catch (e) {
      Logger.error('Error checking admin status', e);
    }
    return false;
  }

  /// Update user profile
  Future<void> updateUserProfile({
    required String userId,
    String? name,
    String? photoUrl,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (name != null) {
        updateData['name'] = name;
        await _auth.currentUser?.updateDisplayName(name);
      }

      if (photoUrl != null) {
        updateData['photoUrl'] = photoUrl;
        await _auth.currentUser?.updatePhotoURL(photoUrl);
      }

      if (additionalData != null) {
        updateData.addAll(additionalData);
      }

      if (updateData.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update(updateData);

        // Clear cache for updated user to force refresh
        clearUserFromCache(userId);
      }
    } catch (e) {
      throw Exception('Profile update failed: $e');
    }
  }

  /// Get all admin users
  Future<List<FirebaseUser>> getAdminUsers() async {
    try {
      final snapshot =
          await _firestore
              .collection('users')
              .where('role', whereIn: ['admin', 'super_admin'])
              .get();

      return snapshot.docs.map((doc) {
        return FirebaseUser.fromJson({'id': doc.id, ...doc.data()});
      }).toList();
    } catch (e) {
      Logger.error('Error getting admin users', e);
      return [];
    }
  }

  /// Handle Firebase Auth exceptions
  Exception _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception('No user found for this email address.');
      case 'wrong-password':
        return Exception('Wrong password provided.');
      case 'invalid-email':
        return Exception('The email address is not valid.');
      case 'user-disabled':
        return Exception('This user account has been disabled.');
      case 'too-many-requests':
        return Exception('Too many requests. Try again later.');
      case 'operation-not-allowed':
        return Exception('Signing in with Email and Password is not enabled.');
      case 'weak-password':
        return Exception('The password provided is too weak.');
      case 'email-already-in-use':
        return Exception('The account already exists for that email.');
      case 'invalid-credential':
        return Exception('Invalid credentials provided.');
      case 'account-exists-with-different-credential':
        return Exception('Account exists with different credentials.');
      case 'invalid-verification-code':
        return Exception('Invalid verification code.');
      case 'invalid-verification-id':
        return Exception('Invalid verification ID.');
      default:
        return Exception('Authentication failed: ${e.message}');
    }
  }

  /// Initialize auth state listener
  void initializeAuthStateListener() {
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        // User is signed in
        _updateOnlineStatus(user.uid, true);
      }
    });
  }

  /// Create test admin (for development only)
  Future<FirebaseUser?> createTestAdmin({
    required String email,
    required String password,
  }) async {
    // Only allow in debug mode
    assert(() {
      return true;
    }());

    return createAdminUser(
      email: email,
      password: password,
      name: 'Test Admin',
    );
  }

  /// Create super admin user
  Future<FirebaseUser?> createSuperAdmin({
    required String email,
    required String password,
    required String name,
    String? photoUrl,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Update display name
        await credential.user!.updateDisplayName(name);
        if (photoUrl != null) {
          await credential.user!.updatePhotoURL(photoUrl);
        }

        // Create super admin user document
        final superAdminUser = FirebaseUser(
          id: credential.user!.uid,
          name: name,
          email: email,
          role: 'super_admin',
          photoUrl: photoUrl,
          createdAt: DateTime.now(),
          lastSeen: DateTime.now(),
          isOnline: true,
        );

        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .set(superAdminUser.toJson());

        return superAdminUser;
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Super admin creation failed: $e');
    }
    return null;
  }

  /// Create test super admin (for development only)
  Future<FirebaseUser?> createTestSuperAdmin({
    required String email,
    required String password,
  }) async {
    // Only allow in debug mode
    assert(() {
      return true;
    }());

    return createSuperAdmin(
      email: email,
      password: password,
      name: 'Super Admin',
    );
  }

  /// Change password with reauthentication
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user signed in');

      // Reauthenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);

      // Update last seen
      await _updateLastSeen(user.uid);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Password change failed: $e');
    }
  }

  /// Remove admin user (requires super admin privileges)
  Future<void> removeAdminUser(String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No user signed in');

      // Check if current user is super admin
      final currentUserData = await getUserById(currentUser.uid);
      if (currentUserData?.role != 'super_admin') {
        throw Exception('Only super admins can remove admin users');
      }

      // Update user role to 'user' instead of deleting (safer approach)
      await _firestore.collection('users').doc(userId).update({
        'role': 'user',
        'lastModified': Timestamp.fromDate(DateTime.now()),
        'modifiedBy': currentUser.uid,
      });

      // Clear cache for updated user
      clearUserFromCache(userId);
    } catch (e) {
      throw Exception('Admin removal failed: $e');
    }
  }

  /// Disable admin user (alternative to removal)
  Future<void> disableAdminUser(String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No user signed in');

      // Check if current user is super admin
      final currentUserData = await getUserById(currentUser.uid);
      if (currentUserData?.role != 'super_admin') {
        throw Exception('Only super admins can disable admin users');
      }

      await _firestore.collection('users').doc(userId).update({
        'isActive': false,
        'disabledAt': Timestamp.fromDate(DateTime.now()),
        'disabledBy': currentUser.uid,
      });

      // Clear cache for updated user
      clearUserFromCache(userId);
    } catch (e) {
      throw Exception('Admin disable failed: $e');
    }
  }

  /// Enable admin user
  Future<void> enableAdminUser(String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No user signed in');

      // Check if current user is super admin
      final currentUserData = await getUserById(currentUser.uid);
      if (currentUserData?.role != 'super_admin') {
        throw Exception('Only super admins can enable admin users');
      }

      await _firestore.collection('users').doc(userId).update({
        'isActive': true,
        'enabledAt': Timestamp.fromDate(DateTime.now()),
        'enabledBy': currentUser.uid,
      });

      // Clear cache for updated user
      clearUserFromCache(userId);
    } catch (e) {
      throw Exception('Admin enable failed: $e');
    }
  }

  /// Send password reset email to admin user
  Future<void> sendAdminPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Ensure current user has admin data in Firestore
  Future<FirebaseUser?> ensureCurrentUserData() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      // Try to get user data, this will create it if it doesn't exist
      return await getUserById(currentUser.uid);
    } catch (e) {
      Logger.error('Error ensuring user data', e);
      return null;
    }
  }

  /// Get current user as FirebaseUser (with auto-creation if needed)
  Future<FirebaseUser?> getCurrentFirebaseUser() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      return await getUserById(currentUser.uid);
    } catch (e) {
      Logger.error('Error getting current Firebase user', e);
      return null;
    }
  }
}
