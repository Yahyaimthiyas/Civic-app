/// @file ai_analysis_card.dart
/// @description Core UI component for the Civic App.
/// Professionally structured and maintained by the Civic App Team.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AIAnalysisCard extends StatelessWidget {
  final Map<String, dynamic>? aiData;

  const AIAnalysisCard({Key? key, this.aiData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (aiData == null) return const SizedBox.shrink();

    final issueType = aiData?['issue_type'] ?? 'Unknown';
    final confidence = (aiData?['confidence'] ?? 0.0) * 100;
    final severity = aiData?['severity'] ?? 'Medium';
    final description = aiData?['description'] ?? 'No analysis available.';

    Color severityColor;
    switch (severity.toString().toLowerCase()) {
      case 'high':
      case 'critical':
        severityColor = Colors.red.shade600;
        break;
      case 'medium':
        severityColor = Colors.orange.shade600;
        break;
      case 'low':
        severityColor = Colors.green.shade600;
        break;
      default:
        severityColor = Colors.grey.shade600;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.purple.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                "AI Analysis",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.purple.shade900,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Text(
                  "${confidence.toStringAsFixed(0)}% Confidence",
                  style: GoogleFonts.robotoMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildBadge("Type", issueType, Colors.blue.shade100, Colors.blue.shade800),
              const SizedBox(width: 8),
              _buildBadge("Severity", severity, severityColor.withValues(alpha: 0.1), severityColor),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              description,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.black87,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, String value, Color bg, Color text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: text.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
