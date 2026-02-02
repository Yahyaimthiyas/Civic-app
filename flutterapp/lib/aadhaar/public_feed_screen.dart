import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'services/aadhaar_api.dart';
import 'complaint_details_screen.dart';

class PublicFeedScreen extends StatefulWidget {
  const PublicFeedScreen({super.key});

  @override
  State<PublicFeedScreen> createState() => _PublicFeedScreenState();
}

class _PublicFeedScreenState extends State<PublicFeedScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    try {
      final reports = await AadhaarApi.fetchPublicFeed();
      if (mounted) {
        setState(() {
          _reports = reports;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Community Feed', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _reports.isEmpty
              ? const Center(child: Text("No public issues reported yet."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reports.length,
                  itemBuilder: (context, index) {
                    final report = _reports[index];
                    final date = DateTime.tryParse(report['createdAt'] ?? '') ?? DateTime.now();
                    final formattedDate = DateFormat('dd MMM yyyy').format(date);
                    final imageUrl = report['imageUrl'];

                    return GestureDetector(
                      onTap: () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => ComplaintDetailsScreen(report: report)));
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                // Image Header
                                Container(
                                    height: 180,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                        color: Colors.grey.shade200,
                                        image: imageUrl != null 
                                            ? DecorationImage(
                                                image: imageUrl.startsWith('http') ? NetworkImage(imageUrl) : const NetworkImage('https://via.placeholder.com/600x300?text=Issue+Image'),
                                                fit: BoxFit.cover
                                              )
                                            : null
                                    ),
                                    child: imageUrl == null ? const Center(child: Icon(Icons.image, color: Colors.grey)) : null,
                                ),
                                Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                            Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                    Chip(
                                                        label: Text(report['category'] ?? 'Issue', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                                        backgroundColor: Colors.orange,
                                                        visualDensity: VisualDensity.compact,
                                                    ),
                                                    Text(formattedDate, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey))
                                                ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                                report['description'] ?? 'No description',
                                                style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
                                                maxLines: 2, overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                                children: [
                                                    const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
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
                                            const SizedBox(height: 16),
                                            Row(
                                                children: [
                                                    _buildAction(Icons.thumb_up_alt_outlined, "${report['upvotes']} Supports"),
                                                    const SizedBox(width: 20),
                                                    _buildAction(Icons.comment_outlined, "Comment"),
                                                    const Spacer(),
                                                    const Icon(Icons.share_outlined, size: 20, color: Colors.grey)
                                                ],
                                            )
                                        ],
                                    ),
                                )
                            ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildAction(IconData icon, String label) {
      return Row(
          children: [
              Icon(icon, size: 18, color: Colors.grey.shade700),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700))
          ],
      );
  }
}
