import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../models/tournament_model.dart';
import '../../services/tournament_service.dart';

class CreateTournamentScreen extends StatefulWidget {
  final TournamentModel? tournamentToEdit;
  const CreateTournamentScreen({super.key, this.tournamentToEdit});

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _titleCtrl = TextEditingController();
  final _footerCtrl = TextEditingController(text: "LOQX OFFICIAL");
  final _prefixCtrl = TextEditingController(text: "LQX");
  final _slotsCtrl = TextEditingController(text: "48");
  final _groupSizeCtrl = TextEditingController(text: "12");
  final _rulesCtrl = TextEditingController(text: "1. Fair Play\n2. No Hacks");
  
  // RESTORED PRIZE CONTROLLERS
  final _prizePoolCtrl = TextEditingController(text: "0");
  final _rank1Ctrl = TextEditingController(text: "0");
  final _rank2Ctrl = TextEditingController(text: "0");
  final _rank3Ctrl = TextEditingController(text: "0");
  
  String _matchType = 'BR';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.tournamentToEdit != null) {
      final t = widget.tournamentToEdit!;
      _titleCtrl.text = t.title;
      _footerCtrl.text = t.footerName;
      _prefixCtrl.text = t.codePrefix;
      _slotsCtrl.text = t.totalSlots.toString();
      _groupSizeCtrl.text = t.groupSize.toString();
      _rulesCtrl.text = t.formatRules; 
      
      // Load Prize Data
      _prizePoolCtrl.text = t.prizePool.toString();
      _rank1Ctrl.text = t.rank1Prize.toString();
      _rank2Ctrl.text = t.rank2Prize.toString();
      _rank3Ctrl.text = t.rank3Prize.toString();
    }
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);

    String bannerAsset = _matchType == 'BR' ? 'assets/BR.jpg' : 'assets/CS.jpeg';

    try {
      if (widget.tournamentToEdit != null) {
        await TournamentService().updateTournament(widget.tournamentToEdit!.id, {
          'title': _titleCtrl.text,
          'footerName': _footerCtrl.text,
          'codePrefix': _prefixCtrl.text,
          'entryFee': 0, // ALWAYS FREE
          'formatRules': _rulesCtrl.text,
          'totalSlots': int.parse(_slotsCtrl.text),
          'groupSize': int.parse(_groupSizeCtrl.text),
          // SAVING PRIZES
          'prizePool': int.parse(_prizePoolCtrl.text),
          'rank1Prize': int.parse(_rank1Ctrl.text),
          'rank2Prize': int.parse(_rank2Ctrl.text),
          'rank3Prize': int.parse(_rank3Ctrl.text),
          'bannerUrl': bannerAsset, 
        });
      } else {
        await TournamentService().createTournament(
          title: _titleCtrl.text,
          footerName: _footerCtrl.text,
          codePrefix: _prefixCtrl.text,
          totalSlots: int.parse(_slotsCtrl.text),
          groupSize: int.parse(_groupSizeCtrl.text),
          entryFee: 0, // ALWAYS FREE
          rules: _rulesCtrl.text,
          // SAVING PRIZES
          prizePool: int.parse(_prizePoolCtrl.text),
          rank1Prize: int.parse(_rank1Ctrl.text),
          rank2Prize: int.parse(_rank2Ctrl.text),
          rank3Prize: int.parse(_rank3Ctrl.text),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.tournamentToEdit != null ? "EDIT CUP" : "CREATE CUP", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Align(alignment: Alignment.centerLeft, child: Text("TOURNAMENT TYPE", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: 1))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: ChoiceChip(label: const Text("BATTLE ROYALE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), selected: _matchType == 'BR', onSelected: (v) => setState(() => _matchType = 'BR'), selectedColor: AppColors.primary, labelStyle: TextStyle(color: _matchType == 'BR' ? Colors.black : Colors.white))),
                const SizedBox(width: 12),
                Expanded(child: ChoiceChip(label: const Text("CLASH SQUAD", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), selected: _matchType == 'CS', onSelected: (v) => setState(() => _matchType = 'CS'), selectedColor: AppColors.primary, labelStyle: TextStyle(color: _matchType == 'CS' ? Colors.black : Colors.white))),
              ],
            ),
            const SizedBox(height: 24),
            
            AppTextField(label: "Tournament Title", controller: _titleCtrl),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: AppTextField(label: "Total Slots", controller: _slotsCtrl, keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: AppTextField(label: "Group Size", controller: _groupSizeCtrl, keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 16),
            AppTextField(label: "Code Prefix (e.g. LQX)", controller: _prefixCtrl),
            const SizedBox(height: 24),

            // RESTORED PRIZE SECTION
            const Align(alignment: Alignment.centerLeft, child: Text("PRIZE DISTRIBUTION", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: 1))),
            const SizedBox(height: 12),
            AppTextField(label: "Total Prize Pool (₹)", controller: _prizePoolCtrl, keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: AppTextField(label: "Rank 1 (₹)", controller: _rank1Ctrl, keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: AppTextField(label: "Rank 2 (₹)", controller: _rank2Ctrl, keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: AppTextField(label: "Rank 3 (₹)", controller: _rank3Ctrl, keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 24),

            AppTextField(label: "Footer Label", controller: _footerCtrl),
            const SizedBox(height: 16),
            AppTextField(label: "Rules", controller: _rulesCtrl, maxLines: 5, keyboardType: TextInputType.multiline),
            const SizedBox(height: 32),
            AppButton(text: widget.tournamentToEdit != null ? "UPDATE" : "LAUNCH CUP", isLoading: _isLoading, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}