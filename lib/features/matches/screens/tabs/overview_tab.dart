import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/premium_widgets.dart'; // Ensure you have this
import '../../models/match_model.dart';
import '../../services/match_service.dart';

class OverviewTab extends StatefulWidget {
  final MatchModel match;
  const OverviewTab({super.key, required this.match});

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  String _selectedStatus = 'open';

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.match.status;
  }

  Future<void> _updateStatus(String? newStatus) async {
    if (newStatus != null) {
      setState(() => _selectedStatus = newStatus);
      await MatchService().updateMatch(widget.match.id, {'status': newStatus});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Match Updated!"), backgroundColor: AppColors.success));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumCard(
            padding: const EdgeInsets.all(16),
            glowColor: AppColors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Map: ${widget.match.map}", style: const TextStyle(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 8),
                Text("Fee: ₹${widget.match.entryFee}  |  Prize: ₹${widget.match.prizePool}", style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                Text(DateFormat('MMM d, yyyy • h:mm a').format(widget.match.scheduledAt), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text("Match Status", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStatus,
                isExpanded: true,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: Colors.white),
                items: ['open', 'ongoing', 'completed'].map((s) {
                  return DropdownMenuItem(value: s, child: Text(s.toUpperCase()));
                }).toList(),
                onChanged: _updateStatus,
              ),
            ),
          ),
        ],
      ),
    );
  }
}