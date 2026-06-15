/// @file dashboard_view.dart
/// @description Core UI component for the Civic App.
/// Professionally structured and maintained by the Civic App Team.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutterapp/features/auth/data/services/aadhaar_api.dart';
import 'package:flutterapp/features/complaints/presentation/screens/report_screen.dart';
import 'package:flutterapp/features/complaints/presentation/screens/my_reports_screen.dart';
import 'package:flutterapp/features/complaints/presentation/screens/complaint_details_screen.dart';
import 'package:flutterapp/core/theme/app_colors.dart';

class DashboardView extends StatefulWidget {
  final AadhaarUser user;
  const DashboardView({super.key, required this.user});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _nearbyReports = [];
  Map<String, dynamic> _stats = {'total': 0, 'resolved': 0, 'pending': 0, 'inProgress': 0, 'verified': 0, 'rejected': 0};
  List<Map<String, dynamic>> _myRecentReports = [];
  String? _detectedDistrict;

  @override
  void initState() {
    super.initState();
    _loadFromCache();
    _loadDashboardData();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keyPrefix = 'dashboard_${widget.user.id}_';

      final nearbyJson = prefs.getString('${keyPrefix}nearby');
      final statsJson = prefs.getString('${keyPrefix}stats');
      final myJson = prefs.getString('${keyPrefix}myReports');
      final cachedDist = prefs.getString('last_detected_district');

      List<Map<String, dynamic>> nearby = _nearbyReports;
      Map<String, dynamic> stats = _stats;
      List<Map<String, dynamic>> myReports = _myRecentReports;

      if (cachedDist != null) _detectedDistrict = cachedDist;

      if (nearbyJson != null) {
        final decoded = jsonDecode(nearbyJson) as List;
        nearby =
            decoded.map((e) => (e as Map).cast<String, dynamic>()).toList();
      }
      if (statsJson != null) {
        final decoded = jsonDecode(statsJson) as Map;
        stats = decoded.cast<String, dynamic>();
      }
      if (myJson != null) {
        final decoded = jsonDecode(myJson) as List;
        myReports =
            decoded.map((e) => (e as Map).cast<String, dynamic>()).toList();
      }

      if (!mounted) return;
      if (nearby.isNotEmpty || myReports.isNotEmpty) {
        setState(() {
          _nearbyReports = nearby;
          _stats = stats;
          _myRecentReports = myReports;
        });
      }
    } catch (_) {
      // ignore cache errors
    }
  }

  Future<void> _determineDistrict() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      Position position = await Geolocator.getCurrentPosition(
              locationSettings:
                  const LocationSettings(accuracy: LocationAccuracy.medium))
          .timeout(const Duration(seconds: 5));

      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        setState(() {
          _detectedDistrict = placemarks[0].subAdministrativeArea ??
              placemarks[0].locality ??
              widget.user.district;
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_detected_district', _detectedDistrict!);
      }
    } catch (e) {
      debugPrint("Error detecting district: $e");
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    
    // First try to determine current district
    await _determineDistrict();
    final String district = _detectedDistrict ?? widget.user.district ?? 'Chennai';

    try {
      final results = await Future.wait([
        AadhaarApi.fetchPublicFeed(district: district).catchError((_) => <Map<String, dynamic>>[]),
        AadhaarApi.fetchDistrictStats(district).catchError((_) => {'total': 0, 'resolved': 0, 'pending': 0}),
        AadhaarApi.fetchUserReports(widget.user.id).catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (mounted) {
        setState(() {
          _nearbyReports = results[0] as List<Map<String, dynamic>>;
          _stats = results[1] as Map<String, dynamic>;
          _myRecentReports = results[2] as List<Map<String, dynamic>>;
          _isLoading = false;
        });

        final prefs = await SharedPreferences.getInstance();
        final keyPrefix = 'dashboard_${widget.user.id}_';
        await prefs.setString(
            '${keyPrefix}nearby', jsonEncode(_nearbyReports));
        await prefs.setString('${keyPrefix}stats', jsonEncode(_stats));
        await prefs.setString(
            '${keyPrefix}myReports', jsonEncode(_myRecentReports));
      }
    } catch (e) {
      debugPrint('Dashboard Load Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _nearbyReports.isEmpty && _myRecentReports.isEmpty) {
      return _buildLoadingSkeleton();
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: Colors.orange,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              Text(
                'Vanakkam, ${widget.user.name.split(' ')[0]}',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.orange.shade800),
              ),
              const SizedBox(height: 24),

              // Hero Card
              _buildHeroCard(context),

              const SizedBox(height: 32),

              // Your Recent Complaints
              if (_myRecentReports.isNotEmpty) ...[
                _buildSectionHeader("Your Recent Complaints", () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => MyReportsScreen(user: widget.user)));
                }),
                const SizedBox(height: 16),
                ..._myRecentReports.take(2).map((report) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildComplaintCard(
                    title: report['category'] ?? 'Issue',
                    status: report['status'] ?? 'PENDING',
                    location: report['location']?['address']?.split(',')[0] ?? 'Unknown',
                    progress: (report['status'] == 'RESOLVED' ? 1.0 : (report['status'] == 'IN_PROGRESS' ? 0.6 : 0.2)),
                    icon: _getCategoryIcon(report['category'] ?? ''),
                    color: AppColors.accent.withValues(alpha: 0.1),
                    iconColor: _getStatusColor(report['status'] ?? 'PENDING'),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ComplaintDetailsScreen(report: report, user: widget.user))),
                  ),
                )),
                const SizedBox(height: 20),
              ],

              // Nearby in District
              _buildSectionHeader("Nearby in ${_detectedDistrict ?? widget.user.district ?? 'Chennai'}", null),
              const SizedBox(height: 16),
              SizedBox(
                height: 210,
                child: _nearbyReports.isEmpty 
                 ? const Center(child: Text("No nearby reports found"))
                 : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _nearbyReports.length,
                    itemBuilder: (context, index) {
                      final report = _nearbyReports[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: _buildNearbyCard(
                          report: report,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ComplaintDetailsScreen(report: report, user: widget.user))),
                        ),
                      );
                    },
                  ),
              ),

              const SizedBox(height: 32),
              
              // Impact Stats
              _buildImpactStats(),

              const SizedBox(height: 80), 
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 16,
              width: 140,
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 26,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              height: 18,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback? onSeeAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0B3D91))),
        if (onSeeAll != null)
          TextButton(onPressed: onSeeAll, child: Text('View All', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFFFF9933)))),
      ],
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Column(
        children: [
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Icon(Icons.assignment_turned_in_outlined, size: 150, color: Colors.white.withValues(alpha: 0.1)),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "TAMIL NADU",
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "CIVIC CONNECT",
                        style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Report a Public Issue', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0B3D91))),
                const SizedBox(height: 8),
                Text('Help improve your neighborhood by reporting infrastructure problems directly to authorities.', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600, height: 1.5)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportScreen(user: widget.user))),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                  child: const Text('Report Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactStats() {
    final resolved = _stats['resolved'] ?? 0;
    final active = (_stats['pending'] ?? 0) + (_stats['inProgress'] ?? 0) + (_stats['verified'] ?? 0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.orange.shade50), boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 4))]),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('DISTRICT IMPACT', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: const Color(0xFF0B3D91))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFFF9933), borderRadius: BorderRadius.circular(20)), child: const Text('LIVE STATS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildStatItem('$resolved', 'RESOLVED'),
              Container(width: 1, height: 40, color: Colors.grey.shade300),
              const SizedBox(width: 24),
              _buildStatItem('$active', 'ACTIVE ISSUES'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF0B3D91))),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildComplaintCard({required String title, required String status, required String location, required double progress, required IconData icon, required Color color, required Color iconColor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: iconColor)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0B3D91))),
                  Text('$location • Updated', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: iconColor)),
                      const SizedBox(width: 8),
                      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress, backgroundColor: Colors.grey.shade100, valueColor: AlwaysStoppedAnimation<Color>(iconColor), minHeight: 4))),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyCard({required Map<String, dynamic> report, required VoidCallback onTap}) {
    final title = report['category'] ?? 'Public Issue';
    final location = report['location']?['address']?.split(',')[0] ?? 'Tamil Nadu';
    
    // Support Base64 and URL
    final images = report['images'] as List?;
    String? imageUrl = report['imageUrl'];
    if (images != null && images.isNotEmpty) {
      imageUrl = images[0]['url'] ?? images[0]['base64'];
    }
    // Auto-fix missing base64 prefix if needed
    if (imageUrl != null && imageUrl.length > 100 && !imageUrl.startsWith('http') && !imageUrl.startsWith('data:image')) {
      imageUrl = 'data:image/jpeg;base64,$imageUrl';
    }

    // SPEED OPTIMIZATION: If imageUrl is null or not a real URL/Base64, we don't use a mock Unsplash photo.
    // Instead, we show a themed placeholder inside the widget.

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 240,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: imageUrl != null && imageUrl.startsWith('data:image')
              ? Image.memory(base64Decode(imageUrl.split(',').last), height: 120, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c,e,s) => _buildNoImage())
              : (imageUrl != null && imageUrl.startsWith('http') 
                  ? CachedNetworkImage(imageUrl: imageUrl, height: 120, width: double.infinity, fit: BoxFit.cover, errorWidget: (c,u,e) => _buildNoImage())
                  : _buildNoImage())
        ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_getFormattedCategory(title), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0B3D91)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.orange.shade700),
                      const SizedBox(width: 4),
                      Expanded(child: Text(location, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    String cat = category.toLowerCase();
    if (cat.contains('road')) return Icons.edit_road;
    if (cat.contains('garbage')) return Icons.delete_outline;
    if (cat.contains('light')) return Icons.lightbulb_outline;
    if (cat.contains('water')) return Icons.water_drop_outlined;
    return Icons.assignment_outlined;
  }

  Widget _buildNoImage() {
    return Container(
      height: 120,
      width: double.infinity,
      color: Colors.grey.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined, size: 30, color: Colors.grey.shade400),
          const SizedBox(height: 4),
          Text("No Photo", style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'RESOLVED') return Colors.green;
    if (status == 'IN_PROGRESS') return Colors.orange;
    return Colors.pink;
  }

  String _getFormattedCategory(String cat) {
    final Map<String, String> categoryDisplayNames = {
      'pothole': 'Pothole',
      'streetlight_not_working': 'Streetlight',
      'garbage_overflow': 'Garbage',
      'water_leakage': 'Water Leak',
      'sewage_overflow': 'Sewage',
    };
    if (categoryDisplayNames.containsKey(cat)) return categoryDisplayNames[cat]!;
    return cat.split('_').map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '').join(' ');
  }
}
