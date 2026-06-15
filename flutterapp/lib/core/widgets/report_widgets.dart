/// @file report_widgets.dart
/// @description Core UI component for the Civic App.
/// Professionally structured and maintained by the Civic App Team.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutterapp/core/theme/app_colors.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final bool required;

  const SectionHeader(this.title, {super.key, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
          if (required) const Text(" *", style: TextStyle(color: Colors.red))
        ],
      ),
    );
  }
}

class AntiSpoofingCameraCard extends StatelessWidget {
  final File? selectedImage;
  final bool isAnalyzing;
  final String address;
  final VoidCallback onTakePhoto;

  const AntiSpoofingCameraCard({
    super.key,
    required this.selectedImage,
    required this.isAnalyzing,
    required this.address,
    required this.onTakePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text("Real-time Geo-tagged photo required", style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onTakePhoto,
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    label: const Text("Take Photo", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            if (selectedImage != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(selectedImage!, height: 150, width: double.infinity, fit: BoxFit.cover),
                    ),
                    if (isAnalyzing)
                      Positioned.fill(child: Container(color: Colors.black45, child: const Center(child: CircularProgressIndicator()))),
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          "📍 $address\n${DateTime.now()}",
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  ],
                ),
              )
          ],
        ),
      ),
    );
  }
}

class LocationCard extends StatelessWidget {
  final String address;
  final String district;
  final VoidCallback onGetLocation;

  const LocationCard({
    super.key,
    required this.address,
    required this.district,
    required this.onGetLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.location_on, color: Colors.red),
        title: Text(address, style: GoogleFonts.inter(fontSize: 14)),
        subtitle: Text(district, style: GoogleFonts.inter(fontSize: 12)),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onGetLocation,
          child: const Text("Get Location", style: TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ),
    );
  }
}
