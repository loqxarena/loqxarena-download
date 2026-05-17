import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../models/wallet_transaction_model.dart';



class WalletService {

final FirebaseFirestore _db = FirebaseFirestore.instance;

final FirebaseAuth _auth = FirebaseAuth.instance;



// Get Current Balance Stream

Stream<int> getBalance() {

final uid = _auth.currentUser?.uid;

if (uid == null) return Stream.value(0);

return _db.collection('users').doc(uid).snapshots().map((doc) {

return (doc.data()?['wallet_balance'] as int?) ?? 0;

});

}



// Get Transaction History

Stream<List<WalletTransactionModel>> getTransactions() {

final uid = _auth.currentUser?.uid;

if (uid == null) return const Stream.empty();

return _db.collection('users').doc(uid).collection('transactions')

.orderBy('timestamp', descending: true)

.snapshots()

.map((s) => s.docs.map((d) => WalletTransactionModel.fromFirestore(d)).toList());

}



// 1. ADD MONEY (Deposit)

Future<void> depositCoins(int amount, String paymentId) async {

final uid = _auth.currentUser?.uid;

if (uid == null) throw "User not logged in";



final userRef = _db.collection('users').doc(uid);

final txRef = userRef.collection('transactions').doc();



await _db.runTransaction((transaction) async {

final snapshot = await transaction.get(userRef);

int currentBalance = (snapshot.data()?['wallet_balance'] as int?) ?? 0;



// Update Balance

transaction.set(userRef, {'wallet_balance': currentBalance + amount}, SetOptions(merge: true));



// Record Transaction

transaction.set(txRef, {

'userId': uid,

'type': 'deposit',

'amount': amount,

'description': 'Added via Razorpay ($paymentId)',

'timestamp': FieldValue.serverTimestamp(),

'status': 'success',

});

});

}



// 2. PAY ENTRY FEE (Deduct)

Future<void> payEntryFee(int amount, String matchTitle) async {

final uid = _auth.currentUser?.uid;

if (uid == null) throw "User not logged in";



final userRef = _db.collection('users').doc(uid);


await _db.runTransaction((transaction) async {

final snapshot = await transaction.get(userRef);

int currentBalance = (snapshot.data()?['wallet_balance'] as int?) ?? 0;



if (currentBalance < amount) {

throw "Insufficient Balance";

}



// Deduct

transaction.update(userRef, {'wallet_balance': currentBalance - amount});



// Record

final txRef = userRef.collection('transactions').doc();

transaction.set(txRef, {

'userId': uid,

'type': 'entry_fee',

'amount': -amount, // Negative for deduction

'description': 'Joined: $matchTitle',

'timestamp': FieldValue.serverTimestamp(),

'status': 'success',

});

});

}



// 3. WITHDRAW REQUEST

Future<void> requestWithdrawal(int amount, String upiId) async {

final uid = _auth.currentUser?.uid;

if (uid == null) throw "User not logged in";

if (amount < 10) throw "Minimum withdrawal is 10 Coins";



final userRef = _db.collection('users').doc(uid);


await _db.runTransaction((transaction) async {

final snapshot = await transaction.get(userRef);

int currentBalance = (snapshot.data()?['wallet_balance'] as int?) ?? 0;



if (currentBalance < amount) throw "Insufficient Balance";



// Deduct immediately (Freeze funds)

transaction.update(userRef, {'wallet_balance': currentBalance - amount});



// User Transaction Record

final txRef = userRef.collection('transactions').doc();

transaction.set(txRef, {

'userId': uid,

'type': 'withdrawal',

'amount': -amount,

'description': 'Withdrawal Request to $upiId',

'timestamp': FieldValue.serverTimestamp(),

'status': 'pending',

});



// Admin Request Record

final adminRef = _db.collection('withdrawal_requests').doc();

transaction.set(adminRef, {

'userId': uid,

'userName': _auth.currentUser?.displayName ?? 'User',

'amount': amount,

'upiId': upiId,

'status': 'pending',

'requestedAt': FieldValue.serverTimestamp(),

});

});

}

}