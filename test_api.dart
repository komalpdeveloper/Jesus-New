import 'dart:io';
import 'lib/core/services/biblical_chat_api.dart';
import 'lib/core/models/chat_models.dart';

void main() async {
  print('🙏 Testing Biblical Chat API Integration...\n');
  
  // Test 1: Health Check
  print('1. Testing API Health Check...');
  try {
    final health = await BiblicalChatApiService.checkHealth();
    print('✅ Health Status: ${health.status}');
    print('   Message: ${health.message}');
    print('   Timestamp: ${health.timestamp}\n');
  } catch (e) {
    print('❌ Health check failed: $e\n');
  }

  // Test 2: Chat with Jesus
  print('2. Testing Jesus Persona...');
  try {
    final response = await BiblicalChatApiService.sendMessage(
      persona: BiblicalPersona.jesus,
      message: 'I need peace in my heart',
    );
    print('✅ Jesus Response:');
    print('   ${response.response}');
    print('   Persona: ${response.persona}');
    print('   Session: ${response.sessionId}\n');
  } catch (e) {
    print('❌ Jesus chat failed: $e\n');
  }

  // Test 3: Chat with God the Father
  print('3. Testing God the Father Persona...');
  try {
    final response = await BiblicalChatApiService.sendMessage(
      persona: BiblicalPersona.god,
      message: 'Show me your strength',
    );
    print('✅ God the Father Response:');
    print('   ${response.response}');
    print('   Persona: ${response.persona}');
    print('   Session: ${response.sessionId}\n');
  } catch (e) {
    print('❌ God the Father chat failed: $e\n');
  }

  // Test 4: Chat with Living Word
  print('4. Testing Living Word Persona...');
  try {
    final response = await BiblicalChatApiService.sendMessage(
      persona: BiblicalPersona.livingWord,
      message: 'What does the Bible say about wisdom?',
    );
    print('✅ Living Word Response:');
    print('   ${response.response}');
    print('   Persona: ${response.persona}');
    print('   Session: ${response.sessionId}\n');
  } catch (e) {
    print('❌ Living Word chat failed: $e\n');
  }

  // Test 5: API Stats (optional)
  print('5. Testing API Statistics...');
  try {
    final stats = await BiblicalChatApiService.getStats();
    print('✅ API Stats:');
    print('   Endpoints: ${stats.endpoints.keys.join(", ")}');
    print('   Features: ${stats.features.keys.join(", ")}\n');
  } catch (e) {
    print('❌ Stats failed: $e\n');
  }

  print('🎯 API Integration Test Complete!');
  exit(0);
}