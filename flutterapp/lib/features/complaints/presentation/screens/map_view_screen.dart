/// @file map_view_screen.dart
/// @description Handles the reporting, mapping, and viewing of civic issues.
/// Professionally structured and maintained by the Civic App Team.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutterapp/features/auth/data/services/aadhaar_api.dart';
import 'package:flutterapp/core/theme/app_colors.dart';
import 'package:flutterapp/features/complaints/presentation/screens/complaint_details_screen.dart';

class MapViewScreen extends StatefulWidget {
   final dynamic user;
   const MapViewScreen({super.key, this.user});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  final MapController _mapController = MapController();
  final Location _location = Location();

  // State
  List<Marker> _markers = [];
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = false;
  
  // Debouncing
  Timer? _debounceTimer;

  // Default: Anna Salai, Chennai
  static const LatLng _defaultLocation = LatLng(13.0604, 80.2496);
  LatLng _userPosition = _defaultLocation;

  // Filters
  String _selectedCategory = 'All';
  String _selectedSeverity = 'All';
  String _selectedDateRange = 'All';

  final List<String> _categories = ['All', 'pothole', 'garbage_overflow', 'streetlight_not_working', 'water_leakage', 'stray_animals', 'tree_fallen'];
  
  // Display names for UI
  final Map<String, String> _categoryDisplayNames = {
    'All': 'All',
    'pothole': 'Potholes',
    'garbage_overflow': 'Garbage',
    'streetlight_not_working': 'Street Lights',
    'water_leakage': 'Water',
    'stray_animals': 'Animals',
    'tree_fallen': 'Trees'
  };
  final List<String> _severities = ['All', 'Low', 'Medium', 'High', 'Critical'];
  final List<String> _dateRanges = ['All', 'Today', 'Week', 'Month'];

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _loadReports();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _scheduleLoadReports() {
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    // Schedule new load after 500ms
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _loadReports();
    });
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    final locationData = await _location.getLocation();
    if (locationData.latitude != null && locationData.longitude != null && mounted) {
      setState(() {
        _userPosition = LatLng(locationData.latitude!, locationData.longitude!);
      });
      _mapController.move(_userPosition, 15.0);
    }
  }

  Future<void> _loadReports() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final reports = await AadhaarApi.fetchPublicFeed(
        category: _selectedCategory,
        severity: _selectedSeverity,
        dateRange: _selectedDateRange.toLowerCase(),
      );

      _reports = reports;
      _generateMarkers();

    } catch (e) {
      debugPrint("Error loading map reports: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _generateMarkers() {
    _markers = _reports.map((report) {
         final img = report['imageUrl'];
         final images = report['images'] as List?;
         final loc = report['location'];
         if (loc == null) {
           debugPrint("Skipping report ${report['id']} - No location found");
           return null;
         }

         // Robust parsing for Lat/Lng
         // Supports: { latitude: 12.3, longitude: 80.1 } AND { lat: 12.3, lng: 80.1 }
         dynamic latVal = loc['latitude'] ?? loc['lat'];
         dynamic lngVal = loc['longitude'] ?? loc['lng'];

         if (latVal == null || lngVal == null) {
            // Check if it's a string "lat,lng"
            if (loc is String && loc.contains(',')) {
               final parts = loc.split(',');
               latVal = parts[0];
               lngVal = parts[1];
            } else {
               return null;
            }
         }

         double lat = double.tryParse(latVal.toString()) ?? 0.0;
         double lng = double.tryParse(lngVal.toString()) ?? 0.0;

         if (lat == 0 && lng == 0) return null;

         return Marker(
           point: LatLng(lat, lng),
           width: 50,
           height: 50,
           child: _buildMarkerIcon(report),
         );
    }).whereType<Marker>().toList();
  }

  Widget _buildMarkerIcon(Map<String, dynamic> report) {
    final category = report['category']?.toString() ?? 'other';
    IconData iconData = Icons.location_on;
    Color color = Colors.orange;

    if (category.contains('pothole') || category.contains('road')) {
      iconData = Icons.edit_road;
      color = Colors.blueGrey;
    } else if (category.contains('garbage') || category.contains('trash') || category.contains('dustbin')) {
      iconData = Icons.delete_outline;
      color = Colors.brown;
    } else if (category.contains('light')) {
      iconData = Icons.lightbulb_outline;
      color = Colors.orange;
    } else if (category.contains('water') || category.contains('leak') || category.contains('sewage')) {
      iconData = Icons.water_drop_outlined;
      color = Colors.blue;
    } else if (category.contains('animal')) {
      iconData = Icons.pets;
      color = Colors.deepOrange;
    } else if (category.contains('tree') || category.contains('garden')) {
      iconData = Icons.park;
      color = Colors.green;
    } else if (category.contains('planning') || category.contains('construction')) {
      iconData = Icons.architecture;
      color = Colors.deepPurple;
    }

    if (report['status'] == 'RESOLVED') {
       color = Colors.green; // Override color for resolved
       iconData = Icons.check_circle;
    }

    return GestureDetector(
      onTap: () => _showReportDetails(report),
      child: RepaintBoundary(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
            border: Border.all(color: color, width: 2)
          ),
          padding: const EdgeInsets.all(6),
          child: Icon(iconData, color: color, size: 24),
        ),
      ),
    );
  }

  void _showReportDetails(Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: 380,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
        ),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.only(top: 12), height: 4, width: 40, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _getStatusBgColor(report['status'] ?? 'pending'),
                            borderRadius: BorderRadius.circular(8)
                          ),
                          child: Text((report['status'] ?? 'Pending').toString().toUpperCase(), style: TextStyle(color: _getStatusTextColor(report['status'] ?? 'pending'), fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Text(
                            _formatDate(report['createdAt']),
                            style: const TextStyle(color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(_getDisplayName(report['category']), style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(height: 8),
                    Text(report['description'] ?? 'No description', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade700), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 24),
                    if (report['location'] != null && report['location'] is Map && report['location']['address'] != null)
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(report['location']['address'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w500))),
                        ],
                      ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (widget.user != null) {
                             Navigator.push(context, MaterialPageRoute(builder: (_) => ComplaintDetailsScreen(report: report, user: widget.user)));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("View Full Details", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomStats() {
    int total = _reports.length;
    int resolved = _reports.where((r) => r['status'] == 'RESOLVED').length;
    int pending = total - resolved;

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("Reports", total.toString(), Colors.orange),
          _buildStatItem("Pending", pending.toString(), Colors.redAccent),
          _buildStatItem("Resolved", resolved.toString(), Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultLocation,
              initialZoom: 12.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.myfirstapp.sevatrack',
              ),
              MarkerLayer(markers: _markers),
            ],
          ),

          // Header
          Positioned(
            top: 50, left: 16, right: 16,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back, color: Colors.black87),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text("Live Issue Map", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) :
                      IconButton(icon: const Icon(Icons.refresh, color: Colors.orange), onPressed: _loadReports),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ..._categories.map((cat) => _buildFilterItem(cat, _selectedCategory, (val) => setState(() {
                        _selectedCategory = val;
                        _scheduleLoadReports();
                      }))),
                      const SizedBox(width: 8),
                      ..._severities.map((sev) => _buildFilterItem(sev, _selectedSeverity, (val) => setState(() {
                        _selectedSeverity = val;
                        _scheduleLoadReports();
                      }))),
                      const SizedBox(width: 8),
                      ..._dateRanges.map((range) => _buildFilterItem(range, _selectedDateRange, (val) => setState(() {
                        _selectedDateRange = val;
                        _scheduleLoadReports();
                      }))),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // FAB for location
           Positioned(
            bottom: 120, right: 16,
            child: FloatingActionButton.small(
               heroTag: "loc_btn",
               backgroundColor: Colors.white,
               child: const Icon(Icons.my_location, color: AppColors.primary),
               onPressed: () {
                   _mapController.move(_userPosition, 15.0);
               },
            ),
          ),

          // Bottom Stats Card
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _buildBottomStats(),
          ),
          
          // Loading Overlay
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text("Loading reports...", style: TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildFilterItem(String value, String selectedValue, Function(String) onSelected) {
    bool isSelected = selectedValue == value;
    String displayLabel = _categoryDisplayNames[value] ?? value;
    return GestureDetector(
      onTap: () => onSelected(value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
          border: Border.all(color: isSelected ? Colors.orange : Colors.grey.shade200),
        ),
        child: Text(
          displayLabel,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  String _getDisplayName(dynamic category) {
    if (category == null) return 'Public Issue';
    String cat = category.toString();
    if (_categoryDisplayNames.containsKey(cat)) return _categoryDisplayNames[cat]!;
    // Fallback for slugs: "garbage_overflow" -> "Garbage Overflow"
    return cat.split('_').map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '').join(' ');
  }

  Color _getStatusBgColor(String status) {
    status = status.toLowerCase();
    if (status == 'resolved') return Colors.green.shade50;
    if (status == 'rejected') return Colors.red.shade50;
    if (status == 'in_progress') return Colors.blue.shade50;
    return Colors.orange.shade50;
  }

  Color _getStatusTextColor(String status) {
    status = status.toLowerCase();
    if (status == 'resolved') return Colors.green;
    if (status == 'rejected') return Colors.red;
    if (status == 'in_progress') return Colors.blue;
    return Colors.orange;
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Just now';
    DateTime? dt;
    if (dateValue is String) {
      dt = DateTime.tryParse(dateValue);
    } else if (dateValue is Map && dateValue.containsKey('_seconds')) {
      dt = DateTime.fromMillisecondsSinceEpoch(dateValue['_seconds'] * 1000);
    }
    
    if (dt == null) return 'Just now';
    return DateFormat('dd MMM yyyy').format(dt);
  }
}
