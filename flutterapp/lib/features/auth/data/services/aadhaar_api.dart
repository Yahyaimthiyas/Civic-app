/// @file aadhaar_api.dart
/// @description Authentication and user verification module.
/// Professionally structured and maintained by the Civic App Team.

import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutterapp/core/network/api_constants.dart';

class AadhaarApiException implements Exception {
  AadhaarApiException(this.message);
  final String message;

  @override
  String toString() => 'AadhaarApiException: $message';
}

class SendOtpResponse {
  SendOtpResponse({required this.maskedMobile, required this.phoneE164});

  final String maskedMobile;
  final String phoneE164;
}

/// Represents a verified citizen utilizing the Civic application.
/// 
/// Holds demographic data fetched securely from the Aadhaar verification
/// process. This data is used to tie complaints and upvotes to a verified identity.
class AadhaarUser {
  AadhaarUser({
    required this.id,
    required this.name,
    required this.aadhaarNumber,
    required this.phoneNumber,
    this.address,
    this.photoUrl,
    this.dob,
    this.gender,
    this.age,
    this.district,
    this.state,
  });

  final String id;
  final String name;
  final String aadhaarNumber;
  final String phoneNumber;
  final String? address;
  final String? photoUrl;
  final String? dob;
  final String? gender;
  final int? age;
  final String? district;
  final String? state;

  factory AadhaarUser.fromJson(Map<String, dynamic> json) {
    return AadhaarUser(
      id: json['aadhaarNumber']?.toString() ?? json['id']?.toString() ?? 'USER_${DateTime.now().millisecondsSinceEpoch}',
      name: json['fullName']?.toString() ?? json['name']?.toString() ?? 'Unknown',
      aadhaarNumber: json['aadhaarNumber']?.toString() ?? '',
      phoneNumber: json['mobile']?.toString() ?? json['phoneNumber']?.toString() ?? '',
      address: json['address']?.toString(),
      photoUrl: json['photoUrl']?.toString(),
      dob: json['dob']?.toString(),
      gender: json['gender']?.toString(),
      age: json['age'] is int ? json['age'] : int.tryParse(json['age']?.toString() ?? ''),
      district: json['district']?.toString(),
      state: json['state']?.toString(),
    );
  }
}

class VerifyOtpResponse {
  VerifyOtpResponse({required this.user});

  final AadhaarUser user;
}

/// The core networking service for the Civic app.
/// 
/// Handles all outbound HTTP communication with the backend Node.js server.
/// Includes methods for authentication (OTP), submitting complaints with images,
/// and fetching community analytics and feeds.
class AadhaarApi {
  // Base URL is configured in ApiConstants.

  static AadhaarApiException _wrapError(Object e, String defaultMessage) {
    if (e is AadhaarApiException) return e;
    if (e is TimeoutException) {
      return AadhaarApiException('Connection timed out. Please check your internet connection and try again.');
    }
    if (e is SocketException) {
      return AadhaarApiException('Unable to reach the server. Please check your internet connection.');
    }
    return AadhaarApiException(defaultMessage);
  }

  static Future<SendOtpResponse> sendOtp(String aadhaarNumber) async {
    final uri = Uri.parse(ApiConstants.sendOtp);
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'aadhaarNumber': aadhaarNumber}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 || data['success'] != true) {
        throw AadhaarApiException(
          data['message']?.toString() ?? 'Failed to send OTP',
        );
      }

      return SendOtpResponse(
        maskedMobile: data['maskedMobile']?.toString() ?? '',
        phoneE164: data['phoneE164']?.toString() ?? '',
      );
    } catch (e) {
      throw _wrapError(e, 'Failed to send OTP');
    }
  }

  static Future<VerifyOtpResponse> verifyOtp(String aadhaarNumber) async {
    final uri = Uri.parse(ApiConstants.verifyOtp);
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'aadhaarNumber': aadhaarNumber}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 || data['success'] != true) {
        throw AadhaarApiException(
          data['message']?.toString() ?? 'Failed to verify OTP',
        );
      }

      final userMap = (data['user'] as Map).cast<String, dynamic>();

      return VerifyOtpResponse(user: AadhaarUser.fromJson(userMap));
    } catch (e) {
      throw _wrapError(e, 'Failed to verify OTP');
    }
  }

  static Future<Map<String, dynamic>> analyzeImage(File imageFile) async {
    final uri = Uri.parse(ApiConstants.analyzeImage);
    final request = http.MultipartRequest('POST', uri);
    
    // Add file
    final pic = await http.MultipartFile.fromPath('file', imageFile.path);
    request.files.add(pic);

    try {
      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 || data['success'] != true) {
        throw AadhaarApiException(
            data['message']?.toString() ?? 'AI Analysis Failed');
      }

      return data;
    } catch (e) {
      throw _wrapError(e, 'AI Analysis Failed');
    }
  }

  static Future<String> submitReport(Map<String, dynamic> reportData, File? imageFile) async {
    final uri = Uri.parse(ApiConstants.submitReport);
    
    try {
      final Map<String, dynamic> body = Map.from(reportData);

      // Convert image to Base64 if present
      if (imageFile != null) {
        final bytes = await imageFile.readAsBytes();
        String mimeType = 'image/jpeg';
        if (imageFile.path.toLowerCase().endsWith('.png')) mimeType = 'image/png';
        body['image'] = 'data:$mimeType;base64,${base64Encode(bytes)}';
      }

      // Ensure proper types for JSON serialization
      // In case reportData has JSON strings instead of objects (safety check)
      if (body['location'] is String) body['location'] = jsonDecode(body['location']);
      if (body['tags'] is String) body['tags'] = jsonDecode(body['tags']);
      if (body['metadata'] is String) body['metadata'] = jsonDecode(body['metadata']);

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 45)); // Increased timeout for upload

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw AadhaarApiException(data['message']?.toString() ?? 'Submission Failed');
      }

      if (data['success'] != true) {
         throw AadhaarApiException(data['message']?.toString() ?? 'Submission Failed');
      }

      return data['reportId']?.toString() ?? '';

    } catch (e) {
      print('Submit Report Error: $e');
      throw _wrapError(e, 'Submission Failed');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchUserReports(String userId) async {
    final uri = Uri.parse('${ApiConstants.fetchUserReports}/$userId');
    try {
        final response = await http.get(uri).timeout(const Duration(seconds: 10));
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        if (response.statusCode != 200 || data['success'] != true) {
             throw AadhaarApiException(data['message']?.toString() ?? 'Failed to fetch reports');
        }
        
        return (data['reports'] as List).cast<Map<String, dynamic>>();

    } catch (e) {
         throw _wrapError(e, 'Failed to fetch reports');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchPublicFeed({
    String? district, 
    String? status,
    String? category,
    String? severity,
    String? dateRange,
    int? limit,
    String? lastId
  }) async {
    String query = '';
    if (district != null && district != 'All Districts') query += 'district=$district&';
    if (status != null && status != 'All Reports') query += 'status=$status&';
    if (category != null && category != 'All' && category != 'all') query += 'category=$category&';
    if (severity != null && severity != 'All' && severity != 'all') query += 'severity=$severity&';
    if (dateRange != null && dateRange != 'All' && dateRange != 'all') query += 'dateRange=$dateRange&';
    if (limit != null) query += 'limit=$limit&';
    if (lastId != null) query += 'lastId=$lastId&';
    
    final uri = Uri.parse('${ApiConstants.fetchFeed}?$query');
    try {
        final response = await http.get(uri).timeout(const Duration(seconds: 20)); // Balanced timeout for initial loads
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        if (response.statusCode != 200 || data['success'] != true) {
             throw AadhaarApiException(data['message']?.toString() ?? 'Failed to fetch feed');
        }
        
        return (data['reports'] as List).cast<Map<String, dynamic>>();

    } catch (e) {
         throw _wrapError(e, 'Failed to fetch feed');
    }
  }

  static Future<void> upvoteReport(String reportId, String userId, String? userPhoto) async {
    final uri = Uri.parse('${ApiConstants.upvote}/$reportId');
    try {
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'userId': userId,
                'userPhoto': userPhoto
              }),
            )
            .timeout(const Duration(seconds: 8));
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] != true) throw AadhaarApiException(data['message'] ?? 'Upvote failed');
    } catch (e) {
        throw _wrapError(e, 'Failed to upvote report');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchComments(String reportId) async {
    final uri = Uri.parse('${ApiConstants.comments}/$reportId');
    try {
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 10));
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['comments'] as List).cast<Map<String, dynamic>>();
    } catch (e) {
        throw _wrapError(e, 'Failed to fetch comments');
    }
  }

  static Future<void> addComment(String reportId, String userId, String userName, String text, String? userPhoto) async {
    final uri = Uri.parse('${ApiConstants.addComment}/$reportId');
    try {
        await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                  'userId': userId,
                  'userName': userName,
                  'text': text,
                  'userPhoto': userPhoto
              }),
            )
            .timeout(const Duration(seconds: 8));
    } catch (e) {
        throw _wrapError(e, 'Failed to add comment');
    }
  }
  static Future<Map<String, dynamic>> fetchDistrictStats(String district) async {
    final uri = Uri.parse('${ApiConstants.districtStats}/$district');
    try {
        final response = await http.get(uri).timeout(const Duration(seconds: 30));
        return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
        throw _wrapError(e, 'Failed to fetch district stats');
    }
  }
  static Future<Map<String, dynamic>> sendChatMessage(String message, List<Map<String, String>> history) async {
    final uri = Uri.parse(ApiConstants.chat);
    try {
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'message': message, 'history': history}),
            )
            .timeout(const Duration(seconds: 30));
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        if (response.statusCode != 200 || data['success'] != true) {
             throw AadhaarApiException(data['message']?.toString() ?? 'Failed to send message');
        }
        
        return data;
    } catch (e) {
         throw _wrapError(e, 'Failed to send message');
    }
  }

  static Future<Map<String, dynamic>> fetchCommunityAnalytics(String? district) async {
    String query = district != null && district != 'All Districts' ? '?district=$district' : '';
    final uri = Uri.parse('${ApiConstants.communityAnalytics}$query');
    try {
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 30));
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] != true) throw AadhaarApiException('Failed to fetch analytics');
        return data['stats'];
    } catch (e) {
        throw _wrapError(e, 'Failed to fetch analytics');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchLeaderboard(String? district) async {
    String query = district != null && district != 'All Districts' ? '?district=$district' : '';
    final uri = Uri.parse('${ApiConstants.leaderboard}$query');
    try {
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 10));
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] != true) throw AadhaarApiException('Failed to fetch leaderboard');
        return (data['leaderboard'] as List).cast<Map<String, dynamic>>();
    } catch (e) {
        throw _wrapError(e, 'Failed to fetch leaderboard');
    }
  }
  static Future<Map<String, dynamic>> verifyReport(String reportId, String userId, String userEmail) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/report/verify/$reportId');
    try { 
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'userId': userId, 'userEmail': userEmail}),
            )
            .timeout(const Duration(seconds: 10));
            
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // Backend returns success: true, isVerified: bool, verificationCount: int
        if (response.statusCode != 200 && response.statusCode != 201) {
           throw AadhaarApiException(data['message']?.toString() ?? 'Failed to verify report');
        }
        return data; 
    } catch (e) {
        throw _wrapError(e, 'Failed to verify report');
    }
  }

  static Future<Map<String, dynamic>> fetchReportDetails(String reportId) async {
    final uri = Uri.parse('${ApiConstants.reportDetails}/$reportId');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      
      if (response.statusCode != 200 || data['success'] != true) {
        throw AadhaarApiException(data['message']?.toString() ?? 'Failed to fetch details');
      }
      
      return data['report'] as Map<String, dynamic>;
    } catch (e) {
      throw _wrapError(e, 'Failed to fetch details');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchNotifications(String userId) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/notifications/$userId');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['notifications']);
      }
      return [];
    } catch (e) {
      debugPrint("Fetch Notifications Error: $e");
      return [];
    }
  }

  static Future<void> markNotificationRead(String notificationId) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/notifications/mark-read/$notificationId');
    try {
      await http.post(uri).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("Mark Notification Read Error: $e");
    }
  }

  static Future<void> markAllNotificationsRead(String userId) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/notifications/mark-all-read/$userId');
    try {
      await http.post(uri).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("Mark All Notifications Read Error: $e");
    }
  }
}
