import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/wallet_service.dart';

class WalletHistoryScreen extends StatefulWidget {
  const WalletHistoryScreen({super.key});

  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _transactions = [];
  List<dynamic> _transfers = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        WalletService.getCompleteTransactionHistory(),
        WalletService.getWalletTransferHistory(),
      ]);

      if (mounted) {
        setState(() {
          // Explicit casting to fix the "operator '[]' isn't defined for Object" error
          final txResult = results[0] as Map<String, dynamic>;
          final transferResult = results[1] as Map<String, dynamic>;
          
          if (txResult['success'] == true) {
            final txData = txResult['data'] as Map<String, dynamic>;
            _transactions = txData['transactions'] ?? [];
          }
          if (transferResult['success'] == true) {
            final transferData = transferResult['data'];
            if (transferData is List) {
              _transfers = transferData;
            } else if (transferData is Map) {
              _transfers = transferData['transfers'] ?? [];
            }
          }
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Wallet History',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF84BD00),
          labelColor: const Color(0xFF84BD00),
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Transactions'),
            Tab(text: 'Transfers'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTransactionList(),
                _buildTransferList(),
              ],
            ),
    );
  }

  Widget _buildTransactionList() {
    if (_transactions.isEmpty) {
      return _buildEmptyState('No transactions found');
    }

    return RefreshIndicator(
      onRefresh: _fetchHistory,
      color: const Color(0xFF84BD00),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _transactions.length,
        itemBuilder: (context, index) {
          final tx = _transactions[index];
          final String type = tx['transactionType'] ?? tx['type'] ?? 'Unknown';
          final String coin = tx['coin'] ?? '';
          final double amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0;
          final DateTime date = DateTime.tryParse(tx['createdAt']?.toString() ?? '') ?? DateTime.now();
          final bool isCredit = amount > 0 || type.toLowerCase().contains('deposit') || type.toLowerCase().contains('credit');

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: (isCredit ? Colors.green : Colors.red).withOpacity(0.1),
                  child: Icon(
                    isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isCredit ? Colors.green : Colors.red,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, yyyy HH:mm').format(date),
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isCredit ? '+' : ''}$amount $coin',
                      style: TextStyle(
                        color: isCredit ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tx['status']?.toString().toUpperCase() ?? 'COMPLETED',
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransferList() {
    if (_transfers.isEmpty) {
      return _buildEmptyState('No transfers found');
    }

    return RefreshIndicator(
      onRefresh: _fetchHistory,
      color: const Color(0xFF84BD00),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _transfers.length,
        itemBuilder: (context, index) {
          final transfer = _transfers[index];
          final String from = transfer['fromWallet'] ?? 'Unknown';
          final String to = transfer['toWallet'] ?? 'Unknown';
          final String coin = transfer['coin'] ?? '';
          final double amount = double.tryParse(transfer['amount']?.toString() ?? '0') ?? 0;
          final DateTime date = DateTime.tryParse(transfer['createdAt']?.toString() ?? '') ?? DateTime.now();

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF84BD00),
                  child: Icon(Icons.swap_horiz, color: Colors.black, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${from.toUpperCase()} ➔ ${to.toUpperCase()}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, yyyy HH:mm').format(date),
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$amount $coin',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history, color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchHistory,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1A1A)),
            child: const Text('Refresh', style: TextStyle(color: Color(0xFF84BD00))),
          ),
        ],
      ),
    );
  }
}
