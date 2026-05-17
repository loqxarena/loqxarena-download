import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart'; 
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/premium_widgets.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../services/wallet_service.dart';
import '../models/wallet_transaction_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:loqx_arena/features/matches/services/match_service.dart'; 

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("FUNDS & HISTORY", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.white)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
      ),
      body: const _WalletContentTab(),
    );
  }
}

class _WalletContentTab extends StatefulWidget {
  const _WalletContentTab();

  @override
  State<_WalletContentTab> createState() => _WalletContentTabState();
}

class _WalletContentTabState extends State<_WalletContentTab> {
  
  // --- WITHDRAW SHEET (Players can ONLY withdraw) ---
  void _showWithdrawSheet(BuildContext context, int currentBalance) {
    final coinsCtrl = TextEditingController();
    final upiCtrl = TextEditingController();
    final coinsNotifier = ValueNotifier<int>(0);
    File? qrImage;

    coinsCtrl.addListener(() {
      coinsNotifier.value = int.tryParse(coinsCtrl.text) ?? 0;
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSheet) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("WITHDRAW WINNINGS", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 16),
                
                AppTextField(label: "Coins to Withdraw", controller: coinsCtrl, keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                ValueListenableBuilder<int>(
                  valueListenable: coinsNotifier,
                  builder: (context, val, child) {
                    return Text("You will receive: ₹$val in Bank", style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold));
                  },
                ),
                const SizedBox(height: 20),
                
                const Text("CHOOSE WITHDRAWAL METHOD (Select One)", style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),

                AppTextField(label: "Enter UPI ID", controller: upiCtrl, hint: "e.g. 9876543210@ybl"),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Center(child: Text("- OR -", style: TextStyle(color: Colors.grey))),
                ),
                
                GestureDetector(
                  onTap: () async {
                    final XFile? img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50);
                    if (img != null) {
                      setStateSheet(() {
                        qrImage = File(img.path);
                        upiCtrl.clear(); 
                      });
                    }
                  },
                  child: Container(
                    height: 50,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: qrImage != null ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                      border: Border.all(color: qrImage != null ? AppColors.primary : Colors.white24), 
                      borderRadius: BorderRadius.circular(12)
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code, color: qrImage != null ? AppColors.primary : Colors.white),
                        const SizedBox(width: 8),
                        Text(qrImage == null ? "Upload QR Screenshot" : "QR Selected (Tap to change)", style: TextStyle(color: qrImage != null ? AppColors.primary : Colors.white)),
                        if(qrImage != null) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check_circle, color: AppColors.success, size: 16)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                
                PremiumButton(
                  text: "REQUEST WITHDRAWAL",
                  onPressed: () async {
                    int coins = int.tryParse(coinsCtrl.text) ?? 0;
                    
                    if (coins < 10) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Minimum withdrawal is 10 Coins")));
                      return;
                    }
                    if (coins > currentBalance) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Insufficient Balance")));
                      return;
                    }

                    bool hasUPI = upiCtrl.text.trim().isNotEmpty;
                    bool hasQR = qrImage != null;

                    if (!hasUPI && !hasQR) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please provide either UPI ID or QR Code"), backgroundColor: Colors.orange));
                      return;
                    }

                    try {
                      Navigator.pop(context); 
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Processing...")));
                      
                      String detailText = "";
                      if (hasUPI) {
                        detailText = "UPI: ${upiCtrl.text.trim()}";
                      } else if (hasQR) {
                        final url = await MatchService().uploadMatchBanner(qrImage!); 
                        detailText = "QR_IMAGE|$url";
                      }

                      await WalletService().requestWithdrawal(coins, detailText);
                      
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Sent!"), backgroundColor: AppColors.success));
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                    }
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        }
      ),
    );
  }

  // --- SHOW QR DIALOG (FOR USER HISTORY) ---
  void _showQrDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: WalletService().getBalance(),
      builder: (context, snapshot) {
        final balance = snapshot.data ?? 0;
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFA88626)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("TOTAL WINNINGS", style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.black, size: 36),
                      const SizedBox(width: 12),
                      Text("$balance", style: const TextStyle(color: Colors.black, fontSize: 40, fontWeight: FontWeight.w900)),
                      const Text(" Coins", style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // ONLY WITHDRAW ALLOWED
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.black, width: 2), 
                        foregroundColor: Colors.black, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ), 
                      onPressed: () => _showWithdrawSheet(context, balance), 
                      child: const Text("WITHDRAW TO BANK", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1))
                    ),
                  ),
                ],
              ),
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Align(alignment: Alignment.centerLeft, child: Text("RECENT TRANSACTIONS", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)))),
            Expanded(
              child: StreamBuilder<List<WalletTransactionModel>>(
                stream: WalletService().getTransactions(),
                builder: (context, txSnapshot) {
                  if (!txSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  final txs = txSnapshot.data!;
                  if (txs.isEmpty) return const Center(child: Text("No transactions yet.", style: TextStyle(color: Colors.grey)));
                  
                  return ListView.separated(
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 120),
                    itemCount: txs.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final tx = txs[index];
                      final isCredit = tx.amount > 0;
                      
                      String displayDescription = tx.description;
                      String? qrUrl;
                      if (tx.description.contains("QR_IMAGE|")) {
                        final parts = tx.description.split("QR_IMAGE|");
                        if (parts.length > 1) {
                          displayDescription = "Withdrawal Request (QR)";
                          qrUrl = parts[1].trim();
                        }
                      }

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (isCredit ? Colors.green : Colors.red).withOpacity(0.1), shape: BoxShape.circle), child: Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward, color: isCredit ? Colors.green : Colors.red, size: 20)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(displayDescription, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  if (qrUrl != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: InkWell(
                                        onTap: () => _showQrDialog(qrUrl!),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(Icons.qr_code_scanner, color: AppColors.primary, size: 14),
                                            SizedBox(width: 4),
                                            Text("VIEW QR IMAGE", style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(DateFormat('MMM d, h:mm a').format(tx.timestamp), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                ],
                              ),
                            ),
                            Text("${isCredit ? '+' : ''}${tx.amount}", style: TextStyle(color: isCredit ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
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
      },
    );
  }
}