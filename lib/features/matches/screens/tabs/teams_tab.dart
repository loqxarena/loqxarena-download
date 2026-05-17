import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/premium_widgets.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../models/match_model.dart';
import '../../models/team_model.dart';
import '../../services/match_service.dart';

class TeamsTab extends StatefulWidget {
  final MatchModel match;
  const TeamsTab({super.key, required this.match});

  @override
  State<TeamsTab> createState() => _TeamsTabState();
}

class _TeamsTabState extends State<TeamsTab> {
  bool _isUpdating = false;

  Future<void> _updateStatus(TeamModel team, String status) async {
    setState(() => _isUpdating = true);
    try {
      await MatchService().updateTeamStatus(widget.match.id, team.id, status);
      
      // AUTO SEND MESSAGE ON APPROVE (Requested Format)
      if (status == 'approved') {
        await FirebaseFirestore.instance
            .collection('matches')
            .doc(widget.match.id)
            .collection('chats')
            .doc(team.createdBy)
            .collection('messages')
            .add({
          // UPDATED MESSAGE CONTENT
          'text': "Hello ${team.name}! Please send the end-match screenshot here and wait for the results.",
          'senderId': 'admin',
          'senderName': 'LOQX System',
          'senderEmail': 'admin@loqx.com',
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'text',
        });
      }

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Team ${status.toUpperCase()}!"), backgroundColor: status == 'approved' ? AppColors.success : AppColors.error));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showAddTeamDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text("Add Team Manually", style: TextStyle(color: Colors.white)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        AppTextField(label: "Team Name", controller: nameCtrl),
        const SizedBox(height: 12),
        AppTextField(label: "Phone", controller: phoneCtrl),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        TextButton(onPressed: () async {
          if (nameCtrl.text.isEmpty) return;
          final user = FirebaseAuth.instance.currentUser;
          final newTeam = TeamModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: nameCtrl.text,
            captainPhone: phoneCtrl.text,
            paymentScreenshotUrl: "", 
            createdBy: user?.uid ?? "admin", 
            createdByEmail: "Manual Entry",
            registrationStatus: "approved", 
          );
          await MatchService().addTeam(widget.match.id, newTeam);
          if(mounted) Navigator.pop(context);
        }, child: const Text("ADD", style: TextStyle(color: AppColors.primary))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold( 
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: Colors.white,
        onPressed: _showAddTeamDialog,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('matches').doc(widget.match.id).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final List<dynamic> rawTeams = data['teams'] ?? [];
          final teams = rawTeams.map((t) => TeamModel.fromMap(t)).toList();

          if (teams.isEmpty) return const Center(child: Text("No teams registered.", style: TextStyle(color: Colors.grey)));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: teams.length,
            itemBuilder: (context, index) {
              final team = teams[index];
              Color statusColor = Colors.orange;
              if (team.registrationStatus == 'approved') statusColor = AppColors.success;
              if (team.registrationStatus == 'rejected') statusColor = AppColors.error;

              return PremiumCard(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(children: [CircleAvatar(child: Text("${index + 1}")), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(team.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), Text(team.createdByEmail, style: const TextStyle(color: Colors.grey, fontSize: 12)), Text(team.captainPhone, style: const TextStyle(color: Colors.grey, fontSize: 12))])), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: statusColor)), child: Text(team.registrationStatus.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)))]),
                    const SizedBox(height: 16),
                    if (!_isUpdating)
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                          if (team.registrationStatus != 'rejected') TextButton(onPressed: () => _updateStatus(team, 'rejected'), child: const Text("REJECT", style: TextStyle(color: AppColors.error))),
                          if (team.registrationStatus != 'approved') TextButton(onPressed: () => _updateStatus(team, 'approved'), child: const Text("APPROVE", style: TextStyle(color: AppColors.success))),
                        ]),
                    if (team.paymentScreenshotUrl.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12.0), child: TextButton(onPressed: () { showDialog(context: context, builder: (c) => Dialog(child: Image.network(team.paymentScreenshotUrl))); }, child: const Text("View Payment Screenshot", style: TextStyle(color: AppColors.primary))))
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}