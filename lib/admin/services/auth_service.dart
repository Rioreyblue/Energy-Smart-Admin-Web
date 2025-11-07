import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Check if user is admin
  bool get isAdmin {
    final user = currentUser;
    if (user == null) return false;
    
    // For now, we'll use email-based admin check
    // In production, you'd check custom claims or user roles
    final adminEmails = [
      'admin@energysmart.com',
      'superadmin@energysmart.com',
    ];
    
    return adminEmails.contains(user.email);
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Handle authentication exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Signing in with Email and Password is not enabled.';
      default:
        return 'An error occurred: ${e.message}';
    }
  }

  // Stream of authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Check if user has admin privileges (placeholder for future implementation)
  Future<bool> hasAdminPrivileges(String userId) async {
    // In production, you would check Firestore for user roles
    // or use Firebase Admin SDK to check custom claims
    await Future.delayed(const Duration(milliseconds: 500));
    return true; // Placeholder
  }

  // Update user profile
  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('No user signed in');

    await user.updateDisplayName(displayName);
    await user.updatePhotoURL(photoURL);
  }

  // Change password
  Future<void> changePassword(String newPassword) async {
    final user = currentUser;
    if (user == null) throw Exception('No user signed in');

    await user.updatePassword(newPassword);
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
