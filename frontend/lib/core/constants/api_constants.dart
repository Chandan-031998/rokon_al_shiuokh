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

    return productionBaseUrl;
  }

  static Uri endpoint(
    String path, {
    Map<String, Object?>? queryParameters,
  }) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final resolvedQueryParameters = queryParameters == null
        ? null
        : {
            for (final entry in queryParameters.entries)
              if (entry.value != null) entry.key: '${entry.value}',
          };

    return Uri.parse('$baseUrl$normalizedPath').replace(
      queryParameters: resolvedQueryParameters?.isEmpty ?? true
          ? null
          : resolvedQueryParameters,
    );
  }

  static String get localDevelopmentHint {
    if (kIsWeb) {
      return webDevelopmentBaseUrl;
    }
    return emulatorDevelopmentBaseUrl;
  }
}
