class TournamentTeamModel {
  final String id;
  final String name;
  final String code;
  final String captainId;
  final String captainPhone;
  final List<String> playerIds;
  final List<String> playerNames;
  final int assignedGroupIndex;
  final int slotNumber;
  
  // Results
  final int placementPoints; // Stores the calculated points (12, 9, 8...)
  final int kills;

  TournamentTeamModel({
    required this.id,
    required this.name,
    required this.code,
    required this.captainId,
    required this.captainPhone,
    required this.playerIds,
    required this.playerNames,
    required this.assignedGroupIndex,
    required this.slotNumber,
    this.placementPoints = 0, 
    this.kills = 0, 
  });

  // --- NEW: Helper to calculate points based on Rank ---
  // Rank 1 = 12, 2 = 9, 3 = 8, ... 10 = 1, 11+ = 0
  static int getPointsForRank(int rank) {
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
    return 0; // Rank 11, 12, etc.
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'captainId': captainId,
      'captainPhone': captainPhone,
      'playerIds': playerIds,
      'playerNames': playerNames,
      'assignedGroupIndex': assignedGroupIndex,
      'slotNumber': slotNumber,
      'placementPoints': placementPoints, // Save results
      'kills': kills, // Save results
    };
  }

  // Create from Map (Firestore Data)
  factory TournamentTeamModel.fromMap(Map<String, dynamic> map) {
    return TournamentTeamModel(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Unknown Team',
      code: map['code'] ?? '',
      captainId: map['captainId'] ?? '',
      captainPhone: map['captainPhone'] ?? '',
      playerIds: List<String>.from(map['playerIds'] ?? []),
      playerNames: List<String>.from(map['playerNames'] ?? []),
      assignedGroupIndex: (map['assignedGroupIndex'] ?? 0).toInt(),
      slotNumber: (map['slotNumber'] ?? 0).toInt(),
      placementPoints: (map['placementPoints'] ?? 0).toInt(), // Load results
      kills: (map['kills'] ?? 0).toInt(), // Load results
    );
  }
}