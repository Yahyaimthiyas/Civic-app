import 'package:geolocator/geolocator.dart';

class GeofenceService {
  // Approximate Bounding Box for Tamil Nadu
  static const double minLat = 8.0;
  static const double maxLat = 14.0; // Slightly generous to include border areas
  static const double minLng = 76.0;
  static const double maxLng = 81.0;

  static const List<String> allowedKeywords = [
    'tamil nadu', 'tamilnadu', 'tn', 'chennai', 'coimbatore', 
    'madurai', 'salem', 'tiruchirappalli', 'trichy', 'tirunelveli',
    'vellore', 'erode', 'thoothukudi', 'thanjavur'
  ];

  static Future<bool> isLocationAllowed(Position position, String? address) async {
    // 1. Check Coordinates
    bool inBounds = position.latitude >= minLat && 
                    position.latitude <= maxLat && 
                    position.longitude >= minLng && 
                    position.longitude <= maxLng;

    if (inBounds) return true;

    // 2. Check Address (Fallback)
    if (address != null) {
      String lowerAddr = address.toLowerCase();
      for (String keyword in allowedKeywords) {
        if (lowerAddr.contains(keyword)) return true;
      }
    }

    return false;
  }
}
