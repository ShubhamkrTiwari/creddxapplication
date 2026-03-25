import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/p2p_service.dart';

class P2PChatDetailScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String appealId;
  
  const P2PChatDetailScreen({
    super.key, 
    required this.userId,
    required this.userName,
    required this.appealId,
  });

  @override
  State<P2PChatDetailScreen> createState() => _P2PChatDetailScreenState();
}

class _P2PChatDetailScreenState extends State<P2PChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _isLoading = true;
  String _currentUserId = '';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _fetchChats();
    // Refresh chat every 3 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchChats(showLoading: false);
    });
  }

  Future<void> _loadCurrentUser() async {
    final userData = await AuthService.getUserData();
    if (mounted) {
      setState(() {
        _currentUserId = userData?['id']?.toString() ?? userData?['_id']?.toString() ?? '';
      });
    }
  }

  Future<void> _fetchChats({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _isLoading = true);
    
    final chats = await P2PService.getChatMessages(widget.appealId, widget.userId);
    
    if (mounted) {
      setState(() {
        _messages = chats;
        _isLoading = false;
      });
      // Scroll to bottom on first load or when new messages arrive
      if (showLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    }
  }

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final messageData = {
      'appealId': widget.appealId,
      'receiverId': widget.userId,
      'message': text,
    };

    _messageController.clear();
    final success = await P2PService.sendMessage(messageData);
    
    if (success) {
      _fetchChats(showLoading: false);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showProfileBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildProfileBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF5C4B2A),
              child: Text(widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : '?', 
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.userName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  const Text('Online', style: TextStyle(color: Color(0xFF84BD00), fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: _showProfileBottomSheet,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
                : _buildChatArea(),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildChatArea() {
    if (_messages.isEmpty) {
      return const Center(child: Text('No messages yet', style: TextStyle(color: Colors.white54)));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final chat = _messages[index];
        final senderId = (chat['sender'] ?? chat['senderId'] ?? chat['userId'] ?? '').toString();
        final isMe = senderId == _currentUserId;
        
        return _buildMessageBubble(
          text: chat['message'] ?? '',
          isMe: isMe,
          time: _formatTime(chat['createdAt'] ?? chat['timestamp'] ?? ''),
        );
      },
    );
  }

  String _formatTime(String timestamp) {
    if (timestamp.isEmpty) return '';
    try {
      final date = DateTime.parse(timestamp);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  Widget _buildMessageBubble({
    required String text,
    required bool isMe,
    required String time,
  }) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF84BD00) : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(text, style: TextStyle(color: isMe ? Colors.black : Colors.white, fontSize: 14)),
            const SizedBox(height: 4),
            Text(time, style: TextStyle(color: isMe ? Colors.black54 : Colors.white54, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF0D0D0D),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(24)),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Color(0xFF8E8E93)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onSubmitted: (_) => _handleSendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFF84BD00),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.black),
              onPressed: _handleSendMessage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileBottomSheet() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.white),
            title: const Text('P2P Trading Info', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.report_problem_outlined, color: Colors.white),
            title: const Text('Report User', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.block, color: Colors.redAccent),
            title: const Text('Block User', style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              Navigator.pop(context);
              _showBlockUserDialog();
            },
          ),
        ],
      ),
    );
  }

  void _showBlockUserDialog() {
    final TextEditingController remarkController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Block User', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to block this user?', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            TextField(
              controller: remarkController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Add a remark (optional)',
                hintStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final success = await P2PService.blockUser(widget.userId, remarkController.text);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'User blocked' : 'Failed to block user'),
                    backgroundColor: success ? const Color(0xFF84BD00) : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Block', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
