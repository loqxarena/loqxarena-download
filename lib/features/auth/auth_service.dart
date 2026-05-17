import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'; 

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // --- 1. THE SILENT INITIALIZATION SCRIPT (PERFECT SCHEMA) ---
  Future<void> _initializePerfectSchema(User user) async {
    final docRef = _db.collection('users').doc(user.uid);
    final docSnap = await docRef.get();

    // ONLY create if the profile doesn't exist yet to prevent overwriting wallets to 0
    if (!docSnap.exists) {
      await docRef.set({
        'email': user.email ?? 'No Email',
        'teamName': '',
        'whatsappNumber': '',
        'wallet_balance': 0,
        'totalWinnings': 0,
        'matchesPlayed': 0,
        'matchesWon': 0,
        'totalKills': 0,
        'isBanned': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint("Perfect Schema initialized for new user: ${user.uid}");
    }
  }

  // --- 2. LOGIN (Email/Password) ---
  Future<String?> login({required String email, required String password}) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(), 
        password: password.trim()
      );
      
      // Safety net: in case they were manually created in Firebase Console
      if (credential.user != null) {
        await _initializePerfectSchema(credential.user!);
      }
      
      return null; 
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return 'No user found for that email.';
      if (e.code == 'wrong-password') return 'Wrong password provided.';
      if (e.code == 'invalid-email') return 'The email address is badly formatted.';
      return e.message ?? 'An unknown error occurred';
    } catch (e) {
      return 'System Error: $e';
    }
  }

  // --- 3. REGISTER (Email/Password) ---
  Future<String?> register({required String email, required String password}) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), 
        password: password.trim()
      );
      
      // Instantly inject the Perfect Schema upon account creation
      if (credential.user != null) {
        await _initializePerfectSchema(credential.user!);
      }
      
      return null; 
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Registration Error: ${e.message}';
    } catch (e) {
      return 'System Error: $e';
    }
  }

  // --- 4. GOOGLE SIGN-IN ---
  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return 'Sign in aborted by user';

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential credentialData = await _auth.signInWithCredential(credential);
      
      // Instantly inject the Perfect Schema (Google Sign in acts as both Login & Register)
      if (credentialData.user != null) {
        await _initializePerfectSchema(credentialData.user!);
      }

      return null;
    } catch (e) {
      return 'Google Sign-In Error: $e';
    }
  }

  // --- 5. LOGOUT ---
  Future<void> logout() async {
    try {
      // Sign out from Google completely to clear the cached account
      await GoogleSignIn().signOut();
      // Sign out from Firebase
      await _auth.signOut();
      debugPrint("User Signed Out completely");
    } catch (e) {
      debugPrint("Error signing out: $e");
    }
  }
}