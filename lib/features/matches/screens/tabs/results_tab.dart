import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/premium_widgets.dart';
import '../../models/match_model.dart';
import '../../models/team_model.dart';
import '../../services/match_service.dart';

class ResultsTab extends StatefulWidget {
  final MatchModel match;
  const ResultsTab({super.key, required this.match});

  @override
  State<ResultsTab> createState() => _ResultsTabState();
}

class _ResultsTabState extends State<ResultsTab> {
  final Map<String, TextEditingController> _killControllers = {};
  final Map<String, TextEditingController> _rankControllers = {}; 

  @override
  void initState() {
    super.initState();
    for (var team in widget.match.teams) {
      _killControllers[team.id] = TextEditingController(text: team.kills.toString());
      _rankControllers[team.id] = TextEditingController(text: team.rank.toString());
    }
  }

  int _calculatePlacementPoints(int rank) {
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
    return 0;
  }

  Future<void> _saveResults() async {
    List<Map<String, dynamic>> updatedTeams = widget.match.teams.map((team) {
      int input1 = int.tryParse(_rankControllers[team.id]?.text ?? '0') ?? 0; 
      int input2 = int.tryParse(_killControllers[team.id]?.text ?? '0') ?? 0; 

      int rank = 0;
      int kills = 0;
      int placementPts = 0;

      if (widget.match.matchType == 'BR') {
        rank = input1;
        kills = input2;
        placementPts = _calculatePlacementPoints(rank); 
      } else {
        kills = input2; 
      }

      return TeamModel(
        id: team.id, name: team.name, captainPhone: team.captainPhone, paymentScreenshotUrl: team.paymentScreenshotUrl, createdBy: team.createdBy, createdByEmail: team.createdByEmail, registrationStatus: team.registrationStatus, kills: kills, placementPoints: placementPts, rank: rank
      ).toMap();
    }).toList();

    await MatchService().updateMatch(widget.match.id, {'teams': updatedTeams});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Results Saved!"), backgroundColor: AppColors.success));
  }

  @override
  Widget build(BuildContext context) {
    bool isBR = widget.match.matchType == 'BR';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(isBR ? "UPDATE BR SCORES" : "UPDATE CS ROUNDS", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.match.teams.length,
            itemBuilder: (context, index) {
              final team = widget.match.teams[index];
              return Card(
                color: AppColors.surface,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(team.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      
                      if (isBR) ...[
                        Expanded(child: _buildBoxField(_rankControllers[team.id], "Rank #")),
                        const SizedBox(width: 8),
                        Expanded(child: _buildBoxField(_killControllers[team.id], "Kills")),
                      ] else ...[
                        const Text("Rounds Won: ", style: TextStyle(color: Colors.grey)),
                        Expanded(child: _buildBoxField(_killControllers[team.id], "")),
                      ]
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          PremiumButton(text: "PUBLISH RESULTS", onPressed: _saveResults),
        ],
      ),
    );
  }

  // --- BOX STYLE INPUT ---
  Widget _buildBoxField(TextEditingController? controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label.isEmpty ? null : label,
        labelStyle: const TextStyle(fontSize: 10, color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
        isDense: true,
      ),
    );
  }
}