import 'package:flutter/material.dart';
import '../services/p2p_service.dart';
import 'p2p_chat_detail_screen.dart';

class P2PChatListScreen extends StatefulWidget {
  const P2PChatListScreen({super.key});

  @override
  State<P2PChatListScreen> createState() => _P2PChatListScreenState();
}

class _P2PChatListScreenState extends State<P2PChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _chatList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchChatList();
  }

  Future<void> _fetchChatList() async {
    setState(() => _isLoading = true);
    final chats = await P2PService.getLastChats();
    if (mounted) {
      setState(() {
        _chatList = chats;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text('P2P Message', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchChatList,
                color: const Color(0xFF84BD00),
                child: _buildChatList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search Chat',
            hintStyle: TextStyle(color: Color(0xFF8E8E93)),
            prefixIcon: Icon(Icons.search, color: Color(0xFF8E8E93)),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildChatList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)));
    }
    
    if (_chatList.isEmpty) {
      return ListView( // Wrap in ListView for RefreshIndicator to work
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          const Center(child: Text('No chats yet', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 16))),
        ],
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _chatList.length,
      itemBuilder: (context, index) {
        final chat = _chatList[index];
        final name = chat['userName'] ?? chat['senderName'] ?? 'Unknown';
        final message = chat['lastMessage'] ?? chat['message'] ?? '';
        final time = _formatTime(chat['createdAt'] ?? chat['timestamp'] ?? '');
        
        return _buildChatItem(
          name: name,
          message: message,
          time: time,
          userId: chat['userId'] ?? chat['sender'] ?? '',
          appealId: chat['appealId'] ?? chat['orderId'] ?? '',
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

  Widget _buildChatItem({
    required String name,
    required String message,
    required String time,
    required String userId,
    required String appealId,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => P2PChatDetailScreen(
              userId: userId,
              userName: name,
              appealId: appealId,
            ),
          ),
        ).then((_) => _fetchChatList());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF5C4B2A),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(message, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text(time, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
