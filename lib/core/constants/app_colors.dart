import 'package:flutter/material.dart';

class AppColors {
  // --- PREMIUM PALETTE ---
  static const Color primary = Color(0xFFFFC107); // Gold
  static const Color secondary = Color(0xFF00E676); // Neon Green
  static const Color success = Color(0xFF00C853); 
  static const Color background = Color(0xFF121212); 
  static const Color surface = Color(0xFF1E1E1E); 
  static const Color error = Color(0xFFFF5252); 
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;

  // --- NEW: Added Missing Gold Color ---
  static const Color gold = Color(0xFFFFD700); 

  // --- GRADIENTS ---
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A2A2A), Color(0xFF121212)],
  );

  static const LinearGradient greenButtonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF00E676), Color(0xFF66BB6A)],
  );
  
  static const LinearGradient goldButtonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFFFC107), Color(0xFFFFD54F)],
  );
}