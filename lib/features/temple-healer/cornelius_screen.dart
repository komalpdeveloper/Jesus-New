import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'health_notes_screen.dart';
import '../../shared/widgets/back_nav_button.dart';

class CorneliusTempleHealerScreen extends StatefulWidget {
  const CorneliusTempleHealerScreen({super.key});

  @override
  State<CorneliusTempleHealerScreen> createState() =>
      _CorneliusTempleHealerScreenState();
}

class _CorneliusTempleHealerScreenState
    extends State<CorneliusTempleHealerScreen> {
  // --- Video Background ---
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;

  // --- API / Chat ---
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _sessionId = const Uuid().v4();
  final List<Map<String, String>> _messages =
      []; // {'sender': 'user'|'cornelius', 'text': '...'}
  bool _isTyping = false;

  // --- Constants ---
  static const String _apiUrl =
      "https://fastapi-chat-service-1-7-update.onrender.com/chat/cornelius";
  static const String _apiKey =
      "sk-chat-api-2025-Zx9Kp7Qm4Rt8Wv3Yh6Bf1Ng5Lc2Sd9Ae7Xu0Iy4";

  // --- Assets ---
  static const String _assetBackground = 'assets/temple/cornelius_bg.mp4';
  static const String _assetFallback = 'assets/temple-healer/wall.jpg';
  static const String _assetWindowFrame =
      'assets/temple-healer/window_frame.png';
  static const String _assetTable = 'assets/temple-healer/table.png';
  static const String _assetBooks = 'assets/temple-healer/books.png';
  static const String _assetNotebook = 'assets/temple-healer/notebook.png';

  String? _initError;

  @override
  void initState() {
    super.initState();
    _initializeVideo();

    // Initial greeting (optional)
    _messages.add({
      'sender': 'cornelius',
      'text':
          'Welcome to my sanctuary. How may I assist you with your healing journey today?',
    });
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.asset(_assetBackground);
      await _videoController.initialize().timeout(
        const Duration(seconds: 10),
      ); // Timeout added
      // Ensure we start playing immediately and loop
      await _videoController.setLooping(true);
      await _videoController.setVolume(0.0);
      await _videoController.play();

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _initError = null;
        });
      }
    } catch (e) {
      debugPrint("Error initializing video: $e");
      if (mounted) {
        setState(() {
          _isVideoInitialized = false;
          _initError = "Video Error: $e";
        });
      }
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- Logic ---

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _isTyping = true;
    });
    _textController.clear();
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json', 'X-API-Key': _apiKey},
        body: jsonEncode({'message': text, 'session_id': _sessionId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final botReply =
            data['response'] ??
            data['message'] ??
            data['reply'] ??
            response.body;

        setState(() {
          _messages.add({'sender': 'cornelius', 'text': botReply.toString()});
        });
      } else {
        setState(() {
          _messages.add({
            'sender': 'cornelius',
            'text':
                "I apologize, the spirits are quiet. (Error: ${response.statusCode})",
          });
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({
          'sender': 'cornelius',
          'text': "Connection to the temple lost.",
        });
      });
    } finally {
      setState(() {
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showCorneliusProfile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFAF9F6), // Parchment / Paper color
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: AssetImage('assets/temple-healer/avatar.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Cornelius",
                          style: TextStyle(
                            fontFamily: 'Serif', // Or use specific serif font
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          "The Child Healer",
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.brown),
                const SizedBox(height: 24),

                // Gallery
                SizedBox(
                  height: 150,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildGalleryItem('assets/temple-healer/1.png'),
                      _buildGalleryItem('assets/temple-healer/2.png'),
                      _buildGalleryItem('assets/temple-healer/3.png'),
                      _buildGalleryItem('assets/temple-healer/4.png'),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Story Title
                const Text(
                  "The Story",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Serif',
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),

                // Story Content
                const Text(
                  "Cornelius was the quiet kid no one expected. He grew up in the back streets near the temple, smaller than the other children and often sick himself. While they raced through the markets, he sat on the steps watching people’s faces—the way shoulders dropped when someone was tired, the way hands trembled when someone carried a secret they were afraid to say out loud.\n\nOne night, when his fever was high and everyone thought he might not wake up, Cornelius had a dream. In the dream, a Man stood beside his bed, eyes kind and steady. The Man laid a hand on his chest and the burning cooled at once.\n\n“Why are You helping me?” Cornelius asked.\n\n“Because one day,” the Man answered, “you will help them. Listen to Me, and listen to people. I will be with you.”\n\nWhen Cornelius woke up, the fever was gone. He didn’t yet know the name of the Man in his dream, but every time he walked past the temple, he felt the same warmth in his chest.\n\nAs he grew, Cornelius began spending his days in the temple halls where the physicians gathered. He was only a child, but he listened—really listened—to their questions, their debates, and the quiet sighs of the people waiting on the benches. When the doctors finished their long arguments, Cornelius would gently ask the one question no one had thought to ask, or remind them of the simple thing they had overlooked: “Did you ask if he’s afraid?” “Has she eaten in days?” “Maybe his heart is heavy, not just his body.”\n\nAt first the physicians smiled politely and moved on. But slowly they began to notice something. When Cornelius sat with the sick and simply talked, people calmed down. When he prayed the short, honest prayers he had learned from his dream—“Jesus, be near; Jesus, bring peace; Jesus, show us what to do”—things changed. Headaches faded. Tight chests loosened. Angry eyes softened into tears and then into rest.\n\nOne afternoon, the temple was crowded and tense. A young woman had arrived, shaking and breathless, with no clear illness the doctors could name. Voices rose, remedies were suggested and dismissed. Cornelius stepped close, knelt beside her, and quietly asked, “What hurts the most—your body, or your heart?” She broke down and admitted she was terrified of the future, certain God was angry with her.\n\nCornelius didn’t give a long lecture. He simply told her about the Man who had stood by his bed when he was sick. “His name is Jesus,” he said. “He is not here to crush you. He is here to carry you.” He prayed with her, slow and steady. Her breathing calmed. Her hands stopped shaking. The whole room went quiet.\n\nFrom that day on, the physicians started calling him “the child healer.” Cornelius never claimed to be a great doctor. He always said the same thing: “I just listen to Jesus, and I listen to you.”",
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    fontFamily: 'Serif',
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGalleryItem(String path) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(image: AssetImage(path), fit: BoxFit.cover),
      ),
    );
  }

  void _navToHealthNotes() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const HealthNotesScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // Calculate visuals based on screen width
    final screenWidth = MediaQuery.of(context).size.width;

    // Table: 1500 x 1000 => Aspect Ratio 1.5
    // Height = Width / 1.5
    final deskHeight = screenWidth * 1.3;

    // Books: 500x500
    // We want them reasonably sized on the desk.
    final bookSize = screenWidth * 0.4;

    // Lift the desk up to overlap the frame more naturally
    final deskBottomOffset = screenWidth * -0.3;

    // Window Frame: 1290 x 1600 => Aspect Ratio ~0.8
    // We assume it fits width at the top.
    // We want the chat to start below the "arch" of the frame.
    // Let's approximate the header part of the frame is the top 15-20%.

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Layer 0: Wall Background (Most Below)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height:
                MediaQuery.of(context).size.height *
                0.5, // 1/2 size, at the bottom
            child: Image.asset(_assetFallback, fit: BoxFit.cover),
          ),

          // Layer 1: Background (Video or Fallback) -> Constrained 'Inside' Frame
          if (_isVideoInitialized)
            Positioned(
              top:
                  screenWidth *
                  0.1, // Push down slightly more to clear top arch
              left: screenWidth * 0.10, // Tighten side margins
              right: screenWidth * 0.10, // Tighten side margins
              height:
                  screenWidth *
                  0.98, // Explicit height to stop before bottom wood bezel
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController.value.size.width,
                    height: _videoController.value.size.height,
                    child: VideoPlayer(_videoController),
                  ),
                ),
              ),
            )
          else if (_initError != null)
            // Fallback image + Error Text matched to frame
            Positioned(
              top: screenWidth * 0.1,
              left: screenWidth * 0.1,
              right: screenWidth * 0.1,
              height: screenWidth * 0.98, // Explicit height matching video
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(_assetFallback, fit: BoxFit.cover),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.black54,
                      child: Text(
                        _initError!,
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Layer 1.5: Glass Tint
          Positioned(
            top: screenWidth * 0.1,
            left: screenWidth * 0.1,
            right: screenWidth * 0.1,
            height: screenWidth * 0.98,
            child: Container(color: Colors.white.withOpacity(0.1)),
          ),

          // Layer 2: Glass Chat Overlay
          Positioned(
            top: screenWidth * 0.1,
            left: screenWidth * 0.1,
            right: screenWidth * 0.1,
            height: screenWidth * 0.98,
            child: _buildGlassOverlay(),
          ),

          // Layer 3: Window Frame (Top)
          Positioned(
            top: -5,
            left: -5,
            right: -5,
            child: IgnorePointer(
              child: Image.asset(
                _assetWindowFrame,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
              ),
            ),
          ),

          // Layer 4: Desk (Bottom)
          Positioned(
            bottom: deskBottomOffset,
            left: 0,
            right: 0,
            height: deskHeight,
            child: IgnorePointer(
              child: Image.asset(
                _assetTable,
                fit: BoxFit.cover,
                alignment: Alignment.bottomCenter,
              ),
            ),
          ),

          // Layer 5: Interactive Objects (Books & Notebook)
          // Books (Left)
          Positioned(
            bottom: (deskHeight * 0.7) + deskBottomOffset, // Lifted higher
            left: 8,
            width: bookSize,
            height: bookSize,
            child: GestureDetector(
              onTap: _showCorneliusProfile,
              child: Image.asset(_assetBooks, fit: BoxFit.contain),
            ),
          ),

          // Notebook (Right/Center)
          Positioned(
            bottom: (deskHeight * 0.7) + deskBottomOffset, // Lifted higher
            right: 8,
            width: bookSize,
            height: bookSize,
            child: GestureDetector(
              onTap: _navToHealthNotes,
              child: Image.asset(_assetNotebook, fit: BoxFit.contain),
            ),
          ),

          // Layer 6: Debug / Loading Overlay (Top Most)
          if (!_isVideoInitialized && _initError == null)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.amber),
                      const SizedBox(height: 16),
                      const Text(
                        "Summoning Temple Vision...",
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_initError != null)
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red.withOpacity(0.8),
                child: Text(
                  "Video Failed: $_initError\nCheck asset path or format.",
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // Layer 7: Back Navigation Button
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFD4AF37), width: 1),
              ),
              child: const BackNavButton(
                iconSize: 18,
                padding: EdgeInsets.all(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassOverlay() {
    return Container(
      decoration: BoxDecoration(
        // Removed global blur
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Chat List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['sender'] == 'user';
                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isUser
                          ? const Radius.circular(16)
                          : Radius.zero,
                      bottomRight: isUser
                          ? Radius.zero
                          : const Radius.circular(16),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        decoration: BoxDecoration(
                          color: isUser
                              ? const Color(0xFFD4AF37).withOpacity(
                                  0.4,
                                ) // Gold/Temple theme (More transparent)
                              : Colors.black.withOpacity(0.4),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                          // No shadow on glass usually, but subtle is okay
                        ),
                        child: Text(
                          msg['text'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14, // Smaller font
                            fontFamily: 'Rubik',
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Glass TextField
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            // Wrap TextField container in glass too? User asked for "glass effect on bubbles msgs".
            // But usually input field also looks nice as glass.
            // I'll keep it simple: just reduced size + glass look.
            height:
                50, // Constrain height explicitly to make it smaller/sleeker
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: const Color(0xFFD4AF37).withOpacity(0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ), // Smaller text
                    cursorColor: const Color(0xFFD4AF37),
                    decoration: const InputDecoration(
                      hintText: "Speak...",
                      hintStyle: TextStyle(color: Colors.white54, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0, // Centered vertically by Container height
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  iconSize: 20,
                  icon: _isTyping
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFD4AF37),
                          ),
                        )
                      : const Icon(Icons.send, color: Color(0xFFD4AF37)),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
