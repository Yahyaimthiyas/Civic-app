/// @file public_feed_screen.dart
/// @description Main dashboard and public feed interface.
/// Professionally structured and maintained by the Civic App Team.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutterapp/features/auth/data/services/aadhaar_api.dart';
import 'package:flutterapp/core/theme/app_colors.dart';
import 'package:flutterapp/core/widgets/improved_report_card.dart';
import 'package:flutterapp/core/widgets/share_sheet.dart';
import 'package:flutterapp/features/complaints/presentation/screens/complaint_details_screen.dart';

const List<String> tnDistricts = [
  'All Districts',
  'Ariyalur',
  'Chengalpattu',
  'Chennai',
  'Coimbatore',
  'Cuddalore',
  'Dharmapuri',
  'Dindigul',
  'Erode',
  'Kallakurichi',
  'Kancheepuram',
  'Karur',
  'Krishnagiri',
  'Madurai',
  'Mayiladuthurai',
  'Nagapattinam',
  'Namakkal',
  'Nilgiris',
  'Perambalur',
  'Pudukkottai',
  'Ramanathapuram',
  'Ranipet',
  'Salem',
  'Sivaganga',
  'Tenkasi',
  'Thanjavur',
  'Theni',
  'Thoothukudi',
  'Tiruchirappalli',
  'Tirunelveli',
  'Tirupathur',
  'Tiruppur',
  'Tiruvallur',
  'Tiruvannamalai',
  'Tiruvarur',
  'Vellore',
  'Viluppuram',
  'Virudhunagar',
  'Kanyakumari'
];

final Map<String, String> _categoryDisplayNames = {
  'pothole': 'Pothole',
  'streetlight_not_working': 'Streetlight',
  'garbage_overflow': 'Garbage',
  'water_leakage': 'Water Leak',
  'sewage_overflow': 'Sewage',
};

String _getFormattedCategory(String cat) {
  if (_categoryDisplayNames.containsKey(cat)) return _categoryDisplayNames[cat]!;
  // Fallback: "garbage_overflow" -> "Garbage Overflow"
  return cat.split('_').map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '').join(' ');
}

class PublicFeedScreen extends StatefulWidget {
  final AadhaarUser user;
  const PublicFeedScreen({super.key, required this.user});

  @override
  State<PublicFeedScreen> createState() => _PublicFeedScreenState();
}

class _PublicFeedScreenState extends State<PublicFeedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedDistrict = 'All Districts';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialDistrict();
  }

  Future<void> _loadInitialDistrict() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDist = prefs.getString('last_detected_district');
      if (lastDist != null && tnDistricts.contains(lastDist)) {
        if (mounted) {
           setState(() {
             _selectedDistrict = lastDist;
           });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Community Hub', style: GoogleFonts.inter(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedDistrict,
                icon: const Icon(Icons.location_on, size: 16, color: AppColors.primary),
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w600),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedDistrict = newValue;
                    });
                  }
                },
                items: tnDistricts.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: "Feed"),
            Tab(text: "Analytics"),
            Tab(text: "Leaderboard"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          FeedTab(user: widget.user, district: _selectedDistrict),
          AnalyticsTab(user: widget.user, district: _selectedDistrict),
          LeaderboardTab(user: widget.user, district: _selectedDistrict),
        ],
      ),
    );
  }
}

// --- TAB 1: FEED ---
class FeedTab extends StatefulWidget {
  final AadhaarUser user;
  final String district;
  const FeedTab({super.key, required this.user, required this.district});
  @override
  State<FeedTab> createState() => _FeedTabState();
}
class _FeedTabState extends State<FeedTab> {
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFromCache();
    _fetchFeed();
  }

  @override
  void didUpdateWidget(FeedTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.district != widget.district) {
      _fetchFeed();
    }
  }

  Future<void> _fetchFeed() async {
    setState(() => _isLoading = true);
    try {
      final data = await AadhaarApi.fetchPublicFeed(district: widget.district);
      if (mounted) {
        setState(() { _reports = data; _isLoading = false; });
        final prefs = await SharedPreferences.getInstance();
        final key = 'feed_${widget.user.id}_${widget.district}';
        await prefs.setString(key, jsonEncode(_reports));
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'feed_${widget.user.id}_${widget.district}';
      final json = prefs.getString(key);
      if (json == null) return;
      final decoded = jsonDecode(json) as List;
      final cached = decoded.map((e) => (e as Map).cast<String, dynamic>()).toList();
      if (!mounted) return;
      if (cached.isNotEmpty) {
        setState(() { _reports = cached; _isLoading = false; });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isLoading && _reports.isEmpty) const LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchFeed,
            color: AppColors.primary,
            child: _reports.isEmpty && !_isLoading
                ? ListView(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                      Center(child: Text("No reports in ${widget.district}", style: GoogleFonts.inter())),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: _reports.length,
                      itemBuilder: (ctx, i) {
                        final report = _reports[i];
                        return ImprovedReportCard(
                          report: report,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ComplaintDetailsScreen(report: report, user: widget.user),
                              ),
                            );
                          },
                          onUpvote: () async {
                            try {
                              await AadhaarApi.upvoteReport(report['id'], widget.user.id, widget.user.photoUrl);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upvoted!')));
                                _fetchFeed(); // Refresh to show new count
                              }
                            } catch (_) {}
                          },
                          onShare: () => CivicShareSheet.show(context, report),
                          fallbackDistrict: widget.district,
                        );
                      },
                  ),
          ),
        )
      ],
    );
  }

  Widget _buildLoadingSkeleton() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 150, color: Colors.grey.shade200),
            const SizedBox(height: 12),
            Container(height: 14, width: 120, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Container(height: 12, width: double.infinity, color: Colors.grey.shade200),
          ],
        ),
      ),
    );
  }

}

// --- TAB 2: ANALYTICS ---
class AnalyticsTab extends StatefulWidget {
  final AadhaarUser user;
  final String district;
  const AnalyticsTab({super.key, required this.user, required this.district});
  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}
class _AnalyticsTabState extends State<AnalyticsTab> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  @override
  void didUpdateWidget(AnalyticsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.district != widget.district) {
      _fetchStats();
    }
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      final data = await AadhaarApi.fetchCommunityAnalytics(widget.district);
      if (mounted) setState(() { _stats = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _stats == null) return const Center(child: CircularProgressIndicator());
    if (_stats == null) return Center(child: Text("No Data for ${widget.district}"));
    
    final catCounts = Map<String, int>.from(_stats!['categoryCounts'] ?? {});
    final total = _stats!['total'] ?? 0;
    final resolved = _stats!['resolved'] ?? 0;
    final pending = _stats!['pending'] ?? 0;
    final inProgress = _stats!['inProgress'] ?? 0;

    return RefreshIndicator(
      onRefresh: _fetchStats,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text("Overview", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                  child: Text(widget.district, style: GoogleFonts.inter(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w500)),
                )
              ],
            ),
            const SizedBox(height: 16),
            _buildStatGrid(resolved, pending, inProgress),
            const SizedBox(height: 24),
            _buildCard(
              title: "Category Breakdown",
              child: SizedBox(
                height: 220,
                child: catCounts.isEmpty ? const Center(child: Text("No breakdown available")) : PieChart(
                  PieChartData(
                    sections: catCounts.entries.map((e) {
                       final color = Colors.primaries[e.key.hashCode % Colors.primaries.length];
                       return PieChartSectionData(
                         value: e.value.toDouble(),
                         title: total > 0 ? "${((e.value/total)*100).toStringAsFixed(0)}%" : "0%",
                         radius: 60,
                         color: color,
                         titleStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                         badgeWidget: _buildBadge(_getFormattedCategory(e.key), color)
                       );
                    }).toList(),
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
             _buildCard(
              title: "Weekly Trend",
              child: SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                     gridData: const FlGridData(show: false),
                     titlesData: FlTitlesData(
                       show: true,
                       bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, meta) => Text("Day ${val.toInt()}", style: const TextStyle(fontSize: 10)))),
                       leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: 5)),
                       topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                       rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                     ),
                     borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade200)),
                     lineBarsData: [
                       LineChartBarData(
                         spots: (_stats!['trendData'] as List? ?? []).asMap().entries.map((e) {
                            return FlSpot(e.key.toDouble(), (e.value['count'] as num).toDouble());
                         }).toList(),
                         isCurved: true,
                         color: AppColors.primary,
                         barWidth: 3,
                         dotData: const FlDotData(show: true),
                         belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.1)),
                       )
                     ]
                  )
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: color)),
      child: Text(text, style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.bold)),
    );
  }
  
  Widget _buildStatGrid(int resolved, int pending, int remaining) {
    return Row(
      children: [
        Expanded(child: _statCard("Resolved", "$resolved", Colors.green, Icons.check_circle)),
        const SizedBox(width: 12),
        Expanded(child: _statCard("Pending", "$pending", Colors.orange, Icons.pending)),
        const SizedBox(width: 12),
        Expanded(child: _statCard("Remaining", "$remaining", Colors.blue, Icons.history_rounded)),
      ],
    );
  }
  
  Widget _statCard(String label, String count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(count, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          child
        ],
      ),
    );
  }
}

// --- TAB 3: LEADERBOARD ---
class LeaderboardTab extends StatefulWidget {
  final AadhaarUser user;
  final String district;
  const LeaderboardTab({super.key, required this.user, required this.district});
  @override
  State<LeaderboardTab> createState() => _LeaderboardTabState();
}
class _LeaderboardTabState extends State<LeaderboardTab> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInternal();
  }

  @override
  void didUpdateWidget(LeaderboardTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.district != widget.district) {
      _fetchInternal();
    }
  }

  Future<void> _fetchInternal() async {
    setState(() => _isLoading = true);
    try {
      final data = await AadhaarApi.fetchLeaderboard(widget.district);
      if (mounted) setState(() { _users = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _users.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_users.isEmpty) return Center(child: Text("No contributions yet in ${widget.district}"));

    return RefreshIndicator(
      onRefresh: _fetchInternal,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length + 1, // Header
        itemBuilder: (ctx, i) {
          if (i == 0) return _buildHeader();
          final u = _users[i - 1];
          final rank = i;
          return _buildLeaderboardTile(u, rank);
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Top Contributors", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(widget.district, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTile(Map<String, dynamic> user, int rank) {
    final isTop3 = rank <= 3;
    final color = rank == 1 ? const Color(0xFFFFD700) : (rank == 2 ? const Color(0xFFC0C0C0) : (rank == 3 ? const Color(0xFFCD7F32) : Colors.grey.shade100));
    final textColor = rank <= 3 ? Colors.white : Colors.black;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isTop3 ? Border.all(color: color.withValues(alpha: 0.5)) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))]
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text("#$rank", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          CircleAvatar(backgroundColor: Colors.blue.shade50, child: Text(user['name']?[0] ?? 'U', style: const TextStyle(color: Colors.blue))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['name'] ?? 'User', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                Text("${user['reports']} Reports • ${user['resolved']} Resolved", style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               Text("${user['score']}", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16)),
               Text("pts", style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
             ],
          ),
        ],
      ),
    );
  }
}
