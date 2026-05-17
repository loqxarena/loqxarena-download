import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/match_model.dart';
import 'tabs/overview_tab.dart';
import 'tabs/teams_tab.dart';
import 'tabs/results_tab.dart';

class MatchDetailsScreen extends StatefulWidget {
  final MatchModel match;

  const MatchDetailsScreen({super.key, required this.match});

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // We have 3 tabs: Overview, Teams, Results
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.match.title),
        bottom: TabBar(
          controller: _tabController, // <--- FIXED: Added 'controller:'
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "OVERVIEW"),
            Tab(text: "TEAMS"),
            Tab(text: "RESULTS"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          
          // 1. Overview Tab
          OverviewTab(match: widget.match),
          
          
          // 2. Teams Tab
          TeamsTab(match: widget.match),
          
          
          // 3. Results Tab
          ResultsTab(match: widget.match),
        ],
      ),
    );
  }
}