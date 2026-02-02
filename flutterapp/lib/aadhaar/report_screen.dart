import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'services/aadhaar_api.dart';
import 'services/geofence_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // Form State
  File? _selectedImage;
  String? _description;
  String? _category;
  String? _department;
  String? _urgency;
  Position? _currentPosition;
  String _address = "Location not fetched";
  String? _district;
  bool _isLoading = false;
  bool _isAnalyzing = false;
  bool _isLocationValid = false;
  
  // Constants
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _descController = TextEditingController();

  final List<String> _categories = ['Pothole', 'Garbage', 'Street Light', 'Water Leakage', 'Public Toilet', 'Others'];
  final List<String> _departments = ['Public Works Department (PWD)', 'Municipal Corporation', 'State Electricity Board', 'Water Resources Department', 'Health Department', 'Transport Department'];
  final List<String> _severities = ['Low', 'Medium', 'High', 'Critical'];

  // Speech State
  SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _checkLocationAndPermit(silent: true);
    _initSpeech();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
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

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      // Anti-Spoofing
      if (position.isMocked) {
           _showBlockingAlert("Fake Location Detected", "Mock locations are not allowed.");
           throw Exception("Mock Location Detected");
      }

      // Geofencing
      bool allowed = await GeofenceService.isLocationAllowed(position, null);
      if (!allowed) {
           _showBlockingAlert("Restricted Area", "You must be in Tamil Nadu to report.");
           throw Exception("Location outside Tamil Nadu");
      }

      // Reverse Geocoding for Exact Address
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark place = placemarks.isNotEmpty ? placemarks[0] : Placemark(locality: 'Middle of Nowhere', subAdministrativeArea: 'Unknown');
      
      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        // Construct detailed address: Street, Locality, District (SubAdminArea or Locality)
        _district = place.subAdministrativeArea ?? place.locality ?? "Tamil Nadu";
        _address = "${place.street ?? ''}, ${place.locality ?? ''}, $_district";
        if (_address.startsWith(", ")) _address = _address.substring(2);

        _isLocationValid = true;
        _isLoading = false;
      });

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (!silent) _address = "Error: $e";
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
      // STRICT: Camera Only (Gallery option is removed from UI).
      // Check Location First
      if (!_isLocationValid) {
          await _checkLocationAndPermit();
          if (!_isLocationValid) return;
      }

      try {
          final XFile? photo = await _picker.pickImage(source: source, imageQuality: 60);
          if (photo != null) {
              setState(() {
                  _selectedImage = File(photo.path);
                  _isAnalyzing = true;
              });

              // AI Analysis
              try {
                  final result = await AadhaarApi.analyzeImage(_selectedImage!);
                  if (!mounted) return;

                  setState(() {
                      // Map AI results to UI
                      String? aiIssue = result['issue_type']?.toString().toLowerCase();
                      if (aiIssue != null) {
                           if (aiIssue.contains('pothole')) _category = 'Pothole';
                           else if (aiIssue.contains('garbage')) _category = 'Garbage';
                           else if (aiIssue.contains('light')) _category = 'Street Light';
                           else if (aiIssue.contains('water')) _category = 'Water Leakage';
                           else _category = 'Others';
                      }

                      _descController.text = result['description'] ?? _descController.text;
                      
                      // Department Mapping Logic
                      String rawDept = result['department']?.toString().toLowerCase() ?? '';
                      if (rawDept.contains('highways') || rawDept.contains('pwd') || rawDept.contains('road')) _department = 'Public Works Department (PWD)';
                      else if (rawDept.contains('corporation') || rawDept.contains('municipality') || rawDept.contains('revenue') || rawDept.contains('parks')) _department = 'Municipal Corporation';
                      else if (rawDept.contains('tneb') || rawDept.contains('electric') || rawDept.contains('pole')) _department = 'State Electricity Board';
                      else if (rawDept.contains('water') || rawDept.contains('cmwssb') || rawDept.contains('twad') || rawDept.contains('drainage') || rawDept.contains('sewage')) _department = 'Water Resources Department';
                      else if (rawDept.contains('health') || rawDept.contains('sanitation') || rawDept.contains('toilet') || rawDept.contains('animal') || rawDept.contains('mosquito')) _department = 'Health Department';
                      else if (rawDept.contains('transport') || rawDept.contains('traffic') || rawDept.contains('signal')) _department = 'Transport Department';
                      else _department = 'Municipal Corporation'; // Default fallback

                      
                      // Map Severity
                      String? aiSev = result['severity']?.toString().toLowerCase();
                       if (aiSev != null) {
                           if (aiSev.contains('high')) _urgency = 'High';
                           else if (aiSev.contains('critical')) _urgency = 'Critical';
                           else if (aiSev.contains('low')) _urgency = 'Low';
                           else _urgency = 'Medium';
                       }
                      
                      _isAnalyzing = false;
                  });

                  // AI Analysis Success Popup
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                        title: const Row(children: [Icon(Icons.auto_awesome, color: Colors.orange), SizedBox(width: 8), Text("AI Detected")]),
                        content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text("Issue Type: $_category", style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text("Department: $_department"),
                                const SizedBox(height: 8),
                                Text("Severity: $_urgency"),
                            ],
                        ),
                        actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK", style: TextStyle(color: Colors.blueAccent)))
                        ],
                    )
                  );

                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI Analysis Complete"), backgroundColor: Colors.green));

              } catch (e) {
                  setState(() => _isAnalyzing = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("AI Failed: $e")));
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
              'userId': 'USER_123',
              'userName': 'Arul Kumar',
              'category': _category,
              'description': _descController.text,
              'department': _department ?? 'Unknown',
              'urgency': _urgency ?? 'Medium',
              'location': {
                  'lat': _currentPosition?.latitude ?? 0.0,
                  'lng': _currentPosition?.longitude ?? 0.0,
                  'address': _address
              },
              'district': _district ?? 'Unknown',
              'status': 'PENDING'
          };
          
          await AadhaarApi.submitReport(reportData, _selectedImage);

          if (!mounted) return;
          showDialog(
              context: context,
              builder: (_) => AlertDialog(
                  title: const Text("Success"),
                  content: const Text("Report Submitted Successfully!"),
                  actions: [
                      TextButton(onPressed: () {
                           Navigator.pop(context);
                           Navigator.pop(context);
                      }, child: const Text("OK"))
                  ]
              )
          );

      } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      } finally {
          if (mounted) setState(() => _isLoading = false);
      }
  }

  void _showBlockingAlert(String title, String message) {
    showDialog(context: context, builder: (_) => AlertDialog(title: Text(title), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Report an Issue', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.orange,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress Bar (Mock)
            LinearProgressIndicator(value: 0.2, backgroundColor: Colors.grey.shade200, color: Colors.green, minHeight: 6, borderRadius: BorderRadius.circular(3)),
            const SizedBox(height: 20),

            // 1. Add Photo Section
            _buildSectionHeader("Add Photo (Anti-Spoofing Active)"),
            Card(
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
                                            onPressed: () => _pickImage(ImageSource.camera),
                                            icon: const Icon(Icons.camera_alt, color: Colors.white),
                                            label: const Text("Take Photo", style: TextStyle(color: Colors.white)),
                                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B3D91), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                        )
                                    ),
                                    const SizedBox(width: 10),
                                    // Gallery Removed - Showing disabled/greyed out or just nothing? 
                                    // User said "REMOVE THE GALLERY", so I will NOT show it.
                                ],
                            ),
                            if (_selectedImage != null)
                                Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Stack(
                                        children: [
                                            ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.file(_selectedImage!, height: 150, width: double.infinity, fit: BoxFit.cover),
                                            ),
                                            if (_isAnalyzing)
                                                Positioned.fill(child: Container(color: Colors.black45, child: const Center(child: CircularProgressIndicator()))),
                                            Positioned(
                                                bottom: 0, left: 0, right: 0,
                                                child: Container(
                                                    color: Colors.black54,
                                                    padding: const EdgeInsets.all(4),
                                                    child: Text(
                                                        "📍 $_address\n${DateTime.now()}",
                                                        style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center
                                                    ),
                                                ),
                                            )
                                        ],
                                    ),
                                )
                        ],
                    ),
                ),
            ),
            const SizedBox(height: 20),

            // 2. Location Section
            _buildSectionHeader("Location", required: true),
            Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                    leading: const Icon(Icons.location_on, color: Colors.red),
                    title: Text(_address, style: GoogleFonts.inter(fontSize: 14)),
                    subtitle: Text(_district ?? "Fetching district...", style: GoogleFonts.inter(fontSize: 12)),
                    trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B3D91), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        onPressed: () => _checkLocationAndPermit(),
                        child: const Text("Get Location", style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                ),
            ),
            const SizedBox(height: 20),

            // 3. Category Section
            _buildSectionHeader("Category"),
            Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: DropdownButtonFormField<String>(
                        value: _category,
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setState(() => _category = v),
                        decoration: const InputDecoration(border: InputBorder.none, prefixIcon: Icon(Icons.category, color: Colors.orange)),
                        hint: const Text("Select Category"),
                    ),
                ),
            ),
            const SizedBox(height: 20),

            // 4. Department Section
            _buildSectionHeader("Department (Auto-Detected)"),
            Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: DropdownButtonFormField<String>(
                        value: (_department != null && _departments.any((d) => d.contains(_department!))) ? _departments.firstWhere((d) => d.contains(_department!)) : null,
                        items: _departments.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setState(() => _department = v),
                        isExpanded: true,
                         decoration: const InputDecoration(border: InputBorder.none, prefixIcon: Icon(Icons.business, color: Colors.blue)),
                        hint: const Text("Select Department"),
                    ),
                ),
            ),
             const SizedBox(height: 20),

            // 5. Description
            _buildSectionHeader("Description"),
             Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                        controller: _descController,
                        maxLines: 4,
                        decoration: InputDecoration(
                            border: InputBorder.none, 
                            hintText: "Describe the issue... (Tap mic to speak)",
                            suffixIcon: IconButton(
                                icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.red : Colors.grey),
                                onPressed: _listen,
                            )
                        ),
                    ),
                ),
            ),
            const SizedBox(height: 20),

            // 6. Severity Level
            _buildSectionHeader("Severity Level"),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _severities.map((sev) {
                    bool isSelected = _urgency == sev;
                    Color color = sev == 'Critical' ? Colors.red : (sev == 'High' ? Colors.orange : (sev == 'Medium' ? Colors.amber : Colors.green));
                    return GestureDetector(
                        onTap: () => setState(() => _urgency = sev),
                        child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                                color: isSelected ? color : Colors.transparent, // Fill only if selected
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isSelected ? color : Colors.grey.shade400, width: 1.5), // Grey border if unselected
                            ),
                            child: Text(sev, style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey.shade700, // White text if selected, Grey if not
                                fontWeight: FontWeight.bold, 
                                fontSize: 13
                            )),
                        ),
                    );
                }).toList(),
            ),

            const SizedBox(height: 40),
            
            // Submit Button
            SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                    onPressed: (_isLoading || !_isLocationValid) ? null : _submitReport,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B3D91),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                    ),
                    child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("SUBMIT REPORT", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool required = false}) {
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
