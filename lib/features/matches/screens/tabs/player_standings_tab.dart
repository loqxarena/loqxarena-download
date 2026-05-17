import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/match_model.dart';
import '../../models/team_model.dart';

class PlayerStandingsTab extends StatelessWidget {
  final MatchModel match;
  const PlayerStandingsTab({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('matches').doc(match.id).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final List<dynamic> rawTeams = data['teams'] ?? [];
        var teams = rawTeams.map((t) => TeamModel.fromMap(t)).toList();

        // Check if results are live
        bool hasResults = teams.any((t) => t.kills > 0 || t.rank > 0);

        if (!hasResults && match.status != 'completed') {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.leaderboard, size: 64, color: Colors.grey.shade800),
                const SizedBox(height: 16),
                const Text("LEADERBOARD PENDING", style: TextStyle(color: Colors.grey, letterSpacing: 2, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        // --- CS VERSUS MODE ---
        if (match.matchType == 'CS') {
          if (teams.length < 2) return const Center(child: Text("Waiting for opponent...", style: TextStyle(color: Colors.grey)));
          
          final teamA = teams[0];
          final teamB = teams[1];
          bool aWins = teamA.kills > teamB.kills; // Kills = Rounds Won
          bool draw = teamA.kills == teamB.kills;

          return Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.surface, Colors.black],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 20)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("FINAL SCORE", style: TextStyle(color: Colors.grey, letterSpacing: 4, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // TEAM A
                      Column(children: [
                        Text(teamA.name, style: TextStyle(color: aWins ? AppColors.primary : Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                        const SizedBox(height: 8),
                        Text("${teamA.kills}", style: TextStyle(color: aWins ? AppColors.primary : Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
                      ]),
                      // VS
                      Text(":", style: TextStyle(color: Colors.grey.shade800, fontSize: 32, fontWeight: FontWeight.w900)),
                      // TEAM B
                      Column(children: [
                        Text(teamB.name, style: TextStyle(color: (!aWins && !draw) ? AppColors.primary : Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                        const SizedBox(height: 8),
                        Text("${teamB.kills}", style: TextStyle(color: (!aWins && !draw) ? AppColors.primary : Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 32),
                  if (!draw)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                      child: Text("WINNER: ${aWins ? teamA.name : teamB.name}".toUpperCase(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                    )
                ],
              ),
            ),
          );
        }

        // --- BR LEADERBOARD MODE ---
        // Sort: Total Points Descending
        teams.sort((a, b) => (b.placementPoints + b.kills).compareTo(a.placementPoints + a.kills));

        return Column(
          children: [
            // HEADER
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 40, child: Text("#", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                  Expanded(flex: 4, child: Text("TEAM", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Center(child: Text("P.PTS", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)))),
                  Expanded(flex: 1, child: Center(child: Text("KILLS", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)))),
                  Expanded(flex: 1, child: Center(child: Text("TOTAL", style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w900)))),
                ],
              ),
            ),
            
            // LIST
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: teams.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final team = teams[index];
                  final total = team.placementPoints + team.kills;
                  
                  // Rank Colors
                  Color rankColor = Colors.white;
                  Color bgColor = AppColors.surface;
                  if (index == 0) { rankColor = const Color(0xFFFFD700); bgColor = const Color(0xFF2A2A2A); } // Gold
                  else if (index == 1) { rankColor = const Color(0xFFC0C0C0); } // Silver
                  else if (index == 2) { rankColor = const Color(0xFFCD7F32); } // Bronze

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: index == 0 ? Border.all(color: AppColors.primary.withOpacity(0.3)) : null,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40, 
                          child: Text(
                            "${index + 1}", 
                            style: TextStyle(color: rankColor, fontWeight: FontWeight.w900, fontSize: 16)
                          )
                        ),
                        Expanded(
                          flex: 4, 
                          child: Text(
                            team.name, 
                            style: TextStyle(color: Colors.white, fontWeight: index == 0 ? FontWeight.w900 : FontWeight.bold)
                          )
                        ),
                        Expanded(flex: 1, child: Center(child: Text("${team.placementPoints}", style: const TextStyle(color: Colors.white54, fontSize: 14)))),
                        Expanded(flex: 1, child: Center(child: Text("${team.kills}", style: const TextStyle(color: Colors.white54, fontSize: 14)))),
                        Expanded(
                          flex: 1, 
                          child: Center(
                            child: Text(
                              "$total", 
                              style: TextStyle(color: index == 0 ? AppColors.primary : Colors.white, fontWeight: FontWeight.w900, fontSize: 16)
                            )
                          )
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}