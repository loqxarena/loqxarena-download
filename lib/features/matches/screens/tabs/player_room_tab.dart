import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/premium_widgets.dart';
import '../../models/match_model.dart';
import '../../models/team_model.dart';
import '../../../chat/match_chat_screen.dart';

class PlayerRoomTab extends StatelessWidget {
  final MatchModel match;
  const PlayerRoomTab({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('matches').doc(match.id).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));

        final data = snapshot.data!.data() as Map<String, dynamic>;
        
        // --- FIX: Read correct field 'roomPassword' ---
        final String roomId = data['roomId'] ?? '';
        final String roomPass = data['roomPassword'] ?? data['roomPass'] ?? ''; // Checks both keys
        
        final String status = data['status'] ?? 'open';
        final List<dynamic> rawTeams = data['teams'] ?? [];
        
        final myTeamMap = rawTeams.firstWhere((t) => (t['createdBy'] ?? '') == (user?.uid ?? ''), orElse: () => null);

        if (myTeamMap == null) return const Center(child: Text("Not registered", style: TextStyle(color: Colors.grey))); 
        final myTeam = TeamModel.fromMap(myTeamMap);

        if (myTeam.registrationStatus == 'pending_approval') return const Center(child: Text("Verification Pending...", style: TextStyle(color: AppColors.primary)));
        if (myTeam.registrationStatus == 'rejected') return const Center(child: Text("Entry Rejected.", style: TextStyle(color: AppColors.error)));

        bool hasRoomDetails = roomId.isNotEmpty;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (status == 'completed')
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 24),
                      const SizedBox(height: 8),
                      const Text("MATCH COMPLETED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text("Room & Chat history preserved.", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                    ],
                  ),
                ),

              // ROOM DETAILS CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasRoomDetails 
                      ? [AppColors.surface, const Color(0xFF1E1E1E)] 
                      : [AppColors.surface, AppColors.surface],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: hasRoomDetails ? AppColors.primary.withOpacity(0.3) : Colors.white10),
                  boxShadow: hasRoomDetails 
                    ? [BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 4))] 
                    : [],
                ),
                child: hasRoomDetails
                  ? Column(
                      children: [
                        const Text("ROOM ID", style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 2)),
                        const SizedBox(height: 8),
                        SelectableText(
                          roomId, 
                          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 2)
                        ),
                        const SizedBox(height: 24),
                        const Text("PASSWORD", style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 2)),
                        const SizedBox(height: 8),
                        // Display "---" if pass is empty, otherwise show password
                        SelectableText(
                          roomPass.isEmpty ? "---" : roomPass, 
                          style: const TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.bold)
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 45,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.copy, color: Colors.black, size: 18),
                            label: const Text("COPY DETAILS", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            onPressed: () {
                               Clipboard.setData(ClipboardData(text: "ID: $roomId\nPass: $roomPass"));
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied!")));
                            },
                          ),
                        )
                      ],
                    )
                  : Column(
                      children: [
                        Icon(Icons.lock_clock, size: 60, color: Colors.grey.shade800),
                        const SizedBox(height: 16),
                        const Text("ROOM LOCKED", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Text("Details will appear here\n15 mins before match start.", style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
                      ],
                    ),
              ),
              
              const SizedBox(height: 32),
              
              // CHAT BUTTON
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.forum, color: Colors.white),
                  label: const Text("OPEN LOBBY CHAT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2962FF), // Royal Blue for Chat
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                  onPressed: () {
                     Navigator.push(context, MaterialPageRoute(
                       builder: (context) => MatchChatScreen(
                         matchId: match.id,
                         teamId: user!.uid,
                         teamName: myTeam.name,
                         isAdmin: false,
                         matchStatus: status,
                       ),
                     ));
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Use chat for queries, screenshots & results.",
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}