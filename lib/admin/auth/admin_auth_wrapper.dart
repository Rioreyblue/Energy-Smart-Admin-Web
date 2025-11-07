import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_auth_service.dart';
import 'admin_login_screen.dart';
import '../main_admin_screen.dart';
import '../../utils/logger.dart';

class AdminAuthWrapper extends StatelessWidget {
  const AdminAuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking authentication state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        // If user is not authenticated, show login screen
        if (snapshot.data == null) {
          return const AdminLoginScreen();
        }

        // If user is authenticated, check if they are an admin
        return FutureBuilder<bool>(
          future: _isAdminUser(snapshot.data!),
          builder: (context, adminSnapshot) {
            if (adminSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }

            // If user is not an admin, show login screen
            if (adminSnapshot.data != true) {
              return const AdminLoginScreen();
            }

            // If user is an admin, show the main admin screen
            return const MainAdminScreen();
          },
        );
      },
    );
  }

  Future<bool> _isAdminUser(User user) async {
    try {
      final authService = AdminAuthService();
      final adminUser = await authService.getAdminUserFromFirebaseUser(user);
      return adminUser != null && adminUser.isAdmin;
    } catch (e) {
      Logger.error('Error checking admin status', e);
      return false;
    }
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2ECC71).withAlpha(26),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF2ECC71).withAlpha(77),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.flash_on,
                size: 48,
                color: Color(0xFF2ECC71),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'EnergySmart Admin',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Loading...',
              style: TextStyle(fontSize: 16, color: Color(0xFF7F8C8D)),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2ECC71)),
            ),
          ],
        ),
      ),
    );
  }
}
