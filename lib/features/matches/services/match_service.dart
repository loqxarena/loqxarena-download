import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart'; 
import '../models/match_model.dart';
import '../models/team_model.dart';

class MatchService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final CollectionReference _matchesRef = FirebaseFirestore.instance.collection('matches');

  Stream<List<MatchModel>> getMatches() {
    return _matchesRef
        .orderBy('createdAt', descending: true) 
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => MatchModel.fromFirestore(doc)).toList());
  }

  Stream<List<MatchModel>> getMyMatches() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    
    return _matchesRef.orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => MatchModel.fromFirestore(doc)).where((match) {
        return match.teams.any((team) => team.createdBy == user.uid);
      }).toList();
    });
  }

  Future<String> uploadMatchImage(File file, String folder) async {
    String fileName = '${folder}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    Reference ref = _storage.ref().child(folder).child(fileName);
    UploadTask uploadTask = ref.putFile(file);
    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<String> uploadMatchBanner(File imageFile) async {
    return await uploadMatchImage(imageFile, 'matches');
  }

  Future<void> createMatch({
    required String title,
    required String map,
    required String matchMode,
    required String matchType,
    required int entryFee,
    required int prizePool,
    required String prizeBreakdown,
    required String rules,
    required int totalSlots, 
    required DateTime scheduledAt,
    String? bannerImage,
    String? paymentQrUrl, // NEW: Admin uploads QR
  }) async {
    final docRef = _matchesRef.doc();
    await docRef.set({
      'id': docRef.id,
      'title': title,
      'map': map,
      'matchMode': matchMode,
      'matchType': matchType,
      'entryFee': entryFee,
      'prizePool': prizePool,
      'prizeBreakdown': prizeBreakdown,
      'rules': rules,
      'scheduledAt': scheduledAt,
      'thumbnailImage': bannerImage,
      'paymentQrUrl': paymentQrUrl, // NEW: Saved to DB
      'status': 'open',
      'totalSlots': totalSlots, 
      'teams': [],
      'createdAt': FieldValue.serverTimestamp(), 
      'roomId': '', 
      'roomPassword': '', 
    });
  }

  Future<void> updateMatch(String id, Map<String, dynamic> data) async {
    await _matchesRef.doc(id).update(data);
  }

  Future<void> updateMatchRoomDetails(String matchId, String roomId, String password) async {
    await _matchesRef.doc(matchId).update({
      'roomId': roomId,
      'roomPassword': password,
    });
  }

  Future<void> deleteMatch(String matchId) async {
    await _matchesRef.doc(matchId).delete();
  }

  Future<void> joinMatch(String matchId, TeamModel team) async {
    final docRef = _matchesRef.doc(matchId);
    
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw "Match not found!";
      
      MatchModel match = MatchModel.fromFirestore(snapshot);
      
      if (match.status != 'open') throw "Match is no longer open.";
      if (match.slotsLeft <= 0) throw "Match Full!";
      
      final data = snapshot.data() as Map<String, dynamic>?;
      List<dynamic> currentTeams = data?['teams'] ?? [];

      if (currentTeams.any((t) => t['createdBy'] == team.createdBy)) {
          throw "You are already registered for this match.";
      }
      
      currentTeams.add(team.toMap());
      
      transaction.update(docRef, {
        'teams': currentTeams,
      });
    });
  }

  Future<void> approveTeamPayment(String matchId, String teamId) async {
    try {
      final docRef = _matchesRef.doc(matchId);
      
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception("Match not found.");

        final data = snapshot.data() as Map<String, dynamic>?;
        List<dynamic> currentTeams = data?['teams'] ?? [];
        
        List<dynamic> updatedTeams = currentTeams.map((t) {
          if (t['id'] == teamId) {
            var updatedTeam = Map<String, dynamic>.from(t as Map);
            updatedTeam['registrationStatus'] = 'approved';
            return updatedTeam;
          }
          return t;
        }).toList();

        transaction.update(docRef, {'teams': updatedTeams});
      });
    } catch (e) {
      throw Exception("Approval Failed: $e");
    }
  }

  Future<void> addTeam(String matchId, TeamModel team) async {
     final docRef = _matchesRef.doc(matchId);
     await docRef.update({
       'teams': FieldValue.arrayUnion([team.toMap()]),
     });
  }

  Future<void> updateTeamStatus(String matchId, String teamId, String status) async {
    final docRef = _matchesRef.doc(matchId);
    final snapshot = await docRef.get();
    
    if (!snapshot.exists) return;
    final data = snapshot.data() as Map<String, dynamic>;
    
    List<dynamic> teams = data['teams'] ?? [];
    List<dynamic> updatedTeams = teams.map((t) {
      if (t['id'] == teamId) {
        t['registrationStatus'] = status;
      }
      return t;
    }).toList();

    await docRef.update({'teams': updatedTeams});
  }
  
  Future<void> distributeMatchPrize(String matchId, String userId, int amount, String rank) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('distributePrizes');
      await callable.call({
        'tournamentId': matchId, 
        'winners': [
          {'userId': userId, 'amount': amount, 'rank': rank}
        ],
      });
    } catch (e) {
      throw "Payout Failed: $e";
    }
  }
}