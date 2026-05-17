import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/premium_widgets.dart';
import '../matches/services/practice_service.dart';

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("PRACTICE ROOMS", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<List<PracticeModel>>(
        stream: PracticeService().getPracticeMatches(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.gamepad, size: 64, color: Colors.white10), SizedBox(height: 16), Text("No practice rooms active.", style: TextStyle(color: Colors.grey))]));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final match = snapshot.data![index];
              return PremiumCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner
                    if (match.imageUrl.isNotEmpty)
                      SizedBox(height: 120, width: double.infinity, child: Image.network(match.imageUrl, fit: BoxFit.cover)),
                    
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(match.title.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          // ID & Pass Row
                          Row(
                            children: [
                              _buildInfoBox("ROOM ID", match.roomId, true),
                              const SizedBox(width: 12),
                              _buildInfoBox("PASSWORD", match.password, true),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Note
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
                            child: Row(children: [const Icon(Icons.info_outline, size: 16, color: AppColors.primary), const SizedBox(width: 8), Expanded(child: Text(match.note, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)))]),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoBox(String label, String value, bool copyable) {
    return Expanded(
      child: Builder(builder: (context) {
        return InkWell(
          onTap: copyable ? () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$label Copied!")));
          } : null,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    if (copyable) const Icon(Icons.copy, size: 14, color: Colors.grey),
                  ],
                )
              ],
            ),
          ),
        );
      }),
    );
  }
}