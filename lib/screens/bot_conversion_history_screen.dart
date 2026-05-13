import 'package:flutter/material.dart';

import '../services/bot_service.dart';

class BotConversionHistoryScreen extends StatefulWidget {
  const BotConversionHistoryScreen({super.key});

  @override
  State<BotConversionHistoryScreen> createState() => _BotConversionHistoryScreenState();
}

class _BotConversionHistoryScreenState extends State<BotConversionHistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _history = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await BotService.getBotConversionHistory();
      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _history = result['data'] ?? [];
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = result['error'] ?? 'Failed to load history';
            _isLoading = false;
          });
        }
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Conversion History', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.white54)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchHistory,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF84BD00)),
                        child: const Text('Retry', style: TextStyle(color: Colors.black)),
                      ),
                    ],
                  ),
                )
              : _history.isEmpty
                  ? const Center(child: Text('No conversion history found', style: TextStyle(color: Colors.white54)))
                  : RefreshIndicator(
                      onRefresh: _fetchHistory,
                      color: const Color(0xFF84BD00),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final item = _history[index];
                          return _buildHistoryItem(item);
                        },
                      ),
                    ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final fromSymbol = item['fromCoin']?['symbol'] ?? '???';
    final toSymbol = item['toCoin']?['symbol'] ?? '???';
    final fromAmount = item['fromAmount'] ?? 0;
    final toAmount = item['toAmount'] ?? 0;
    final rate = item['rate'] ?? 0;
    final createdAt = item['createdAt'] ?? '';
    final description = item['description'] ?? 'Conversion';
    
    // Status mapping: 2 usually means completed based on typical backend patterns
    final status = item['status'];
    final bool isCompleted = status == 2 || status == 'completed';

    DateTime? date;
    if (createdAt.isNotEmpty) {
      date = DateTime.tryParse(createdAt)?.toLocal();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$fromSymbol → $toSymbol',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompleted ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isCompleted ? 'Completed' : 'Pending',
                  style: TextStyle(
                    color: isCompleted ? Colors.green : Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('From', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text('$fromAmount $fromSymbol', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
              const Icon(Icons.arrow_forward, color: Colors.white24, size: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('To', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text('${toAmount is num ? toAmount.toStringAsFixed(4) : toAmount} $toSymbol', 
                    style: const TextStyle(color: Color(0xFF84BD00), fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rate: 1 USDT = ₹$rate',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              Text(
                date != null ? '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}' : '',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
