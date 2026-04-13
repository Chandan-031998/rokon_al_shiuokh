import 'package:flutter/foundation.dart';

class ApiConstants {
  static String get baseUrl {
    const configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (configuredBaseUrl.isNotEmpty) {
      return configuredBaseUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }

    return 'http://10.0.2.2:5000/api';
  }
}
