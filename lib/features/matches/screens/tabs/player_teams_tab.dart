import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/match_model.dart';
import '../../models/team_model.dart';

class PlayerTeamsTab extends StatelessWidget {
  final MatchModel match;
  const PlayerTeamsTab({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('matches').doc(match.id).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final List<dynamic> rawTeams = data['teams'] ?? [];
        final teams = rawTeams.map((t) => TeamModel.fromMap(t)).toList();

        if (teams.isEmpty) return const Center(child: Text("No teams registered yet.", style: TextStyle(color: Colors.grey)));

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: teams.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final team = teams[index];
            final isApproved = team.registrationStatus == 'approved';

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  // Avatar with Slot #
                  Container(
                    width: 45, height: 45,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(
                      "${index + 1}",
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Team Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.name, 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isApproved)
                          const Text(
                            "Pending Verification...", 
                            style: TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic)
                          ),
                      ],
                    ),
                  ),

                  // Verification Badge
                  if (isApproved)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: AppColors.success, size: 16),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}