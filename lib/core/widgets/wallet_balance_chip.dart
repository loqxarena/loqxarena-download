import 'package:flutter/material.dart';
import '../../features/wallet/services/wallet_service.dart';
import '../../core/constants/app_colors.dart';

class WalletBalanceChip extends StatelessWidget {
  const WalletBalanceChip({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: WalletService().getBalance(),
      builder: (context, snapshot) {
        final balance = snapshot.data ?? 0;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 16),
              const SizedBox(width: 6),
              Text(
                "$balance",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}