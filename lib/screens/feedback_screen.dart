import 'package:flutter/material.dart';
import '../services/p2p_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<dynamic> _receivedFeedback = [];
  List<dynamic> _givenFeedback = [];
  List<dynamic> _filteredReceivedFeedback = [];
  List<dynamic> _filteredGivenFeedback = [];
  String? _error;
  String _selectedFilter = 'all'; // 'all', 'positive', 'negative'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchFeedback();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchFeedback() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        P2PService.getReceivedFeedback(),
        P2PService.getGivenFeedback(),
      ]);

      if (mounted) {
        setState(() {
          _receivedFeedback = results[0];
          _givenFeedback = results[1];
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: const Text(
          'Feedback',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF84BD00),
          labelColor: const Color(0xFF84BD00),
          unselectedLabelColor: const Color(0xFF8E8E93),
          labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Received'),
            Tab(text: 'Given'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF84BD00)),
            )
          : _error != null
              ? _buildErrorState()
              : Column(
                  children: [
                    _buildFilterOptions(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildFeedbackList(_filteredReceivedFeedback, 'received'),
                          _buildFeedbackList(_filteredGivenFeedback, 'given'),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFFFF3B30),
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Error loading feedback',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchFeedback,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF84BD00),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOptions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        border: Border(bottom: BorderSide(color: Color(0xFF2C2C2E), width: 1)),
      ),
      child: Row(
        children: [
          const Text(
            'Filter:',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Positive', 'positive'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Negative', 'negative'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : const Color(0xFF8E8E93),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
          _applyFilter();
        });
      },
      backgroundColor: const Color(0xFF0D0D0D),
      selectedColor: const Color(0xFF84BD00),
      checkmarkColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF2C2C2E)),
      ),
    );
  }

  void _applyFilter() {
    setState(() {
      if (_selectedFilter == 'all') {
        _filteredReceivedFeedback = _receivedFeedback;
        _filteredGivenFeedback = _givenFeedback;
      } else if (_selectedFilter == 'positive') {
        _filteredReceivedFeedback = _receivedFeedback.where((feedback) {
          final rating = int.tryParse(feedback['rating']?.toString() ?? '5') ?? 5;
          return rating >= 4;
        }).toList();
        _filteredGivenFeedback = _givenFeedback.where((feedback) {
          final rating = int.tryParse(feedback['rating']?.toString() ?? '5') ?? 5;
          return rating >= 4;
        }).toList();
      } else if (_selectedFilter == 'negative') {
        _filteredReceivedFeedback = _receivedFeedback.where((feedback) {
          final rating = int.tryParse(feedback['rating']?.toString() ?? '5') ?? 5;
          return rating <= 3;
        }).toList();
        _filteredGivenFeedback = _givenFeedback.where((feedback) {
          final rating = int.tryParse(feedback['rating']?.toString() ?? '5') ?? 5;
          return rating <= 3;
        }).toList();
      }
    });
  }

  String _getEmptyMessage(String type) {
    if (_selectedFilter == 'positive') {
      return type == 'received' ? 'No positive feedback received' : 'No positive feedback given';
    } else if (_selectedFilter == 'negative') {
      return type == 'received' ? 'No negative feedback received' : 'No negative feedback given';
    } else {
      return type == 'received' ? 'No feedback received' : 'No feedback given';
    }
  }

  Widget _buildFeedbackList(List<dynamic>? feedback, String type) {
    if (feedback == null || feedback.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.chat_bubble_outline,
              color: Color(0xFF8E8E93),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _getEmptyMessage(type),
              style: const TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
  }

  return RefreshIndicator(
      onRefresh: _fetchFeedback,
      color: const Color(0xFF84BD00),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: feedback.length,
        itemBuilder: (context, index) {
          final item = feedback[index] as Map<String, dynamic>;
          return _buildFeedbackCard(item);
        },
      ),
    );
  }

  Widget _buildFeedbackCard(Map<String, dynamic> feedback) {
    final userName = feedback['from_user_name'] ?? feedback['to_user_name'] ?? 'Unknown User';
    final rating = feedback['rating']?.toString() ?? '5';
    final comment = feedback['comment'] ?? feedback['message'] ?? 'No comment';
    final date = feedback['created_at'] ?? feedback['date'] ?? 'Unknown date';
    final tradeId = feedback['trade_id'] ?? feedback['order_id'] ?? 'N/A';

    final ratingValue = int.tryParse(rating) ?? 5;
    final isPositive = ratingValue >= 4;
    final sentimentColor = isPositive ? const Color(0xFF00C851) : const Color(0xFFFF3B30);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPositive ? const Color(0xFF00C851).withOpacity(0.3) : const Color(0xFFFF3B30).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isPositive ? const Color(0xFF00C851) : const Color(0xFFFF3B30),
                child: Text(
                  userName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: sentimentColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPositive ? Icons.thumb_up : Icons.thumb_down,
                                color: sentimentColor,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isPositive ? 'Positive' : 'Negative',
                                style: TextStyle(
                                  color: sentimentColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Trade #$tradeId',
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _buildRatingStars(rating, isPositive),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            comment,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDate(date),
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingStars(String rating, bool isPositive) {
    final ratingValue = int.tryParse(rating) ?? 5;
    final starColor = isPositive ? Colors.amber : const Color(0xFFFF3B30);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < ratingValue ? Icons.star : Icons.star_border,
          color: starColor,
          size: 16,
        );
      }),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minutes ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return dateString;
    }
  }
}
