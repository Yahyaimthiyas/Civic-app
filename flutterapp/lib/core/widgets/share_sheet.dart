/// @file share_sheet.dart
/// @description Core UI component for the Civic App.
/// Professionally structured and maintained by the Civic App Team.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

class CivicShareSheet {
  static void show(BuildContext context, Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildShareSheet(context, report),
    );
  }

  static Widget _buildShareSheet(BuildContext context, Map<String, dynamic> report) {
    final status = report['status']?.toString().toUpperCase() ?? 'PENDING';
    final title = report['category'] ?? 'Public Issue';
    final id = report['id']?.toString().substring(0, 8).toUpperCase() ?? 'TN-0000';
    final imageUrl = report['imageUrl'];
    final description = report['description'] ?? 'No description';
    final location = report['location'] is Map ? (report['location']['address'] ?? 'Unknown Location') : (report['location'] ?? 'Unknown Location');

    void handleShare() {
      final text = "📢 *Civic Issue Report*\n\n"
          "*Category:* $title\n"
          "*ID:* #$id\n"
          "*Status:* $status\n"
          "*Location:* $location\n\n"
          "*Details:*\n$description\n\n"
          "${imageUrl != null ? 'View Image: $imageUrl\n\n' : ''}"
          "Shared via Civic App";
      
      Share.share(text);
      Navigator.pop(context);
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          
          Text(
            'SHARE ISSUE',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF6B8E23), // Olive Green from design
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 24),

          // Report Card in Share Sheet
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            status,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF4A7C44),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0B3D91),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: #$id',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF4A7C44),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl ?? 'https://images.unsplash.com/photo-1558036117-15d82a90b9b1?w=400',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (_,__,___) => Container(color: Colors.grey, width: 100, height: 100),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Share Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: handleShare,
              icon: const Icon(Icons.share, color: Colors.white),
              label: Text(
                'Share Now',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9933),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
