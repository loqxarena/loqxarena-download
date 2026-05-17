import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/premium_widgets.dart';
import '../../../core/widgets/app_text_field.dart';
import '../models/tournament_model.dart';
import '../services/tournament_service.dart';
import 'tournament_group_chat_screen.dart'; 

Widget _buildSquadGrid(List members, bool isRegisteredView) {
  return Column(
    children: [
      Row(
        children: [
          Expanded(child: _buildPlayerSlot(1, members)),
          const SizedBox(width: 12),
          Expanded(child: _buildPlayerSlot(2, members)),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: _buildPlayerSlot(3, members)),
          const SizedBox(width: 12),
          Expanded(child: _buildPlayerSlot(4, members)),
        ],
      ),
      if (isRegisteredView && members.length < 4)
        Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: Text("Share your SQUAD CODE with teammates so they can join!", style: TextStyle(color: AppColors.primary.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        )
    ],
  );
}

Widget _buildPlayerSlot(int role, List members) {
  var member = members.firstWhere((m) => m['role'] == role, orElse: () => null);
  bool isEmpty = member == null;
  bool isIGL = role == 1;

  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12), border: Border.all(color: isIGL && !isEmpty ? AppColors.primary.withOpacity(0.3) : Colors.transparent)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(isIGL ? "IGL" : "PLAYER $role", style: TextStyle(color: isIGL ? AppColors.primary : Colors.grey, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
            if (isIGL && !isEmpty) const Icon(Icons.star, color: AppColors.primary, size: 10),
          ],
        ),
        const SizedBox(height: 4),
        Text(isEmpty ? "Open Slot" : member['name'], style: TextStyle(color: isEmpty ? Colors.white24 : Colors.white, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

class TournamentDetailsScreen extends StatefulWidget {
  final TournamentModel tournament;
  final bool isAdmin;

  const TournamentDetailsScreen({super.key, required this.tournament, this.isAdmin = false});

  @override
  State<TournamentDetailsScreen> createState() => _TournamentDetailsScreenState();
}

class _TournamentDetailsScreenState extends State<TournamentDetailsScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  void _deleteTournament() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Delete Tournament?", style: TextStyle(color: AppColors.error)),
        content: const Text("This action cannot be undone. All teams and data will be lost.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("DELETE", style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm == true) {
      await TournamentService().deleteTournament(widget.tournament.id);
      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tournament Deleted.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(widget.tournament.title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
          backgroundColor: AppColors.surface,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (widget.isAdmin) 
              IconButton(icon: const Icon(Icons.delete, color: AppColors.error), onPressed: _deleteTournament),
          ],
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              Tab(text: "INFO"),
              Tab(text: "TEAMS"),
              Tab(text: "GROUP CHAT"),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('tournaments').doc(widget.tournament.id).collection('teams').snapshots(),
          builder: (context, snapshot) {
            bool isRegistered = false;
            String myTeamCode = "";
            Map<String, dynamic>? myTeamData;

            if (currentUser != null && snapshot.hasData) {
              for (var doc in snapshot.data!.docs) {
                var data = doc.data() as Map<String, dynamic>;
                List members = data['members'] ?? [];
                if (members.any((m) => m['uid'] == currentUser!.uid)) {
                  isRegistered = true;
                  myTeamCode = data['teamCode'] ?? "";
                  myTeamData = data;
                  break;
                }
              }
            }

            return TabBarView(
              children: [
                _buildInfoTab(isRegistered, myTeamCode, myTeamData),
                _TournamentTeamsTab(tournament: widget.tournament, isAdmin: widget.isAdmin, teamDocs: snapshot.hasData ? snapshot.data!.docs : []),
                _TournamentGroupsTab(tourneyId: widget.tournament.id, isAdmin: widget.isAdmin, currentUser: currentUser, myTeamCode: myTeamCode),
              ],
            );
          }
        ),
      ),
    );
  }

  Widget _buildInfoTab(bool isRegistered, String teamCode, Map<String, dynamic>? teamData) {
    
    // FIX: Consistent Image Fallback
    String banner = widget.tournament.bannerUrl;
    Widget bannerWidget;
    if (banner.startsWith('http')) {
      bannerWidget = CachedNetworkImage(imageUrl: banner, height: 180, width: double.infinity, fit: BoxFit.cover);
    } else {
      if (banner.isEmpty) banner = 'assets/BR.jpg'; 
      bannerWidget = Image.asset(banner, height: 180, width: double.infinity, fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => Container(
          height: 180, width: double.infinity, color: Colors.grey.shade900,
          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.image_not_supported, color: Colors.white54, size: 40), 
            SizedBox(height: 8), 
            Text("Asset missing. Check pubspec.yaml", style: TextStyle(color: Colors.white54, fontSize: 10))
          ])
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(16), child: bannerWidget),
          const SizedBox(height: 24),
          
          PremiumCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStat(Icons.groups, "Teams", "${widget.tournament.totalSlots}"),
                    // FIX: Changed from Group Size to Group Count (totalGroups = totalSlots/groupSize handled in backend)
                    _buildStat(Icons.grid_view, "Groups", "${widget.tournament.totalGroups}"),
                    _buildStat(Icons.monetization_on, "Entry", "FREE"),
                  ],
                ),
                const Divider(color: Colors.white10, height: 30),
                const Text("PRIZEPOOL (PER GROUP)", style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text("🥇 ₹${widget.tournament.rank1Prize}", style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("🥈 ₹${widget.tournament.rank2Prize}", style: const TextStyle(color: Color(0xFFC0C0C0), fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("🥉 ₹${widget.tournament.rank3Prize}", style: const TextStyle(color: Color(0xFFCD7F32), fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (!widget.isAdmin) ...[
            if (!isRegistered) ...[
               const Text("CUP REGISTRATION", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12)),
               const SizedBox(height: 12),
               _CupRegistrationEmbedded(tournament: widget.tournament, user: currentUser!),
            ] else if (isRegistered && teamData != null) ...[
               Container(
                 width: double.infinity, padding: const EdgeInsets.all(20),
                 decoration: BoxDecoration(color: Colors.green.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green.withOpacity(0.5))),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(teamData['teamName']?.toUpperCase() ?? "MY SQUAD", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
                             const SizedBox(height: 4),
                             Text("IGL Contact: ${teamData['captainPhone']}", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                           ],
                         ),
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                           decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                           child: const Text("REGISTERED", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                         )
                       ],
                     ),
                     const SizedBox(height: 16),
                     Row(
                       children: [
                         const Text("SQUAD CODE: ", style: TextStyle(color: Colors.white70, fontSize: 12)),
                         SelectableText(teamCode, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 16)),
                       ],
                     ),
                     const SizedBox(height: 20),
                     _buildSquadGrid(teamData['members'] ?? [], true),
                   ],
                 ),
               ),
            ],
            const SizedBox(height: 30),
          ],
          
          const Text("RULES & FORMAT", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
            child: Text(widget.tournament.formatRules, style: const TextStyle(color: Colors.grey, height: 1.6, fontSize: 14)), 
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String label, String value) {
    return Column(children: [Icon(icon, color: AppColors.primary, size: 20), const SizedBox(height: 4), Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)), Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]);
  }
}

class _CupRegistrationEmbedded extends StatefulWidget {
  final TournamentModel tournament;
  final User user;
  const _CupRegistrationEmbedded({required this.tournament, required this.user});

  @override
  State<_CupRegistrationEmbedded> createState() => _CupRegistrationEmbeddedState();
}

class _CupRegistrationEmbeddedState extends State<_CupRegistrationEmbedded> {
  bool isCreating = true; 
  bool isLoading = false;
  
  final _teamNameCtrl = TextEditingController();
  final _player1NameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _teamCodeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _teamNameCtrl.text = prefs.getString('pref_team_name') ?? "";
      _player1NameCtrl.text = prefs.getString('pref_player_name') ?? "";
      _phoneCtrl.text = prefs.getString('pref_phone') ?? "";
    });
  }

  Future<void> _finalizeTournamentRegistration(Map<String, dynamic> squadData) async {
    setState(() => isLoading = true);
    try {
      final db = FirebaseFirestore.instance;
      String newCode = squadData['teamCode'];
      
      await db.collection('tournaments').doc(widget.tournament.id).collection('teams').doc(newCode).set({
        'teamName': squadData['teamName'],
        'teamCode': newCode,
        'captainPhone': squadData['captainPhone'],
        'paymentScreenshotUrl': '', 
        'isVerified': true, 
        'createdAt': FieldValue.serverTimestamp(),
        'members': squadData['members'],
      });

      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Registered Successfully!"), backgroundColor: Colors.green));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _createGlobalSquadAndProceed() async {
    if (_teamNameCtrl.text.isEmpty || _player1NameCtrl.text.isEmpty || _phoneCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ Fill all fields."), backgroundColor: Colors.red));
      return;
    }
    
    setState(() => isLoading = true);
    
    try {
      String prefix = widget.tournament.codePrefix.isNotEmpty ? widget.tournament.codePrefix : "LQX";
      String code = "$prefix-${Random().nextInt(999999).toString().padLeft(6, '0')}";
      
      Map<String, dynamic> squadData = {
        'teamName': _teamNameCtrl.text.trim(),
        'teamCode': code,
        'captainPhone': _phoneCtrl.text.trim(),
        'memberIds': [widget.user.uid],
        'members': [{'uid': widget.user.uid, 'name': _player1NameCtrl.text.trim(), 'role': 1}],
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('squads').doc(code).set(squadData);
      await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).set({'teamName': _teamNameCtrl.text.trim(), 'whatsappNumber': _phoneCtrl.text.trim()}, SetOptions(merge: true));

      setState(() => isLoading = false);
      _finalizeTournamentRegistration(squadData); 

    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      setState(() => isLoading = false);
    }
  }

  Future<void> _joinGlobalSquadAndProceed() async {
    if (_teamCodeCtrl.text.isEmpty || _player1NameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ Fill all fields."), backgroundColor: Colors.red));
      return;
    }

    setState(() => isLoading = true);
    String code = _teamCodeCtrl.text.trim().toUpperCase();

    try {
      Map<String, dynamic>? updatedSquadData;

      await FirebaseFirestore.instance.runTransaction((tx) async {
        DocumentSnapshot snap = await tx.get(FirebaseFirestore.instance.collection('squads').doc(code));
        if (!snap.exists) throw "Invalid Squad Code!";
        
        Map<String, dynamic> data = snap.data() as Map<String, dynamic>;
        List members = List.from(data['members'] ?? []);
        List memberIds = List.from(data['memberIds'] ?? []);
        
        if (members.length >= 4) throw "This squad is already full!";
        if (memberIds.contains(widget.user.uid)) throw "You are already in this squad!";

        List<int> takenRoles = members.map<int>((m) => m['role'] as int).toList();
        int nextRole = [2, 3, 4].firstWhere((r) => !takenRoles.contains(r));

        members.add({'uid': widget.user.uid, 'name': _player1NameCtrl.text.trim(), 'role': nextRole});
        memberIds.add(widget.user.uid);

        updatedSquadData = data;
        updatedSquadData!['members'] = members;
        updatedSquadData!['memberIds'] = memberIds;

        tx.update(snap.reference, {'members': members, 'memberIds': memberIds});
      });

      await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).set({'teamName': updatedSquadData!['teamName']}, SetOptions(merge: true));

      setState(() => isLoading = false);
      _finalizeTournamentRegistration(updatedSquadData!);

    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('squads').where('memberIds', arrayContains: widget.user.uid).limit(1).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        if (snapshot.data!.docs.isNotEmpty) {
          var squadData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          return PremiumCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("YOUR GLOBAL SQUAD", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(height: 12),
                Text(squadData['teamName'].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildSquadGrid(squadData['members'] ?? [], false),
                const SizedBox(height: 24),
                PremiumButton(
                  text: "CONFIRM CUP REGISTRATION",
                  isLoading: isLoading,
                  gradient: AppColors.greenButtonGradient,
                  onPressed: () => _finalizeTournamentRegistration(squadData),
                ),
              ],
            ),
          );
        }

        return PremiumCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("SETUP YOUR SQUAD FIRST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
              const SizedBox(height: 4),
              const Text("Create or join a global squad to enter this cup.", style: TextStyle(color: Colors.grey, fontSize: 10)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: ChoiceChip(label: const Text("CREATE SQUAD", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), selected: isCreating, onSelected: (v) => setState(() => isCreating = true), selectedColor: AppColors.primary, labelStyle: TextStyle(color: isCreating ? Colors.black : Colors.white))),
                  const SizedBox(width: 12),
                  Expanded(child: ChoiceChip(label: const Text("JOIN VIA CODE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), selected: !isCreating, onSelected: (v) => setState(() => isCreating = false), selectedColor: AppColors.primary, labelStyle: TextStyle(color: !isCreating ? Colors.black : Colors.white))),
                ],
              ),
              const SizedBox(height: 24),

              if (isCreating) ...[
                AppTextField(label: "Squad Name", controller: _teamNameCtrl),
                const SizedBox(height: 12),
                AppTextField(label: "Your Name in Game (IGL)", controller: _player1NameCtrl),
                const SizedBox(height: 12),
                AppTextField(label: "WhatsApp Number", controller: _phoneCtrl, keyboardType: TextInputType.phone),
              ] else ...[
                AppTextField(label: "Enter Squad Code", controller: _teamCodeCtrl, hint: "e.g. LQX-123456"),
                const SizedBox(height: 12),
                AppTextField(label: "Your Name in Game", controller: _player1NameCtrl),
              ],
              
              const SizedBox(height: 32),
              PremiumButton(
                text: isCreating ? "CREATE GLOBAL SQUAD" : "JOIN GLOBAL SQUAD", 
                isLoading: isLoading, 
                onPressed: isCreating ? _createGlobalSquadAndProceed : _joinGlobalSquadAndProceed,
              ),
            ],
          ),
        );
      }
    );
  }
}

class _TournamentTeamsTab extends StatelessWidget {
  final TournamentModel tournament;
  final bool isAdmin;
  final List<QueryDocumentSnapshot> teamDocs;

  const _TournamentTeamsTab({required this.tournament, required this.isAdmin, required this.teamDocs});

  @override
  Widget build(BuildContext context) {
    if (teamDocs.isEmpty) return const Center(child: Text("No squads registered yet.", style: TextStyle(color: Colors.grey)));

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 120),
      itemCount: teamDocs.length,
      itemBuilder: (context, index) {
        var team = teamDocs[index].data() as Map<String, dynamic>;
        List members = team['members'] ?? [];
        String code = team['teamCode'] ?? "UNKNOWN";
        bool isFull = members.length == 4;
        
        return Card(
          color: AppColors.surface,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isFull ? AppColors.success.withOpacity(0.3) : Colors.white10)),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: CircleAvatar(backgroundColor: Colors.white10, child: Text("${index + 1}", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
              title: Text(team['teamName']?.toUpperCase() ?? "SQUAD", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
              subtitle: const Text("Status: APPROVED", style: TextStyle(color: Colors.green, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold)),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  child: Column(
                    children: [
                      if (isAdmin) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("CODE: $code", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const Divider(color: Colors.white10, height: 16),
                      ],
                      _buildSquadGrid(members, false),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TournamentGroupsTab extends StatelessWidget {
  final String tourneyId;
  final bool isAdmin;
  final User? currentUser;
  final String myTeamCode;

  const _TournamentGroupsTab({required this.tourneyId, required this.isAdmin, required this.currentUser, required this.myTeamCode});

  void _showCreateGroupSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    
    showModalBottomSheet(
      context: context, 
      backgroundColor: AppColors.surface, 
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("CREATE GROUP CHAT", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              AppTextField(label: "Group Name (e.g. Finals Lobby)", controller: nameCtrl),
              const SizedBox(height: 12),
              AppTextField(label: "Description / Rules", controller: descCtrl),
              const SizedBox(height: 24),
              PremiumButton(
                text: "CREATE ROOM", 
                onPressed: () async {
                  if (nameCtrl.text.isEmpty) return;
                  await FirebaseFirestore.instance.collection('tournaments').doc(tourneyId).collection('groups').add({
                    'name': nameCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'allowedTeamCodes': [], 
                    'createdAt': FieldValue.serverTimestamp(),
                    'lastUpdated': FieldValue.serverTimestamp(),
                  });
                  if(ctx.mounted) Navigator.pop(ctx);
                }
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('tournaments').doc(tourneyId).collection('groups').orderBy('lastUpdated', descending: true).snapshots(),
      builder: (context, groupSnap) {
        if (!groupSnap.hasData) return const Center(child: CircularProgressIndicator());
        
        var groups = groupSnap.data!.docs.where((g) {
          if (isAdmin) return true;
          List allowed = g['allowedTeamCodes'] ?? [];
          return allowed.contains(myTeamCode);
        }).toList();

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: isAdmin ? FloatingActionButton.extended(
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add, color: Colors.black),
            label: const Text("CREATE GROUP", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            onPressed: () => _showCreateGroupSheet(context),
          ) : null,
          body: groups.isEmpty
              ? Center(child: Text(isAdmin ? "No groups created yet." : "You haven't been added to any groups.", style: const TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    var group = groups[index].data() as Map<String, dynamic>;
                    
                    return Card(
                      color: AppColors.surface,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.white10, child: Icon(Icons.groups, color: AppColors.primary)),
                        title: Text(group['name'] ?? 'Tournament Group', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(group['description'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                        onTap: () async {
                           String myPlayerName = "Player";
                           int myRole = 0;
                           if (!isAdmin && currentUser != null && myTeamCode.isNotEmpty) {
                             var tDoc = await FirebaseFirestore.instance.collection('tournaments').doc(tourneyId).collection('teams').doc(myTeamCode).get();
                             if (tDoc.exists) {
                               List members = tDoc.data()?['members'] ?? [];
                               var me = members.firstWhere((m) => m['uid'] == currentUser!.uid, orElse: () => null);
                               if (me != null) {
                                 myPlayerName = me['name'] ?? "Player";
                                 myRole = me['role'] ?? 0;
                               }
                             }
                           }

                          Navigator.push(context, MaterialPageRoute(builder: (_) => TournamentGroupChatScreen(
                            tourneyId: tourneyId,
                            groupId: groups[index].id,
                            groupName: "${group['name']} - $myPlayerName", 
                            isAdmin: isAdmin,
                            myTeamCode: myTeamCode,
                            myRole: myRole, 
                          )));
                        },
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}