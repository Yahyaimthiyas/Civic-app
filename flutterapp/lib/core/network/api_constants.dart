/// @file api_constants.dart
/// @description Core UI component for the Civic App.
/// Professionally structured and maintained by the Civic App Team.

class ApiConstants {
  // Replace with your machine's IP address if running on a real device
  // 10.0.2.2 for Android Emulator, localhost for iOS Simulator
  static const String baseUrl = 'http://10.1.34.184:4000';
  
  static const String sendOtp = '$baseUrl/aadhaar/send-otp';
  static const String verifyOtp = '$baseUrl/aadhaar/verify-otp';
  static const String analyzeImage = '$baseUrl/report/analyze';
  static const String submitReport = '$baseUrl/report/submit';
  static const String fetchUserReports = '$baseUrl/report/user';
  static const String fetchFeed = '$baseUrl/report/feed';
  static const String upvote = '$baseUrl/report/upvote';
  static const String comments = '$baseUrl/report/comments';
  static const String addComment = '$baseUrl/report/comment';
  static const String districtStats = '$baseUrl/report/stats';
  static const String chat = '$baseUrl/chat';
  static const String communityAnalytics = '$baseUrl/community/analytics';
  static const String leaderboard = '$baseUrl/community/leaderboard';
  static const String reportDetails = '$baseUrl/report/details';
}
