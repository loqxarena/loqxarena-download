import 'package:flutter/material.dart';
import 'features/dashboard/player_home_screen.dart';

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context) {
    // Points to the new Dashboard (which is PlayerHomeScreen)
    return const PlayerHomeScreen();
  }
}