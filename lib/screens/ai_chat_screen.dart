import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/ai_services.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  _AIChatScreenState createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [];
  final AIService _aiService = AIService();

  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isTyping = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  String _userType = "user";

  @override
  void initState() {
    super.initState();
    _checkUserType();
    _initTts();
  }

  void _initTts() async {
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setSpeechRate(1.0);
    await _flutterTts.setPitch(1.05);

    _flutterTts.setStartHandler(() => setState(() => _isSpeaking = true));
    _flutterTts.setCompletionHandler(() => setState(() => _isSpeaking = false));
    _flutterTts.setErrorHandler((msg) => setState(() => _isSpeaking = false));

    try {
      await _flutterTts.setEngine("com.google.android.tts");
    } catch (e) {
      debugPrint("Google TTS not available.");
    }
  }

  Future<void> _checkUserType() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userType = (prefs.getString('userType') ?? "user").toLowerCase();
    });
  }

  void _listen() async {
    if (!_isListening) {
      await _flutterTts.stop();

      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          pauseFor: const Duration(seconds: 2),
          listenFor: const Duration(seconds: 30),
          onResult: (val) {
            String heardText = val.recognizedWords.toLowerCase();

            if (heardText.contains("stop") || heardText.contains("chup") ||
                heardText.contains("ruko") || heardText.contains("wait")) {
              _flutterTts.stop();
              _speech.stop();
              setState(() {
                _isListening = false;
                _isSpeaking = false;
                _controller.clear();
              });
              return;
            }

            setState(() {
              _controller.text = val.recognizedWords;
            });

            if (val.finalResult) {
              setState(() => _isListening = false);
              _sendMessage(fromVoice: true);
            }
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
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

  void _sendMessage({bool fromVoice = false}) async {
    if (_controller.text.trim().isEmpty) return;

    await _flutterTts.stop();

    String userMsg = _controller.text.trim();
    String currentTime = DateFormat('hh:mm a').format(DateTime.now());

    setState(() {
      _messages.add({"role": "user", "text": userMsg, "time": currentTime});
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    String rawAiMsg = await _aiService.getAIResponse(userMsg);
    String aiTime = DateFormat('hh:mm a').format(DateTime.now());

    String detectedLang = rawAiMsg.contains("[HI]") ? "hi-IN" : "en-US";
    String cleanAiMsg = rawAiMsg.replaceAll("[HI]", "").replaceAll("[EN]", "").trim();

    setState(() {
      _messages.add({"role": "ai", "text": cleanAiMsg, "time": aiTime});
      _isTyping = false;
    });

    if (fromVoice) {
      await _flutterTts.setLanguage(detectedLang);
      await _flutterTts.speak(cleanAiMsg);
    }

    _scrollToBottom();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isTeacher = _userType == "teacher";

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        elevation: 2,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(isTeacher ? Icons.assignment_ind : Icons.psychology, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isTeacher ? "Teacher's Assistant" : "School Buddy", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(isTeacher ? "Online | Support Agent" : "Online | AI Tutor", style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isTeacher ? [const Color(0xFF004D40), const Color(0xFF00695C)] : [const Color(0xFF008080), const Color(0xFF004D40)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty ? _buildEmptyState(isTeacher) : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                bool isUser = _messages[index]["role"] == "user";
                return _buildMessageBubble(isUser, _messages[index]["text"]!, _messages[index]["time"]!);
              },
            ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(isTeacher ? "Assistant is searching..." : "School Buddy is thinking...", style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
              ),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isTeacher) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isTeacher ? Icons.menu_book_rounded : Icons.school_outlined, size: 80, color: Colors.teal.withOpacity(0.3)),
          const SizedBox(height: 10),
          const Text("How can I help you today?", style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(bool isUser, String text, String time) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) const CircleAvatar(radius: 12, backgroundColor: Colors.teal, child: Icon(Icons.smart_toy, size: 14, color: Colors.white)),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.teal : Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(15),
                      topRight: const Radius.circular(15),
                      bottomLeft: Radius.circular(isUser ? 15 : 0),
                      bottomRight: Radius.circular(isUser ? 0 : 15),
                    ),
                  ),
                  // FIXED: Removed 'const' before TextStyle because isUser makes it dynamic
                  child: Text(text, style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 15)),
                ),
                Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isUser) const CircleAvatar(radius: 12, backgroundColor: Colors.tealAccent, child: Icon(Icons.person, size: 14, color: Colors.teal)),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))]),
      child: SafeArea(
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _isListening ? Colors.red : Colors.teal.withOpacity(0.1),
              child: IconButton(
                icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.white : Colors.teal),
                onPressed: _listen,
              ),
            ),
            const SizedBox(width: 8),
            if (_isSpeaking)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.orange.withOpacity(0.1),
                  child: IconButton(
                    icon: const Icon(Icons.stop_circle, color: Colors.orange),
                    onPressed: () => _flutterTts.stop(),
                  ),
                ),
              ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(25)),
                child: TextField(
                  controller: _controller,
                  onSubmitted: (value) => _sendMessage(fromVoice: false),
                  textInputAction: TextInputAction.send,
                  decoration: const InputDecoration(
                    hintText: "Type or use mic...",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.teal,
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: () => _sendMessage(fromVoice: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}