import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'constants/constant.dart';
import 'admin/auth/admin_auth_wrapper.dart';
import 'admin/services/onesignal_service.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize OneSignal first (before Firebase)
    await OneSignalService().initialize();
    Logger.info('OneSignal initialized successfully');
  } catch (e) {
    Logger.error('OneSignal initialization error', e);
  }

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    Logger.info('Firebase initialized successfully');
  } catch (e) {
    Logger.error('Firebase initialization error', e);
  }

  runApp(const EnergySmartAdmin());
}

class EnergySmartAdmin extends StatelessWidget {
  const EnergySmartAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EnergySmart Admin Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        primaryColor: AppColor.primary,
        scaffoldBackgroundColor: AppColor.surface,
        fontFamily: 'Inter',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColor.primary,
          brightness: Brightness.light,
        ),
      ),
      home: const AdminAuthWrapper(),
    );
  }
}
