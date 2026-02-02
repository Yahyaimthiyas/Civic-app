import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ComplaintDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> report;

  const ComplaintDetailsScreen({super.key, required this.report});

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING': return Colors.orange;
      case 'ASSIGNED': return Colors.blue;
      case 'IN_PROGRESS': return Colors.deepPurple;
      case 'RESOLVED': return Colors.green;
      case 'REJECTED': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = report['status']?.toString().toUpperCase() ?? 'UNKNOWN';
    final date = DateTime.tryParse(report['createdAt'] ?? '') ?? DateTime.now();
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);
    final imageUrl = report['imageUrl']; // Assuming full URL or local path

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Complaint Details', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Complaint ID", style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                    Text("#${report['id'].toString().substring(0, 8)}", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                Chip(
                    label: Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    backgroundColor: _getStatusColor(status)
                )
              ],
            ),
            const SizedBox(height: 5),
            Text(formattedDate, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
            
            const SizedBox(height: 20),

            // Image
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                image: imageUrl != null 
                    ? DecorationImage(
                        image: imageUrl.startsWith('http') 
                            ? NetworkImage(imageUrl) 
                            : const NetworkImage('https://via.placeholder.com/400x200?text=Complaint+Image'), // Fallback if local path invalid in web
                        fit: BoxFit.cover
                      )
                    : null
              ),
              child: imageUrl == null 
                  ? const Center(child: Icon(Icons.image_not_supported, color: Colors.grey))
                  : null,
            ),

            const SizedBox(height: 20),

            // Details
            _buildSectionTitle("Category"),
            Text(report['category'] ?? 'N/A', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500)),
            
            const SizedBox(height: 15),
            
            _buildSectionTitle("Description"),
            Text(report['description'] ?? 'No description provided.', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade800, height: 1.5)),

             const SizedBox(height: 15),

            _buildSectionTitle("Location"),
            Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    const Icon(Icons.location_on, color: Colors.red, size: 20),
                    const SizedBox(width: 5),
                    Expanded(
                        child: Text(
                             report['location']?['address'] ?? "Unknown Location",
                             style: GoogleFonts.inter(fontSize: 14, color: Colors.black87)
                        )
                    )
                ],
            ),

            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 20),

            // Timeline (Mock for now, could fetch real timeline)
            _buildSectionTitle("Status Timeline"),
            _buildTimelineStep("Submitted", formattedDate, true, true),
            _buildTimelineStep("Assigned to Department", "Pending", status != 'PENDING', true),
            _buildTimelineStep("Work In Progress", "Pending", status == 'IN_PROGRESS' || status == 'RESOLVED', true),
            _buildTimelineStep("Resolved", "Pending", status == 'RESOLVED', false),

          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
    );
  }

  Widget _buildTimelineStep(String title, String date, bool isCompleted, bool showLine) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 16, height: 16,
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green : Colors.grey.shade300,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 2)]
              ),
            ),
            if (showLine)
              Container(
                width: 2, height: 40,
                color: isCompleted ? Colors.green.shade200 : Colors.grey.shade300,
              )
          ],
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: isCompleted ? Colors.black : Colors.grey)),
              Text(date, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 30) // Spacing
            ],
          ),
        )
      ],
    );
  }
}
