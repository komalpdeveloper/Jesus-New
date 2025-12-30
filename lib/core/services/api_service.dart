import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:math';
import '../config/app_config.dart';

class ApiService {
  // Use configuration from AppConfig
  static const String baseUrl = AppConfig.baseUrl;
  static const String apiKey = AppConfig.apiKey;
  
  // Session management for conversation continuity
  static final Map<String, String> _sessions = {};
  
  /// Generates a unique session ID for a user
  static String generateSessionId(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(9999);
    return '${userId}_${timestamp}_$random';
  }
  
  /// Gets or creates a session ID for the given endpoint/user
  static String getSessionId(String endpoint) {
    final key = endpoint.replaceAll('/', '_');
    if (!_sessions.containsKey(key)) {
      _sessions[key] = generateSessionId(key);
    }
    return _sessions[key]!;
  }
  
  /// Clears session for a specific endpoint
  static Future<void> clearSession(String endpoint) async {
    final key = endpoint.replaceAll('/', '_');
    final sessionId = _sessions[key];
    
    if (sessionId != null) {
      try {
        // Call the backend to clear the session
        final uri = Uri.parse('$baseUrl/chat/session/$sessionId');
        await http.delete(
          uri,
          headers: {
            'X-API-Key': apiKey,
          },
        ).timeout(const Duration(seconds: 10));
      } catch (e) {
                print('[ApiService] Error clearing session: $e');
      }
      
      // Remove from local storage
      _sessions.remove(key);
    }
  }

  /// Sends a chat message to the given endpoint.
  ///
  /// - endpoint: can be a relative path (e.g. "/chat/jesus") or an absolute URL
  /// - prompt: the user's message to send in the {"message": prompt} body
  /// - sessionId: optional session ID for conversation continuity (auto-generated if not provided)
  static Future<String> send(String endpoint, String prompt, {String? sessionId}) async {
    final bool isAbsolute = endpoint.startsWith('http://') || endpoint.startsWith('https://');
    final uri = Uri.parse(isAbsolute ? endpoint : '$baseUrl$endpoint');

    try {
      // Debug: print the final URL being called (useful during integration)
      // ignore: avoid_print
      print('[ApiService] POST -> ${uri.toString()}');

      // Build the request body based on the Biblical chat API format
      final Map<String, dynamic> requestBody = {
        'message': prompt,
      };
      
      // Use provided session or auto-generate one for conversation continuity
      final effectiveSessionId = sessionId ?? getSessionId(endpoint);
      requestBody['session_id'] = effectiveSessionId;

      http.Response res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'X-API-Key': apiKey,
            },
            // Backend expects {"message": "...", "session_id": "..."} for Biblical chats
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 45));

      // If 404, try once more toggling trailing slash, in case the router is strict
      if (res.statusCode == 404) {
        final bool hasSlash = uri.path.endsWith('/');
        final String newPath = hasSlash && uri.path.length > 1
            ? uri.path.substring(0, uri.path.length - 1)
            : (hasSlash ? uri.path : uri.path + '/');
        final alt = uri.replace(path: newPath);
        // ignore: avoid_print
        print('[ApiService] 404 fallback -> ${alt.toString()}');
        res = await http
            .post(
              alt,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'X-API-Key': apiKey,
              },
              body: jsonEncode(requestBody),
            )
            .timeout(const Duration(seconds: 30));
      }

      // If transient server errors, retry up to 2 times with small backoff
      int attempts = 0;
      while (res.statusCode >= 500 && attempts < 2) {
        attempts += 1;
        await Future.delayed(Duration(milliseconds: 400 * attempts));
        res = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'X-API-Key': apiKey,
              },
              body: jsonEncode(requestBody),
            )
            .timeout(const Duration(seconds: 30));
      }

      if (res.statusCode >= 200 && res.statusCode < 300) {
        // Try to parse the response smartly
        final contentType = res.headers['content-type'] ?? '';
        if (contentType.contains('application/json')) {
          final dynamic data = jsonDecode(res.body);
          if (data is Map<String, dynamic>) {
            // Biblical chat APIs return responses in 'response' field
            // Try Biblical API format first, then fallback to other common keys
            return data['response'] ??
                data['reply'] ??
                data['message'] ??
                data['text'] ??
                data['answer'] ??
                // If nothing obvious, return first string value or the whole JSON stringified
                (data.values.firstWhere(
                  (v) => v is String && v.isNotEmpty,
                  orElse: () => jsonEncode(data),
                ) as String);
          } else if (data is List) {
            // If it's a list, join any string elements
            final strings = data.whereType<String>().toList();
            if (strings.isNotEmpty) return strings.join('\n');
          }
          // Fallback to raw body
          return res.body;
        } else {
          // Non-JSON response, return as-is
          return res.body;
        }
      } else {
        return 'Error ${res.statusCode}: ${res.body}';
      }
    } on SocketException {
      return 'Network error: Please check your internet connection.';
    } on FormatException {
      // Response wasn't valid JSON when expected; return raw
      return 'Received unexpected response format.';
    } on HttpException catch (e) {
      return 'HTTP error: ${e.message}';
    } on TimeoutException {
      return 'Request timed out. Please try again.';
    } catch (e) {
      return 'Unexpected error: $e';
    }
  }
}
