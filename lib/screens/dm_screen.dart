import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DMScreen extends StatefulWidget {
  const DMScreen({super.key});

  @override
  State<DMScreen> createState() => _DMScreenState();
}

class _DMScreenState extends State<DMScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Starting mock messages list
  final List<Map<String, dynamic>> _messages = [
    {
      'sender': 'them',
      'text': 'Hi there! Thanks for reaching out. How can I help you on your fitness journey?',
      'time': '10:32 AM',
    },
    {
      'sender': 'me',
      'text': 'Hi! I saw your before/after weight transformation post. It is amazing! What was your calorie target?',
      'time': '10:34 AM',
    },
    {
      'sender': 'them',
      'text': 'Thank you! I kept a steady 1600 kcal budget and made sure to eat fresh oatmeal in the morning and avocado salad for dinner.',
      'time': '10:35 AM',
    },
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        'sender': 'me',
        'text': text,
        'time': 'Just now',
      });
      _messageController.clear();
    });

    // Scroll to the bottom of the list
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // Simulated automated response delay for premium demo experience
    Future.delayed(const Duration(seconds: 1500 ~/ 1000), () {
      if (!mounted) return;
      setState(() {
        _messages.add({
          'sender': 'them',
          'text': 'That sounds like a great plan! Feel free to ask if you want recipe breakdowns or tips.',
          'time': 'Just now',
        });
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Extract recipient info passed as arguments
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String recipientName = args?['recipientName'] ?? 'Sophia Miller';
    final String recipientUsername = args?['recipientUsername'] ?? 'sophiam';
    final int avatarColor = args?['avatarColor'] ?? 0xFF9B59B6;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E272C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Color(avatarColor).withOpacity(0.15),
              child: Text(
                recipientName[0],
                style: GoogleFonts.outfit(
                  color: Color(avatarColor),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipientName,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E272C),
                    ),
                  ),
                  Text(
                    '@$recipientUsername',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

      ),
      body: Column(
        children: [
          // Message List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20.0),
              physics: const BouncingScrollPhysics(),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe = message['sender'] == 'me';
                
                return TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(isMe ? 15 * (1.0 - value) : -15 * (1.0 - value), 0),
                        child: child,
                      ),
                    );
                  },
                  child: Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 14.0),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      decoration: BoxDecoration(
                        color: isMe ? const Color(0xFF2ECC71) : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16.0),
                          topRight: const Radius.circular(16.0),
                          bottomLeft: isMe ? const Radius.circular(16.0) : const Radius.circular(4.0),
                          bottomRight: isMe ? const Radius.circular(4.0) : const Radius.circular(16.0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: isMe ? null : Border.all(color: Colors.grey[150].colorWithBorderDefault(), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message['text'],
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: isMe ? Colors.white : Colors.black87,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              message['time'],
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                color: isMe ? Colors.white60 : Colors.grey[400],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Chat Input Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFECECEC), width: 1)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FBF9),
                        borderRadius: BorderRadius.circular(24.0),
                        border: Border.all(color: Colors.grey[200]!, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _messageController,
                              style: GoogleFonts.poppins(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Message...',
                                hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              textInputAction: TextInputAction.send,
                              onFieldSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey, size: 20),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF2ECC71),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension ColorBorderExtension on Color? {
  Color colorWithBorderDefault() {
    return const Color(0xFFF2F2F2);
  }
}
