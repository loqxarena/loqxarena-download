import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/services/notification_service.dart';
import '../matches/services/match_service.dart';
import '../matches/services/practice_service.dart';
import '../tournaments/services/tournament_service.dart';
import '../matches/screens/admin/create_match_screen.dart';
import '../matches/screens/admin/create_practice_match_screen.dart';
import '../matches/screens/admin/admin_match_details_screen.dart';
import '../tournaments/screens/admin/create_tournament_screen.dart';
import '../tournaments/screens/tournament_details_screen.dart';
import '../chat/match_chat_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7, 
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text("ADMIN CONSOLE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white)),
          backgroundColor: Colors.black.withOpacity(0.5),
          elevation: 0,
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
            tabs: [
              Tab(text: "PAYOUTS"),
              Tab(text: "ARENA"), 
              Tab(text: "PRACTICE"), 
              Tab(text: "LOQX CUP"), 
              Tab(text: "SUPPORT"), 
              Tab(text: "APP STATS"),
              Tab(text: "NOTIFY"), 
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PayoutsAdminTab(), 
            _ArenaAdminTab(), 
            _PracticeAdminTab(), 
            _TournamentAdminTab(), 
            _SupportAdminTab(), 
            _AppStatsTab(),
            _NotifyAdminTab(), 
          ],
        ),
      ),
    );
  }
}

class _VisibilityToggle extends StatelessWidget {
  final String label;
  final String configKey;

  const _VisibilityToggle({required this.label, required this.configKey});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('settings').doc('app_config').snapshots(),
      builder: (context, snapshot) {
        bool isVisible = true;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          isVisible = data?[configKey] ?? true;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            border: const Border(bottom: BorderSide(color: Colors.white10))
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(isVisible ? Icons.visibility : Icons.visibility_off, color: isVisible ? AppColors.success : Colors.grey, size: 20),
                  const SizedBox(width: 12),
                  Text("SHOW $label TO PLAYERS", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                ],
              ),
              Switch(
                value: isVisible,
                activeColor: AppColors.success,
                onChanged: (val) {
                  FirebaseFirestore.instance.collection('settings').doc('app_config').set({
                    configKey: val
                  }, SetOptions(merge: true));
                },
              )
            ],
          ),
        );
      }
    );
  }
}

class _PayoutsAdminTab extends StatelessWidget {
  const _PayoutsAdminTab();

  void _showQRDialog(BuildContext context, String qrUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(child: CachedNetworkImage(imageUrl: qrUrl, placeholder: (c, u) => const CircularProgressIndicator(), errorWidget: (c, u, e) => const Icon(Icons.error))),
            IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  void _markAsPaid(BuildContext context, String docId, String userName, int amount) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Confirm Payment", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        content: Text("Have you successfully transferred ₹$amount to $userName's bank account?", style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          PremiumButton(text: "YES, MARK PAID", onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('withdrawal_requests').doc(docId).update({'status': 'completed', 'paidAt': FieldValue.serverTimestamp()});
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payout marked as completed!"), backgroundColor: AppColors.success));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('withdrawal_requests').where('status', isEqualTo: 'pending').orderBy('requestedAt', descending: false).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No pending payouts! You're all caught up.", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)));

        return ListView.builder(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 120),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final time = (data['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            
            String upiId = data['upiId'] ?? '';
            bool isQR = upiId.startsWith("QR_IMAGE|");
            String qrUrl = isQR ? upiId.split("|")[1] : "";

            return Card(
              color: AppColors.surface,
              // FIX: border -> side
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.primary.withOpacity(0.3))),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(data['userName'] ?? 'Unknown User', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                        Text("₹${data['amount']}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 20)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text("Requested: ${DateFormat('MMM d, h:mm a').format(time)}", style: const TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1)),
                    const Divider(color: Colors.white10, height: 30),
                    
                    if (isQR)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.qr_code, color: AppColors.primary), label: const Text("VIEW QR CODE", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        onPressed: () => _showQRDialog(context, qrUrl),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
                        child: Row(children: [const Icon(Icons.account_balance, color: Colors.grey, size: 16), const SizedBox(width: 8), Expanded(child: SelectableText(upiId, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))]),
                      ),
                    
                    const SizedBox(height: 20),
                    SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: AppColors.primary, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () => _markAsPaid(context, doc.id, data['userName'], data['amount']), child: const Text("MARK AS PAID", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)))),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _NotifyAdminTab extends StatefulWidget {
  const _NotifyAdminTab();

  @override
  State<_NotifyAdminTab> createState() => _NotifyAdminTabState();
}

class _NotifyAdminTabState extends State<_NotifyAdminTab> {
  final TextEditingController _titleCtrl = TextEditingController(text: "LOQX ARENA");
  final TextEditingController _msgCtrl = TextEditingController();
  bool _isSending = false;

  void _sendNotification() async {
    if (_msgCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Message cannot be empty")));
      return;
    }

    setState(() => _isSending = true);

    try {
      await NotificationService.sendGlobalPush(_titleCtrl.text.trim(), _msgCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Global Notification Sent!"), backgroundColor: AppColors.success));
        _msgCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 120),
      child: PremiumCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.campaign, color: AppColors.primary, size: 28),
                SizedBox(width: 12),
                Text("GLOBAL BROADCAST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
              ],
            ),
            const SizedBox(height: 8),
            const Text("Send a push notification to EVERY user with the app installed.", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const Divider(color: Colors.white10, height: 40),
            
            AppTextField(
              label: "Notification Title",
              controller: _titleCtrl,
            ),
            const SizedBox(height: 16),
            
            AppTextField(
              label: "Message Body (e.g. 🔴 LOBBY IS OPEN!)",
              controller: _msgCtrl,
              maxLines: 4,
            ),
            const SizedBox(height: 32),
            
            PremiumButton(
              text: "SEND NOTIFICATION",
              icon: Icons.send,
              isLoading: _isSending,
              onPressed: _sendNotification,
            )
          ],
        ),
      ),
    );
  }
}

class _SupportAdminTab extends StatelessWidget {
  const _SupportAdminTab();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('support_inbox').orderBy('lastUpdated', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No support messages.", style: TextStyle(color: Colors.grey)));

        return ListView.builder(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 120), 
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final time = (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now();
            final userName = data['userName'] ?? 'Unknown';
            final userId = data['userId'] ?? doc.id;

            return Card(
              color: AppColors.surface,
              // FIX: border -> side
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.person, color: Colors.blueAccent)),
                title: Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(data['lastMessage'] ?? '', maxLines: 1, style: const TextStyle(color: Colors.white70)),
                trailing: Text(DateFormat('h:mm a').format(time), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchChatScreen(matchId: 'global_support', teamId: userId, teamName: userName, isAdmin: true, matchStatus: 'ongoing'))),
              ),
            );
          },
        );
      },
    );
  }
}

class _AppStatsTab extends StatelessWidget {
  const _AppStatsTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _VisibilityToggle(label: "LEADERBOARD", configKey: "showLeaderboard"),
        
        Expanded(
          child: FutureBuilder<Map<String, String>>(
            future: _fetchStats(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              final stats = snapshot.data!;
              
              return ListView(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 120), 
                children: [
                  _buildStatCard("TOTAL PLAYERS", stats["Registered Players"]!, Icons.people, Colors.blue), 
                  const SizedBox(height: 16),
                  _buildStatCard("TOTAL ENGAGEMENT", stats["Total Engagement"]!, Icons.sports_esports, Colors.green), 
                  const SizedBox(height: 16),
                  _buildStatCard("ARENA MATCHES", stats["Total Matches"]!, Icons.add_box, Colors.orange), 
                  const SizedBox(height: 16), 
                  _buildStatCard("LOQX CUPS", stats["Active Tournaments"]!, Icons.emoji_events, Colors.purple), 
                ]
              );
            },
          ),
        ),
      ],
    );
  }

  Future<Map<String, String>> _fetchStats() async {
    final db = FirebaseFirestore.instance;
    final usersSnap = await db.collection('users').count().get();
    final matchesSnap = await db.collection('matches').count().get();
    final tourneySnap = await db.collection('tournaments').count().get();
    final usersData = await db.collection('users').get();
    int totalEngagement = 0;
    for (var doc in usersData.docs) {
      totalEngagement += (doc.data()['matchesPlayed'] as num?)?.toInt() ?? 0;
    }
    
    return {
      "Registered Players": "${usersSnap.count}", 
      "Total Engagement": "$totalEngagement",
      "Total Matches": "${matchesSnap.count}", 
      "Active Tournaments": "${tourneySnap.count}", 
    };
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24), 
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3)), boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 20)]), 
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: color, size: 32)), 
          const SizedBox(width: 24), 
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)), 
                const SizedBox(height: 8), 
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900))
            ]),
          )
        ]
      )
    );
  }
}

class _ArenaAdminTab extends StatelessWidget {
  const _ArenaAdminTab();

  String _formatMapName(String rawMapString) {
    if (rawMapString.isEmpty) return "Random";
    List<String> maps = rawMapString.split(',').map((e) => e.trim()).toList();
    if (maps.length == 1) return maps.first;
    return maps.map((m) => m.isNotEmpty ? m[0].toUpperCase() : '').join('/');
  }

  void _confirmDelete(BuildContext context, String matchId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Delete Arena Match?", style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
        content: const Text("This action cannot be undone. All teams and data will be lost.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("DELETE", style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm == true) {
      await MatchService().deleteMatch(matchId);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Match Deleted")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _VisibilityToggle(label: "ARENA", configKey: "showArena"),
        Expanded(
          child: Scaffold(
            backgroundColor: Colors.transparent, 
            floatingActionButton: Padding(
              padding: const EdgeInsets.only(bottom: 100.0),
              child: FloatingActionButton(backgroundColor: AppColors.primary, onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateMatchScreen())), child: const Icon(Icons.add, color: Colors.black)),
            ), 
            body: StreamBuilder(
              stream: MatchService().getMatches(), 
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                
                return ListView.separated(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 120), 
                  itemCount: snapshot.data!.length, 
                  separatorBuilder: (context, index) => const SizedBox(height: 24),
                  itemBuilder: (context, index) { 
                    final match = snapshot.data![index]; 
                    
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                SizedBox(
                                  height: 120, 
                                  width: double.infinity, 
                                  child: match.thumbnailImage != null 
                                    ? CachedNetworkImage(imageUrl: match.thumbnailImage!, fit: BoxFit.cover, placeholder: (context, url) => Container(color: Colors.grey.shade900), errorWidget: (context, url, error) => Container(color: Colors.grey.shade900, child: const Icon(Icons.broken_image, color: Colors.white24)))
                                    : Container(color: Colors.grey.shade900, child: const Center(child: Icon(Icons.sports_esports, color: Colors.white24)))
                                ),
                                Positioned(bottom: 0, left: 0, right: 0, child: Container(height: 60, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [AppColors.surface, Colors.transparent])))),
                              ],
                            ),
                            
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text(match.title.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                                        decoration: BoxDecoration(color: match.status == 'open' ? AppColors.secondary.withOpacity(0.2) : Colors.white10, borderRadius: BorderRadius.circular(6), border: Border.all(color: match.status == 'open' ? AppColors.secondary : Colors.grey)), 
                                        child: Text(match.status.toUpperCase(), style: TextStyle(color: match.status == 'open' ? AppColors.secondary : Colors.grey, fontSize: 10, fontWeight: FontWeight.w900))
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 12),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal, 
                                    child: Row(children: [
                                      Icon(Icons.calendar_today, size: 12, color: AppColors.primary), 
                                      const SizedBox(width: 4), 
                                      Text(DateFormat('MMM d, h:mm a').format(match.scheduledAt).toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)), 
                                      const SizedBox(width: 12), 
                                      _buildSimpleTag(_formatMapName(match.map)), 
                                      const SizedBox(width: 8), 
                                      _buildSimpleTag(match.matchMode)
                                    ])
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          icon: const Icon(Icons.edit, size: 16), label: const Text("EDIT", style: TextStyle(fontWeight: FontWeight.bold)),
                                          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateMatchScreen(matchToEdit: match))),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          icon: const Icon(Icons.settings, size: 16), label: const Text("MANAGE", style: TextStyle(fontWeight: FontWeight.bold)),
                                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminMatchDetailsScreen(match: match))),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: AppColors.error),
                                        onPressed: () => _confirmDelete(context, match.id), 
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                );
              }
            )
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleTag(String text) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)), child: Text(text.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)));
  }
}

class _PracticeAdminTab extends StatelessWidget {
  const _PracticeAdminTab();

  void _confirmDelete(BuildContext context, String matchId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Delete Practice Match?", style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
        content: const Text("This action cannot be undone.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("DELETE", style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm == true) {
      await PracticeService().deletePracticeMatch(matchId);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Practice Match Deleted")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _VisibilityToggle(label: "PRACTICE", configKey: "showPractice"),
        Expanded(
          child: Scaffold(
            backgroundColor: Colors.transparent, 
            floatingActionButton: Padding(
              padding: const EdgeInsets.only(bottom: 100.0),
              child: FloatingActionButton(backgroundColor: AppColors.secondary, onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePracticeMatchScreen())), child: const Icon(Icons.add, color: Colors.black)),
            ), 
            body: StreamBuilder(
              stream: PracticeService().getPracticeMatches(), 
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                return ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 120), 
                  itemCount: snapshot.data!.length, 
                  itemBuilder: (context, index) { 
                    final match = snapshot.data![index]; 
                    return Card(
                      color: AppColors.surface, 
                      // FIX: border -> side
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(match.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
                        subtitle: Text("ROOM ID: ${match.roomId}", style: const TextStyle(color: Colors.grey, fontSize: 11, letterSpacing: 1)), 
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min, 
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreatePracticeMatchScreen(matchToEdit: match)))), 
                            IconButton(icon: const Icon(Icons.delete, color: AppColors.error), onPressed: () => _confirmDelete(context, match.id)) 
                          ]
                        )
                      )
                    );
                  }
                );
              }
            )
          ),
        ),
      ],
    );
  }
}

class _TournamentAdminTab extends StatelessWidget {
  const _TournamentAdminTab();

  void _confirmDelete(BuildContext context, String tourneyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Delete LOQX Cup?", style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
        content: const Text("This action cannot be undone. All teams and data will be lost.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("DELETE", style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm == true) {
      await TournamentService().deleteTournament(tourneyId);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("LOQX Cup Deleted")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _VisibilityToggle(label: "LOQX CUP", configKey: "showTournament"),
        Expanded(
          child: Scaffold(
            backgroundColor: Colors.transparent, 
            floatingActionButton: Padding(
              padding: const EdgeInsets.only(bottom: 100.0),
              child: FloatingActionButton(backgroundColor: Colors.purpleAccent, onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTournamentScreen())), child: const Icon(Icons.add, color: Colors.white)),
            ), 
            body: StreamBuilder(
              stream: TournamentService().getTournaments(), 
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                
                final tournaments = snapshot.data!;
                tournaments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                return ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 120), 
                  itemCount: tournaments.length, 
                  itemBuilder: (context, index) { 
                    final tourney = tournaments[index]; 
                    return Card(
                      color: AppColors.surface, 
                      // FIX: border -> side
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(tourney.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min, 
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTournamentScreen(tournamentToEdit: tourney)))), 
                            IconButton(icon: const Icon(Icons.settings, color: AppColors.primary), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TournamentDetailsScreen(tournament: tourney, isAdmin: true)))), 
                            IconButton(icon: const Icon(Icons.delete, color: AppColors.error), onPressed: () => _confirmDelete(context, tourney.id)) 
                          ]
                        )
                      )
                    );
                  }
                );
              }
            )
          ),
        ),
      ],
    );
  }
}