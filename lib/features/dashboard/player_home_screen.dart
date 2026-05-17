import 'dart:ui'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/premium_widgets.dart'; 
import '../matches/models/match_model.dart';
import '../matches/services/match_service.dart';
import '../matches/screens/player_match_details_screen.dart';
import '../profile/profile_screen.dart';
import '../practice/practice_screen.dart';
import '../tournaments/screens/tournament_tab.dart';
// FIX: Added /screens/ to the path so Flutter can find your file!
import '../wallet/screens/wallet_screen.dart';
import 'admin_dashboard_screen.dart';

class PlayerHomeScreen extends StatefulWidget {
  const PlayerHomeScreen({super.key});

  @override
  State<PlayerHomeScreen> createState() => _PlayerHomeScreenState();
}

class _PlayerHomeScreenState extends State<PlayerHomeScreen> {
  int _selectedIndex = 0;
  bool _isAdmin = false;
  
  final List<String> _adminEmails = ['admin@loqx.com', 'app.sportsbuzz@gmail.com', 'loqxarena@gmail.com'];

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  void _checkAdmin() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _adminEmails.map((e) => e.toLowerCase()).contains(user.email?.toLowerCase())) {
      setState(() => _isAdmin = true);
    }
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('settings').doc('app_config').snapshots(),
      builder: (context, snapshot) {
        bool showArena = true;
        bool showPractice = true;
        bool showTournament = true;

        if (snapshot.hasData && snapshot.data!.exists) {
          try {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            showArena = data['showArena'] ?? true;
            showPractice = data['showPractice'] ?? true;
            showTournament = data['showTournament'] ?? true;
          } catch (e) {
            debugPrint("Config Error: $e");
          }
        }

        List<Widget> screens = [];
        List<Map<String, dynamic>> navItems = [];

        if (showArena) {
          screens.add(const _ArenaView());
          navItems.add({'icon': Icons.sports_esports, 'label': "ARENA"});
        }

        if (showPractice) {
          screens.add(const PracticeScreen());
          navItems.add({'icon': Icons.gamepad, 'label': "PRACTICE"});
        }

        if (showTournament) {
          screens.add(const TournamentTab());
          navItems.add({'icon': Icons.emoji_events, 'label': "LOQX CUP"});
        }

        // WALLET RE-INTEGRATED
        screens.add(const WalletScreen());
        navItems.add({'icon': Icons.account_balance_wallet, 'label': "WALLET"});

        screens.add(const ProfileScreen());
        navItems.add({'icon': Icons.person, 'label': "PROFILE"});

        if (_isAdmin) {
          screens.add(const AdminDashboardScreen());
          navItems.add({'icon': Icons.admin_panel_settings, 'label': "ADMIN"});
        }

        int safeIndex = _selectedIndex;
        if (safeIndex >= screens.length) safeIndex = screens.length - 1;

        return Scaffold(
          backgroundColor: AppColors.background,
          extendBody: true, 
          body: screens[safeIndex],
          
          bottomNavigationBar: SafeArea(
            child: Container(
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(navItems.length, (index) {
                        bool isSelected = safeIndex == index; 
                        return GestureDetector(
                          onTap: () => _onItemTapped(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            padding: EdgeInsets.symmetric(horizontal: isSelected ? 16 : 10, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: isSelected ? AppColors.primary.withOpacity(0.5) : Colors.transparent, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(navItems[index]['icon'], color: isSelected ? AppColors.primary : Colors.grey.shade500, size: 24),
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  Text(navItems[index]['label'], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                                ]
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ArenaView extends StatelessWidget {
  const _ArenaView();

  String _formatMapName(String rawMapString) {
    if (rawMapString.isEmpty) return "Random";
    List<String> maps = rawMapString.split(',').map((e) => e.trim()).toList();
    if (maps.length == 1) return maps.first;
    return maps.map((m) => m.isNotEmpty ? m[0].toUpperCase() : '').join('/');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        flexibleSpace: ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.transparent))),
        elevation: 0,
        title: RichText(text: const TextSpan(style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2), children: [TextSpan(text: "LOQX ", style: TextStyle(color: Colors.white)), TextSpan(text: "ARENA", style: TextStyle(color: AppColors.primary))])),
      ),
      body: StreamBuilder<List<MatchModel>>(
        stream: MatchService().getMatches(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("No upcoming matches.", style: TextStyle(color: Colors.grey)));

          final matches = snapshot.data!.where((match) {
            if (match.status == 'completed') {
              return DateTime.now().difference(match.scheduledAt).inHours < 24; 
            }
            return true;
          }).toList();

          if (matches.isEmpty) return const Center(child: Text("No upcoming matches.", style: TextStyle(color: Colors.grey)));

          return ListView.separated(
            itemCount: matches.length,
            padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 120),
            separatorBuilder: (context, index) => const SizedBox(height: 24),
            itemBuilder: (context, index) {
              final match = matches[index];
              
              bool isRegistered = false;
              if (user != null) {
                for (var t in match.teams) {
                  Map<String, dynamic> teamMap = (t as dynamic).toMap();
                  List members = teamMap['members'] ?? [];
                  if (t.createdBy == user.uid || members.any((m) => m['uid'] == user.uid)) {
                    isRegistered = true;
                    break;
                  }
                }
              }
              
              int slotsLeft = match.slotsLeft;
              String btnText = "JOIN NOW";
              LinearGradient btnGradient = AppColors.greenButtonGradient;
              VoidCallback? onPressed = () => Navigator.push(context, MaterialPageRoute(builder: (context) => PlayerMatchDetailsScreen(match: match)));
              
              if (isRegistered) {
                  btnText = "VIEW ROOM";
                  btnGradient = const LinearGradient(colors: [Colors.blueAccent, Colors.blue]);
              } else {
                if (match.status == 'ongoing') {
                  btnText = "LIVE NOW"; 
                  btnGradient = const LinearGradient(colors: [AppColors.error, Color(0xFFFF8A80)]);
                } else if (match.status == 'completed') {
                  btnText = "RESULTS";
                  btnGradient = const LinearGradient(colors: [Colors.grey, Colors.blueGrey]);
                } else if (slotsLeft <= 0) {
                  btnText = "FULL";
                  btnGradient = const LinearGradient(colors: [Colors.grey, Colors.black]);
                  onPressed = null;
                }
              }

              // DYNAMIC ASSET FALLBACK
              String banner = match.thumbnailImage ?? '';
              Widget bannerWidget;
              if (banner.startsWith('http')) {
                bannerWidget = CachedNetworkImage(imageUrl: banner, fit: BoxFit.cover, placeholder: (c, u) => Container(color: Colors.grey.shade900), errorWidget: (c, u, e) => Container(color: Colors.grey.shade900, child: const Icon(Icons.sports_esports, color: Colors.white24)));
              } else {
                if (banner.isEmpty) banner = match.matchType == 'CS' ? 'assets/CS.jpeg' : 'assets/BR.jpg'; 
                bannerWidget = Image.asset(banner, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => Container(color: Colors.grey.shade900, child: const Icon(Icons.image_not_supported, color: Colors.white24)));
              }

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: match.status == 'open' ? AppColors.primary.withOpacity(0.3) : Colors.white10),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          SizedBox(
                            height: 140, 
                            width: double.infinity, 
                            child: bannerWidget,
                          ),
                          Positioned(bottom: 0, left: 0, right: 0, child: Container(height: 80, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [AppColors.surface, Colors.transparent])))),
                          Positioned(
                            top: 12, right: 12,
                            child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)), child: Text(match.status.toUpperCase(), style: TextStyle(color: match.status == 'open' ? AppColors.success : Colors.grey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1))),
                          )
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(match.title.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1), overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildTag(Icons.calendar_today, DateFormat('MMM d, h:mm a').format(match.scheduledAt).toUpperCase()),
                                const SizedBox(width: 8),
                                _buildTag(Icons.map, _formatMapName(match.map)),
                                const SizedBox(width: 8),
                                _buildTag(Icons.group, match.matchMode),
                              ]
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12), 
                              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), 
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                                children: [
                                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("PRIZE POOL", style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1)), const SizedBox(height: 4), Text("₹${match.prizePool}", style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w900))]), 
                                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text("ENTRY FEE", style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1)), const SizedBox(height: 4), Text(match.entryFee == 0 ? "FREE" : "₹${match.entryFee}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))])
                                ]
                              )
                            ),
                            if (match.status == 'open' && !isRegistered) Padding(padding: const EdgeInsets.only(top: 12), child: Center(child: Text("🔥 ONLY $slotsLeft SLOTS REMAINING", style: const TextStyle(color: Color(0xFFFF5252), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)))),
                            const SizedBox(height: 16),
                            PremiumButton(text: btnText, onPressed: onPressed, gradient: btnGradient),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), 
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6)), 
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      )
    );
  }
}