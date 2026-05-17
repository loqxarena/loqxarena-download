import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants/app_colors.dart';
import '../dashboard/player_home_screen.dart'; 
import '../dashboard/admin_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // List of Admin Emails
  final List<String> _adminEmails = [
    'admin@loqx.com', 
    'app.sportsbuzz@gmail.com', 
    'loqxarena@gmail.com'
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeIn));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      
      // FIX: Force the Google Sign-In prompt to show all accounts every time.
      // This prevents auto-login to the previous account.
      await googleSignIn.signOut(); 

      // 1. Trigger Google Sign In Flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        // User canceled the login
        setState(() => _isLoading = false);
        return;
      }

      // 2. Obtain Auth Details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Create Credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Sign in to Firebase
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      // 5. Navigate based on Role
      if (user != null && mounted) {
        // Check if the user's email is in the admin list
        if (user.email != null && _adminEmails.contains(user.email!.toLowerCase())) {
           Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
        } else {
           Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PlayerHomeScreen()));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Login Failed: ${e.toString()}"),
            backgroundColor: AppColors.error,
          )
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Elements
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.1),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 100, spreadRadius: 50)
                ]
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withOpacity(0.1),
                boxShadow: [
                  BoxShadow(color: AppColors.secondary.withOpacity(0.2), blurRadius: 80, spreadRadius: 40)
                ]
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 2),
                          boxShadow: [
                            BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
                          ]
                        ),
                        child: Image.asset(
                          'assets/app_icon.png', 
                          height: 80, 
                          width: 80,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.sports_esports, size: 80, color: AppColors.primary),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Title
                      const Text(
                        "LOQX ARENA",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 10, offset: Offset(0, 5))
                          ]
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Subtitle
                      Text(
                        "DOMINATE. COMPETE. EARN.",
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      
                      const SizedBox(height: 60),

                      // Login Button
                      _isLoading 
                        ? const CircularProgressIndicator(color: AppColors.primary)
                        : Container(
                            width: double.infinity,
                            height: 55,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFBC02D)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              boxShadow: [
                                BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5))
                              ]
                            ),
                            child: ElevatedButton(
                              onPressed: _signInWithGoogle,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Minimalist Google "G" representation or Icon
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    child: const Icon(Icons.g_mobiledata, color: Colors.black, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    "CONTINUE WITH GOOGLE",
                                    style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                      const SizedBox(height: 40),
                      
                      // Footer Text
                      const Text(
                        "By continuing, you agree to our\nTerms of Service & Privacy Policy.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}