/// @file report_screen.dart
/// @description Handles the reporting, mapping, and viewing of civic issues.
/// Professionally structured and maintained by the Civic App Team.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img; // Watermarking
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutterapp/features/auth/data/services/aadhaar_api.dart';
import 'package:flutterapp/features/complaints/data/services/geofence_service.dart';
import 'package:flutterapp/core/widgets/report_widgets.dart';
import 'package:flutterapp/core/theme/app_colors.dart';

/// The primary screen for citizens to report civic issues.
/// 
/// Allows users to take a photo, automatically detects the location using GPS,
/// runs AI analysis to determine the issue type, and submits the report to the server.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, required this.user});

  final AadhaarUser user;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // Form State
  File? _selectedImage;
  String? _category;
  String? _department;
  String? _urgency = 'Medium';
  Position? _currentPosition;
  String _address = "Location not fetched";
  String? _district;
  bool _isLoading = false;
  bool _isAnalyzing = false;
  bool _isLocationValid = false;
  int _currentStep = 0; // 0: Photo, 1: Category/Details, 2: Review

  // Speech to Text
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;

  // Constants
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _descController = TextEditingController();

  final List<Map<String, dynamic>> _categoryItems = [
    {'name': 'Pothole', 'id': 'pothole', 'icon': Icons.broken_image_outlined, 'color': Colors.grey.shade700},
    {'name': 'Streetlight Not Working', 'id': 'streetlight_not_working', 'icon': Icons.lightbulb_outline, 'color': Colors.amber.shade700},
    {'name': 'Garbage Overflow', 'id': 'garbage_overflow', 'icon': Icons.delete_outline, 'color': Colors.brown},
    {'name': 'Water Leakage', 'id': 'water_leakage', 'icon': Icons.water_drop_outlined, 'color': Colors.blue},
    {'name': 'Sewage Overflow', 'id': 'sewage_overflow', 'icon': Icons.water, 'color': Colors.brown.shade800},
  ];

  final List<String> _severities = ['Low', 'Medium', 'High', 'Critical'];

  final Map<String, String> _categoryToDepartment = {
    "pothole": "Roads",
    "streetlight_not_working": "Electrical",
    "garbage_overflow": "Sanitation",
    "water_leakage": "Water Supply & Sewerage",
    "sewage_overflow": "Sewerage",
  };

  void _onCategorySelected(String id) {
    setState(() {
      _category = id;
      _department = _categoryToDepartment[id] ?? 'Unknown';
    });
  }

  @override
  void initState() {
    super.initState();
    _checkLocationAndPermit(silent: true);
    _initSpeech();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    if (mounted) setState(() {});
  }

  void _listen() async {
    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Speech recognition not available")));
      return;
    }

    if (_isListening) {
      await _speechToText.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _speechToText.listen(onResult: (result) {
        setState(() {
          _descController.text = result.recognizedWords;
          if (result.finalResult) {
            _isListening = false;
          }
        });
      });
    }
  }

  Future<void> _checkLocationAndPermit({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Location permissions are denied');
      }

      // High accuracy can be slow, but it's required for precise reporting.
      Position position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high))
          .timeout(const Duration(seconds: 15));

      // Future improvement: Implement Anti-Spoofing check here if needed.

      if (!mounted) return;

      // UPDATE POSITION IMMEDIATELY
      setState(() {
        _currentPosition = position;
        _isLocationValid = true; // At least we have lat/lng
      });

      // Geofencing (Optional - can be lenient for now)
      // bool allowed = await GeofenceService.isLocationAllowed(position, null);

      // Reverse Geocoding for Exact Address
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        Placemark place = placemarks.isNotEmpty ? placemarks[0] : Placemark(locality: 'Unknown Location', subAdministrativeArea: '');
        
        if (mounted) {
          setState(() {
             String rawDistrict = place.subAdministrativeArea ?? place.locality ?? "Tamil Nadu";
             // Normalize: Remove " District" suffix
             _district = rawDistrict.replaceAll(RegExp(r'\s+District$', caseSensitive: false), '');
             
             _address = "${place.street ?? ''}, ${place.name ?? ''}, ${place.locality ?? ''}, ${place.subAdministrativeArea ?? ''}".trim();
             _address = _address.replaceAll(RegExp(r', ,'), ','); // Cleanup double commas
             if (_address.startsWith(", ")) _address = _address.substring(2);

             // Fallback: If district is generic "Tamil Nadu" or "Unknown", try extracting from address
             if (_district == "Tamil Nadu" || _district == "Unknown District") {
                final extract = _extractDistrictFromAddress(_address);
                if (extract != null) _district = extract;
             }

             _isLoading = false;
          });
        }
      } catch (geoError) {
        debugPrint("Geocoding failed: $geoError");
        if (mounted) {
           setState(() {
             _district = "Unknown District";
             _address = "Address unavailable (Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)})";
             _isLoading = false;
           });
        }
      }

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (!silent) _address = "Location Error: $e";
      });
    }
  }

  String? _extractDistrictFromAddress(String addr) {
    const districts = [
      "Ariyalur", "Chengalpattu", "Chennai", "Coimbatore", "Cuddalore", "Dharmapuri",
      "Dindigul", "Erode", "Kallakurichi", "Kancheepuram", "Karur", "Krishnagiri",
      "Madurai", "Mayiladuthurai", "Nagapattinam", "Namakkal", "Nilgiris", "Perambalur",
      "Pudukkottai", "Ramanathapuram", "Ranipet", "Salem", "Sivaganga", "Tenkasi",
      "Thanjavur", "Theni", "Thoothukudi", "Tiruchirappalli", "Tirunelveli", "Tirupathur",
      "Tiruppur", "Tiruvallur", "Tiruvannamalai", "Tiruvarur", "Vellore", "Viluppuram",
      "Virudhunagar", "Kanyakumari"
    ];

    for (var d in districts) {
      if (addr.toLowerCase().contains(d.toLowerCase())) {
        return d;
      }
    }
    return null;
  }

  /// Adds a geolocational and timestamp watermark to the provided image.
  /// 
  /// This ensures that submitted photos have embedded proof of time and location,
  /// increasing the authenticity of the citizen's report.
  Future<File> _watermarkImage(File originalFile) async {
      try {
        final bytes = await originalFile.readAsBytes();
        var image = img.decodeImage(bytes);

        if (image == null) return originalFile;

        // 1. Resize for consistency
        if (image.width > 1200) {
           image = img.copyResize(image, width: 1200);
        }

        // 2. Prepare Data
        final dateTime = DateTime.now().toString().split('.')[0];
        final lat = _currentPosition?.latitude.toStringAsFixed(6) ?? "0.000000";
        final lng = _currentPosition?.longitude.toStringAsFixed(6) ?? "0.000000";
        
        String shortAddr = _address.length > 50 ? "${_address.substring(0, 50)}..." : _address;
        
        // 3. Draw Semi-Transparent Overlay (Bottom strip)
        // Instead of a solid block, we darken the bottom pixels to make text pop while keeping context.
        const int barHeight = 220;
        final int yStart = image.height - barHeight;
        
        // Loop through pixels in the bottom region and darken them
        for (var y = yStart; y < image.height; y++) {
          for (var x = 0; x < image.width; x++) {
            final p = image.getPixel(x, y);
            // Darken by multiplying by 0.4 (60% darkness)
            p.r = p.r * 0.4;
            p.g = p.g * 0.4;
            p.b = p.b * 0.4;
          }
        }

        // 4. Draw Text Properties
        final font = img.arial48;
        final textColor = img.ColorRgb8(255, 255, 255); // White

        // Line 1: Lat / Lng
        img.drawString(
          image, 
          "Lat: $lat  Lng: $lng", 
          font: font, 
          x: 40, 
          y: yStart + 20, 
          color: textColor,
        );

        // Line 2: Address
        img.drawString(
          image, 
          "Loc: $shortAddr", 
          font: font, 
          x: 40, 
          y: yStart + 80, 
          color: textColor,
        );

        // Line 3: Date Time
        img.drawString(
          image, 
          "Time: $dateTime", 
          font: font, 
          x: 40, 
          y: yStart + 140, 
          color: textColor,
        );

        // 5. Save with optimized quality for speed
        final watermarkedBytes = img.encodeJpg(image, quality: 75); // Reduced from 90 for faster upload
        final newPath = originalFile.path.replaceAll('.jpg', '_geo_${DateTime.now().millisecondsSinceEpoch}.jpg');
        final newFile = await File(newPath).writeAsBytes(watermarkedBytes);
        
        return newFile;

      } catch (e) {
        debugPrint("Error watermarking: $e");
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Watermarking Failed: $e"), backgroundColor: Colors.red));
        }
        return originalFile;
      }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (!_isLocationValid) {
      await _checkLocationAndPermit();
      if (!_isLocationValid) return;
    }

    try {
      final XFile? photo = await _picker.pickImage(source: source, imageQuality: 50, maxWidth: 1080); // Capped resolution
      if (photo != null) {
        setState(() {
          _isLoading = true; // Show loading for watermark
        });

        // Watermark the image
        try {
           final watermarkedFile = await _watermarkImage(File(photo.path));
           setState(() {
              _selectedImage = watermarkedFile;
              _isAnalyzing = true; 
              _isLoading = false;
              _currentStep = 1;
           });
        } catch (e) {
           debugPrint("Watermark Error: $e");
           // Fallback to original if watermark fails
           setState(() {
             _selectedImage = File(photo.path);
             _isAnalyzing = true;
             _isLoading = false;
             _currentStep = 1;
           });
        }

        // 🤖 AI Analysis (Auto-Selection)
        try {
          final result = await AadhaarApi.analyzeImage(_selectedImage!);
          if (!mounted) return;

          setState(() {
            // 1. Set Description
            _descController.text = result['description'] ?? _descController.text;

            // 2. Map Severity to Urgency
            String? aiSev = result['severity']?.toString().toLowerCase();
            if (aiSev != null) {
              if (aiSev.contains('high')) _urgency = 'High';
              else if (aiSev.contains('critical')) _urgency = 'Critical';
              else if (aiSev.contains('low')) _urgency = 'Low';
              else _urgency = 'Medium';
            }

            _isAnalyzing = false;
          });

          // 3. Auto-Select Category & Department (Robust Fuzzy Match)
          String? aiIssue = result['issue_type']?.toString().toLowerCase().trim().replaceAll(' ', '_');
          String? detectedCategoryName;
          
          if (aiIssue != null) {
            String? bestMatch;
            
            // Try exact match or containment
            for (var item in _categoryItems) {
              String id = item['id'].toString().toLowerCase();
              if (id == aiIssue || aiIssue.contains(id) || id.contains(aiIssue)) {
                bestMatch = item['id'];
                detectedCategoryName = item['name'];
                break;
              }
            }

            if (bestMatch != null) {
              _onCategorySelected(bestMatch);
              debugPrint("✨ AI Auto-Selected: $bestMatch");
            }
          }

          // AI Analysis Success Toast with details
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      detectedCategoryName != null 
                        ? "AI Auto-Selected: $detectedCategoryName"
                        : "AI Analysis Complete!",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ]),
                backgroundColor: Colors.indigo.shade700,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 4),
              )
            );
          }

        } catch (e) {
          if (mounted) {
            setState(() => _isAnalyzing = false);
          }
        }
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  Future<void> _submitReport() async {
    if (_selectedImage == null || _category == null || !_isLocationValid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please complete all sections")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final reportData = {
        'userId': widget.user.id,
        'userName': widget.user.name,
        'category': _category,
        'description': _descController.text,
        'department': _department ?? 'Unknown',
        'severity': _urgency ?? 'Medium', // Corrected key for backend
        'location': {
          'latitude': _currentPosition?.latitude ?? 0.0,
          'longitude': _currentPosition?.longitude ?? 0.0,
          'address': _address
        },
        'district': _district ?? 'Tamil Nadu',
        'status': 'PENDING'
      };

      await AadhaarApi.submitReport(reportData, _selectedImage);

      if (!mounted) return;
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Column(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 60),
                  SizedBox(height: 10),
                  Text("Submitted!", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: const Text("Your report has been received and tracking ID generated.", textAlign: TextAlign.center),
              actions: [
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12)
                    ),
                    child: const Text("Done", style: TextStyle(color: Colors.white)),
                  ),
                )
              ]
          )
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showBlockingAlert(String title, String message) {
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(title), content: Text(message), 
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))]
      )
    );
  }

  // --- UI Components ---

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _stepDot(0, "Photo"),
          _stepLine(0),
          _stepDot(1, "Details"),
          _stepLine(1),
          _stepDot(2, "Review"),
        ],
      ),
    );
  }

  Widget _stepDot(int step, String label) {
    bool isActive = _currentStep >= step;
    bool isCurrent = _currentStep == step;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isCurrent ? 32 : 24,
          height: isCurrent ? 32 : 24,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.3),
            shape: BoxShape.circle,
            border: Border.all(color: isActive ? AppColors.primary : Colors.white, width: 2),
            boxShadow: isActive ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)] : []
          ),
          child: isActive 
            ? Icon(Icons.check, size: 14, color: AppColors.primary)
            : Center(child: Text("${step+1}", style: const TextStyle(fontSize: 10, color: Colors.white54))),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(
          color: Colors.white.withValues(alpha: isActive ? 1.0 : 0.6), 
          fontSize: 10, 
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal
        ))
      ],
    );
  }

  Widget _stepLine(int step) {
    bool isActive = _currentStep > step;
    return Expanded(
      child: Container(
        height: 2,
        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.2),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 15),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _categoryItems.length,
      itemBuilder: (context, index) {
        final item = _categoryItems[index];
        bool isSelected = _category == item['id'];
        return GestureDetector(
          onTap: () => _onCategorySelected(item['id'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? (item['color'] as Color).withValues(alpha: 0.1) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? (item['color'] as Color) : Colors.grey.shade200,
                width: isSelected ? 2 : 1
              ),
              boxShadow: [
                if (isSelected) BoxShadow(color: (item['color'] as Color).withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))
                else const BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))
              ]
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item['icon'] as IconData, color: isSelected ? item['color'] : Colors.grey.shade600, size: 30),
                const SizedBox(height: 8),
                Text(item['name'], 
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12, 
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? item['color'] : Colors.grey.shade700
                  )
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Column(
        children: [
          // Custom Header
          Container(
            padding: const EdgeInsets.only(top: 50, left: 16, right: 16, bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight
              ),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.white)),
                    const Text("New Report", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 48) // Balance back button
                  ],
                ),
                const SizedBox(height: 20),
                Text("What's happening?", style: GoogleFonts.outfit(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                const Text("Help us fix it by reporting below.", style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 20),
                _buildStepIndicator(),
              ],
            ),
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Photo Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("1. Evidence", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                      if (_isAnalyzing) 
                         Row(children: [SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)), const SizedBox(width: 6), Text("AI Analyzing...", style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600))])
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _pickImage(ImageSource.camera),
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.transparent, 
                        borderRadius: BorderRadius.circular(20),
                        image: _selectedImage != null 
                          ? DecorationImage(
                              image: FileImage(_selectedImage!), 
                              fit: BoxFit.cover,
                              alignment: Alignment.bottomCenter // IMPORTANT: Keep watermark (at bottom) visible
                            ) 
                          : null,
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 3))]
                      ),
                      child: _selectedImage == null 
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt_outlined, size: 40, color: Colors.grey.shade400),
                              const SizedBox(height: 10),
                              Text("Tap to take photo", style: TextStyle(color: Colors.grey.shade500))
                            ],
                          )
                        : null,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. Location Section
                  Text("2. Location", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                    ),
                    child: Row(
                      children: [
                         Container(
                           padding: const EdgeInsets.all(10),
                           decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                           child: const Icon(Icons.location_on, color: Colors.blue),
                         ),
                         const SizedBox(width: 12),
                         Expanded(
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text(_district ?? "Detecting...", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                               Text(_address, style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                             ],
                           ),
                         ),
                         IconButton(onPressed: () => _checkLocationAndPermit(), icon: const Icon(Icons.my_location, color: Colors.blue))
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Category Grid
                  Text("3. Problem Type", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildCategoryGrid(),

                  const SizedBox(height: 24),

                  // 4. Description
                  Text("4. Description", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                    ),
                    child: TextField(
                      controller: _descController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                        hintText: "Describe the issue...",
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        suffixIcon: IconButton(
                          icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.red : AppColors.primary),
                          onPressed: _listen,
                        )
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 5. Severity
                  Text("Severity", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                    ),
                    child: Row(
                      children: _severities.map((sev) {
                        bool isSelected = _urgency == sev;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _urgency = sev),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isSelected ? (sev == 'Critical' ? Colors.red : (sev == 'High' ? Colors.orange : (sev == 'Medium' ? Colors.blue : Colors.green))) : Colors.transparent,
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: Center(
                                child: Text(sev, style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.grey.shade600, 
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 12
                                )),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Auto-Detected Dept
                  const SizedBox(height: 20),
                  if (_department != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.business, size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(child: Text("Auto-assigned to: $_department", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)))
                        ],
                      ),
                    ),

                  const SizedBox(height: 40),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: (_isLoading || !_isLocationValid) ? null : _submitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 5,
                        shadowColor: AppColors.primary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text("SUBMIT REPORT", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
