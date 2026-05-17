import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_constants.dart';
import 'team_model.dart';

class MatchModel {
  final String id;
  final String title;
  final String matchType;
  final String matchMode;
  final String map;
  final int entryFee;
  final int prizePool;
  final String prizeBreakdown; 
  final DateTime scheduledAt;
  final String status;
  final String? roomId;
  final String? roomPassword;
  final String? resultImage;
  final String? bannerImage;
  final String? thumbnailImage;
  final String rules;
  final int totalSlots; // Replaced maxTeams with totalSlots to match the new UI
  final String? paymentQrUrl;
  final List<TeamModel> teams;
  
  // Computed property for legacy compatibility
  String get roomPass => roomPassword ?? ''; 

  MatchModel({
    required this.id,
    required this.title,
    required this.matchType,
    required this.matchMode,
    required this.map,
    required this.entryFee,
    required this.prizePool,
    this.prizeBreakdown = '', 
    required this.scheduledAt,
    required this.status,
    this.roomId,
    this.roomPassword, 
    this.resultImage,
    this.bannerImage,
    this.thumbnailImage,
    this.rules = AppConstants.defaultBRRules,
    this.totalSlots = 12, // Default to 12
    this.paymentQrUrl,
    this.teams = const [],
  });

  // Calculate slots left based on approved/pending teams
  int get slotsLeft {
    return totalSlots - teams.where((t) => t.registrationStatus != 'rejected').length;
  }

  factory MatchModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    var teamList = (data['teams'] as List<dynamic>? ?? [])
        .map((t) => TeamModel.fromMap(t as Map<String, dynamic>))
        .toList();

    return MatchModel(
      id: doc.id,
      title: data['title'] ?? 'Untitled Match',
      matchType: data['matchType'] ?? 'BR',
      matchMode: data['matchMode'] ?? 'Squad',
      map: data['map'] ?? 'Bermuda',
      entryFee: (data['entryFee'] ?? 0).toInt(),
      prizePool: (data['prizePool'] ?? 0).toInt(),
      prizeBreakdown: data['prizeBreakdown'] ?? '', 
      scheduledAt: (data['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'open',
      
      // Read both keys for backward compatibility
      roomId: data['roomId'] ?? '',
      roomPassword: data['roomPassword'] ?? data['roomPass'] ?? '', 
      
      resultImage: data['resultImage'],
      bannerImage: data['bannerImage'],
      thumbnailImage: data['thumbnailImage'],
      rules: data['rules'] ?? AppConstants.defaultBRRules,
      
      // SAFELY PARSE: Try totalSlots first, fallback to maxTeams for old matches, then default to 12
      totalSlots: (data['totalSlots'] ?? data['maxTeams'] ?? 12).toInt(),
      
      paymentQrUrl: data['paymentQrUrl'],
      teams: teamList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'matchType': matchType,
      'matchMode': matchMode,
      'map': map,
      'entryFee': entryFee,
      'prizePool': prizePool,
      'prizeBreakdown': prizeBreakdown,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'status': status,
      'roomId': roomId,
      'roomPassword': roomPassword,
      'resultImage': resultImage,
      'bannerImage': bannerImage,
      'thumbnailImage': thumbnailImage,
      'rules': rules,
      'totalSlots': totalSlots, // Save using the new key
      'paymentQrUrl': paymentQrUrl,
      // 'teams' are typically updated via arrayUnion in your services, 
      // but if you save the whole object, you would map it here.
    };
  }
}