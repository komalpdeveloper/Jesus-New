import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:math';
import '../config/app_config.dart';
import '../models/chat_models.dart';

/// Enhanced API service for Biblical Chat Service
/// Provides proper error handling, model usage, and rate limiting awareness
class BiblicalChatApiService {
  static const String _baseUrl = AppConfig.baseUrl;
  static const String _apiKey = AppConfig.apiKey;
  
  // Session management for conversation continuity
  static final Map<String, String> _sessions = {};
  
  // Rate limiting tracking
  static final Map<String, DateTime> _lastRequestTime = {};
  static const Duration _minRequestInterval = Duration(seconds: 12); // 5 req/min = 12s interval
  
  /// Generates a unique session ID
  static String _generateSessionId(String endpoint) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(9999);
    final personaKey = endpoint.replaceAll('/chat/', '').replaceAll('/', '');
    return '${personaKey}_${timestamp}_$random';
  }
  
  /// Gets or creates a session ID for the given endpoint
  static String getSessionId(String endpoint) {
    if (!_sessions.containsKey(endpoint)) {
      _sessions[endpoint] = _generateSessionId(endpoint);
    }
    return _sessions[endpoint]!;
  }
  
  /// Checks if we should wait before making another request to avoid rate limiting
  static Duration? getWaitTime(String endpoint) {
    // Rate limiting is currently disabled on the backend during testing
    if (AppConfig.rateLimitPerMinute == 0) {
      return null; // No rate limiting
    }
    
    final lastRequest = _lastRequestTime[endpoint];
    if (lastRequest == null) return null;
    
    final elapsed = DateTime.now().difference(lastRequest);
    if (elapsed < _minRequestInterval) {
      return _minRequestInterval - elapsed;
    }
    return null;
  }
  
  /// Records the time of the last request
  static void _recordRequestTime(String endpoint) {
    _lastRequestTime[endpoint] = DateTime.now();
  }

  /// Sends a chat message to the specified Biblical persona
  static Future<ChatResponse> sendMessage({
    required BiblicalPersona persona,
    required String message,
    String? sessionId,
  }) async {
    // Validate message length
    if (message.isEmpty) {
      throw ApiError(
        detail: 'Message cannot be empty',
        statusCode: 400,
      );
    }
    
    if (message.length > AppConfig.maxCharactersPerMessage) {
      throw ApiError(
        detail: 'Message too long. Maximum ${AppConfig.maxCharactersPerMessage} characters allowed.',
        statusCode: 422,
      );
    }

    // Check for rate limiting (currently disabled on backend)
    final waitTime = getWaitTime(persona.endpoint);
    if (waitTime != null && waitTime.inMilliseconds > 0 && AppConfig.rateLimitPerMinute > 0) {
      throw ApiError(
        detail: 'Please wait ${waitTime.inSeconds} seconds before sending another message.',
        statusCode: 429,
      );
    }

    final effectiveSessionId = sessionId ?? getSessionId(persona.endpoint);
    final request = ChatRequest(
      message: message,
      sessionId: effectiveSessionId,
    );

    try {
      final uri = Uri.parse('$_baseUrl${persona.endpoint}');
      _recordRequestTime(persona.endpoint);

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-API-Key': _apiKey,
        },
        body: jsonEncode(request.toJson()),
      ).timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } on SocketException {
      throw ApiError(
        detail: 'Network error. Please check your internet connection.',
        statusCode: 0,
      );
    } on TimeoutException {
      throw ApiError(
        detail: 'Request timed out. Please try again.',
        statusCode: 408,
      );
    } on HttpException catch (e) {
      throw ApiError(
        detail: 'HTTP error: ${e.message}',
        statusCode: 0,
      );
    } catch (e) {
      throw ApiError(
        detail: 'Unexpected error: $e',
        statusCode: 500,
      );
    }
  }

  /// Handles HTTP response and converts to ChatResponse or throws ApiError
  static ChatResponse _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    
    try {
      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      
      if (statusCode >= 200 && statusCode < 300) {
        // Success response
        return ChatResponse.fromJson(jsonData);
      } else {
        // Error response
        throw ApiError.fromJson(jsonData, statusCode);
      }
    } on FormatException {
      // Response is not valid JSON
      if (statusCode >= 200 && statusCode < 300) {
        // If it's a successful status but not JSON, treat as plain text response
        return ChatResponse(
          response: response.body,
          persona: 'Unknown',
          sessionId: 'unknown',
        );
      } else {
        throw ApiError(
          detail: 'Invalid response format: ${response.body}',
          statusCode: statusCode,
        );
      }
    }
  }

  /// Clears conversation session for a specific persona
  static Future<SessionClearResponse> clearSession(BiblicalPersona persona) async {
    final sessionId = _sessions[persona.endpoint];
    if (sessionId == null) {
      throw ApiError(
        detail: 'No active session found',
        statusCode: 404,
      );
    }

    try {
      final uri = Uri.parse('$_baseUrl/chat/session/$sessionId');
      final response = await http.delete(
        uri,
        headers: {
          'X-API-Key': _apiKey,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Remove from local storage
        _sessions.remove(persona.endpoint);
        _lastRequestTime.remove(persona.endpoint);
        
        try {
          final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
          return SessionClearResponse.fromJson(jsonData);
        } on FormatException {
          return SessionClearResponse(
            message: 'Session cleared successfully',
            sessionId: sessionId,
          );
        }
      } else {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        throw ApiError.fromJson(jsonData, response.statusCode);
      }
    } on SocketException {
      throw ApiError(
        detail: 'Network error. Please check your internet connection.',
        statusCode: 0,
      );
    } on TimeoutException {
      throw ApiError(
        detail: 'Request timed out. Please try again.',
        statusCode: 408,
      );
    } catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError(
        detail: 'Unexpected error: $e',
        statusCode: 500,
      );
    }
  }

  /// Checks API health status
  static Future<HealthStatus> checkHealth() async {
    try {
      final uri = Uri.parse('$_baseUrl/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return HealthStatus.fromJson(jsonData);
      } else {
        return HealthStatus(
          status: 'error',
          message: 'API returned status ${response.statusCode}',
          timestamp: DateTime.now().toIso8601String(),
        );
      }
    } catch (e) {
      return HealthStatus(
        status: 'error',
        message: 'Failed to connect to API: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Gets API statistics (requires authentication)
  static Future<ApiStats> getStats() async {
    try {
      final uri = Uri.parse('$_baseUrl/stats');
      final response = await http.get(
        uri,
        headers: {
          'X-API-Key': _apiKey,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiStats.fromJson(jsonData);
      } else {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        throw ApiError.fromJson(jsonData, response.statusCode);
      }
    } on SocketException {
      throw ApiError(
        detail: 'Network error. Please check your internet connection.',
        statusCode: 0,
      );
    } on TimeoutException {
      throw ApiError(
        detail: 'Request timed out. Please try again.',
        statusCode: 408,
      );
    } catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError(
        detail: 'Unexpected error: $e',
        statusCode: 500,
      );
    }
  }

  /// Gets list of available AI models (requires authentication)
  static Future<List<String>> getAvailableModels() async {
    try {
      final uri = Uri.parse('$_baseUrl/models');
      final response = await http.get(
        uri,
        headers: {
          'X-API-Key': _apiKey,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.cast<String>();
        } else if (data is Map<String, dynamic>) {
          // Handle different response formats
          final models = data['models'] ?? data['data'] ?? [];
          if (models is List) {
            return models.cast<String>();
          }
        }
        return [];
      } else {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        throw ApiError.fromJson(jsonData, response.statusCode);
      }
    } on SocketException {
      throw ApiError(
        detail: 'Network error. Please check your internet connection.',
        statusCode: 0,
      );
    } on TimeoutException {
      throw ApiError(
        detail: 'Request timed out. Please try again.',
        statusCode: 408,
      );
    } catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError(
        detail: 'Unexpected error: $e',
        statusCode: 500,
      );
    }
  }
}