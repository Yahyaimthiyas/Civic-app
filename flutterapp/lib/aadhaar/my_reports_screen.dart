import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'complaint_details_screen.dart';
import 'services/aadhaar_api.dart'; 

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      // TODO: Get real User ID from session. Hardcoded for MVP as per Submit Logic
      final reports = await AadhaarApi.fetchUserReports('USER_123');
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING': return Colors.orange;
      case 'IN_PROGRESS': return Colors.blue;
      case 'RESOLVED': return Colors.green;
      case 'REJECTED': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('My Complaints', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _error != null 
              ? Center(child: Text('Error: $_error'))
              : _reports.isEmpty 
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.assignment_outlined, size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      Text("No complaints found", style: TextStyle(color: Colors.grey.shade500))
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _reports.length,
                      itemBuilder: (context, index) {
                        final report = _reports[index];
                        final date = DateTime.tryParse(report['createdAt'] ?? '') ?? DateTime.now();
                        final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);
                        final status = report['status']?.toString().toUpperCase() ?? 'UNKNOWN';

                        return GestureDetector(
                          onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => ComplaintDetailsScreen(report: report)));
                          },
                          child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                            ]
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Chip(
                                        label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                        backgroundColor: _getStatusColor(status),
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                    ),
                                    Text(
                                        '#${report['id'].toString().substring(0, 8)}', // Show partial ID
                                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                    report['category'] ?? 'General Issue', 
                                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0B3D91))
                                ),
                                const SizedBox(height: 4),
                                Row(
                                    children: [
                                        const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                            child: Text(
                                                report['location']?['address'] ?? 'Unknown Location',
                                                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                            )
                                        )
                                    ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(),
                                const SizedBox(height: 8),
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                        Text(formattedDate, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
                                        Text("View Details >", style: GoogleFonts.inter(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
                                    ],
                                )
                              ],
                            ),
                          ),
                        ),
                        );
                      },
                    ),
    );
  }
}
