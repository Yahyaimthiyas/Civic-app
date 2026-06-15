/// @file improved_report_card.dart
/// @description Core UI component for the Civic App.
/// Professionally structured and maintained by the Civic App Team.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutterapp/core/theme/app_colors.dart';
import 'dart:convert';

/// Improved Report Card Widget for Community Feed
/// Features:
/// - Enhanced image display with overlays
/// - Tracking ID badge
/// - Verification status
/// - Priority indicators
/// - Engagement metrics (upvotes, comments, verifications)
/// - Impact score display
/// - Modern action buttons
class ImprovedReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final VoidCallback onTap;
  final VoidCallback? onUpvote;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final String fallbackDistrict;

  const ImprovedReportCard({
    super.key,
    required this.report,
    required this.onTap,
    this.onUpvote,
    this.onComment,
    this.onShare,
    this.fallbackDistrict = 'Unknown',
  });

  @override
  Widget build(BuildContext context) {
    // Extract data with fallbacks
    final img = report['imageUrl'];
    final images = report['images'] as List?;
    final isVerified = report['communityVerification']?['isVerified'] == true;
    final trackingId = report['trackingId']?.toString();
    // Safe metric extraction (handle both raw counts and user ID lists)
    int _getCount(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is List) return value.length;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    final upvotes = _getCount(report['upvotes'] ?? report['engagement']?['upvotes']);
    final comments = _getCount(report['engagement']?['comments']);
    final verificationCount = _getCount(report['communityVerification']?['verificationCount']);
    final priority = report['priority'] is int ? report['priority'] : (int.tryParse(report['priority']?.toString() ?? '') ?? 3);
    final impactScore = _getCount(report['impactScore']);

    // Determine image URL
    String? imageUrl;
    if (images != null && images.isNotEmpty) {
      imageUrl = images[0]['url'] ?? images[0]['base64'];
    } else if (img != null && img.toString().isNotEmpty) {
      imageUrl = img.toString();
    }

    // Auto-fix missing base64 prefix if needed
    if (imageUrl != null && imageUrl.length > 100 && !imageUrl.startsWith('http') && !imageUrl.startsWith('data:image')) {
      imageUrl = 'data:image/jpeg;base64,$imageUrl';
    }

    // Priority color
    Color priorityColor = priority == 1
        ? Colors.red
        : priority == 2
            ? Colors.orange
            : priority == 3
                ? Colors.blue
                : Colors.grey;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section with Overlay
            if (imageUrl != null && imageUrl.isNotEmpty)
              _buildImageSection(imageUrl, trackingId, isVerified, priority, priorityColor),

            // Content Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category and Status Row
                  _buildHeaderRow(),

                  const SizedBox(height: 8),

                  // Description
                  Text(
                    report['description'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Location and Time
                  _buildLocationTimeRow(),

                  const SizedBox(height: 12),

                  // Engagement Metrics
                  _buildEngagementRow(upvotes, comments, verificationCount, impactScore, report['aiClassification']),
                ],
              ),
            ),

            // Action Bar
            _buildActionBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(String imageUrl, String? trackingId, bool isVerified, int priority, Color priorityColor) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: imageUrl.startsWith('http')
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 200,
                    color: Colors.grey.shade200,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 200,
                    color: Colors.grey.shade100,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text('Image unavailable', style: GoogleFonts.inter(color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                )
              : (imageUrl.startsWith('data:image') 
                  ? Image.memory(
                      base64Decode(imageUrl.split(',').last),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                          height: 200,
                          color: Colors.grey.shade100,
                          child: const Center(child: Icon(Icons.broken_image, size: 48, color: Colors.grey)),
                      ),
                    )
                  : Container(
                      height: 200,
                      color: Colors.grey.shade100,
                      child: Center(
                        child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey.shade400),
                      ),
                    )),
        ),
        // Gradient Overlay
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.5),
                  Colors.transparent,
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
        ),
        // Tracking ID Badge
        if (trackingId != null)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tag, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    trackingId,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Verification Badge
        if (isVerified)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    'Verified',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Priority Indicator
        if (priority <= 2)
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: priorityColor.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    priority == 1 ? Icons.priority_high : Icons.warning_amber_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    priority == 1 ? 'Critical' : 'High Priority',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      children: [
        Expanded(
          child: Text(
            report['category'] ?? 'Issue',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppColors.textDark,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getStatusColor(report['status']).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _getStatusColor(report['status']).withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            _getStatusText(report['status']),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _getStatusColor(report['status']),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationTimeRow() {
    return Row(
      children: [
        Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            report['location'] is Map
                ? (report['location']['address'] ?? fallbackDistrict)
                : (report['location']?.toString() ?? fallbackDistrict),
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          report['timeAgo'] ?? '',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildEngagementRow(int upvotes, int comments, int verifications, int impactScore, Map<String, dynamic>? aiData) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildMetricChip(Icons.thumb_up_alt_outlined, upvotes.toString(), Colors.blue),
        _buildMetricChip(Icons.chat_bubble_outline, comments.toString(), Colors.orange),
        _buildMetricChip(Icons.verified_user_outlined, verifications.toString(), verifications > 0 ? Colors.green : Colors.grey),
        
        // Impact Score
        if (impactScore > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.8),
                  AppColors.primary,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.trending_up, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  '$impactScore',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActionBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
            onPressed: onUpvote,
            icon: const Icon(Icons.thumb_up_outlined, size: 18),
            label: Text('Upvote', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue,
            ),
          ),
          Container(width: 1, height: 24, color: Colors.grey.shade300),
          TextButton.icon(
            onPressed: onComment ?? onTap,
            icon: const Icon(Icons.comment_outlined, size: 18),
            label: Text('Comment', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange,
            ),
          ),
          Container(width: 1, height: 24, color: Colors.grey.shade300),
          TextButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.share_outlined, size: 18),
            label: Text('Share', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'resolved':
        return Colors.green;
      case 'verified':
        return Colors.blue;
      case 'in_progress':
      case 'in progress':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    if (status == null) return 'Pending';
    return status.split('_').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
  }
}
