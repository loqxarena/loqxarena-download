import 'package:cloud_firestore/cloud_firestore.dart';

class WalletTransactionModel {
  final String id;
  final String userId;
  final String type; // 'deposit', 'withdrawal', 'entry_fee', 'winnings'
  final int amount;
  final String description;
  final DateTime timestamp;
  final String status; // 'success', 'pending', 'failed'

  WalletTransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.description,
    required this.timestamp,
    required this.status,
  });

  factory WalletTransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalletTransactionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: data['type'] ?? 'unknown',
      amount: data['amount'] ?? 0,
      description: data['description'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      status: data['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'amount': amount,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
      'status': status,
    };
  }
}