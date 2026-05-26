import 'package:flutter/foundation.dart';

class ApiLogger {
  static void request(String method, Uri uri, {String? label}) {
    if (!kDebugMode) return;
    debugPrint('[API] ${label ?? method} -> $method ${_redactUri(uri)}');
  }

  static void response(
    String method,
    Uri uri,
    int statusCode, {
    String? label,
    String? body,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[API] ${label ?? method} <- $statusCode $method ${_redactUri(uri)}',
    );
    if (body != null && body.isNotEmpty) {
      debugPrint('[API] response body: ${_truncate(body)}');
    }
  }

  static void error(String method, Uri uri, Object error, {String? label}) {
    if (!kDebugMode) return;
    debugPrint('[API] ${label ?? method} !! $method ${_redactUri(uri)}');
    debugPrint('[API] error: $error');
  }

  static Uri _redactUri(Uri uri) {
    if (!uri.queryParameters.containsKey('api_key')) return uri;
    return uri.replace(
      queryParameters: {...uri.queryParameters, 'api_key': '***'},
    );
  }

  static String _truncate(String value) {
    const maxLength = 500;
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength)}...';
  }
}
