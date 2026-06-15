/// @file my_reports_screen.dart
/// @description Handles the reporting, mapping, and viewing of civic issues.
/// Professionally structured and maintained by the Civic App Team.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutterapp/features/complaints/presentation/screens/complaint_details_screen.dart';
import 'package:flutterapp/features/auth/data/services/aadhaar_api.dart'; 
import 'package:flutterapp/core/widgets/improved_report_card.dart';
import 'package:flutterapp/core/widgets/share_sheet.dart';
import 'package:flutterapp/core/theme/app_colors.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key, required this.user});

  final AadhaarUser user;

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];
  String _activeFilter = 'All';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFromCache();
    _loadReports();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'myReports_${widget.user.id}';
      final json = prefs.getString(key);
      if (json == null) return;

      final decoded = jsonDecode(json) as List;
      final cached =
          decoded.map((e) => (e as Map).cast<String, dynamic>()).toList();

      if (!mounted) return;
      if (cached.isNotEmpty) {
        setState(() {
          _reports = cached;
          _isLoading = false;
        });
      }
    } catch (_) {
      // ignore cache errors
    }
  }

  Future<void> _loadReports() async {
    if (_reports.isEmpty) setState(() => _isLoading = true);
    
    try {
      final reports = await AadhaarApi.fetchUserReports(widget.user.id);
      if (!mounted) return;
      
      setState(() {
        _reports = reports;
        _isLoading = false;
        _error = null;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('myReports_${widget.user.id}', jsonEncode(reports));
    } catch (e) {
      debugPrint("Error fetching reports: $e");
      if (mounted) {
        setState(() {
          _error = _reports.isEmpty ? e.toString() : null; // Only show error page if no cached data
          _isLoading = false;
        });
        if (_reports.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update. Showing cached data.'))
          );
        }
      }
    }
  }

  int get _totalCount => _reports.length;
  int get _activeCount => _reports.where((r) => r['status']?.toString().toUpperCase() != 'RESOLVED').length;
  int get _resolvedCount => _reports.where((r) => r['status']?.toString().toUpperCase() == 'RESOLVED').length;


  @override
  Widget build(BuildContext context) {
    final filteredList = _reports.where((r) {
      bool matchesFilter = true;
      if (_activeFilter == 'Active') matchesFilter = r['status']?.toString().toUpperCase() != 'RESOLVED';
      else if (_activeFilter == 'Resolved') matchesFilter = r['status']?.toString().toUpperCase() == 'RESOLVED';
      
      return matchesFilter;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // 1. Premium App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text('My Complaints', 
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)
              ),
              centerTitle: true,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          // 2. Summary Dashboard
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                children: [
                  _buildSummaryCard("Total", _totalCount.toString(), Colors.blue),
                  const SizedBox(width: 12),
                  _buildSummaryCard("Active", _activeCount.toString(), Colors.orange),
                  const SizedBox(width: 12),
                  _buildSummaryCard("Resolved", _resolvedCount.toString(), Colors.green),
                ],
              ),
            ),
          ),

          // 3. Filter Bar (Pinned)
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverFilterDelegate(
              child: Container(
                color: Colors.grey.shade50,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: ['All', 'Active', 'Resolved'].map((filter) {
                      bool isSelected = _activeFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (val) => setState(() => _activeFilter = filter),
                          selectedColor: AppColors.primary,
                          labelStyle: GoogleFonts.inter(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                          backgroundColor: Colors.white,
                          elevation: isSelected ? 4 : 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          side: BorderSide(color: isSelected ? AppColors.primary : Colors.grey.shade200),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),

          // 4. Content Area
          if (_isLoading && _reports.isEmpty)
            SliverFillRemaining(child: _buildLoadingSkeleton())
          else if (_error != null && _reports.isEmpty)
             SliverFillRemaining(child: _buildErrorState())
          else if (filteredList.isEmpty)
             SliverFillRemaining(child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final report = filteredList[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ImprovedReportCard(
                        report: report,
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ComplaintDetailsScreen(report: report, user: widget.user),
                        )),
                        onUpvote: () => _handleUpvote(report['id']),
                        onShare: () => CivicShareSheet.show(context, report),
                        fallbackDistrict: widget.user.district ?? 'Tamil Nadu',
                      ),
                    );
                  },
                  childCount: filteredList.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text("No reports found", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Text(_activeFilter == 'All' ? "You haven't filed any complaints yet." : "No reports match this status.", 
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.grey.shade500)
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text("Oops! Connection Failed", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error ?? "Unknown error", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _loadReports, child: const Text("Try Again")),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUpvote(String id) async {
    try {
      await AadhaarApi.upvoteReport(id, widget.user.id, widget.user.photoUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support added!'), backgroundColor: Colors.green));
        _loadReports();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.shade50),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: 140,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SliverFilterDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SliverFilterDelegate({required this.child});

  @override
  double get minExtent => 80;
  @override
  double get maxExtent => 80;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}
