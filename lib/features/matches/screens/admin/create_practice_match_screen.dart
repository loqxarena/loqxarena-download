import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../services/practice_service.dart';
import '../../models/match_model.dart'; // Reusing for Practice Model type

class CreatePracticeMatchScreen extends StatefulWidget {
  final PracticeModel? matchToEdit;
  const CreatePracticeMatchScreen({super.key, this.matchToEdit});

  @override
  State<CreatePracticeMatchScreen> createState() => _CreatePracticeMatchScreenState();
}

class _CreatePracticeMatchScreenState extends State<CreatePracticeMatchScreen> {
  final _titleCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.matchToEdit != null) {
      _titleCtrl.text = widget.matchToEdit!.title;
      _roomCtrl.text = widget.matchToEdit!.roomId;
      _passCtrl.text = widget.matchToEdit!.password;
      _noteCtrl.text = widget.matchToEdit!.note;
    }
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.isEmpty || _roomCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title and Room ID are required")));
      return;
    }
    setState(() => _isLoading = true);

    try {
      if (widget.matchToEdit != null) {
        await PracticeService().updatePracticeMatch(widget.matchToEdit!.id, {
          'title': _titleCtrl.text, 'roomId': _roomCtrl.text, 'password': _passCtrl.text, 'note': _noteCtrl.text
        });
      } else {
        await PracticeService().createPracticeMatch(
          title: _titleCtrl.text, roomId: _roomCtrl.text, password: _passCtrl.text, note: _noteCtrl.text
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
        title: Text(widget.matchToEdit != null ? "EDIT PRACTICE" : "CREATE PRACTICE", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            AppTextField(label: "Title", hint: "e.g. Scrim 8 PM", controller: _titleCtrl),
            const SizedBox(height: 16),
            AppTextField(label: "Room ID", controller: _roomCtrl, keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            AppTextField(label: "Password", controller: _passCtrl, keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            AppTextField(label: "Note (Optional)", hint: "e.g. Map Download Required", controller: _noteCtrl),
            const SizedBox(height: 32),
            AppButton(text: "PUBLISH", isLoading: _isLoading, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}