// Configuration constants for the app
class AppConfig {
  // API Configuration - Updated to production endpoint
  static const String baseUrl = 'https://fastapi-chat-service-1-8.onrender.com';
  
  // Actual working API key for the backend service
  static const String apiKey = 'sk-chat-api-2025-Zx9Kp7Qm4Rt8Wv3Yh6Bf1Ng5Lc2Sd9Ae7Xu0Iy4';
  
  // Chat endpoints
  static const String jesusEndpoint = '/chat/jesus';
  static const String godEndpoint = '/chat/god';
  static const String wordEndpoint = '/chat/word';
  
  // Rate limiting info (from API docs) - Currently disabled on backend
  static const int rateLimitPerMinute = 0; // Unlimited during testing phase
  static const int maxCharactersPerMessage = 4000;
  
  // Session configuration
  static const Duration sessionTimeout = Duration(minutes: 30);
  
  // App settings
  static const String appVersion = '1.0.0';
  static const bool enableDebugLogs = true;
}