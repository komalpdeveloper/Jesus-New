import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BibleChatPage extends StatefulWidget {
  const BibleChatPage({super.key});

  @override
  State<BibleChatPage> createState() => _BibleChatPageState();
}

class _BibleChatPageState extends State<BibleChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _verseController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  String? _revealedVerse;

  static const String _apiKey = 'sk-chat-api-2025-Zx9Kp7Qm4Rt8Wv3Yh6Bf1Ng5Lc2Sd9Ae7Xu0Iy4';
  static const String _chatUrl = 'https://fastapi-chat-service-1-8.onrender.com/chat-bible';
  static const String _revealUrl = 'https://fastapi-chat-service-1-8.onrender.com/reveal-verse';

  @override
  void dispose() {
    _messageController.dispose();
    _verseController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': message});
      _isLoading = true;
    });

    _messageController.clear();

    try {
      final response = await http.post(
        Uri.parse(_chatUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey,
        },
        body: jsonEncode({'user_message': message}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Debug: print the full response
        print('Chat API Response: $data');
        
        setState(() {
          _messages.add({'role': 'assistant', 'text': data['response'] ?? 'No response'});
        });
      } else {
        setState(() {
          _messages.add({'role': 'error', 'text': 'Error ${response.statusCode}: ${response.body}'});
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'error', 'text': 'Error: $e'});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _revealVerse() async {
    final verse = _verseController.text.trim();
    if (verse.isEmpty) return;

    setState(() {
      _isLoading = true;
      _revealedVerse = null;
    });

    try {
      final response = await http.post(
        Uri.parse(_revealUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey,
        },
        body: jsonEncode({'verse_text': verse}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Debug: print the full response
        print('Reveal API Response: $data');
        
        // Try different possible response keys
        final revealed = data['revealed_verse'] ?? 
                        data['response'] ?? 
                        data['result'] ?? 
                        data.toString();
        
        setState(() {
          _revealedVerse = revealed;
        });
      } else {
        setState(() {
          _revealedVerse = 'Error ${response.statusCode}: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _revealedVerse = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text('Bible Chat', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                final isError = msg['role'] == 'error';
                
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                    decoration: BoxDecoration(
                      color: isError 
                          ? Colors.red[900] 
                          : isUser 
                              ? Colors.blue[900] 
                              : Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      msg['text'] ?? '',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),

          // Reveal verse section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[900],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Reveal Verse',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _verseController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Enter verse text...',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          filled: true,
                          fillColor: Colors.grey[850],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _revealVerse,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple[700],
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Text('Reveal'),
                    ),
                  ],
                ),
                if (_revealedVerse != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        _revealedVerse!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Chat input
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[850],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendMessage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    padding: const EdgeInsets.all(16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
