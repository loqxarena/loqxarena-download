import 'package:cloud_firestore/cloud_firestore.dart';

class TeamModel {
  final String id;
  final String name;
  final String captainPhone;
  final String paymentScreenshotUrl;
  final String createdBy; 
  final String createdByEmail;
  final String registrationStatus; 
  final int kills;
  final int placementPoints;
  final int rank; 

  TeamModel({
    required this.id,
    required this.name,
    required this.captainPhone,
    required this.paymentScreenshotUrl,
    required this.createdBy,
    required this.createdByEmail,
    required this.registrationStatus,
    this.kills = 0,
    this.placementPoints = 0,
    this.rank = 0,
  });

  // --- FIX: Compatibility Getter ---
  // This prevents the "NoSuchMethodError: Class 'TeamModel' has no instance getter 'captainId'"
  String get captainId => createdBy; 

  int get totalPoints => kills + placementPoints;

  factory TeamModel.fromMap(Map<String, dynamic> map) {
    return TeamModel(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Unknown Team',
      captainPhone: map['captainPhone'] ?? '',
      paymentScreenshotUrl: map['paymentScreenshotUrl'] ?? '',
      createdBy: map['createdBy'] ?? '',
      createdByEmail: map['createdByEmail'] ?? 'No Email',
      registrationStatus: map['registrationStatus'] ?? 'pending',
      kills: map['kills'] ?? 0,
      placementPoints: map['placementPoints'] ?? 0,
      rank: map['rank'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'captainPhone': captainPhone,
      'paymentScreenshotUrl': paymentScreenshotUrl,
      'createdBy': createdBy,
      'createdByEmail': createdByEmail,
      'registrationStatus': registrationStatus,
      'kills': kills,
      'placementPoints': placementPoints,
      'rank': rank,
    };
  }
}