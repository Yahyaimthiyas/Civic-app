/// @file chatbot_screen.dart
/// @description AI-powered assistant interface for citizen queries.
/// Professionally structured and maintained by the Civic App Team.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutterapp/features/auth/data/services/aadhaar_api.dart';
import 'package:flutterapp/features/complaints/presentation/screens/report_screen.dart';
import 'package:flutterapp/features/complaints/presentation/screens/map_view_screen.dart';
import 'package:flutterapp/features/complaints/presentation/screens/my_reports_screen.dart';
import 'package:flutterapp/features/home/presentation/screens/public_feed_screen.dart';
import 'package:flutterapp/core/theme/app_colors.dart';
// import 'package:flutterapp/features/auth/presentation/screens/login_screen.dart'; // Unused

class ChatbotScreen extends StatefulWidget {
  final AadhaarUser user;
  const ChatbotScreen({super.key, required this.user});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final List<CategoryMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Voice
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  
  // State
  bool _isLoading = false;
  final List<Map<String, String>> _history = [];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _addBotMessage("Vanakkam ${widget.user.name}! 👋\nI am **Vidhya**, your Official Civic Assistant.\n\nI can help you:\n* Report issues 📸\n* Track complaints 📝\n* Find nearby reports 🗺️\n\nHow can I help you today?");
  }
  
  void _initSpeech() async {
    await _speech.initialize();
    setState(() {});
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        if (!mounted) return;
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
             if (!mounted) return;
             setState(() {
               _controller.text = val.recognizedWords;
             });
          },
        );
      }
    } else {
      if (!mounted) return;
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _addBotMessage(String text) {
    if (!mounted) return;
    setState(() {
      _messages.add(CategoryMessage(text: text, isUser: false));
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(CategoryMessage(text: text, isUser: true));
      _history.add({"role": "user", "parts": text});
    });
    _scrollToBottom();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    _addUserMessage(text);
    _controller.clear();
    setState(() => _isLoading = true);

    try {
      final response = await AadhaarApi.sendChatMessage(text, _history);
      
      final botText = response['text'];
      final action = response['action'];
      
      _addBotMessage(botText);
      _history.add({"role": "model", "parts": botText});

      if (action != null) _handleAction(action);

    } catch (e) {
      _addBotMessage("⚠️ **Connection Error**\nI'm unable to reach the server. Please check your internet.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleAction(String action) {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      
      switch (action) {
        case 'NAVIGATE_REPORT':
            Navigator.push(context, MaterialPageRoute(builder: (_) => ReportScreen(user: widget.user)));
            break;
        case 'NAVIGATE_MAP':
            Navigator.push(context, MaterialPageRoute(builder: (_) => MapViewScreen(user: widget.user)));
            break;
        case 'NAVIGATE_MY_REPORTS':
            Navigator.push(context, MaterialPageRoute(builder: (_) => MyReportsScreen(user: widget.user)));
             break;
        case 'NAVIGATE_FEED':
             Navigator.push(context, MaterialPageRoute(builder: (_) => PublicFeedScreen(user: widget.user)));
             break;
        case 'CALL_EMERGENCY':
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🚨 Dialing Emergency Services (100)...'), backgroundColor: Colors.red));
             break;
      }
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.success, width: 2)),
              child: const CircleAvatar(radius: 16, backgroundColor: Colors.white, child: Icon(Icons.psychology, size: 20, color: AppColors.primary)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vidhya AI', style: GoogleFonts.inter(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Official Assistant • Online', style: GoogleFonts.inter(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 20),
              child: Row(
                children: [
                   CircleAvatar(radius: 8, backgroundColor: Colors.grey.shade300, child: Padding(padding: EdgeInsets.all(2), child: CircularProgressIndicator(strokeWidth: 2))),
                   SizedBox(width: 8),
                   Text("Vidhya is typing...", style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(CategoryMessage msg) {
    final isMe = msg.isUser;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.80),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
          ),
          boxShadow: [
             if (!isMe) BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1))
          ],
        ),
        child: isMe 
          ? Text(msg.text, style: GoogleFonts.inter(fontSize: 14, height: 1.4, color: Colors.white))
          : MarkdownBody(
              data: msg.text,
              styleSheet: MarkdownStyleSheet(
                p: GoogleFonts.inter(fontSize: 14, height: 1.4, color: Colors.black87),
                strong: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                listBullet: TextStyle(color: AppColors.accent),
              ),
            ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: Offset(0, -5))]),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickAction("How to report?", Icons.help_outline),
                _buildQuickAction("Report Issue", Icons.camera_alt),
                _buildQuickAction("My Status", Icons.history),
                _buildQuickAction("How Points work?", Icons.stars_rounded),
                _buildQuickAction("What is Verification?", Icons.verified_user_rounded),
                _buildQuickAction("Nearby Problems", Icons.map),
              ],
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.grey.shade200)),
                  child: TextField(
                    controller: _controller,
                    onSubmitted: _sendMessage,
                    decoration: InputDecoration(
                      hintText: _isListening ? 'Listening...' : 'Type your question...', 
                      hintStyle: TextStyle(color: _isListening ? AppColors.accent : Colors.grey.shade500),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14)
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton.small(
                heroTag: "mic_btn",
                backgroundColor: _isListening ? Colors.red : Colors.white,
                elevation: 1,
                child: Icon(_isListening ? Icons.mic_off : Icons.mic, color: _isListening ? Colors.white : Colors.black54),
                onPressed: _listen,
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: AppColors.accent,
                radius: 22,
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  onPressed: () => _sendMessage(_controller.text),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickAction(String label, IconData icon) {
     return Padding(
       padding: const EdgeInsets.only(right: 8.0),
       child: ActionChip(
         avatar: Icon(icon, size: 14, color: AppColors.primary),
         label: Text(label, style: TextStyle(fontSize: 12, color: AppColors.primary)),
         backgroundColor: Colors.blue.shade50,
         side: BorderSide.none,
         onPressed: () => _sendMessage(label), // Send as message
       ),
     );
  }
}

class CategoryMessage {
  final String text;
  final bool isUser;
  CategoryMessage({required this.text, required this.isUser});
}
