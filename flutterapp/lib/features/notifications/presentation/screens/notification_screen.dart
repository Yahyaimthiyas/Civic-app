/// @file notification_screen.dart
/// @description Real-time alert and notification center.
/// Professionally structured and maintained by the Civic App Team.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutterapp/core/theme/app_colors.dart';
import 'package:flutterapp/features/auth/data/services/aadhaar_api.dart';
import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutterapp/features/complaints/presentation/screens/complaint_details_screen.dart';

class NotificationScreen extends StatefulWidget {
  final AadhaarUser user;
  const NotificationScreen({super.key, required this.user});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  String _activeFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) _loadNotifications(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final data = await AadhaarApi.fetchNotifications(widget.user.id);
      if (mounted) {
        setState(() {
          _notifications = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await AadhaarApi.markNotificationRead(id);
      _loadNotifications(silent: true);
    } catch (e) {
      debugPrint("Error marking read: $e");
    }
  }

  Future<void> _markAllRead() async {
    try {
      await AadhaarApi.markAllNotificationsRead(widget.user.id);
      _loadNotifications(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All marked as read')));
      }
    } catch (e) {
      debugPrint("Error marking all read: $e");
    }
  }

  List<Map<String, dynamic>> get _filteredNotifications {
    if (_activeFilter == 'All') return _notifications;
    return _notifications.where((n) {
       if (_activeFilter == 'Unread') return n['isRead'] == false;
       final type = n['type']?.toString().toUpperCase() ?? 'UPDATE';
       if (_activeFilter == 'Updates') return type == 'UPDATE';
       if (_activeFilter == 'Alerts') return type == 'DANGER';
       if (_activeFilter == 'Personal') return type == 'AWARD' || type == 'SUCCESS';
       return true;
    }).toList();
  }

  Future<void> _navigateToReport(String reportId) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
      
      final report = await AadhaarApi.fetchReportDetails(reportId);
      
      if (mounted) {
        Navigator.pop(context); // Pop loading
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ComplaintDetailsScreen(report: report, user: widget.user),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Pop loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load report details')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Notifications', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: Colors.black87), 
            onPressed: _markAllRead,
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildTab('All'),
                  _buildTab('Unread'),
                  _buildTab('Updates'),
                  _buildTab('Alerts'),
                  _buildTab('Personal'),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _filteredNotifications.isEmpty 
                ? RefreshIndicator(onRefresh: _loadNotifications, child: ListView(children: [const SizedBox(height: 100), _buildEmptyState()]))
                : RefreshIndicator(
                    onRefresh: _loadNotifications,
                    child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _filteredNotifications.length,
                        itemBuilder: (context, index) {
                          final n = _filteredNotifications[index];
                          return _buildNotificationItem(n);
                        },
                      ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(_activeFilter == 'All' ? "No notifications yet" : "No $_activeFilter notifications", style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildTab(String label) {
    final isSelected = _activeFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isSelected ? AppColors.accent : Colors.transparent, width: 2)),
        ),
        child: Text(label, style: GoogleFonts.inter(color: isSelected ? AppColors.accent : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> n) {
    String type = n['type']?.toString().toUpperCase() ?? 'UPDATE';
    IconData icon = Icons.notifications_none;
    Color color = AppColors.primary;
    
    if (type == 'UPDATE') { icon = Icons.info_outline; color = AppColors.primary; }
    else if (type == 'DANGER') { icon = Icons.report_problem_outlined; color = Colors.red; }
    else if (type == 'SUCCESS') { icon = Icons.check_circle_outline; color = AppColors.success; }
    else if (type == 'AWARD') { icon = Icons.emoji_events_outlined; color = AppColors.accent; }

    final bool isUnread = n['isRead'] == false;
    final String time = _formatTime(n['createdAt']);
    final String? reportId = n['reportId'];
    final String? actorPhoto = n['actorPhoto'];

    return GestureDetector(
      onTap: () async {
        if (isUnread) await _markRead(n['id']);
        
        if (reportId != null && mounted) {
          _navigateToReport(reportId);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isUnread ? color.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isUnread ? color.withValues(alpha: 0.1) : Colors.grey.shade100),
          boxShadow: isUnread ? [BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 4, color: isUnread ? color : Colors.transparent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (actorPhoto != null && actorPhoto.isNotEmpty)
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
                              image: DecorationImage(
                                image: actorPhoto.startsWith('data:image') 
                                    ? MemoryImage(base64Decode(actorPhoto.split(',').last)) as ImageProvider
                                    : CachedNetworkImageProvider(actorPhoto),
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                            child: Icon(icon, color: color, size: 22),
                          ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(type, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: color, letterSpacing: 1)),
                                  Text(time, style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(n['title'] ?? 'Notification', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
                              const SizedBox(height: 4),
                              Text(n['message'] ?? '', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600, height: 1.4)),
                            ],
                          ),
                        ),
                        if (isUnread)
                           Padding(
                             padding: const EdgeInsets.only(left: 8, top: 20),
                             child: Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                           ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(dynamic createdAt) {
    if (createdAt == null) return "Unknown";
    try {
      final dt = DateTime.parse(createdAt.toString());
      final diff = DateTime.now().difference(dt);
      
      if (diff.inMinutes < 60) return "${diff.inMinutes}M AGO";
      if (diff.inHours < 24) return "${diff.inHours}H AGO";
      if (diff.inDays < 7) return "${diff.inDays}D AGO";
      return DateFormat('dd MMM').format(dt);
    } catch (e) {
      return "Just now";
    }
  }
}
