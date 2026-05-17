import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/premium_widgets.dart';
import '../../models/match_model.dart';
import '../../services/match_service.dart';
import '../../../chat/match_chat_screen.dart';

class AdminRoomChatsTab extends StatefulWidget {
  final MatchModel match;
  const AdminRoomChatsTab({super.key, required this.match});

  @override
  State<AdminRoomChatsTab> createState() => _AdminRoomChatsTabState();
}

class _AdminRoomChatsTabState extends State<AdminRoomChatsTab> {
  final _roomIdController = TextEditingController();
  final _passController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _roomIdController.text = widget.match.id;
    _passController.text = widget.match.roomPass;
  }

  Future<void> _saveDetails() async {
    await MatchService().updateMatch(widget.match.id, {
      'roomId': _roomIdController.text,
      'roomPass': _passController.text,
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Room details saved!"), backgroundColor: AppColors.success));
  }

  Future<void> _endChats() async {
    await MatchService().updateMatch(widget.match.id, {'status': 'completed'});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Match Completed. Chats are now Read-Only for players."), backgroundColor: AppColors.primary));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text("ROOM DETAILS", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(controller: _roomIdController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Room ID", filled: true, fillColor: AppColors.surface)),
          const SizedBox(height: 16),
          TextField(controller: _passController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Password", filled: true, fillColor: AppColors.surface)),
          const SizedBox(height: 16),
          PremiumButton(text: "SAVE & PUBLISH", onPressed: _saveDetails),
          
          const Divider(color: Colors.white10, height: 40),
          
          const Text("MANAGE CHATS", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          PremiumButton(text: "END ALL CHATS (MARK COMPLETED)", gradient: const LinearGradient(colors: [Colors.red, Colors.redAccent]), onPressed: _endChats),
          const SizedBox(height: 16),
          
          // List of teams
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.match.teams.length,
            itemBuilder: (context, index) {
              final team = widget.match.teams[index];
              return Card(
                color: AppColors.surface,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  // Display Email as the primary identifier for Admin
                  title: Text(team.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    "${team.createdByEmail}\n${team.captainPhone}", 
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12)
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chat, color: AppColors.secondary),
                  onTap: () {
                    if (team.createdBy.isEmpty) return; // Safety check
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => MatchChatScreen(
                        matchId: widget.match.id,
                        teamId: team.createdBy, 
                        teamName: team.name,
                        isAdmin: true,
                        matchStatus: widget.match.status,
                      ),
                    ));
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}