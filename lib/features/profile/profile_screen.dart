import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/premium_widgets.dart';
import '../../../core/widgets/app_text_field.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../chat/match_chat_screen.dart';
import '../matches/screens/my_matches_screen.dart'; 

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('settings').doc('app_config').snapshots(),
      builder: (context, snapshot) {
        bool showLeaderboard = true;

        if (snapshot.hasData && snapshot.data!.exists) {
          try {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            showLeaderboard = data['showLeaderboard'] ?? true;
          } catch (e) {
            debugPrint("Config Error: $e");
          }
        }

        int tabCount = showLeaderboard ? 3 : 2;

        return DefaultTabController(
          length: tabCount,
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text("COMMAND CENTRE", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
              backgroundColor: Colors.black.withOpacity(0.5),
              elevation: 0,
              centerTitle: true,
              bottom: TabBar(
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelColor: AppColors.primary,
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
                tabs: [
                  const Tab(text: "PROFILE"),
                  const Tab(text: "MY MATCHES"),
                  if (showLeaderboard) const Tab(text: "TOP SQUADS"),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                const _ProfileTab(),
                const ClipRect(child: MyMatchesScreen()), 
                if (showLeaderboard) const _LeaderboardTab(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  String _savedPlayerName = "PLAYER";
  String _savedGameUid = "";
  String _savedPlayerRole = "Rusher"; 

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _savedPlayerName = prefs.getString('pref_player_name') ?? "PLAYER";
        _savedGameUid = prefs.getString('pref_game_uid') ?? "";
        _savedPlayerRole = prefs.getString('pref_player_role') ?? "Rusher";
      });
    }
  }

  void _editProfile(BuildContext context, Map<String, dynamic> currentData) {
    final teamCtrl = TextEditingController(text: currentData['teamName'] ?? '');
    final phoneCtrl = TextEditingController(text: currentData['whatsappNumber'] ?? '');
    
    // Day 2 Identity Additions
    final ignCtrl = TextEditingController(text: currentData['ign'] ?? _savedPlayerName);
    final uidCtrl = TextEditingController(text: currentData['gameUid'] ?? _savedGameUid);
    String selectedRole = currentData['playerRole'] ?? _savedPlayerRole;
    
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("ESPORTS IDENTITY", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.5)),
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Expanded(child: AppTextField(label: "Free Fire IGN", controller: ignCtrl, hint: "In-Game Name")),
                    const SizedBox(width: 12),
                    Expanded(child: AppTextField(label: "Game UID", controller: uidCtrl, hint: "e.g. 12345678", keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 16),
                
                const Text("Primary Role", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedRole,
                      dropdownColor: AppColors.surface,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                      items: ['IGL', 'Sniper', 'Rusher', 'Flanker', 'Support'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (v) => setState(() => selectedRole = v!),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                AppTextField(label: "Squad Name", controller: teamCtrl, hint: "Will be used for Leaderboards"),
                const SizedBox(height: 16),
                AppTextField(label: "WhatsApp Number", controller: phoneCtrl, keyboardType: TextInputType.phone),
                const SizedBox(height: 32),
                
                PremiumButton(
                  text: "SAVE RECORD",
                  isLoading: isSaving,
                  onPressed: () async {
                    setState(() => isSaving = true);
                    final uid = FirebaseAuth.instance.currentUser!.uid;
                    
                    // Save locally for quick access
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('pref_player_name', ignCtrl.text.trim());
                    await prefs.setString('pref_game_uid', uidCtrl.text.trim());
                    await prefs.setString('pref_player_role', selectedRole);

                    // Save to global user doc
                    await FirebaseFirestore.instance.collection('users').doc(uid).set({
                      'teamName': teamCtrl.text.trim(),
                      'whatsappNumber': phoneCtrl.text.trim(),
                      'ign': ignCtrl.text.trim(),
                      'gameUid': uidCtrl.text.trim(),
                      'playerRole': selectedRole,
                    }, SetOptions(merge: true));
                    
                    // Sync the player's updated name/role across any squads they are currently in
                    var squadSnap = await FirebaseFirestore.instance.collection('squads').where('memberIds', arrayContains: uid).get();
                    for (var doc in squadSnap.docs) {
                      List members = List.from(doc['members'] ?? []);
                      int mIndex = members.indexWhere((m) => m['uid'] == uid);
                      if (mIndex != -1) {
                        // Preserve the numeric positional role if needed for Grid, but update name and meta-role
                        members[mIndex]['name'] = ignCtrl.text.trim();
                        members[mIndex]['metaRole'] = selectedRole; 
                        await doc.reference.update({'members': members});
                      }
                    }

                    this.setState(() {
                      _savedPlayerName = ignCtrl.text.trim();
                      _savedGameUid = uidCtrl.text.trim();
                      _savedPlayerRole = selectedRole;
                    });

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("Profile Updated!"), backgroundColor: AppColors.success));
                    }
                  }
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      )
    );
  }

  void _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Log Out?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to log out of your account?", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("LOG OUT", style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService().logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
      }
    }
  }

  void _openSupportChat(BuildContext context, String teamId, String teamName) {
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => MatchChatScreen(
        matchId: 'global_support', 
        teamId: teamId, 
        teamName: teamName, 
        isAdmin: false,
        matchStatus: 'ongoing', 
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("Not logged in"));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('squads').where('memberIds', arrayContains: user.uid).limit(1).snapshots(),
      builder: (context, squadSnapshot) {
        if (squadSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        
        bool isInSquad = squadSnapshot.hasData && squadSnapshot.data!.docs.isNotEmpty;
        Map<String, dynamic>? squadData = isInSquad ? squadSnapshot.data!.docs.first.data() as Map<String, dynamic> : null;
        
        String supportChatId = isInSquad ? squadData!['teamCode'] : user.uid;
        String displayPlayerName = _savedPlayerName;
        String displayTeamName = "NO SQUAD";

        if (isInSquad) {
          displayTeamName = squadData!['teamName'];
          List members = squadData['members'] ?? [];
          var me = members.firstWhere((m) => m['uid'] == user.uid, orElse: () => null);
          if (me != null) displayPlayerName = me['name'];
        }

        String supportTeamName = isInSquad ? "$displayTeamName - $displayPlayerName" : displayPlayerName;
        List<dynamic> memberIdsToFetch = isInSquad ? List.from(squadData!['memberIds']) : [user.uid];

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, whereIn: memberIdsToFetch).snapshots(),
          builder: (context, usersSnapshot) {
            
            int totalPlayed = 0;
            int totalWins = 0;
            int totalKills = 0;

            if (usersSnapshot.hasData) {
              for (var doc in usersSnapshot.data!.docs) {
                var d = doc.data() as Map<String, dynamic>;
                totalPlayed += (d['matchesPlayed'] as num?)?.toInt() ?? 0;
                totalWins += (d['matchesWon'] as num?)?.toInt() ?? 0;
                totalKills += (d['totalKills'] as num?)?.toInt() ?? 0;
              }
              
              if (!isInSquad && usersSnapshot.data!.docs.isNotEmpty) {
                var myData = usersSnapshot.data!.docs.firstWhere((doc) => doc.id == user.uid).data() as Map<String, dynamic>;
                if ((myData['teamName'] ?? '').isNotEmpty) {
                  displayTeamName = myData['teamName'];
                }
              }
            }

            int winRate = totalPlayed > 0 ? ((totalWins / totalPlayed) * 100).round() : 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 120),
              child: Column(
                children: [
                  // --- NEW ESPORTS IDENTITY CARD ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.surface, Colors.black87], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 5))],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: AppColors.primary.withOpacity(0.2),
                          backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                          child: user.photoURL == null ? const Icon(Icons.person, color: AppColors.primary, size: 35) : null,
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(displayPlayerName.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1)),
                              const SizedBox(height: 4),
                              Text("SQUAD: ${displayTeamName.toUpperCase()}", style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              const SizedBox(height: 4),
                              // Replaced email with Game UID
                              Row(
                                children: [
                                  Text("UID: ${_savedGameUid.isEmpty ? 'NOT SET' : _savedGameUid}", style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                                  if (_savedGameUid.isNotEmpty)
                                    GestureDetector(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: _savedGameUid));
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("UID Copied"), backgroundColor: Colors.black, behavior: SnackBarBehavior.floating, margin: EdgeInsets.only(bottom: 80, left: 20, right: 20)));
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.only(left: 6),
                                        child: Icon(Icons.copy, color: Colors.grey, size: 12),
                                      ),
                                    )
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 28),
                          onPressed: () {
                            if(usersSnapshot.hasData && usersSnapshot.data!.docs.isNotEmpty){
                               var myData = usersSnapshot.data!.docs.firstWhere((doc) => doc.id == user.uid).data() as Map<String, dynamic>;
                               _editProfile(context, myData);
                            }
                          }
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  Align(
                    alignment: Alignment.centerLeft, 
                    child: Text(isInSquad ? "SQUAD COMBAT RECORD" : "MY COMBAT RECORD", style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 11))
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildStatCard("MATCHES", "$totalPlayed", Icons.sports_esports, Colors.blue)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatCard("WINS", "$totalWins", Icons.emoji_events, const Color(0xFFFFD700))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildStatCard("TOTAL KILLS", "$totalKills", Icons.my_location, Colors.redAccent)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatCard("WIN RATE", "$winRate%", Icons.pie_chart, Colors.purpleAccent)),
                    ],
                  ),
                  const SizedBox(height: 40),

                  const Align(alignment: Alignment.centerLeft, child: Text("MY SQUAD", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 11))),
                  const SizedBox(height: 16),
                  _SquadManagerSection(user: user, squadData: squadData),
                  const SizedBox(height: 40),

                  const Align(alignment: Alignment.centerLeft, child: Text("SYSTEM", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 11))),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.headset_mic, color: Colors.blueAccent)),
                      title: const Text("LOQX SUPPORT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      subtitle: Text(isInSquad ? "Unified Squad Chat with Admin" : "Raise tickets & get help", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
                      onTap: () => _openSupportChat(context, supportChatId, supportTeamName),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _confirmLogout(context),
                    icon: const Icon(Icons.logout, color: AppColors.error),
                    label: const Text("SIGN OUT", style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      minimumSize: const Size(double.infinity, 55),
                      side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: AppColors.error.withOpacity(0.05),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        ],
      ),
    );
  }
}

class _SquadManagerSection extends StatefulWidget {
  final User user;
  final Map<String, dynamic>? squadData; 

  const _SquadManagerSection({required this.user, this.squadData});

  @override
  State<_SquadManagerSection> createState() => _SquadManagerSectionState();
}

class _SquadManagerSectionState extends State<_SquadManagerSection> {
  String _mode = 'none'; 
  bool _isLoading = false;

  final _teamNameCtrl = TextEditingController();
  final _iglNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  
  final _teamCodeCtrl = TextEditingController();
  final _joinPlayerNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPrefillData();
  }

  Future<void> _loadPrefillData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _teamNameCtrl.text = prefs.getString('pref_team_name') ?? "";
      _phoneCtrl.text = prefs.getString('pref_phone') ?? "";
      _iglNameCtrl.text = prefs.getString('pref_player_name') ?? "";
      _joinPlayerNameCtrl.text = prefs.getString('pref_player_name') ?? "";
    });
  }

  Future<void> _savePrefillData(bool isCreate) async {
    final prefs = await SharedPreferences.getInstance();
    if (isCreate) {
      await prefs.setString('pref_team_name', _teamNameCtrl.text.trim());
      await prefs.setString('pref_phone', _phoneCtrl.text.trim());
      await prefs.setString('pref_player_name', _iglNameCtrl.text.trim());
    } else {
      await prefs.setString('pref_player_name', _joinPlayerNameCtrl.text.trim());
    }
  }

  Future<void> _createSquad() async {
    if (_teamNameCtrl.text.isEmpty || _iglNameCtrl.text.isEmpty || _phoneCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fill all fields!"), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _savePrefillData(true);
      String code = "SQ-${Random().nextInt(99999).toString().padLeft(5, '0')}";
      
      final prefs = await SharedPreferences.getInstance();
      String metaRole = prefs.getString('pref_player_role') ?? 'IGL';

      await FirebaseFirestore.instance.collection('squads').doc(code).set({
        'teamName': _teamNameCtrl.text.trim(),
        'teamCode': code,
        'captainPhone': _phoneCtrl.text.trim(),
        'memberIds': [widget.user.uid],
        'members': [
          {'uid': widget.user.uid, 'name': _iglNameCtrl.text.trim(), 'role': 1, 'metaRole': metaRole} 
        ],
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).set({
        'teamName': _teamNameCtrl.text.trim(),
        'whatsappNumber': _phoneCtrl.text.trim(),
      }, SetOptions(merge: true));

      setState(() => _mode = 'none');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Squad Created!"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinSquad() async {
    if (_teamCodeCtrl.text.isEmpty || _joinPlayerNameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fill all fields!"), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _savePrefillData(false);
      String code = _teamCodeCtrl.text.trim().toUpperCase();
      DocumentReference squadRef = FirebaseFirestore.instance.collection('squads').doc(code);
      
      String joinedTeamName = "";

      await FirebaseFirestore.instance.runTransaction((tx) async {
        DocumentSnapshot snap = await tx.get(squadRef);
        if (!snap.exists) throw "Invalid Squad Code!";
        
        Map<String, dynamic> data = snap.data() as Map<String, dynamic>;
        joinedTeamName = data['teamName'] ?? "SQUAD";
        List members = List.from(data['members'] ?? []);
        List memberIds = List.from(data['memberIds'] ?? []);
        
        if (members.length >= 4) throw "This squad is already full!";
        if (memberIds.contains(widget.user.uid)) throw "You are already in this squad!";

        List<int> takenRoles = members.map<int>((m) => m['role'] as int).toList();
        int nextRole = [2, 3, 4].firstWhere((r) => !takenRoles.contains(r));

        final prefs = await SharedPreferences.getInstance();
        String metaRole = prefs.getString('pref_player_role') ?? 'Rusher';

        members.add({'uid': widget.user.uid, 'name': _joinPlayerNameCtrl.text.trim(), 'role': nextRole, 'metaRole': metaRole});
        memberIds.add(widget.user.uid);

        tx.update(squadRef, {'members': members, 'memberIds': memberIds});
      });

      await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).set({
        'teamName': joinedTeamName,
      }, SetOptions(merge: true));

      setState(() => _mode = 'none');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Joined Squad Successfully!"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmAndLeaveSquad(String code, List currentMembers, List currentMemberIds) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Leave Squad?", style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to leave this squad? You will need the exact team code to rejoin.", style: TextStyle(color: Colors.grey, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          PremiumButton(text: "YES, LEAVE SQUAD", onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirm == true) {
      try {
        currentMembers.removeWhere((m) => m['uid'] == widget.user.uid);
        currentMemberIds.remove(widget.user.uid);
        
        if (currentMemberIds.isEmpty) {
          await FirebaseFirestore.instance.collection('squads').doc(code).delete();
        } else {
          await FirebaseFirestore.instance.collection('squads').doc(code).update({
            'members': currentMembers,
            'memberIds': currentMemberIds,
          });
        }
        
        await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).set({'teamName': ''}, SetOptions(merge: true));
        
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Left Squad.")));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.squadData != null) {
      List members = widget.squadData!['members'] ?? [];
      String code = widget.squadData!['teamCode'] ?? "";

      return Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.squadData!['teamName']?.toString().toUpperCase() ?? "SQUAD", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text("IGL Contact: ${widget.squadData!['captainPhone']}", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: [
                        const Text("TEAM CODE", style: TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.bold)),
                        SelectableText(code, style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
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
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: OutlinedButton(
                onPressed: () => _confirmAndLeaveSquad(code, members, widget.squadData!['memberIds']),
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 45), foregroundColor: AppColors.error, side: BorderSide(color: AppColors.error.withOpacity(0.5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("LEAVE SQUAD", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            )
          ],
        ),
      );
    }

    if (_mode == 'create') {
      return PremiumCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("CREATE NEW SQUAD", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
            const SizedBox(height: 20),
            AppTextField(label: "Squad Name", controller: _teamNameCtrl),
            const SizedBox(height: 12),
            AppTextField(label: "Your Name (IGL)", controller: _iglNameCtrl),
            const SizedBox(height: 12),
            AppTextField(label: "WhatsApp Number", controller: _phoneCtrl, keyboardType: TextInputType.phone),
            const SizedBox(height: 24),
            PremiumButton(text: "CONFIRM & CREATE", isLoading: _isLoading, onPressed: _createSquad),
            const SizedBox(height: 12),
            Center(child: TextButton(onPressed: () => setState(() => _mode = 'none'), child: const Text("Cancel", style: TextStyle(color: Colors.grey)))),
          ],
        ),
      );
    }

    if (_mode == 'join') {
      return PremiumCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("JOIN EXISTING SQUAD", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
            const SizedBox(height: 20),
            AppTextField(label: "Enter Squad Code", controller: _teamCodeCtrl, hint: "e.g. SQ-12345"),
            const SizedBox(height: 12),
            AppTextField(label: "Your Name in Game", controller: _joinPlayerNameCtrl),
            const SizedBox(height: 24),
            PremiumButton(text: "CONFIRM & JOIN", gradient: AppColors.goldButtonGradient, isLoading: _isLoading, onPressed: _joinSquad),
            const SizedBox(height: 12),
            Center(child: TextButton(onPressed: () => setState(() => _mode = 'none'), child: const Text("Cancel", style: TextStyle(color: Colors.grey)))),
          ],
        ),
      );
    }

    return Column(
      children: [
        PremiumButton(text: "CREATE NEW SQUAD", icon: Icons.add_circle_outline, onPressed: () => setState(() => _mode = 'create')),
        const SizedBox(height: 12),
        PremiumButton(text: "JOIN VIA CODE", icon: Icons.group_add, gradient: AppColors.goldButtonGradient, onPressed: () => setState(() => _mode = 'join')),
      ],
    );
  }

  // --- DAY 2 META ROLE DISPLAY FIX ---
  Widget _buildPlayerSlot(int role, List members) {
    var member = members.firstWhere((m) => m['role'] == role, orElse: () => null);
    bool isEmpty = member == null;
    bool isIGL = role == 1;
    String displayRole = isEmpty ? "PLAYER $role" : (member['metaRole'] ?? (isIGL ? "IGL" : "PLAYER $role")).toString().toUpperCase();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12), border: Border.all(color: !isEmpty ? AppColors.primary.withOpacity(0.3) : Colors.transparent)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(displayRole, style: TextStyle(color: !isEmpty ? AppColors.primary : Colors.grey, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
              if (isIGL && !isEmpty) const Icon(Icons.star, color: AppColors.primary, size: 10),
            ],
          ),
          const SizedBox(height: 4),
          Text(isEmpty ? "Open Slot" : member['name'], style: TextStyle(color: isEmpty ? Colors.white24 : Colors.white, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _LeaderboardTab extends StatelessWidget {
  const _LeaderboardTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.15), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            border: const Border(bottom: BorderSide(color: Colors.white10)),
          ),
          child: const Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.military_tech, color: Color(0xFFFFD700), size: 32),
                  SizedBox(width: 12),
                  Text("GLOBAL RANKINGS", style: TextStyle(color: Color(0xFFFFD700), fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2)),
                ],
              ),
              SizedBox(height: 8),
              Text("Rankings based on total Arena Match Wins.", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 0.5)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: Colors.black26,
          child: const Row(
            children: [
              SizedBox(width: 40, child: Text("RANK", style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1))),
              Expanded(child: Text("SQUAD", style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1))),
              SizedBox(width: 60, child: Center(child: Text("PLAYED", style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)))),
              SizedBox(width: 60, child: Center(child: Text("WINS", style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)))),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').orderBy('matchesWon', descending: true).limit(50).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No data available.", style: TextStyle(color: Colors.grey)));

              var rankedUsers = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                return (data['matchesWon'] ?? 0) > 0;
              }).toList();

              if (rankedUsers.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text("No squads have claimed victory yet.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5))));

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 120),
                itemCount: rankedUsers.length,
                itemBuilder: (context, index) {
                  var data = rankedUsers[index].data() as Map<String, dynamic>;
                  int rank = index + 1;
                  String teamName = data['teamName'] ?? '';
                  if (teamName.isEmpty) teamName = "Player ${data['email']?.split('@')[0] ?? 'Unknown'}";
                  
                  int played = data['matchesPlayed'] ?? 0;
                  int wins = data['matchesWon'] ?? 0;

                  return Container(
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        SizedBox(width: 40, child: _buildRankBadge(rank)),
                        Expanded(child: Text(teamName.toUpperCase(), style: TextStyle(color: rank <= 3 ? Colors.white : Colors.white70, fontWeight: rank <= 3 ? FontWeight.w900 : FontWeight.bold, fontSize: 14, letterSpacing: 0.5), overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 60, child: Center(child: Text("$played", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))),
                        SizedBox(width: 60, child: Center(child: Text("$wins", style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w900, fontSize: 16)))),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRankBadge(int rank) {
    if (rank == 1) return const Text("🥇", style: TextStyle(fontSize: 22));
    if (rank == 2) return const Text("🥈", style: TextStyle(fontSize: 22));
    if (rank == 3) return const Text("🥉", style: TextStyle(fontSize: 22));
    return Text("#$rank", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14));
  }
}