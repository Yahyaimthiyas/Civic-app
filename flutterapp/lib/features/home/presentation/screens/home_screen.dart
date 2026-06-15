/// @file home_screen.dart
/// @description Main dashboard and public feed interface.
/// Professionally structured and maintained by the Civic App Team.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutterapp/features/auth/data/services/aadhaar_api.dart';
import 'package:flutterapp/features/complaints/presentation/screens/report_screen.dart';
import 'package:flutterapp/features/home/presentation/screens/public_feed_screen.dart';
import 'package:flutterapp/features/complaints/presentation/screens/map_view_screen.dart';
import 'package:flutterapp/features/profile/presentation/screens/profile_impact_screen.dart';
import 'package:flutterapp/features/chatbot/presentation/screens/chatbot_screen.dart';
import 'package:flutterapp/features/notifications/presentation/screens/notification_screen.dart';
import 'package:flutterapp/core/widgets/dashboard_view.dart';
import 'package:flutterapp/core/theme/app_colors.dart';

/// The main navigation hub for the user.
///
/// Contains the bottom navigation bar and handles switching between the Dashboard,
/// Map, Community Feed, and Profile views. Also displays notifications.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user});

  final AadhaarUser user;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _unreadNotifications = 0;
  Timer? _notifTimer;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardView(user: widget.user),
      MapViewScreen(user: widget.user),
      PublicFeedScreen(user: widget.user),
      CitizenImpactScreen(user: widget.user),
    ];
    _fetchUnreadCount();
    _notifTimer = Timer.periodic(const Duration(seconds: 45), (timer) {
       if (mounted) _fetchUnreadCount();
    });
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final notifs = await AadhaarApi.fetchNotifications(widget.user.id);
      if (mounted) {
        setState(() {
          _unreadNotifications = notifs.where((n) => n['isRead'] == false).length;
        });
      }
    } catch (_) {}
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Remove default back button or leading
        title: Text(
          'Tamil Nadu Civic',
          style: GoogleFonts.inter(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.black87),
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationScreen(user: widget.user)));
                  _fetchUnreadCount(); // Refresh count when coming back
                },
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      '$_unreadNotifications',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Chatbot FAB
            FloatingActionButton.small(
              heroTag: 'chatbot_fab',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatbotScreen(user: widget.user))),
              backgroundColor: Colors.white,
              child: const Icon(Icons.smart_toy_outlined, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            // Main Report FAB
            FloatingActionButton(
              heroTag: 'report_fab',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportScreen(user: widget.user))),
              backgroundColor: AppColors.accent,
              child: const Icon(Icons.add, color: Colors.white, size: 30),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 12,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'Home'),
              _buildNavItem(1, Icons.map_rounded, 'Map'),
              const SizedBox(width: 40), // Space for FAB
              _buildNavItem(2, Icons.people_rounded, 'Community'),
              _buildNavItem(3, Icons.person_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? AppColors.accent : Colors.grey.shade400,
            size: 24,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppColors.accent : Colors.grey.shade400,
            ),
          )
        ],
      ),
    );
  }
}

