import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/premium_widgets.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../models/match_model.dart';
import '../../models/team_model.dart';
import '../../services/match_service.dart';

class RegistrationFormScreen extends StatefulWidget {
  final MatchModel match;
  final String proofUrl; 

  const RegistrationFormScreen({
    super.key, 
    required this.match, 
    required this.proofUrl,
  });

  @override
  State<RegistrationFormScreen> createState() => _RegistrationFormScreenState();
}

class _RegistrationFormScreenState extends State<RegistrationFormScreen> {
  final _teamNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _teamNameController.text = prefs.getString('profile_team_name') ?? '';
      _phoneController.text = prefs.getString('profile_phone') ?? '';
    });
  }

  Future<void> _submit() async {
    if (_teamNameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All fields required")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      
      final team = TeamModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _teamNameController.text,
        captainPhone: _phoneController.text,
        paymentScreenshotUrl: widget.proofUrl, 
        createdBy: user.uid,
        // NEW: Save the Gmail permanently with the team
        createdByEmail: user.email ?? "No Email", 
        registrationStatus: 'pending_approval',
      );

      await MatchService().addTeam(widget.match.id, team);

      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst || route.settings.name == '/match_details'); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Registration Submitted!"), backgroundColor: AppColors.success));
      }
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
      appBar: AppBar(title: const Text("Final Step: Details"), backgroundColor: AppColors.surface, iconTheme: const IconThemeData(color: Colors.white)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("TEAM DETAILS", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            AppTextField(label: "Team Name", controller: _teamNameController, hint: "Enter Team Name"),
            const SizedBox(height: 16),
            AppTextField(label: "WhatsApp Number", controller: _phoneController, hint: "For room password", keyboardType: TextInputType.phone),
            const SizedBox(height: 32),
            PremiumButton(text: "CONFIRM REGISTRATION", isLoading: _isLoading, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}