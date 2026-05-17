import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart'; // Added for Admin functions
import '../models/tournament_model.dart';
import '../models/team_model.dart'; 

class TournamentService {
  final CollectionReference _tourneyRef = FirebaseFirestore.instance.collection('tournaments');
  final Reference _storageRef = FirebaseStorage.instance.ref();

  // --- GETTERS ---
  Stream<List<TournamentModel>> getTournaments() {
    return _tourneyRef.orderBy('createdAt', descending: true).snapshots().map((s) => s.docs.map((d) => TournamentModel.fromFirestore(d)).toList());
  }

  // --- CREATE ---
  Future<void> createTournament({
    required String title, required String footerName, required String codePrefix, 
    required int totalSlots, required int groupSize, required int entryFee,
    required String rules, File? bannerFile,
    required int prizePool, required int rank1Prize, required int rank2Prize, required int rank3Prize,
  }) async {
    String bannerUrl = '';
    if (bannerFile != null) {
      final ref = _storageRef.child('tournament_banners/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(bannerFile);
      bannerUrl = await ref.getDownloadURL();
    }

    await _tourneyRef.add({
      'title': title, 'footerName': footerName, 'codePrefix': codePrefix.toUpperCase(),
      'totalSlots': totalSlots, 'groupSize': groupSize, 'entryFee': entryFee,
      'status': 'registration', 'bannerUrl': bannerUrl, 'formatRules': rules, 
      'createdAt': FieldValue.serverTimestamp(),
      'teams': [],
      'prizePool': prizePool, 'rank1Prize': rank1Prize, 'rank2Prize': rank2Prize, 'rank3Prize': rank3Prize,
    });
  }

  // --- UPDATE ---
  Future<void> updateTournament(String id, Map<String, dynamic> data) async {
    await _tourneyRef.doc(id).update(data);
  }

  // --- DELETE ---
  Future<void> deleteTournament(String id) async {
    await _tourneyRef.doc(id).delete();
  }

  // --- GROUP ROOMS ---
  Future<void> updateGroupRoomDetails(String tourneyId, int groupIndex, String roomId, String pass) async {
    await _tourneyRef.doc(tourneyId).collection('groups').doc(groupIndex.toString()).set({
      'roomId': roomId, 'roomPass': pass
    }, SetOptions(merge: true));
  }

  Stream<Map<String, String>> getGroupRoomDetails(String tourneyId, int groupIndex) {
    return _tourneyRef.doc(tourneyId).collection('groups').doc(groupIndex.toString()).snapshots().map((doc) {
      if (!doc.exists) return {'roomId': '', 'roomPass': ''};
      final data = doc.data() as Map<String, dynamic>;
      return {'roomId': data['roomId'] ?? '', 'roomPass': data['roomPass'] ?? ''};
    });
  }

  // --- TEAM REGISTRATION ---
  Future<String> registerTeam(String tourneyId, String teamName, String phone, String prefix, int maxSlots, int groupSize) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw "User not logged in";
    
    // Check Full
    final allTeams = await _tourneyRef.doc(tourneyId).collection('teams').count().get();
    if ((allTeams.count ?? 0) >= maxSlots) throw "Tournament Full!";
    
    // Check Existing
    final existing = await _tourneyRef.doc(tourneyId).collection('teams').where('playerIds', arrayContains: user.uid).get();
    if (existing.docs.isNotEmpty) throw "Already in a team!";
    
    // Calculate Group/Slot
    int totalCount = allTeams.count ?? 0;
    int groupIndex = (totalCount / groupSize).floor(); 
    int slotInGroup = (totalCount % groupSize) + 1; 
    
    // Generate Code
    String uniqueCode = "$prefix${_generateRandomString(4)}".toUpperCase();
    
    final newTeam = TournamentTeamModel(
      id: user.uid, name: teamName, code: uniqueCode, captainId: user.uid, captainPhone: phone,
      playerIds: [user.uid], playerNames: [user.displayName ?? 'Captain'],
      assignedGroupIndex: groupIndex, slotNumber: slotInGroup,
    );
    
    // Save Team
    await _tourneyRef.doc(tourneyId).collection('teams').doc(user.uid).set(newTeam.toMap());
    
    return uniqueCode;
  }

  // --- JOIN TEAM ---
  Future<void> joinTeam(String tourneyId, String teamCode) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw "User not logged in";
    
    final query = await _tourneyRef.doc(tourneyId).collection('teams').where('code', isEqualTo: teamCode.toUpperCase()).limit(1).get();
    if (query.docs.isEmpty) throw "Invalid Team Code";
    
    final doc = query.docs.first;
    final team = TournamentTeamModel.fromMap(doc.data());
    
    if (team.playerIds.contains(user.uid)) throw "Already in this team.";
    if (team.playerIds.length >= 4) throw "Team Full.";
    
    await doc.reference.update({
      'playerIds': FieldValue.arrayUnion([user.uid]),
      'playerNames': FieldValue.arrayUnion([user.displayName ?? 'Player']),
    });
  }

  // --- REMOVE TEAMMATE ---
  Future<void> removeTeammate(String tourneyId, String teamId, String memberId, String memberName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final docRef = _tourneyRef.doc(tourneyId).collection('teams').doc(teamId);
    
    await docRef.update({
      'playerIds': FieldValue.arrayRemove([memberId]),
      'playerNames': FieldValue.arrayRemove([memberName]),
    });
  }
  
  // --- ADMIN: DISTRIBUTE PRIZES (SECURE) ---
  Future<void> distributePrizes({required String tourneyId, required List<Map<String, dynamic>> winners}) async {
    try {
      // Calls the 'distributePrizes' Cloud Function
      await FirebaseFunctions.instance.httpsCallable('distributePrizes').call({
        'tournamentId': tourneyId,
        'winners': winners,
      });
    } catch (e) {
      throw "Distribution Failed: ${e.toString()}";
    }
  }

  // --- UTILS ---
  Stream<TournamentTeamModel?> getMyTeam(String tourneyId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    return _tourneyRef.doc(tourneyId).collection('teams').where('playerIds', arrayContains: user.uid).snapshots().map((s) => s.docs.isEmpty ? null : TournamentTeamModel.fromMap(s.docs.first.data()));
  }

  Future<void> deleteTeam(String tourneyId, String teamId) async {
    await _tourneyRef.doc(tourneyId).collection('teams').doc(teamId).delete();
  }
  
  Stream<List<TournamentTeamModel>> getTeamsByGroup(String tourneyId, int groupIndex) {
    return _tourneyRef.doc(tourneyId).collection('teams').where('assignedGroupIndex', isEqualTo: groupIndex).snapshots().map((s) => s.docs.map((d) => TournamentTeamModel.fromMap(d.data())).toList());
  }

  String _generateRandomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }
}