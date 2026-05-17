import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'core/constants/app_colors.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/player_home_screen.dart';
import 'firebase_options.dart';
import 'core/services/notification_service.dart'; 

// FIXED IMPORTS: Now it correctly imports the Service and the Screen
import 'core/services/update_service.dart'; 
import 'features/update/update_screen.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Notifications
  await NotificationService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LOQX Arena',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        
        // --- PREMIUM SNACKBAR THEME ---
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF1E1E1E),
          contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
          ),
          behavior: SnackBarBehavior.floating,
          insetPadding: const EdgeInsets.all(20),
          elevation: 10,
        ),
        
        fontFamily: 'Roboto', 
        useMaterial3: true,
      ),
      // App starts at the Gatekeeper to check version before showing UI
      home: const InitialGatekeeper(), 
    );
  }
}

// --- INITIAL GATEKEEPER ---
class InitialGatekeeper extends StatefulWidget {
  const InitialGatekeeper({super.key});

  @override
  State<InitialGatekeeper> createState() => _InitialGatekeeperState();
}

class _InitialGatekeeperState extends State<InitialGatekeeper> {
  bool _isChecking = true;
  bool _needsUpdate = false;
  String _updateUrl = "";

  @override
  void initState() {
    super.initState();
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    final updateData = await UpdateService.checkForUpdate();
    
    if (updateData != null && updateData['updateRequired'] == true) {
      if (mounted) {
        setState(() {
          _needsUpdate = true;
          _updateUrl = updateData['updateUrl'];
          _isChecking = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Show loading screen while checking Firebase
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    // 2. Lockout screen if update is required
    if (_needsUpdate) {
      return UpdateScreen(updateUrl: _updateUrl);
    }

    // 3. Otherwise, proceed to Login or Dashboard
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator(color: AppColors.primary))
          );
        }
        if (snapshot.hasData) {
          return const PlayerHomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}