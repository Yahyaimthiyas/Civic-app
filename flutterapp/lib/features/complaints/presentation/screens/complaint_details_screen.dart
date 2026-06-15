/// @file complaint_details_screen.dart
/// @description Handles the reporting, mapping, and viewing of civic issues.
/// Professionally structured and maintained by the Civic App Team.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutterapp/features/auth/data/services/aadhaar_api.dart';
import 'package:flutterapp/core/widgets/share_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutterapp/core/theme/app_colors.dart';
import 'package:flutterapp/core/widgets/ai_analysis_card.dart';

class ComplaintDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> report;
  final AadhaarUser user;

  const ComplaintDetailsScreen({super.key, required this.report, required this.user});

  @override
  State<ComplaintDetailsScreen> createState() => _ComplaintDetailsScreenState();
}

class _ComplaintDetailsScreenState extends State<ComplaintDetailsScreen> {
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isCommentsLoading = true;
  bool _isSubmittingComment = false;
  late Map<String, dynamic> _localReport;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _localReport = Map.from(widget.report);
    _loadReportFullDetails();
    _loadComments();
    
    // SETUP REAL-TIME SYNC (Polling every 30 seconds)
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadReportFullDetails();
        _loadComments();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadReportFullDetails() async {
    try {
      final fullDetail = await AadhaarApi.fetchReportDetails(_localReport['id']);
      if (mounted) {
        setState(() {
          _localReport = fullDetail;
          _isCommentsLoading = false; 
        });
      }
    } catch (e) {
      debugPrint("Error loading full details: $e");
    }
  }

  Future<void> _loadComments() async {
    try {
      final comments = await AadhaarApi.fetchComments(_localReport['id']);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isCommentsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isCommentsLoading = false);
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;
    
    setState(() => _isSubmittingComment = true);
    try {
      await AadhaarApi.addComment(
        _localReport['id'],
        widget.user.id,
        widget.user.name,
        _commentController.text.trim(),
        widget.user.photoUrl
      );
      _commentController.clear();
      await _loadComments();
      await _loadReportFullDetails(); // Refresh report metadata (Engagement count)
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to post comment')));
      }
    } finally {
      if (mounted) setState(() => _isSubmittingComment = false);
    }
  }

  Future<void> _handleUpvote() async {
    try {
      await AadhaarApi.upvoteReport(_localReport['id'], widget.user.id, widget.user.photoUrl);
      if (mounted) {
        await _loadReportFullDetails(); // Re-fetch from server for real-time accuracy
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upvoted successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        final msg = e is AadhaarApiException ? e.message : 'Failed to upvote';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _handleVerify() async {
    try {
      final result = await AadhaarApi.verifyReport(_localReport['id'], widget.user.id, widget.user.phoneNumber);
      if (mounted) {
        await _loadReportFullDetails(); // Fetch latest state including verified status
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result['isVerified'] == true ? 'Report Verified by Community!' : 'Verification added!'), 
            backgroundColor: Colors.green
        ));
      }
    } catch (e) {
      if (mounted) {
        final msg = e is AadhaarApiException ? e.message : 'Action failed'; 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.orange));
      }
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING': return Colors.grey.shade100;
      case 'VERIFIED': return Colors.blue.shade50;
      case 'IN_PROGRESS': return Colors.orange.shade50;
      case 'RESOLVED': return Colors.green.shade50;
      case 'REJECTED': return Colors.red.shade50;
      default: return Colors.grey.shade100;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING': return Colors.grey.shade700;
      case 'VERIFIED': return AppColors.primary;
      case 'IN_PROGRESS': return AppColors.accent;
      case 'RESOLVED': return Colors.green.shade700;
      case 'REJECTED': return Colors.red.shade700;
      default: return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime _parseDate(dynamic dateValue) {
      if (dateValue == null) return DateTime.now();
      if (dateValue is String) return DateTime.tryParse(dateValue) ?? DateTime.now();
      if (dateValue is Map && dateValue.containsKey('_seconds')) {
        return DateTime.fromMillisecondsSinceEpoch(dateValue['_seconds'] * 1000);
      }
      return DateTime.now();
    }

    final status = _localReport['status']?.toString().toUpperCase() ?? 'PENDING';
    final date = _parseDate(_localReport['createdAt']);
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);
    
    final images = _localReport['images'] as List?;
    String? imageUrl = _localReport['imageUrl'];
    if (images != null && images.isNotEmpty) {
      imageUrl = images[0]['url'] ?? images[0]['base64'];
    }

    if (imageUrl != null && imageUrl.length > 100 && !imageUrl.startsWith('http') && !imageUrl.startsWith('data:image')) {
      imageUrl = 'data:image/jpeg;base64,$imageUrl';
    }

    bool hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final trackingId = _localReport['trackingId']?.toString() ?? 'ID-PENDING';
    final verification = _localReport['communityVerification'] ?? {};
    final isVerified = verification['isVerified'] == true;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // 1. Immersive Header
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.primary,
            iconTheme: const IconThemeData(color: Colors.white),
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black26,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.black26,
                  child: IconButton(
                    icon: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
                    onPressed: () => CivicShareSheet.show(context, _localReport),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'report_img_${_localReport['id']}',
                child: hasImage 
                  ? (imageUrl!.startsWith('data:image')
                      ? Image.memory(base64Decode(imageUrl.split(',').last), fit: BoxFit.cover)
                      : CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, errorWidget: (c,u,e) => _buildImagePlaceholder()))
                  : _buildImagePlaceholder(),
              ),
            ),
          ),

          // 2. Content
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // Tracking ID & Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                        child: Text(trackingId, style: GoogleFonts.robotoMono(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      Text(formattedDate, style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title (Category)
                  Text(
                    _getFormattedCategory(_localReport['category']?.toString() ?? 'public').toUpperCase(),
                    style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: -0.5),
                  ),

                  const SizedBox(height: 12),

                  // Status & Verification Badge
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: _getStatusBgColor(status), borderRadius: BorderRadius.circular(20)),
                        child: Text(status, style: TextStyle(color: _getStatusTextColor(status), fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      if (isVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade100)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, color: Colors.green.shade700, size: 14),
                              const SizedBox(width: 4),
                              Text("Community Verified", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Interaction Bar
                  _buildInteractionBar(),

                  const SizedBox(height: 32),

                  // Description Section
                  _sectionHeader("Description"),
                  const SizedBox(height: 12),
                  Text(
                    _localReport['description'] ?? 'No description provided for this report.',
                    style: GoogleFonts.inter(fontSize: 16, color: Colors.grey.shade800, height: 1.6),
                  ),

                  const SizedBox(height: 32),

                  // Location Section
                  _sectionHeader("Location"),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white, 
                      borderRadius: BorderRadius.circular(20), 
                      border: Border.all(color: Colors.grey.shade100),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)]
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.location_on, color: AppColors.accent, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                               Text(_localReport['location']?['address'] ?? 'Tamil Nadu, India', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                               const SizedBox(height: 4),
                               Text("GPS: ${_localReport['location']?['lat']?.toStringAsFixed(4)}, ${_localReport['location']?['lng']?.toStringAsFixed(4)}", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // AI Analysis Card
                  AIAnalysisCard(aiData: _localReport['aiAnalysis']),

                  const SizedBox(height: 32),

                  // Comments Section (Community Hub)
                  _buildCommentsSection(),

                  const SizedBox(height: 120), // Bottom padding for FAB
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleVerify,
        backgroundColor: isVerified ? Colors.grey.shade400 : AppColors.accent,
        elevation: 4,
        icon: Icon(isVerified ? Icons.check_circle : Icons.verified_outlined, color: Colors.white),
        label: Text(isVerified ? "Already Verified" : "Verify Report", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text("PHOTO UNAVAILABLE", style: GoogleFonts.inter(color: Colors.grey.shade400, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildInteractionBar() {
    final engagement = _localReport['engagement'] ?? {};
    final upvotes = engagement['upvotes'] ?? _localReport['upvotes'] ?? 0;
    final verCount = _localReport['communityVerification']?['verificationCount'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 20)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _interactionItem(Icons.thumb_up_alt_rounded, upvotes.toString(), "Upvotes", onTap: _handleUpvote, color: Colors.blue),
          _interactionItem(Icons.chat_bubble_rounded, _comments.length.toString(), "Comments", color: Colors.orange),
          _interactionItem(Icons.security_rounded, verCount.toString(), "Verified By", color: Colors.green),
        ],
      ),
    );
  }

  Widget _interactionItem(IconData icon, String count, String label, {VoidCallback? onTap, Color color = Colors.blue}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(count, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary)),
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(title.toUpperCase(), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1.5));
  }

  Widget _buildCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             _sectionHeader("Community Hub"),
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
               decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
               child: Text("${_comments.length}", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade700)),
             ),
          ],
        ),
        const SizedBox(height: 20),
        // Comment Input Area
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade50, 
            borderRadius: BorderRadius.circular(16), 
            border: Border.all(color: Colors.grey.shade100)
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(hintText: "Add your voice to this report...", border: InputBorder.none, hintStyle: TextStyle(fontSize: 13)),
                ),
              ),
              if (_isSubmittingComment)
                const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              else
                IconButton(
                  icon: Icon(Icons.send_rounded, color: AppColors.primary, size: 24), 
                  onPressed: _submitComment
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Comments List
        _isCommentsLoading 
          ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          : _comments.isEmpty 
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40), 
                    child: Column(
                      children: [
                        Icon(Icons.forum_outlined, size: 48, color: Colors.grey.shade200),
                        const SizedBox(height: 12),
                        Text("No discussions yet. Start one!", style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                      ],
                    )
                  )
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _comments.length,
                  itemBuilder: (context, index) {
                    final comment = _comments[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.05),
                            child: Text(comment['userName']?[0].toUpperCase() ?? 'U', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 14)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(comment['userName'] ?? 'User', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primary)),
                                    const Spacer(),
                                    Text("RECENT", style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
                                  child: Text(comment['text'] ?? '', style: GoogleFonts.inter(color: Colors.grey.shade800, height: 1.5, fontSize: 14)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      ],
    );
  }

  String _getFormattedCategory(String cat) {
    if (cat.isEmpty) return 'Public Issue';
    final Map<String, String> categoryDisplayNames = {
      'pothole': 'Pothole',
      'streetlight_not_working': 'Streetlight',
      'garbage_overflow': 'Garbage',
      'water_leakage': 'Water Leak',
      'sewage_overflow': 'Sewage',
    };
    if (categoryDisplayNames.containsKey(cat.toLowerCase())) return categoryDisplayNames[cat.toLowerCase()]!;
    return cat.split('_').map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '').join(' ');
  }
}
