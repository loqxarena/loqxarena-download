import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/premium_widgets.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../models/match_model.dart';
import '../../services/match_service.dart';
import '../../../chat/match_chat_screen.dart';

class AdminMatchDetailsScreen extends StatefulWidget {
  final MatchModel match;
  const AdminMatchDetailsScreen({super.key, required this.match});

  @override
  State<AdminMatchDetailsScreen> createState() => _AdminMatchDetailsScreenState();
}

class _AdminMatchDetailsScreenState extends State<AdminMatchDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.match.title.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
          isScrollable: true,
          tabs: const [
            Tab(text: "INFO"),
            Tab(text: "ROOM & CHAT"),
            Tab(text: "TEAMS & VERIFY"), 
            Tab(text: "RESULTS"),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('matches').doc(widget.match.id).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final liveMatch = MatchModel.fromFirestore(snapshot.data!);

          return TabBarView(
            controller: _tabController,
            children: [
              _InfoTab(match: liveMatch),
              _RoomChatTab(match: liveMatch),
              _TeamsTab(match: liveMatch), 
              _ResultsTableTab(matchId: liveMatch.id, participants: liveMatch.teams, matchTitle: liveMatch.title),
            ],
          );
        }
      ),
    );
  }
}

class _InfoTab extends StatefulWidget {
  final MatchModel match;
  const _InfoTab({required this.match});

  @override
  State<_InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends State<_InfoTab> {
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.match.status;
  }

  void _updateStatus(String? newStatus) async {
    if (newStatus == null) return;
    setState(() => _currentStatus = newStatus);
    await MatchService().updateMatch(widget.match.id, {'status': newStatus});
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Match Status Updated to ${newStatus.toUpperCase()}")));
  }

  String _formatPrizeBreakdown(String rawText) {
    if (rawText.isEmpty) return "";
    List<String> parts = rawText.split(',');
    List<String> formattedParts = parts.map((part) {
      String trimmed = part.trim().toUpperCase();
      trimmed = trimmed.replaceAll(RegExp(r'1ST\s*:\s*'), "🥇 ");
      trimmed = trimmed.replaceAll(RegExp(r'2ND\s*:\s*'), "🥈 ");
      trimmed = trimmed.replaceAll(RegExp(r'3RD\s*:\s*'), "🥉 ");
      return trimmed;
    }).toList();
    return formattedParts.join("  ");
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.match.thumbnailImage != null)
            Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5))]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: widget.match.thumbnailImage!,
                      height: 180, width: double.infinity, fit: BoxFit.cover,
                      placeholder: (c, u) => Container(color: Colors.grey.shade900),
                      errorWidget: (c, u, e) => Container(color: Colors.grey.shade900, child: const Icon(Icons.broken_image, color: Colors.white)),
                    ),
                    Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.black.withOpacity(0.9)], begin: Alignment.topCenter, end: Alignment.bottomCenter)))),
                    Positioned(bottom: 16, left: 16, child: Text(widget.match.title.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)))
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primary)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("MATCH STATUS:", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: _currentStatus,
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  underline: Container(),
                  items: ['open', 'ongoing', 'completed'].map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value.toUpperCase(), style: TextStyle(color: value == 'open' ? Colors.green : (value == 'ongoing' ? Colors.orange : Colors.red))));
                  }).toList(),
                  onChanged: _updateStatus,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (widget.match.prizeBreakdown.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.15), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withOpacity(0.5))),
              child: Column(
                children: [
                  const Text("WINNING PRIZES", style: TextStyle(color: AppColors.primary, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(_formatPrizeBreakdown(widget.match.prizeBreakdown), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
                ],
              ),
            ),

          PremiumCard(
            glowColor: Colors.black, 
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildGridItem(Icons.map, "Map", widget.match.map),
                    Container(width: 1, height: 40, color: Colors.white10),
                    _buildGridItem(Icons.groups, "Mode", "${widget.match.matchType} - ${widget.match.matchMode}"),
                  ],
                ),
                const Divider(color: Colors.white10, height: 30),
                Row(
                  children: [
                    _buildGridItem(Icons.calendar_today, "Time", DateFormat('MMM d, h:mm a').format(widget.match.scheduledAt)),
                    Container(width: 1, height: 40, color: Colors.white10),
                    _buildGridItem(Icons.monetization_on, "Entry", widget.match.entryFee == 0 ? "FREE" : "₹${widget.match.entryFee}", isHighlight: true),
                  ],
                ),
                const Divider(color: Colors.white10, height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                     const Text("TOTAL POOL: ", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                     Text("₹${widget.match.prizePool}", style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w900)),
                  ],
                )
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          const Text("RULES & REGULATIONS", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12)),
          const SizedBox(height: 12),
          Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)), child: Text(widget.match.rules, style: const TextStyle(color: Colors.grey, height: 1.6, fontSize: 14))),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildGridItem(IconData icon, String label, String value, {bool isHighlight = false}) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: isHighlight ? AppColors.success : Colors.grey, size: 24),
          const SizedBox(height: 8),
          Text(label.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: isHighlight ? AppColors.success : Colors.white, fontWeight: FontWeight.w900, fontSize: 14), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _RoomChatTab extends StatefulWidget {
  final MatchModel match;
  const _RoomChatTab({required this.match});

  @override
  State<_RoomChatTab> createState() => _RoomChatTabState();
}

class _RoomChatTabState extends State<_RoomChatTab> {
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _idCtrl.text = widget.match.roomId ?? "";
    _passCtrl.text = widget.match.roomPassword ?? "";
  }

  void _saveRoom() {
    MatchService().updateMatchRoomDetails(widget.match.id, _idCtrl.text, _passCtrl.text);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Room Details Updated!")));
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: PremiumCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("UPDATE ROOM DETAILS", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const SizedBox(height: 16),
                  AppTextField(label: "Room ID", controller: _idCtrl),
                  const SizedBox(height: 12),
                  AppTextField(label: "Password", controller: _passCtrl),
                  const SizedBox(height: 24),
                  PremiumButton(text: "PUBLISH DETAILS", onPressed: _saveRoom),
                ],
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text("PLAYER CHATS (ONE-TO-ONE)", style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ),
        ),

        widget.match.teams.isEmpty 
          ? const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No teams registered yet.", style: TextStyle(color: Colors.grey)))))
          : SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final team = widget.match.teams[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    child: Card(
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
                      child: ListTile(
                        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.forum, color: AppColors.secondary, size: 20)),
                        title: Text(team.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text("ID: ${team.createdBy}", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => MatchChatScreen(
                              matchId: widget.match.id,
                              teamId: team.createdBy, 
                              teamName: team.name,
                              isAdmin: true, 
                              matchStatus: 'ongoing'
                            )
                          ));
                        },
                      ),
                    ),
                  );
                },
                childCount: widget.match.teams.length,
              ),
            ),
         const SliverToBoxAdapter(child: SizedBox(height: 50)), 
      ],
    );
  }
}

class _TeamsTab extends StatelessWidget {
  final MatchModel match;
  const _TeamsTab({required this.match});

  @override
  Widget build(BuildContext context) {
    if (match.teams.isEmpty) return const Center(child: Text("No teams joined yet.", style: TextStyle(color: Colors.grey)));
    
    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
      itemCount: match.teams.length,
      itemBuilder: (context, index) {
        final team = match.teams[index];
        
        bool isPending = team.registrationStatus == 'pending_approval';
        String qrUrl = "";
        
        if (team.paymentScreenshotUrl != null && team.paymentScreenshotUrl!.startsWith("QR_IMAGE|")) {
          qrUrl = team.paymentScreenshotUrl!.split("|")[1];
        }

        return Card(
          color: AppColors.surface,
          // FIX: border -> side
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isPending ? Colors.orange : Colors.white10)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.white),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(team.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(team.captainPhone, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        )
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: isPending ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                      child: Text(isPending ? "PENDING" : "APPROVED", style: TextStyle(color: isPending ? Colors.orange : Colors.green, fontSize: 10, fontWeight: FontWeight.bold))
                    )
                  ],
                ),
                
                if (qrUrl.isNotEmpty && isPending) ...[
                  const Divider(color: Colors.white10, height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.image, size: 14), 
                          label: const Text("VIEW QR", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary)),
                          onPressed: () {
                            showDialog(context: context, builder: (_) => Dialog(
                              backgroundColor: Colors.transparent,
                              child: Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  InteractiveViewer(child: CachedNetworkImage(imageUrl: qrUrl)),
                                  IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)),
                                ]
                              )
                            ));
                          }
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check, size: 14), 
                          label: const Text("APPROVE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          onPressed: () async {
                            // FIX: Corrected method call
                            await FirebaseFirestore.instance.collection('matches').doc(match.id).update({
                              'teams': match.teams.map((t) {
                                if (t.id == team.id) {
                                  var teamMap = t.toMap();
                                  teamMap['registrationStatus'] = 'approved';
                                  return teamMap;
                                }
                                return t.toMap();
                              }).toList()
                            });
                            if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Player Approved!")));
                          }
                        ),
                      )
                    ]
                  )
                ]
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ResultsTableTab extends StatefulWidget {
  final String matchId;
  final String matchTitle; 
  final List<dynamic> participants; 

  const _ResultsTableTab({required this.matchId, required this.matchTitle, required this.participants});

  @override
  State<_ResultsTableTab> createState() => _ResultsTableTabState();
}

class _ResultsTableTabState extends State<_ResultsTableTab> {
  final Map<String, TextEditingController> _rankControllers = {};
  final Map<String, TextEditingController> _killControllers = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    for (var team in widget.participants) {
      String key = team.id; 
      _rankControllers[key] = TextEditingController(text: (team.rank ?? 0).toString());
      _killControllers[key] = TextEditingController(text: (team.kills ?? 0).toString());
    }
  }

  @override
  void dispose() {
    for (var c in _rankControllers.values) { c.dispose(); }
    for (var c in _killControllers.values) { c.dispose(); }
    super.dispose();
  }

  int _getPointsForRank(int rank) {
    if (rank == 1) return 12;
    if (rank == 2) return 9;
    if (rank == 3) return 8;
    if (rank == 4) return 7;
    if (rank == 5) return 6;
    if (rank == 6) return 5;
    if (rank == 7) return 4;
    if (rank == 8) return 3;
    if (rank == 9) return 2;
    if (rank == 10) return 1;
    return 0; 
  }

  void _showSendCoinsDialog(String uid, String teamName) {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController(text: "Winnings: ${widget.matchTitle}");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text("PAYOUT TO $teamName", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(label: "Amount (₹)", controller: amountCtrl, keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            AppTextField(label: "Reason", controller: reasonCtrl),
            const SizedBox(height: 12),
            const Text("Note: The player must request a withdrawal from their profile after receiving this.", style: TextStyle(color: Colors.grey, fontSize: 10))
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          PremiumButton(
            text: "SEND PAYOUT",
            onPressed: () async {
              int amount = int.tryParse(amountCtrl.text) ?? 0;
              if (amount <= 0) return;

              Navigator.pop(context);
              try {
                final db = FirebaseFirestore.instance;
                final userRef = db.collection('users').doc(uid); 
                final txRef = userRef.collection('transactions').doc();

                await db.runTransaction((transaction) async {
                  final snapshot = await transaction.get(userRef);
                  int currentBalance = (snapshot.data()?['wallet_balance'] as int?) ?? 0;

                  transaction.set(userRef, {'wallet_balance': currentBalance + amount}, SetOptions(merge: true));

                  transaction.set(txRef, {
                    'userId': uid,
                    'type': 'winnings',
                    'amount': amount,
                    'description': reasonCtrl.text.trim(),
                    'timestamp': FieldValue.serverTimestamp(),
                    'status': 'success',
                  });
                });

                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payout Sent Successfully!"), backgroundColor: AppColors.success));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
              }
            },
          )
        ],
      ),
    );
  }

  void _saveAll() async {
    setState(() => _isSaving = true);
    try {
      final docRef = FirebaseFirestore.instance.collection('matches').doc(widget.matchId);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw "Match not found!";
        
        List<dynamic> teams = snapshot.data()!['teams'] ?? [];
        
        List<dynamic> updatedTeams = teams.map((t) {
          String key = t['id']; 
          if (_rankControllers.containsKey(key)) {
            int rankInput = int.tryParse(_rankControllers[key]?.text ?? "0") ?? 0;
            int killsInput = int.tryParse(_killControllers[key]?.text ?? "0") ?? 0;
            
            int pPoints = _getPointsForRank(rankInput);

            t['rank'] = rankInput;
            t['placementPoints'] = pPoints;
            t['kills'] = killsInput;

            if (t['createdBy'] != null && t['createdBy'].toString().isNotEmpty) {
              final userRef = FirebaseFirestore.instance.collection('users').doc(t['createdBy']);
              transaction.set(userRef, {
                'matchesPlayed': FieldValue.increment(1),
                'totalKills': FieldValue.increment(killsInput), 
                if (rankInput == 1) 'matchesWon': FieldValue.increment(1)
              }, SetOptions(merge: true));
            }
          }
          return t;
        }).toList();

        transaction.update(docRef, {'teams': updatedTeams});
      });

      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Results Saved & Leaderboard Updated!"), backgroundColor: Colors.green));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.participants.isEmpty) return const Center(child: Text("No participants.", style: TextStyle(color: Colors.grey)));

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          color: Colors.white10,
          child: const Row(
            children: [
              Expanded(flex: 2, child: Text("TEAM", style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold))),
              Expanded(flex: 1, child: Center(child: Text("RANK", style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)))),
              Expanded(flex: 1, child: Center(child: Text("KILL", style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)))),
              Expanded(flex: 1, child: Center(child: Text("PAYOUT", style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)))), 
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            itemCount: widget.participants.length,
            itemBuilder: (context, index) {
              final team = widget.participants[index];
              return Container(
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text(team.name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    Expanded(flex: 1, child: _smallInput(_rankControllers[team.id]!)),
                    const SizedBox(width: 4),
                    Expanded(flex: 1, child: _smallInput(_killControllers[team.id]!)),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: 1, 
                      child: IconButton(
                        icon: const Icon(Icons.account_balance_wallet, color: Color(0xFFFFD700), size: 24),
                        tooltip: "Send Winnings",
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showSendCoinsDialog(team.createdBy, team.name),
                      )
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          color: AppColors.surface,
          child: PremiumButton(
            text: "SAVE ALL RESULTS",
            icon: Icons.save,
            isLoading: _isSaving,
            gradient: AppColors.goldButtonGradient,
            onPressed: _saveAll,
          ),
        ),
      ],
    );
  }

  Widget _smallInput(TextEditingController ctrl) {
    return Container(
      height: 35,
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.only(bottom: 12)),
      ),
    );
  }
}