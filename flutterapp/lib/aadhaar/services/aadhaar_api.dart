import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

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

class AadhaarUser {
  AadhaarUser({
    required this.id, // Added ID
    required this.name,
    required this.aadhaarNumber,
    required this.phoneNumber,
    this.email,
    this.address,
    this.photoUrl,
    this.dob,
    this.gender,
  });

  final String id;
  final String name;
  final String aadhaarNumber;
  final String phoneNumber;
  final String? email;
  final String? address;
  final String? photoUrl;
  final String? dob;
  final String? gender;

  factory AadhaarUser.fromJson(Map<String, dynamic> json) {
    return AadhaarUser(
      id: json['id']?.toString() ?? 'USER_${DateTime.now().millisecondsSinceEpoch}', // Auto-generate if missing
      name: json['name']?.toString() ?? 'Unknown',
      aadhaarNumber: json['aadhaarNumber']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      email: json['email']?.toString(),
      address: json['address']?.toString(),
      photoUrl: json['photoUrl']?.toString(),
      dob: json['dob']?.toString(),
      gender: json['gender']?.toString(),
    );
  }
}

class VerifyOtpResponse {
  VerifyOtpResponse({required this.user});

  final AadhaarUser user;
}

class AadhaarApi {
  static const String _baseUrl = 'http://10.190.94.188:4000';

  static Future<SendOtpResponse> sendOtp(String aadhaarNumber) async {
    final uri = Uri.parse('$_baseUrl/aadhaar/send-otp');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'aadhaarNumber': aadhaarNumber}),
      );

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
      print('AadhaarAPI Error: $e');
      rethrow;
    }
  }

  static Future<VerifyOtpResponse> verifyOtp(
    String aadhaarNumber,
    String otp,
  ) async {
    final uri = Uri.parse('$_baseUrl/aadhaar/verify-otp');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'aadhaarNumber': aadhaarNumber, 'otp': otp}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200 || data['success'] != true) {
      throw AadhaarApiException(
        data['message']?.toString() ?? 'Failed to verify OTP',
      );
    }

    final userMap = (data['user'] as Map).cast<String, dynamic>();

    return VerifyOtpResponse(user: AadhaarUser.fromJson(userMap));
  }

  static Future<Map<String, dynamic>> analyzeImage(File imageFile) async {
    final uri = Uri.parse('$_baseUrl/report/analyze');
    final request = http.MultipartRequest('POST', uri);
    
    // Add file
    final pic = await http.MultipartFile.fromPath('file', imageFile.path);
    request.files.add(pic);

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 || data['success'] != true) {
        throw AadhaarApiException(data['message']?.toString() ?? 'AI Analysis Failed');
      }

      return data;
    } catch (e) {
      print('AI Upload Error: $e');
      rethrow;
    }
  }

  static Future<String> submitReport(Map<String, dynamic> reportData, File? imageFile) async {
    final uri = Uri.parse('$_baseUrl/report/submit');
    final request = http.MultipartRequest('POST', uri);

    // Add Fields
    reportData.forEach((key, value) {
        if (value is Map || value is List) {
            request.fields[key] = jsonEncode(value);
        } else {
            request.fields[key] = value.toString();
        }
    });

    // Add File
    if (imageFile != null) {
        final pic = await http.MultipartFile.fromPath('file', imageFile.path);
        request.files.add(pic);
    }

    try {
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        if (response.statusCode != 200 || data['success'] != true) {
             throw AadhaarApiException(data['message']?.toString() ?? 'Submission Failed');
        }
        
        return data['reportId']?.toString() ?? '';

    } catch (e) {
        print('Submit Report Error: $e');
        rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchUserReports(String userId) async {
    final uri = Uri.parse('$_baseUrl/report/user/$userId');
    try {
        final response = await http.get(uri);
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        if (response.statusCode != 200 || data['success'] != true) {
             throw AadhaarApiException(data['message']?.toString() ?? 'Failed to fetch reports');
        }
        
        return (data['reports'] as List).cast<Map<String, dynamic>>();

    } catch (e) {
         print('Fetch Reports Error: $e');
         rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchPublicFeed() async {
    final uri = Uri.parse('$_baseUrl/report/feed');
    try {
        final response = await http.get(uri);
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        if (response.statusCode != 200 || data['success'] != true) {
             throw AadhaarApiException(data['message']?.toString() ?? 'Failed to fetch feed');
        }
        
        return (data['reports'] as List).cast<Map<String, dynamic>>();

    } catch (e) {
         print('Fetch Feed Error: $e');
         rethrow;
    }
  }
}
