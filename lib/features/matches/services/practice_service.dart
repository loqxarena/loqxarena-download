import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PracticeModel {
  final String id;
  final String title;
  final String imageUrl;
  final String roomId;
  final String password;
  final String note; 
  final DateTime createdAt;

  PracticeModel({required this.id, required this.title, required this.imageUrl, required this.roomId, required this.password, required this.note, required this.createdAt});

  factory PracticeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PracticeModel(
      id: doc.id,
      title: data['title'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      roomId: data['roomId'] ?? '',
      password: data['password'] ?? '',
      note: data['note'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class PracticeService {
  final CollectionReference _ref = FirebaseFirestore.instance.collection('practice');
  final Reference _storageRef = FirebaseStorage.instance.ref();

  Stream<List<PracticeModel>> getPracticeMatches() {
    return _ref.orderBy('createdAt', descending: true).snapshots().map((snap) {
      final now = DateTime.now();
      return snap.docs.map((doc) => PracticeModel.fromFirestore(doc)).where((match) {
        if (now.difference(match.createdAt).inHours > 24) return false;
        return true;
      }).toList();
    });
  }

  Future<String?> uploadImage(File file) async {
    try {
      String fileName = 'practice_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = _storageRef.child('practice_images').child(fileName);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) { return null; }
  }

  Future<void> createPracticeMatch({required String title, required String roomId, required String password, required String note, String? imageUrl}) async {
    await _ref.add({
      'title': title, 'roomId': roomId, 'password': password, 'note': note, 'imageUrl': imageUrl, 'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updatePracticeMatch(String id, Map<String, dynamic> data) async {
    await _ref.doc(id).update(data);
  }

  Future<void> deletePracticeMatch(String id) async {
    await _ref.doc(id).delete();
  }
}