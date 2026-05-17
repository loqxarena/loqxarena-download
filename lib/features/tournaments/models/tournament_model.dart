import 'package:cloud_firestore/cloud_firestore.dart';

class TournamentModel {
  final String id;
  final String title;
  final String footerName;
  final String codePrefix;
  final int totalSlots;
  final int groupSize;
  final int entryFee;
  final String status; // 'registration', 'ongoing', 'completed'
  final String bannerUrl;
  final String formatRules;
  final int totalGroups;
  final DateTime createdAt;
  
  // Prize Fields
  final int prizePool;
  final int rank1Prize;
  final int rank2Prize;
  final int rank3Prize;
  
  // FIX: Added Missing Field
  final String matchMode; // e.g. "BR", "CS", "CLASH"

  final List<dynamic> teams; 

  TournamentModel({
    required this.id,
    required this.title,
    required this.footerName,
    required this.codePrefix,
    required this.totalSlots,
    required this.groupSize,
    required this.entryFee,
    required this.status,
    required this.bannerUrl,
    required this.formatRules,
    required this.createdAt,
    this.teams = const [],
    this.prizePool = 0,
    this.rank1Prize = 0,
    this.rank2Prize = 0,
    this.rank3Prize = 0,
    this.matchMode = 'BR', // Default
  }) : totalGroups = (totalSlots / (groupSize == 0 ? 1 : groupSize)).ceil();

  factory TournamentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TournamentModel(
      id: doc.id,
      title: data['title'] ?? '',
      footerName: data['footerName'] ?? '',
      codePrefix: data['codePrefix'] ?? '',
      totalSlots: (data['totalSlots'] ?? 0).toInt(),
      groupSize: (data['groupSize'] ?? 1).toInt(),
      entryFee: (data['entryFee'] ?? 0).toInt(),
      status: data['status'] ?? 'registration',
      bannerUrl: data['bannerUrl'] ?? '',
      formatRules: data['formatRules'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      teams: data['teams'] ?? [],
      prizePool: (data['prizePool'] ?? 0).toInt(),
      rank1Prize: (data['rank1Prize'] ?? 0).toInt(),
      rank2Prize: (data['rank2Prize'] ?? 0).toInt(),
      rank3Prize: (data['rank3Prize'] ?? 0).toInt(),
      matchMode: data['matchMode'] ?? 'BR', // Load matchMode
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'footerName': footerName,
      'codePrefix': codePrefix,
      'totalSlots': totalSlots,
      'groupSize': groupSize,
      'entryFee': entryFee,
      'status': status,
      'bannerUrl': bannerUrl,
      'formatRules': formatRules,
      'createdAt': createdAt,
      'teams': teams,
      'prizePool': prizePool,
      'rank1Prize': rank1Prize,
      'rank2Prize': rank2Prize,
      'rank3Prize': rank3Prize,
      'matchMode': matchMode, // Save matchMode
    };
  }
}