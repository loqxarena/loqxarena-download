import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/premium_widgets.dart'; 
import '../../../core/widgets/app_text_field.dart';
import '../models/match_model.dart'; 
import '../../chat/match_chat_screen.dart';

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

class PlayerMatchDetailsScreen extends StatelessWidget {
  final MatchModel match;
  const PlayerMatchDetailsScreen({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('matches').doc(match.id).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: CircularProgressIndicator());
        
        List<dynamic> rawTeams = snapshot.data!.get('teams') ?? [];

        bool isRegistered = false;
        String myTeamCode = "";
        Map<String, dynamic>? myTeamData;
        String myPlayerName = "Player";
        
        if (user != null) {
          for (var t in rawTeams) {
            List members = t['members'] ?? [];
            var me = members.firstWhere((m) => m['uid'] == user.uid, orElse: () => null);
            if (t['createdBy'] == user.uid || me != null) {
              isRegistered = true;
              myTeamCode = t['teamCode'] ?? "";
              myTeamData = t as Map<String, dynamic>;
              if (me != null) myPlayerName = me['name'] ?? "Player";
              break;
            }
          }
        }

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: Colors.black.withOpacity(0.5),
              elevation: 0,
              title: Text(match.title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
              iconTheme: const IconThemeData(color: Colors.white),
              bottom: const TabBar(
                isScrollable: true,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelColor: AppColors.primary,
                unselectedLabelColor: Colors.grey,
                labelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
                tabs: [Tab(text: "INFO"), Tab(text: "ROOM & CHAT"), Tab(text: "TEAMS"), Tab(text: "STANDINGS")],
              ),
            ),
            body: TabBarView(
              children: [
                _InfoTab(match: match, isRegistered: isRegistered, teamCode: myTeamCode, teamData: myTeamData),
                isRegistered ? _RoomChatTab(match: match, playerName: myPlayerName, teamData: myTeamData) : _buildNotRegisteredView(),
                _TeamsTab(match: match, rawTeams: rawTeams),
                _StandingsTab(match: match, rawTeams: rawTeams),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotRegisteredView() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade800), const SizedBox(height: 16), const Text("Join squad to view Room & Chat", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))]));
  }
}

class _InfoTab extends StatelessWidget {
  final MatchModel match;
  final bool isRegistered;
  final String teamCode;
  final Map<String, dynamic>? teamData;

  const _InfoTab({required this.match, required this.isRegistered, required this.teamCode, this.teamData});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    
    // DYNAMIC ASSET FALLBACK
    String banner = match.thumbnailImage ?? '';
    Widget bannerWidget;
    if (banner.startsWith('http')) {
      bannerWidget = CachedNetworkImage(imageUrl: banner, height: 180, width: double.infinity, fit: BoxFit.cover);
    } else {
      if (banner.isEmpty) banner = match.matchType == 'CS' ? 'assets/CS.jpeg' : 'assets/BR.jpg';
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
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(20), child: bannerWidget),
          const SizedBox(height: 24),

          PremiumCard(
            glowColor: Colors.black, 
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildGridItem(Icons.map, "Map", match.map),
                    Container(width: 1, height: 40, color: Colors.white10),
                    _buildGridItem(Icons.groups, "Mode", "${match.matchType} - ${match.matchMode}"),
                  ],
                ),
                const Divider(color: Colors.white10, height: 30),
                Row(
                  children: [
                    _buildGridItem(Icons.calendar_today, "Time", DateFormat('MMM d, h:mm a').format(match.scheduledAt)),
                    Container(width: 1, height: 40, color: Colors.white10),
                    _buildGridItem(Icons.monetization_on, "Entry", "FREE", isHighlight: true),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
          if (!isRegistered && match.status == 'open') ...[
             const Text("MATCH REGISTRATION", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12)),
             const SizedBox(height: 12),
             _ArenaRegistrationEmbedded(match: match, user: user),
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
                           Text(teamData!['name']?.toUpperCase() ?? "MY SQUAD", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
                           const SizedBox(height: 4),
                           Text("IGL Contact: ${teamData!['captainPhone']}", style: const TextStyle(color: Colors.grey, fontSize: 10)),
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
                   _buildSquadGrid(teamData!['members'] ?? [], true),
                   const SizedBox(height: 20),
                   PremiumButton(
                     text: "VIEW ROOM DETAILS",
                     icon: Icons.meeting_room,
                     gradient: AppColors.goldButtonGradient, 
                     onPressed: () {
                        DefaultTabController.of(context).animateTo(1);
                     },
                   )
                 ],
               ),
             ),
          ] else ...[
             const Center(child: Text("REGISTRATION CLOSED", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, letterSpacing: 1))),
          ],
          
          const SizedBox(height: 30),
          const Text("RULES & REGULATIONS", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
            child: Text(match.rules, style: const TextStyle(color: Colors.grey, height: 1.6, fontSize: 14)),
          ),
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

class _ArenaRegistrationEmbedded extends StatefulWidget {
  final MatchModel match;
  final User user;
  const _ArenaRegistrationEmbedded({required this.match, required this.user});

  @override
  State<_ArenaRegistrationEmbedded> createState() => _ArenaRegistrationEmbeddedState();
}

class _ArenaRegistrationEmbeddedState extends State<_ArenaRegistrationEmbedded> {
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

  Future<void> _handleGlobalRegistration(Map<String, dynamic> squadData) async {
    setState(() => isLoading = true);
    try {
      final db = FirebaseFirestore.instance;
      Map<String, dynamic> newTeam = {
        'id': squadData['teamCode'],
        'name': squadData['teamName'],
        'captainPhone': squadData['captainPhone'] ?? '',
        'paymentScreenshotUrl': '',
        'createdBy': squadData['members'][0]['uid'],
        'registrationStatus': 'approved', 
        'kills': 0,
        'rank': 0,
        'placementPoints': 0,
        'teamCode': squadData['teamCode'],
        'members': squadData['members'],
      };

      await db.collection('matches').doc(widget.match.id).update({
        'teams': FieldValue.arrayUnion([newTeam])
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
      String code = "SQ-${Random().nextInt(99999).toString().padLeft(5, '0')}";
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
      _handleGlobalRegistration(squadData); 

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
      _handleGlobalRegistration(updatedSquadData!); 

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
                  text: "CONFIRM MATCH REGISTRATION",
                  isLoading: isLoading,
                  gradient: AppColors.greenButtonGradient,
                  onPressed: () => _handleGlobalRegistration(squadData),
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
              const Text("Create or join a global squad to enter this match.", style: TextStyle(color: Colors.grey, fontSize: 10)),
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
                AppTextField(label: "Enter Squad Code", controller: _teamCodeCtrl, hint: "e.g. SQ-12345"),
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

class _RoomChatTab extends StatelessWidget {
  final MatchModel match;
  final String playerName; 
  final Map<String, dynamic>? teamData;

  const _RoomChatTab({required this.match, required this.playerName, this.teamData});

  @override
  Widget build(BuildContext context) {
    String myTeamId = teamData != null ? teamData!['createdBy'] : ""; 
    String myTeamName = teamData != null ? teamData!['name'] : "SQUAD";

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          PremiumCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.meeting_room, size: 48, color: AppColors.primary),
                const SizedBox(height: 16),
                const Text("MATCH ROOM DETAILS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 24),
                
                if (match.roomId == null || match.roomId!.isEmpty)
                  const Text("Room details will be updated here 15 minutes before the match starts.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5))
                else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("ROOM ID:", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                      SelectableText(match.roomId!, style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("PASSWORD:", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                      SelectableText(match.roomPassword!, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    ],
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          Container(
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.forum, color: AppColors.secondary)),
              title: const Text("CONTACT ADMIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
              subtitle: const Text("Unified Squad Chat with Host", style: TextStyle(color: Colors.grey, fontSize: 11)),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => MatchChatScreen(
                    matchId: match.id,
                    teamId: myTeamId, 
                    teamName: "$myTeamName - $playerName", 
                    isAdmin: false,
                    matchStatus: match.status,
                  )
                ));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamsTab extends StatelessWidget {
  final MatchModel match;
  final List<dynamic> rawTeams;
  const _TeamsTab({required this.match, required this.rawTeams});

  @override
  Widget build(BuildContext context) {
    if (rawTeams.isEmpty) return const Center(child: Text("No squads registered yet.", style: TextStyle(color: Colors.grey)));

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 120),
      itemCount: rawTeams.length,
      itemBuilder: (context, index) {
        var teamMap = rawTeams[index] as Map<String, dynamic>;
        String teamName = teamMap['name'] ?? "SQUAD";
        List members = teamMap['members'] ?? [];
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
              title: Text(teamName.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
              subtitle: const Text("Status: APPROVED", style: TextStyle(color: Colors.green, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold)),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  child: _buildSquadGrid(members, false),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StandingsTab extends StatelessWidget {
  final MatchModel match;
  final List<dynamic> rawTeams;
  const _StandingsTab({required this.match, required this.rawTeams});

  @override
  Widget build(BuildContext context) {
    if (match.status != 'completed') {
      return const Center(child: Text("Standings will be updated after the match ends.", style: TextStyle(color: Colors.grey)));
    }

    var rankedTeams = List.from(rawTeams);
    rankedTeams.removeWhere((t) => (t['rank'] ?? 0) == 0); 
    rankedTeams.sort((a, b) => (a['rank'] ?? 0).compareTo((b['rank'] ?? 0)));

    if (rankedTeams.isEmpty) return const Center(child: Text("No standings available.", style: TextStyle(color: Colors.grey)));

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 120),
      itemCount: rankedTeams.length,
      itemBuilder: (context, index) {
        var teamMap = rankedTeams[index] as Map<String, dynamic>;
        String teamName = teamMap['name'] ?? "SQUAD";
        List members = teamMap['members'] ?? [];
        int rank = teamMap['rank'] ?? 0;
        int kills = teamMap['kills'] ?? 0;
        int pts = teamMap['placementPoints'] ?? 0;

        Color rankColor = Colors.white10;
        if (rank == 1) rankColor = const Color(0xFFFFD700).withOpacity(0.3); // Gold
        if (rank == 2) rankColor = const Color(0xFFC0C0C0).withOpacity(0.3); // Silver
        if (rank == 3) rankColor = const Color(0xFFCD7F32).withOpacity(0.3); // Bronze

        return Card(
          color: AppColors.surface,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: rankColor)),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: CircleAvatar(backgroundColor: rankColor, child: Text("#$rank", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
              title: Text(teamName.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
              subtitle: Text("Kills: $kills  |  Points: $pts", style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  child: _buildSquadGrid(members, false),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}