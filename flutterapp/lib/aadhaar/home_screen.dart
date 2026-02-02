import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'services/aadhaar_api.dart';
import 'report_screen.dart';
import 'my_reports_screen.dart';
import 'public_feed_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user});

  final AadhaarUser user;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
      setState(() {
          _selectedIndex = index;
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Light grey background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black87),
          onPressed: () {},
        ),
        title: Text(
          'Tamil Nadu Civic',
          style: GoogleFonts.inter(
            color: const Color(0xFF0B3D91), 
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
             IconButton( // Logout for temp access
                icon: const Icon(Icons.logout, color: Colors.red),
                onPressed: () {
                     Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                },
             )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              Text(
                'Vanakkam, ${widget.user.name.split(' ')[0]}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Good morning',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0B3D91), // Deep Blue
                ),
              ),
              const SizedBox(height: 24),

              // Hero Card - Report Issue
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Placeholder Image Header
                    Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        image: const DecorationImage(
                            image: NetworkImage('https://images.unsplash.com/photo-1558036117-15d82a90b9b1?auto=format&fit=crop&q=80&w=800'), // Park/Public space
                            fit: BoxFit.cover,
                        )
                      ),
                    ),
                    Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(
                                    'Report a Public Issue',
                                    style: GoogleFonts.inter(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0B3D91),
                                    ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                    'Help improve your neighborhood by reporting infrastructure problems directly to authorities.',
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                        height: 1.5,
                                    ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                        onPressed: () {
                                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen()));
                                        },
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFFF9933), // TN Orange
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                            ),
                                            elevation: 0,
                                        ),
                                        child: Text(
                                            'Report Now',
                                            style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                            ),
                                        ),
                                    ),
                                )

                            ],
                        ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Your Recent Complaints
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Text(
                        'Your Recent Complaints',
                        style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0B3D91),
                        ),
                    ),
                    TextButton(
                        onPressed: (){
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const MyReportsScreen()));
                        },
                        child: Text(
                            'View All',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFF9933),
                            ),
                        ),
                    )
                ],
              ),
              const SizedBox(height: 12),
              
              // Recent Complaint Item 1
              _buildComplaintCard(
                  title: 'Pothole on Mount Road',
                  status: 'ASSIGNED',
                  location: 'Chennai',
                  progress: 0.6,
                  icon: Icons.edit_road,
                  color: const Color(0xFFFFF3E0),
                  iconColor: Colors.orange,
              ),
              const SizedBox(height: 12),
               _buildComplaintCard(
                  title: 'Streetlight Repair',
                  status: 'PENDING',
                  location: 'Madurai',
                  progress: 0.2,
                  icon: Icons.lightbulb_outline,
                  color: const Color(0xFFE3F2FD),
                  iconColor: Colors.blue,
              ),

              const SizedBox(height: 32),

               // Issues Near You
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Text(
                        'Issues Near You',
                        style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0B3D91),
                        ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              
              SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                      children: [
                           _buildNearbyCard(
                               title: 'Blocked Drainage',
                               distance: '400m away',
                               location: 'Anna Nagar',
                               imageUrl: 'https://images.unsplash.com/photo-1626262791845-e455581b8969?auto=format&fit=crop&q=80&w=400', // Drain
                           ),
                           const SizedBox(width: 16),
                            _buildNearbyCard(
                               title: 'Illegal Garbage',
                               distance: '1.2km away',
                               location: 'T. Nagar',
                               imageUrl: 'https://images.unsplash.com/photo-1530587191325-3f4e96495616?auto=format&fit=crop&q=80&w=400', // Garbage
                           ),
                      ],
                  ),
              ),

              const SizedBox(height: 32),
              
              // Impact Stats
              Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.orange.shade50),
                      boxShadow: [
                          BoxShadow(
                              color: Colors.orange.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                          )
                      ]
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                  Text(
                                    'CITIZEN IMPACT',
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                        color: const Color(0xFF0B3D91),
                                    ),
                                  ),
                                  Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                          color: const Color(0xFFFF9933),
                                          borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                          'LIVE STATS',
                                          style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                          ),
                                      ),
                                  )
                              ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                              children: [
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                              Text(
                                                  '12,480',
                                                  style: GoogleFonts.inter(
                                                      fontSize: 32,
                                                      fontWeight: FontWeight.bold,
                                                      color: const Color(0xFF0B3D91),
                                                  ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                  'ISSUES RESOLVED',
                                                  style: GoogleFonts.inter(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.grey.shade500,
                                                  ),
                                              ),
                                          ],
                                      ),
                                  ),
                                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                                  const SizedBox(width: 24),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                              Text(
                                                  'Chennai',
                                                  style: GoogleFonts.inter(
                                                      fontSize: 32,
                                                      fontWeight: FontWeight.bold,
                                                      color: const Color(0xFF0B3D91),
                                                  ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                  'TOP DISTRICT',
                                                  style: GoogleFonts.inter(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.grey.shade500,
                                                  ),
                                              ),
                                          ],
                                      ),
                                  ),
                              ],
                          ),
                           const SizedBox(height: 24),
                           Text(
                              '"Small reports lead to big changes."',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey.shade600,
                              ),
                           ),
                           Align(
                               alignment: Alignment.bottomRight,
                               child: Icon(Icons.trending_up, color: Colors.orange.shade300),
                           )
                      ],
                  ),
              ),

              const SizedBox(height: 80), // Bottom padding
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
          decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                  )
              ]
          ),
          child: SafeArea(
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                          _buildNavItem(0, Icons.home_rounded, 'Home'),
                          _buildNavItem(1, Icons.map_rounded, 'Map'),
                          
                          // FAB in middle
                          GestureDetector(
                              onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen()));
                              },
                              child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                          colors: [Color(0xFFFF9933), Color(0xFFFF7722)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                          BoxShadow(
                                              color: Colors.orange.withOpacity(0.4),
                                              blurRadius: 15,
                                              offset: const Offset(0, 8),
                                          )
                                      ]
                                  ),
                                  child: const Icon(Icons.add, color: Colors.white, size: 30),
                              ),
                          ),

                          _buildNavItem(3, Icons.notifications_rounded, 'Alerts'),
                          _buildNavItem(4, Icons.person_rounded, 'Profile'),
                      ],
                  ),
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
                      color: isSelected ? const Color(0xFFFF9933) : Colors.grey.shade400,
                      size: 26,
                  ),
                  const SizedBox(height: 4),
                  Text(
                      label,
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? const Color(0xFFFF9933) : Colors.grey.shade400,
                      ),
                  )
              ],
          ),
      );
  }

  Widget _buildComplaintCard({
      required String title,
      required String status,
      required String location,
      required double progress,
      required IconData icon,
      required Color color,
      required Color iconColor,
  }) {
      return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
              children: [
                  Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: iconColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Text(
                                  title,
                                  style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0B3D91),
                                  ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                  '$location • Just now',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                  ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                  children: [
                                      Text(
                                          status,
                                          style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: iconColor,
                                          ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                  value: progress,
                                                  backgroundColor: Colors.grey.shade100,
                                                  valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                                                  minHeight: 4,
                                              ),
                                          ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                          '${(progress * 100).toInt()}%',
                                          style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF0B3D91),
                                          ),
                                      ),
                                  ],
                              )
                          ],
                      ),
                  )
              ],
          ),
      );
  }

  Widget _buildNearbyCard({
      required String title,
      required String distance,
      required String location,
      required String imageUrl,
  }) {
      return Container(
          width: 240,
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                  )
              ]
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.network(
                          imageUrl,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                      ),
                  ),
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Text(
                                  title,
                                  style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0B3D91),
                                  ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                  children: [
                                      Icon(Icons.location_on, size: 14, color: Colors.orange.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                          distance,
                                          style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                          ),
                                      ),
                                      const SizedBox(width: 8),
                                       Text(
                                          '• $location',
                                          style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: Colors.grey.shade400,
                                          ),
                                      ),
                                  ],
                              )
                          ],
                      ),
                  )
              ],
          ),
      );
  }
}
