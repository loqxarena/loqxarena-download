import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../services/match_service.dart';
import '../../models/match_model.dart';

class CreateMatchScreen extends StatefulWidget {
  final MatchModel? matchToEdit;
  const CreateMatchScreen({super.key, this.matchToEdit});

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  final _titleController = TextEditingController();
  final _prizeController = TextEditingController();
  final _teamsController = TextEditingController(text: '12'); 
  
  final _rank1Controller = TextEditingController();
  final _rank2Controller = TextEditingController();
  final _rank3Controller = TextEditingController();
  final _perKillController = TextEditingController();
  final _booyahController = TextEditingController();

  late TextEditingController _rulesController;

  String _matchType = 'BR';
  String _matchMode = 'Squad';
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isLoading = false;

  final List<String> _brModes = ['Solo', 'Duo', 'Squad'];
  final List<String> _csModes = ['1v1', '2v2', '4v4', '6v6'];
  final List<String> _allMaps = ['Bermuda', 'Purgatory', 'Kalahari', 'Nextera', 'Alpine', 'Solara'];
  final List<String> _selectedMaps = [];

  @override
  void initState() {
    super.initState();
    _rulesController = TextEditingController(text: "1. No Hacks/Scripts\n2. Screenshots mandatory\n3. Maintain Sportsmanship");
    
    if (widget.matchToEdit != null) {
      final m = widget.matchToEdit!;
      _titleController.text = m.title;
      _prizeController.text = m.prizePool.toString();
      _rulesController.text = m.rules;
      _matchType = m.matchType;
      _matchMode = m.matchMode;
      _selectedDate = m.scheduledAt;
      _selectedTime = TimeOfDay.fromDateTime(m.scheduledAt);
      if (m.map.isNotEmpty) _selectedMaps.addAll(m.map.split(', '));
      
      if (m.matchType == 'CS') {
        _teamsController.text = '2';
      } else {
        _teamsController.text = m.totalSlots.toString();
      }
    }
  }

  Future<void> _selectDateTime() async {
    final now = DateTime.now();
    DateTime validFirstDate = now;
    if (_selectedDate.isBefore(now)) {
      validFirstDate = _selectedDate.subtract(const Duration(minutes: 1));
    } else {
      validFirstDate = now.subtract(const Duration(minutes: 1));
    }

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: validFirstDate, 
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      if (!mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(context: context, initialTime: _selectedTime);
      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
          _selectedTime = pickedTime;
        });
      }
    }
  }

  void _onMatchTypeChanged(String? newValue) {
    if (newValue == null) return;
    setState(() {
      _matchType = newValue;
      if (newValue == 'BR') {
        _matchMode = _brModes.last; 
        _teamsController.text = '12';
      } else {
        _matchMode = _csModes.first;
        _teamsController.text = '2';
      }
    });
  }

  Future<void> _submit() async {
    if (_titleController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title is required")));
        return;
    }
    if (_selectedMaps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select at least one map")));
      return;
    }

    setState(() => _isLoading = true);

    String breakdown = "";
    if (_matchType == 'BR' && _matchMode == 'Solo') {
      List<String> parts = [];
      if (_perKillController.text.isNotEmpty) parts.add("Per Kill: ₹${_perKillController.text}");
      if (_booyahController.text.isNotEmpty) parts.add("Booyah: ₹${_booyahController.text}");
      breakdown = parts.join(" | ");
    } else if (_matchType == 'CS') {
      if (_rank1Controller.text.isNotEmpty) breakdown = "Winner: ₹${_rank1Controller.text}";
    } else {
      List<String> parts = [];
      if (_rank1Controller.text.isNotEmpty) parts.add("1st: ₹${_rank1Controller.text}");
      if (_rank2Controller.text.isNotEmpty) parts.add("2nd: ₹${_rank2Controller.text}");
      if (_rank3Controller.text.isNotEmpty) parts.add("3rd: ₹${_rank3Controller.text}");
      breakdown = parts.join(", ");
    }
    
    if (widget.matchToEdit != null && breakdown.isEmpty) breakdown = widget.matchToEdit!.prizeBreakdown;

    String mapString = _selectedMaps.join(", ");
    String imageUrl = _matchType == 'BR' ? 'assets/BR.jpg' : 'assets/CS.jpeg';

    try {
      int tSlots = _matchType == 'CS' ? 2 : (int.tryParse(_teamsController.text) ?? 12);

      if (widget.matchToEdit != null) {
        await MatchService().updateMatch(widget.matchToEdit!.id, {
          'title': _titleController.text, 
          'matchType': _matchType, 
          'matchMode': _matchMode, 
          'map': mapString,
          'entryFee': 0, // ALWAYS FREE
          'prizePool': int.tryParse(_prizeController.text) ?? 0, // RESTORED
          'prizeBreakdown': breakdown, // RESTORED
          'totalSlots': tSlots, 
          'rules': _rulesController.text,
          'scheduledAt': _selectedDate,
          'thumbnailImage': imageUrl,
        });
      } else {
        await MatchService().createMatch(
          title: _titleController.text, 
          matchType: _matchType, 
          matchMode: _matchMode, 
          map: mapString,
          entryFee: 0, // ALWAYS FREE
          prizePool: int.tryParse(_prizeController.text) ?? 0, // RESTORED
          prizeBreakdown: breakdown, // RESTORED
          totalSlots: tSlots,
          scheduledAt: _selectedDate, 
          rules: _rulesController.text, 
          bannerImage: imageUrl,
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.matchToEdit != null ? "EDIT MATCH" : "CREATE MATCH", style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("MATCH DETAILS"),
            const SizedBox(height: 12),
            AppTextField(label: "Match Title", hint: "e.g. 10 PM Scrim", controller: _titleController),
            const SizedBox(height: 16),
            Row(children: [
                Expanded(child: _buildDropdown("Type", _matchType, ['BR', 'CS'], _onMatchTypeChanged)),
                const SizedBox(width: 16),
                Expanded(child: _buildDropdown("Mode", _matchMode, (_matchType == 'BR' ? _brModes : _csModes), (v) => setState(() => _matchMode = v!))),
              ]),
            const SizedBox(height: 16),
            
            if (_matchType == 'BR')
               AppTextField(label: "Total Teams (Slots)", controller: _teamsController, keyboardType: TextInputType.number),
            
            const SizedBox(height: 20),
            
            _buildSectionHeader("SELECT MAPS"),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: _allMaps.map((map) {
                final isSelected = _selectedMaps.contains(map);
                return FilterChip(
                  label: Text(map), 
                  selected: isSelected, 
                  selectedColor: AppColors.primary, 
                  checkmarkColor: Colors.black,
                  labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  backgroundColor: AppColors.surface, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isSelected ? AppColors.primary : Colors.white24)),
                  onSelected: (bool selected) { setState(() { if (selected) { _selectedMaps.add(map); } else { _selectedMaps.remove(map); } }); },
                );
              }).toList()),
            
            const SizedBox(height: 24),

            // RESTORED PRIZE SECTION
            _buildSectionHeader("PRIZE DISTRIBUTION"),
            const SizedBox(height: 12),
            AppTextField(label: "Total Prize Pool (₹)", controller: _prizeController, keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            
            if (_matchType == 'BR' && _matchMode == 'Solo')
              Row(children: [Expanded(child: AppTextField(label: "Per Kill ₹", controller: _perKillController, keyboardType: TextInputType.number)), const SizedBox(width: 16), Expanded(child: AppTextField(label: "Booyah ₹", controller: _booyahController, keyboardType: TextInputType.number))])
            else if (_matchType == 'CS') 
              AppTextField(label: "Winner Team Prize (₹)", controller: _rank1Controller, keyboardType: TextInputType.number)
            else 
              Row(children: [Expanded(child: AppTextField(label: "1st ₹", controller: _rank1Controller, keyboardType: TextInputType.number)), const SizedBox(width: 8), Expanded(child: AppTextField(label: "2nd ₹", controller: _rank2Controller, keyboardType: TextInputType.number)), const SizedBox(width: 8), Expanded(child: AppTextField(label: "3rd ₹", controller: _rank3Controller, keyboardType: TextInputType.number))]),
            
            const SizedBox(height: 24),

            _buildSectionHeader("RULES & REGULATIONS"),
            const SizedBox(height: 12),
            AppTextField(label: "", controller: _rulesController, maxLines: 4, keyboardType: TextInputType.multiline),
            
            const SizedBox(height: 24),
            _buildSectionHeader("SCHEDULE"),
            const SizedBox(height: 12),
            Container(decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), title: const Text("Start Time", style: TextStyle(color: Colors.grey, fontSize: 12)), subtitle: Text("${_selectedDate.day}/${_selectedDate.month} at ${_selectedTime.format(context)}", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), trailing: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.calendar_today, color: AppColors.primary, size: 20)), onTap: _selectDateTime)),
            
            const SizedBox(height: 40),
            AppButton(text: widget.matchToEdit != null ? "UPDATE MATCH" : "PUBLISH MATCH", isLoading: _isLoading, onPressed: _submit),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Text(title, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5));
  
  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: value, dropdownColor: AppColors.surface, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), isExpanded: true, icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary), items: items.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(), onChanged: onChanged)))]);
}