import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/premium_widgets.dart';
import '../models/match_model.dart';
import '../services/match_service.dart';
import 'player_match_details_screen.dart';

class MyMatchesScreen extends StatelessWidget {
  const MyMatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("MY BATTLE LOG", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<List<MatchModel>>(
        stream: MatchService().getMyMatches(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_edu, size: 80, color: Colors.white.withOpacity(0.1)),
                  const SizedBox(height: 16),
                  const Text("NO BATTLES YET", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                  const SizedBox(height: 8),
                  const Text("Join a tournament from the Arena!", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final matches = snapshot.data!;
          return ListView.separated(
            itemCount: matches.length,
            padding: const EdgeInsets.all(16),
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final match = matches[index];
              Color statusColor = AppColors.primary;
              String statusText = "UPCOMING";
              if (match.status == 'ongoing') { statusColor = AppColors.error; statusText = "LIVE"; }
              if (match.status == 'completed') { statusColor = Colors.grey; statusText = "COMPLETED"; }

              return PremiumCard(
                glowColor: statusColor.withOpacity(0.4),
                padding: const EdgeInsets.all(12),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PlayerMatchDetailsScreen(match: match))),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 80, width: 80,
                        decoration: BoxDecoration(color: Colors.grey.shade900),
                        child: match.thumbnailImage != null 
                            ? Image.network(
                                match.thumbnailImage!, 
                                fit: BoxFit.cover,
                                cacheWidth: 150, // PERFORMANCE FIX: Small cache for small icon
                              )
                            : const Icon(Icons.sports_esports, color: Colors.white24, size: 40),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(match.title.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Row(children: [Icon(Icons.calendar_today, size: 12, color: AppColors.primary), const SizedBox(width: 4), Text(DateFormat('d MMM, h:mm a').format(match.scheduledAt), style: const TextStyle(color: Colors.grey, fontSize: 12))]),
                          const SizedBox(height: 4),
                          Row(children: [const Icon(Icons.map, size: 12, color: Colors.grey), const SizedBox(width: 4), Text(match.map, style: const TextStyle(color: Colors.grey, fontSize: 12))]),
                        ],
                      ),
                    ),
                    Column(children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(border: Border.all(color: statusColor.withOpacity(0.5)), borderRadius: BorderRadius.circular(6), color: statusColor.withOpacity(0.1)), child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold))),
                        const SizedBox(height: 16),
                        const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
                    ]),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}