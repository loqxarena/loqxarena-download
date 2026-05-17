import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/premium_widgets.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../matches/services/match_service.dart';

class MatchChatScreen extends StatefulWidget {
  final String matchId;
  final String teamId; 
  final String teamName; 
  final bool isAdmin;
  final String matchStatus;

  const MatchChatScreen({
    super.key,
    required this.matchId,
    required this.teamId,
    required this.teamName,
    required this.isAdmin,
    required this.matchStatus,
  });

  @override
  State<MatchChatScreen> createState() => _MatchChatScreenState();
}

class _MatchChatScreenState extends State<MatchChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final MatchService _matchService = MatchService();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isAdmin) {
      if (widget.matchId == 'global_support') {
        _checkAndSendSupportGreeting();
      } else {
        _checkAndSendMatchGreeting();
      }
    }
  }

  void _checkAndSendSupportGreeting() async {
    final snapshot = await FirebaseFirestore.instance.collection('matches').doc('global_support').collection('chats').doc(widget.teamId).collection('messages').limit(1).get();
    if (snapshot.docs.isEmpty) {
      await _sendMsg("Hello! 👋\nLOQX Support is here to help with your issues & queries.", 'admin', 'System', 'text');
    }
  }

  void _checkAndSendMatchGreeting() async {
    final chatRef = FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.matchId)
        .collection('chats')
        .doc(widget.teamId)
        .collection('messages');

    final snapshot = await chatRef.limit(1).get();

    if (snapshot.docs.isEmpty) {
      await chatRef.add({
        'text': "Hello Squad!\n\nPlease submit the final scoreboard screenshot here for result verification.\n\n⚠️ Important:\n1. If the screenshot is not uploaded, your team will receive 0 points.\n2. Results will be announced in the Result/Standings tab shortly after match completion.\n3. Top 3 teams should provide payment details here (UPI/QR) to claim their prize pool.\n\nYou can also use this chat for any queries regarding this match.",
        'senderId': 'admin',
        'senderName': 'LOQX Admin',
        'type': 'text',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _sendMsg(String content, String uid, String name, String type) async {
    final user = FirebaseAuth.instance.currentUser;
    String email = widget.isAdmin ? 'admin@loqx.com' : (user?.email ?? 'Unknown');

    await FirebaseFirestore.instance.collection('matches').doc(widget.matchId).collection('chats').doc(widget.teamId).collection('messages').add({
      'text': content, 'senderId': uid, 'senderName': name, 'senderEmail': email, 'timestamp': FieldValue.serverTimestamp(), 'type': type,
    });

    if (widget.matchId == 'global_support') {
      await FirebaseFirestore.instance.collection('support_inbox').doc(widget.teamId).set({
        'userId': widget.teamId, 
        'userName': widget.teamName.split('-')[0].trim(), 
        'userEmail': widget.isAdmin ? (await _getUserEmail(widget.teamId)) : email,
        'lastMessage': type == 'image' ? '[Image]' : content,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<String> _getUserEmail(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('support_inbox').doc(uid).get();
    return doc.exists ? (doc.data()?['userEmail'] ?? '') : '';
  }

  void _handleSend() {
    if (_messageController.text.trim().isEmpty) return;
    if (widget.matchStatus == 'completed' && !widget.isAdmin) { 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chat is read-only."))); 
      return; 
    }
    
    final user = FirebaseAuth.instance.currentUser;
    _sendMsg(_messageController.text.trim(), widget.isAdmin ? 'admin' : user!.uid, widget.isAdmin ? 'ADMIN' : widget.teamName, 'text');
    _messageController.clear();
  }

  Future<void> _pickAndUploadImage() async {
    if (widget.matchStatus == 'completed' && !widget.isAdmin) return;
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      setState(() => _isUploading = true);
      String? url = await _matchService.uploadMatchImage(File(img.path), 'chat');
      setState(() => _isUploading = false);
      
      final user = FirebaseAuth.instance.currentUser;
      if (url != null) _sendMsg(url, widget.isAdmin ? 'admin' : user!.uid, widget.isAdmin ? 'ADMIN' : widget.teamName, 'image');
    }
  }

  void _showSendCoinsDialog() {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController(text: "Match Winnings / Refund");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text("SEND COINS TO SQUAD", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(label: "Amount (Coins)", controller: amountCtrl, keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            AppTextField(label: "Reason", controller: reasonCtrl),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          PremiumButton(
            text: "SEND COINS",
            onPressed: () async {
              int amount = int.tryParse(amountCtrl.text) ?? 0;
              if (amount <= 0) return;

              Navigator.pop(context);
              try {
                final db = FirebaseFirestore.instance;
                final userRef = db.collection('users').doc(widget.teamId); 
                final txRef = userRef.collection('transactions').doc();

                await db.runTransaction((transaction) async {
                  final snapshot = await transaction.get(userRef);
                  int currentBalance = (snapshot.data()?['wallet_balance'] as int?) ?? 0;

                  transaction.set(userRef, {'wallet_balance': currentBalance + amount}, SetOptions(merge: true));

                  transaction.set(txRef, {
                    'userId': widget.teamId,
                    'type': 'winnings',
                    'amount': amount,
                    'description': reasonCtrl.text.trim(),
                    'timestamp': FieldValue.serverTimestamp(),
                    'status': 'success',
                  });
                });

                await _sendMsg("✅ Transferred $amount Coins to your Wallet.\nReason: ${reasonCtrl.text.trim()}", 'admin', 'LOQX Admin', 'text');
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Coins Sent Successfully!"), backgroundColor: AppColors.success));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
              }
            },
          )
        ],
      ),
    );
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
    bool isReadOnly = widget.matchStatus == 'completed' && !widget.isAdmin;
    bool isSupport = widget.matchId == 'global_support';
    
    String titleText = isSupport 
        ? (widget.isAdmin ? widget.teamName : "LOQX SUPPORT") 
        : (widget.isAdmin ? widget.teamName : "LOQX CHAT");

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(titleText, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 14, color: Colors.white)),
        backgroundColor: AppColors.surface,
        elevation: 4,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        shadowColor: Colors.black.withOpacity(0.5),
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 28),
              tooltip: "Send Coins",
              onPressed: _showSendCoinsDialog,
            )
        ],
      ),
      body: Column(
        children: [
          if (widget.matchStatus == 'completed') 
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8), color: Colors.redAccent.withOpacity(0.1), child: const Text("CHAT IS READ-ONLY (MATCH COMPLETED)", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1), textAlign: TextAlign.center)),
            
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('matches').doc(widget.matchId).collection('chats').doc(widget.teamId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                final docs = snapshot.data!.docs;
                
                final currentUser = FirebaseAuth.instance.currentUser;

                return ListView.builder(
                  reverse: true, controller: _scrollController, itemCount: docs.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    
                    bool isMe = widget.isAdmin 
                        ? (data['senderId'] == 'admin') 
                        : (data['senderId'] == currentUser?.uid);

                    return _buildMessageBubble(data, isMe);
                  },
                );
              },
            ),
          ),
          
          if (!isReadOnly) _buildModernInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> data, bool isMe) {
    bool isImage = data['type'] == 'image';
    String content = data['text'] ?? '';
    Timestamp? ts = data['timestamp'];
    String time = ts != null ? DateFormat('h:mm a').format(ts.toDate()) : '...';

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
              child: Text(isMe ? "Me" : (data['senderName'] ?? "System"), style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5))
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
                border: isMe ? null : Border.all(color: Colors.white12), 
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
            Expanded(child: TextField(controller: _messageController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(border: InputBorder.none, hintText: "Type a message...", hintStyle: TextStyle(color: Colors.white38), contentPadding: EdgeInsets.symmetric(horizontal: 8)))),
            GestureDetector(onTap: _handleSend, child: Container(margin: const EdgeInsets.all(4), padding: const EdgeInsets.all(12), decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppColors.secondary, Color(0xFFFFD700)])), child: const Icon(Icons.send_rounded, color: Colors.black, size: 20))),
          ],
        ),
      ),
    );
  }
}