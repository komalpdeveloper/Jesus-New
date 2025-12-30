import 'package:clientapp/core/services/biblical_chat_api.dart';
import 'package:clientapp/core/models/chat_models.dart';
import 'package:clientapp/core/config/app_config.dart';

/// Simple API test utility for the Biblical Chat Service
/// This file can be used for manual testing and debugging
class ApiTester {
  /// Test health check endpoint
  static Future<void> testHealthCheck() async {
    print('🔍 Testing health check...');
    try {
      final health = await BiblicalChatApiService.checkHealth();
      print('✅ Health Status: ${health.status}');
      print('📄 Message: ${health.message}');
      print('⏰ Timestamp: ${health.timestamp}');
    } catch (e) {
      print('❌ Health check failed: $e');
    }
    print('');
  }

  /// Test chat with Jesus persona
  static Future<void> testJesusChat() async {
    print('✝️ Testing Jesus persona chat...');
    try {
      final response = await BiblicalChatApiService.sendMessage(
        persona: BiblicalPersona.jesus,
        message: 'I need peace in my heart',
      );
      print('✅ Jesus Response: ${response.response}');
      print('👤 Persona: ${response.persona}');
      print('🔐 Session: ${response.sessionId}');
    } on ApiError catch (e) {
      print('❌ Jesus chat failed (${e.statusCode}): ${e.detail}');
    } catch (e) {
      print('❌ Jesus chat failed: $e');
    }
    print('');
  }

  /// Test chat with God persona
  static Future<void> testGodChat() async {
    print('☁️ Testing God persona chat...');
    try {
      final response = await BiblicalChatApiService.sendMessage(
        persona: BiblicalPersona.god,
        message: 'Show me your strength',
      );
      print('✅ God Response: ${response.response}');
      print('👤 Persona: ${response.persona}');
      print('🔐 Session: ${response.sessionId}');
    } on ApiError catch (e) {
      print('❌ God chat failed (${e.statusCode}): ${e.detail}');
    } catch (e) {
      print('❌ God chat failed: $e');
    }
    print('');
  }

  /// Test chat with Living Word persona
  static Future<void> testLivingWordChat() async {
    print('📖 Testing Living Word persona chat...');
    try {
      final response = await BiblicalChatApiService.sendMessage(
        persona: BiblicalPersona.livingWord,
        message: 'What does the Bible say about wisdom?',
      );
      print('✅ Living Word Response: ${response.response}');
      print('👤 Persona: ${response.persona}');
      print('🔐 Session: ${response.sessionId}');
    } on ApiError catch (e) {
      print('❌ Living Word chat failed (${e.statusCode}): ${e.detail}');
    } catch (e) {
      print('❌ Living Word chat failed: $e');
    }
    print('');
  }

  /// Test session clearing
  static Future<void> testSessionClear() async {
    print('🗑️ Testing session clearing...');
    try {
      final result = await BiblicalChatApiService.clearSession(BiblicalPersona.jesus);
      print('✅ Session cleared: ${result.message}');
      print('🔐 Session ID: ${result.sessionId}');
    } on ApiError catch (e) {
      print('❌ Session clear failed (${e.statusCode}): ${e.detail}');
    } catch (e) {
      print('❌ Session clear failed: $e');
    }
    print('');
  }

  /// Test rate limiting behavior
  static Future<void> testRateLimiting() async {
    print('⏱️ Testing rate limiting...');
    
    // Send multiple rapid requests to trigger rate limiting
    for (int i = 0; i < 3; i++) {
      try {
        print('📤 Sending request ${i + 1}/3...');
        final response = await BiblicalChatApiService.sendMessage(
          persona: BiblicalPersona.jesus,
          message: 'Test message $i',
        );
        print('✅ Request ${i + 1} success: ${response.response.substring(0, 50)}...');
      } on ApiError catch (e) {
        if (e.statusCode == 429) {
          print('⏰ Rate limiting triggered: ${e.detail}');
        } else {
          print('❌ Request ${i + 1} failed (${e.statusCode}): ${e.detail}');
        }
      } catch (e) {
        print('❌ Request ${i + 1} failed: $e');
      }
      
      // Small delay between requests
      if (i < 2) await Future.delayed(const Duration(seconds: 1));
    }
    print('');
  }

  /// Test error handling with invalid input
  static Future<void> testErrorHandling() async {
    print('🚫 Testing error handling...');
    
    // Test empty message
    try {
      await BiblicalChatApiService.sendMessage(
        persona: BiblicalPersona.jesus,
        message: '',
      );
    } on ApiError catch (e) {
      print('✅ Empty message error caught (${e.statusCode}): ${e.detail}');
    }
    
    // Test extremely long message
    final longMessage = 'A' * (AppConfig.maxCharactersPerMessage + 100);
    try {
      await BiblicalChatApiService.sendMessage(
        persona: BiblicalPersona.jesus,
        message: longMessage,
      );
    } on ApiError catch (e) {
      print('✅ Long message error caught (${e.statusCode}): ${e.detail}');
    }
    print('');
  }

  /// Run all tests
  static Future<void> runAllTests() async {
    print('🚀 Starting Biblical Chat API Integration Tests');
    print('🌐 Base URL: ${AppConfig.baseUrl}');
    print('🔑 API Key: ${AppConfig.apiKey.substring(0, 20)}...');
    print('⏱️ Rate Limit: ${AppConfig.rateLimitPerMinute}/minute');
    print('📏 Max Characters: ${AppConfig.maxCharactersPerMessage}');
    print('=' * 50);
    print('');

    await testHealthCheck();
    await testJesusChat();
    await testGodChat();
    await testLivingWordChat();
    await testSessionClear();
    await testErrorHandling();
    await testRateLimiting();

    print('🏁 API Integration Tests Complete!');
  }
}

/// Uncomment the main function to run tests from command line
/// Run with: flutter pub run test_api.dart
/*
void main() async {
  await ApiTester.runAllTests();
}
*/