import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/premium_widgets.dart';
import '../models/tournament_model.dart';
import 'tournament_details_screen.dart';

class TournamentTab extends StatelessWidget {
  const TournamentTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        title: RichText(text: const TextSpan(style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2), children: [TextSpan(text: "LOQX ", style: TextStyle(color: Colors.white)), TextSpan(text: "CUP", style: TextStyle(color: AppColors.primary))])),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('tournaments').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No tournaments available.", style: TextStyle(color: Colors.grey)));

          var tournaments = snapshot.data!.docs.map((doc) => TournamentModel.fromFirestore(doc)).toList();

          return ListView.separated(
            itemCount: tournaments.length,
            padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 120),
            separatorBuilder: (context, index) => const SizedBox(height: 24),
            itemBuilder: (context, index) {
              final tourney = tournaments[index];

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('tournaments').doc(tourney.id).collection('teams').snapshots(),
                builder: (context, teamSnap) {
                  bool isRegistered = false;
                  int registeredTeamsCount = teamSnap.hasData ? teamSnap.data!.docs.length : 0;
                  int slotsLeft = tourney.totalSlots - registeredTeamsCount;

                  if (user != null && teamSnap.hasData) {
                    for (var doc in teamSnap.data!.docs) {
                      var data = doc.data() as Map<String, dynamic>;
                      List members = data['members'] ?? [];
                      if (members.any((m) => m['uid'] == user.uid)) {
                        isRegistered = true;
                        break;
                      }
                    }
                  }

                  String btnText = "JOIN CUP NOW";
                  LinearGradient btnGradient = AppColors.greenButtonGradient;

                  if (isRegistered) {
                    btnText = "ENTER HUB";
                    btnGradient = const LinearGradient(colors: [Colors.blueAccent, Colors.blue]);
                  } else if (slotsLeft <= 0) {
                    btnText = "REGISTRATION FULL";
                    btnGradient = const LinearGradient(colors: [Colors.grey, Colors.black]);
                  }

                  // FIX: Bulletproof Image rendering for LOQX Cup Feed
                  String banner = tourney.bannerUrl;
                  Widget bannerWidget;
                  if (banner.startsWith('http')) {
                    bannerWidget = CachedNetworkImage(imageUrl: banner, fit: BoxFit.cover, placeholder: (c, u) => Container(color: Colors.grey.shade900), errorWidget: (c, u, e) => Container(color: Colors.grey.shade900, child: const Icon(Icons.emoji_events, color: Colors.white24)));
                  } else {
                    // Default fallback to BR if empty.
                    if (banner.isEmpty) banner = 'assets/BR.jpg'; 
                    bannerWidget = Image.asset(banner, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => Container(color: Colors.grey.shade900, child: const Icon(Icons.image_not_supported, color: Colors.white24)));
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              SizedBox(height: 140, width: double.infinity, child: bannerWidget),
                              Positioned(bottom: 0, left: 0, right: 0, child: Container(height: 80, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [AppColors.surface, Colors.transparent])))),
                              Positioned(
                                top: 12, right: 12,
                                child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(8)), child: const Text("REGISTRATION", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1))),
                              )
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tourney.title.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1), overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildTag(Icons.groups, "${tourney.totalSlots} Slots"),
                                    const SizedBox(width: 8),
                                    _buildTag(Icons.grid_view, "${tourney.totalGroups} Groups"),
                                    const SizedBox(width: 8),
                                    _buildTag(Icons.monetization_on, tourney.entryFee == 0 ? "Free Entry" : "₹${tourney.entryFee}"),
                                  ]
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12), 
                                  decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), 
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text("TOTAL PRIZE POOL", style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1)),
                                          const Icon(Icons.arrow_forward, color: AppColors.primary, size: 16),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text("₹${tourney.prizePool}", style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Text("🥇 ₹${tourney.rank1Prize}", style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 12),
                                          Text("🥈 ₹${tourney.rank2Prize}", style: const TextStyle(color: Color(0xFFC0C0C0), fontSize: 12, fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 12),
                                          Text("🥉 ₹${tourney.rank3Prize}", style: const TextStyle(color: Color(0xFFCD7F32), fontSize: 12, fontWeight: FontWeight.bold)),
                                        ],
                                      )
                                    ],
                                  )
                                ),
                                if (!isRegistered && slotsLeft > 0) Padding(padding: const EdgeInsets.only(top: 12), child: Center(child: Text("🔴 ONLY $slotsLeft SLOTS LEFT!", style: const TextStyle(color: Color(0xFFFF5252), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)))),
                                const SizedBox(height: 16),
                                PremiumButton(
                                  text: btnText, 
                                  gradient: btnGradient,
                                  onPressed: (slotsLeft <= 0 && !isRegistered) ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => TournamentDetailsScreen(tournament: tourney, isAdmin: false))),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
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