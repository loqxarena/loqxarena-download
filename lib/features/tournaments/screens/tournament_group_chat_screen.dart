import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/premium_widgets.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../matches/services/match_service.dart';

class TournamentGroupChatScreen extends StatefulWidget {
  final String tourneyId;
  final String groupId;
  final String groupName;
  final bool isAdmin;
  final String myTeamCode;
  final int myRole; // 1 = Captain, 2/3/4 = Player

  const TournamentGroupChatScreen({
    super.key,
    required this.tourneyId,
    required this.groupId,
    required this.groupName,
    required this.isAdmin,
    required this.myTeamCode,
    required this.myRole,
  });

  @override
  State<TournamentGroupChatScreen> createState() => _TournamentGroupChatScreenState();
}

class _TournamentGroupChatScreenState extends State<TournamentGroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final MatchService _matchService = MatchService();
  bool _isUploading = false;

  // --- ADMIN: MANAGE ALLOWED TEAMS (UPDATED) ---
  void _manageTeams() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85, // Takes up 85% of screen
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("MANAGE GROUP ACCESS", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Text("Add or remove registered teams from this group chat.", style: TextStyle(color: Colors.grey, fontSize: 12)),
              const Divider(color: Colors.white10, height: 30),
              
              Expanded(
                // Stream 1: Listen to the Group's allowed teams
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('tournaments').doc(widget.tourneyId).collection('groups').doc(widget.groupId).snapshots(),
                  builder: (context, groupSnap) {
                    if (!groupSnap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                    
                    List allowedCodes = groupSnap.data!['allowedTeamCodes'] ?? [];

                    // Stream 2: Listen to ALL registered teams in the tournament
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('tournaments').doc(widget.tourneyId).collection('teams').snapshots(),
                      builder: (context, teamsSnap) {
                        if (!teamsSnap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                        
                        var teams = teamsSnap.data!.docs;
                        if (teams.isEmpty) return const Center(child: Text("No teams registered in this tournament yet.", style: TextStyle(color: Colors.grey)));

                        return ListView.builder(
                          itemCount: teams.length,
                          itemBuilder: (context, index) {
                            var teamData = teams[index].data() as Map<String, dynamic>;
                            String teamCode = teamData['teamCode'] ?? '';
                            String teamName = teamData['teamName'] ?? 'Unknown Team';
                            List members = teamData['members'] ?? [];
                            bool isAllowed = allowedCodes.contains(teamCode);

                            return Card(
                              color: isAllowed ? AppColors.primary.withOpacity(0.05) : Colors.black26,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                // FIX: Changed 'border' to 'side' and 'Border.all' to 'BorderSide'
                                side: BorderSide(color: isAllowed ? AppColors.primary.withOpacity(0.5) : Colors.white10)
                              ),
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    // Team Info & Roster
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("$teamName ($teamCode)", style: TextStyle(color: isAllowed ? AppColors.primary : Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                          const SizedBox(height: 8),
                                          // Generate 1: to 4: Roster
                                          ...List.generate(4, (i) {
                                            int role = i + 1;
                                            var member = members.firstWhere((m) => m['role'] == role, orElse: () => null);
                                            String pName = member != null ? member['name'] : 'Waiting...';
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 2),
                                              child: Text("$role: $pName", style: TextStyle(color: member != null ? Colors.white70 : Colors.white24, fontSize: 11)),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                    
                                    // Add / Remove Buttons
                                    if (isAllowed)
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.remove_circle, size: 16, color: Colors.white),
                                        label: const Text("REMOVE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white)),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, padding: const EdgeInsets.symmetric(horizontal: 12)),
                                        onPressed: () => _confirmRemoveTeam(teamCode, teamName),
                                      )
                                    else
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.add_circle, size: 16, color: Colors.black),
                                        label: const Text("ADD", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black)),
                                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, padding: const EdgeInsets.symmetric(horizontal: 12)),
                                        onPressed: () async {
                                          await FirebaseFirestore.instance.collection('tournaments').doc(widget.tourneyId).collection('groups').doc(widget.groupId).update({
                                            'allowedTeamCodes': FieldValue.arrayUnion([teamCode])
                                          });
                                          if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("$teamName Added!"), backgroundColor: AppColors.success));
                                        },
                                      )
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }
                    );
                  }
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- CONFIRMATION DIALOG FOR REMOVING A TEAM ---
  void _confirmRemoveTeam(String teamCode, String teamName) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text("Remove $teamName?", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text("This team will no longer be able to see or chat in this group. You can add them back later.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("REMOVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('tournaments').doc(widget.tourneyId).collection('groups').doc(widget.groupId).update({
        'allowedTeamCodes': FieldValue.arrayRemove([teamCode])
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$teamName Removed."), backgroundColor: Colors.red));
    }
  }

  // --- SEND MESSAGE ---
  Future<void> _sendMsg(String content, String type) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    String senderName = widget.isAdmin ? "ADMIN" : "Captain (${widget.myTeamCode})";

    final db = FirebaseFirestore.instance;
    final groupRef = db.collection('tournaments').doc(widget.tourneyId).collection('groups').doc(widget.groupId);

    // 1. Add message to subcollection
    await groupRef.collection('messages').add({
      'text': content, 
      'senderId': widget.isAdmin ? 'admin' : user.uid, 
      'senderName': senderName, 
      'teamCode': widget.isAdmin ? 'ADMIN' : widget.myTeamCode,
      'timestamp': FieldValue.serverTimestamp(), 
      'type': type,
    });

    // 2. Update group's lastUpdated so it bumps to the top of the chat list
    await groupRef.update({
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  void _handleSend() {
    if (_messageController.text.trim().isEmpty) return;
    _sendMsg(_messageController.text.trim(), 'text');
    _messageController.clear();
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      setState(() => _isUploading = true);
      String? url = await _matchService.uploadMatchImage(File(img.path), 'group_chats');
      setState(() => _isUploading = false);
      
      if (url != null) _sendMsg(url, 'image');
    }
  }

  void _openFullScreenImage(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white), elevation: 0),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true, minScale: 0.5, maxScale: 4.0,
              child: Hero(tag: imageUrl, child: CachedNetworkImage(imageUrl: imageUrl, placeholder: (c, u) => const CircularProgressIndicator(color: AppColors.primary), errorWidget: (c, u, e) => const Icon(Icons.error, color: Colors.white), fit: BoxFit.contain)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only Admin and Captain (Role 1) can type. Everyone else is Read-Only.
    bool canType = widget.isAdmin || widget.myRole == 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.groupName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 16, color: Colors.white)),
        backgroundColor: AppColors.surface,
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (widget.isAdmin)
            IconButton(icon: const Icon(Icons.settings, color: AppColors.primary), onPressed: _manageTeams, tooltip: "Manage Teams"),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('tournaments').doc(widget.tourneyId).collection('groups').doc(widget.groupId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                final docs = snapshot.data!.docs;
                
                if (docs.isEmpty) return const Center(child: Text("Say hello!", style: TextStyle(color: Colors.grey)));

                return ListView.builder(
                  reverse: true, controller: _scrollController, itemCount: docs.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    bool isMe = widget.isAdmin ? (data['senderId'] == 'admin') : (data['senderId'] == FirebaseAuth.instance.currentUser?.uid);
                    return _buildMessageBubble(data, isMe);
                  },
                );
              },
            ),
          ),
          
          if (canType) 
            _buildModernInputArea()
          else
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16), color: Colors.black26,
              child: const Text("READ ONLY • Only Team Captains can send messages here.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            )
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> data, bool isMe) {
    bool isImage = data['type'] == 'image';
    String content = data['text'] ?? '';
    Timestamp? ts = data['timestamp'];
    String time = ts != null ? DateFormat('h:mm a').format(ts.toDate()) : '...';
    bool isAdminMsg = data['senderId'] == 'admin';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4, bottom: 6), 
              child: Text(
                isMe ? "Me" : (data['senderName'] ?? "Unknown"), 
                style: TextStyle(color: isAdminMsg ? AppColors.primary : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)
              )
            ),
            Container(
              padding: isImage ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isMe 
                    ? const LinearGradient(colors: [AppColors.secondary, Color(0xFFFFD700)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : const LinearGradient(colors: [Color(0xFF2C2C2C), Color(0xFF1E1E1E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                  bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                ),
                border: isMe ? null : Border.all(color: isAdminMsg ? AppColors.primary.withOpacity(0.5) : Colors.white12), 
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))]
              ),
              child: isImage 
                ? GestureDetector(
                    onTap: () => _openFullScreenImage(content),
                    child: Hero(tag: content, child: ClipRRect(borderRadius: BorderRadius.circular(14), child: CachedNetworkImage(imageUrl: content, height: 200, width: 200, fit: BoxFit.cover, placeholder: (c, u) => Container(height: 200, width: 200, color: Colors.black12, child: const Center(child: CircularProgressIndicator(color: AppColors.primary))), errorWidget: (c, u, e) => const Icon(Icons.broken_image, color: Colors.white54, size: 40)))),
                  )
                : Text(content, style: TextStyle(color: isMe ? Colors.black87 : Colors.white, fontSize: 14, fontWeight: isMe ? FontWeight.w600 : FontWeight.w400)),
            ),
            Padding(padding: const EdgeInsets.only(top: 6, right: 4, left: 4), child: Text(time, style: const TextStyle(color: Colors.white38, fontSize: 9))),
          ],
        ),
      ),
    );
  }

  Widget _buildModernInputArea() {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24, top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(40), border: Border.all(color: Colors.white12), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))]),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(icon: _isUploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)) : const Icon(Icons.image_outlined, color: AppColors.primary), onPressed: _isUploading ? null : _pickAndUploadImage),
            Expanded(child: AppTextField(label: "", controller: _messageController, hint: "Type a message...")), 
            GestureDetector(onTap: _handleSend, child: Container(margin: const EdgeInsets.all(4), padding: const EdgeInsets.all(12), decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppColors.secondary, Color(0xFFFFD700)])), child: const Icon(Icons.send_rounded, color: Colors.black, size: 20))),
          ],
        ),
      ),
    );
  }
}