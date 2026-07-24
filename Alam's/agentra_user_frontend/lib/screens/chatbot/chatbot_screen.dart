import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../services/chatbot_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../packages/package_detail_screen.dart';

// ─── Package Model for Chat ───────────────────────────────────────────────────
class ChatPackage {
  final String id;
  final String title;
  final String location;
  final int price;
  final String duration;
  final bool isFeatured;
  final bool hasDiscount;
  final int discountPercentage;
  final int availableSeats;

  ChatPackage.fromJson(Map<String, dynamic> json)
      : id = json['_id']?.toString() ?? '',
        title = json['title']?.toString() ?? '',
        location = json['location']?.toString() ?? '',
        price = int.tryParse(json['price']?.toString() ?? '0') ?? 0,
        duration = json['duration']?.toString() ?? '',
        isFeatured = json['isFeatured'] == true,
        hasDiscount = json['hasDiscount'] == true,
        discountPercentage = int.tryParse(json['discountPercentage']?.toString() ?? '0') ?? 0,
        availableSeats = int.tryParse(json['availableSeats']?.toString() ?? '0') ?? 0;
}

// ─── Chat Message with Packages ──────────────────────────────────────────────
class ChatMessageWithPackages {
  final ChatMessage message;
  final List<ChatPackage> packages;

  ChatMessageWithPackages({required this.message, this.packages = const []});
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessageWithPackages> _messages = [];
  String? _conversationId;
  bool _isLoading = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _startConversation();
  }

  Future<void> _startConversation() async {
    setState(() => _isLoading = true);
    final conversationId = await ChatbotService.startConversation();
    if (mounted) {
      setState(() {
        _conversationId = conversationId;
        _isLoading = false;
        _messages.add(ChatMessageWithPackages(
          message: ChatMessage(
            id: 'welcome',
            conversationId: conversationId ?? '',
            message: "Hi! I'm Agentra, your travel assistant 🏔️\n\nI can help you explore **Murree** and **Lahore** — packages, hotels, restaurants, tourist spots, and more!\n\nHow can I help you today?",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        ));
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _conversationId == null) return;

    final userMessage = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _messages.add(ChatMessageWithPackages(
        message: ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          conversationId: _conversationId!,
          message: userMessage,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      ));
      _isSending = true;
    });
    _scrollToBottom();

    // Call our chatbot service
    final result = await ChatbotService.sendMessageWithPackages(
      conversationId: _conversationId!,
      message: userMessage,
    );

    if (mounted) {
      setState(() {
        _isSending = false;
        if (result != null) {
          _messages.add(ChatMessageWithPackages(
            message: ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              conversationId: _conversationId!,
              message: result['reply'] ?? 'Sorry, something went wrong.',
              isUser: false,
              timestamp: DateTime.now(),
            ),
            packages: (result['packages'] as List<dynamic>? ?? [])
                .map((p) => ChatPackage.fromJson(p as Map<String, dynamic>))
                .toList(),
          ));
        } else {
          _messages.add(ChatMessageWithPackages(
            message: ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              conversationId: _conversationId!,
              message: "I'm having trouble connecting right now. Please try again later.",
              isUser: false,
              timestamp: DateTime.now(),
            ),
          ));
        }
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
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
      backgroundColor: const Color(0xFFE3EEFF),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        foregroundColor: Colors.black,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Agentra AI',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            Text('Murree & Lahore Expert',
                style: TextStyle(fontSize: 11, color: Color.fromARGB(179, 0, 0, 0))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ChatbotService.clearSession();
              setState(() {
                _messages.clear();
                _conversationId = null;
              });
              _startConversation();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _buildTypingIndicator();
                      }
                      final item = _messages[index];
                      return Column(
                        children: [
                          ChatBubble(message: item.message),
                          if (item.packages.isNotEmpty)
                            _buildPackageCards(item.packages),
                        ],
                      );
                    },
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildPackageCards(List<ChatPackage> packages) {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
        itemCount: packages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _PackageCard(package: packages[i]),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.travel_explore, size: 18, color: Colors.white),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Text('Typing...',
                style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -3))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'Ask about Murree or Lahore...',
                hintStyle:
                    const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFFF0F4F9),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              onSubmitted: _isSending ? null : (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 10),
          FloatingActionButton.small(
            onPressed: _isSending ? null : _sendMessage,
            backgroundColor: _isSending ? Colors.grey[400] : Colors.blue,
            elevation: 0,
            child: Icon(
              _isSending ? Icons.hourglass_empty : Icons.send_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// ─── Chat Bubble ─────────────────────────────────────────────────────────────
class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(message.isUser ? 20 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 20),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: message.isUser
    ? Text(
        message.message,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          height: 1.4,
        ),
      )
    : MarkdownBody(
        data: message.message,
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.5),
          strong: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
          listBullet: const TextStyle(fontSize: 15, color: Colors.black87),
        ),
      ),
      ),
    );
  }
}

// ─── Package Card Widget ─────────────────────────────────────────────────────
class _PackageCard extends StatelessWidget {
  final ChatPackage package;

  const _PackageCard({required this.package});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Featured badge
          Row(
            children: [
              Expanded(
                child: Text(
                  package.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF1E1E1E)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (package.isFeatured)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('Featured',
                      style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Location + Duration
          Row(
            children: [
              const Icon(Icons.location_on, size: 12, color: Color(0xFF9E9E9E)),
              const SizedBox(width: 3),
              Text(package.location,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF757575))),
              const SizedBox(width: 8),
              const Icon(Icons.access_time, size: 12, color: Color(0xFF9E9E9E)),
              const SizedBox(width: 3),
              Flexible(
                child: Text(package.duration,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF757575)),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Price + Book Now button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PKR ${package.price}',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.blue),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PackageDetailScreen(packageId: package.id),
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(20)),
                  child: const Text('Book Now',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          // Seats warning
          if (package.availableSeats <= 5 && package.availableSeats > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Only ${package.availableSeats} seats left!',
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}