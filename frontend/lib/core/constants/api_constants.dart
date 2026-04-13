import 'package:flutter/foundation.dart';

class ApiConstants {
  static const String productionBaseUrl =
      'https://rokon-al-shiuokh.onrender.com/api';
  static const String webDevelopmentBaseUrl = 'http://localhost:5000/api';
  static const String emulatorDevelopmentBaseUrl = 'http://10.0.2.2:5000/api';

  static String get baseUrl {
    const configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (configuredBaseUrl.isNotEmpty) {
      return configuredBaseUrl;
    }

    if (kReleaseMode) {
      return productionBaseUrl;
    }

    if (kIsWeb) {
      return webDevelopmentBaseUrl;
    }

    return emulatorDevelopmentBaseUrl;
  }
}
