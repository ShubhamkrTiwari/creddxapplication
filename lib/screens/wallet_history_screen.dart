import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  List<dynamic> _conversions = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      // Error cleared on new fetch
    });

    try {
      final results = await Future.wait([
        WalletService.getCompleteTransactionHistory(),
        WalletService.getWalletTransferHistory(),
        WalletService.getConversionHistory(limit: 50),
      ]);

      if (mounted) {
        setState(() {
          final txResult = results[0];
          final transferResult = results[1];
          final conversionResult = results[2];

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
          if (conversionResult['success'] == true) {
            final conversionData = conversionResult['data'];
            if (conversionData is List) {
              _conversions = conversionData.map((item) {
                final conversion = Map<String, dynamic>.from(item);
                conversion['transactionType'] = 'conversion';
                conversion['isConversion'] = true;
                return conversion;
              }).toList();
            } else if (conversionData is Map && conversionData['conversions'] != null) {
              _conversions = (conversionData['conversions'] as List).map((item) {
                final conversion = Map<String, dynamic>.from(item);
                conversion['transactionType'] = 'conversion';
                conversion['isConversion'] = true;
                return conversion;
              }).toList();
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          debugPrint('Error fetching history: $e');
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
            Tab(text: 'Conversions'),
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
                _buildConversionList(),
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
          final tx = _transactions[index] is Map<String, dynamic>
              ? _transactions[index] as Map<String, dynamic>
              : Map<String, dynamic>.from(_transactions[index]);
          final dynamic typeRaw = tx['transactionType'] ?? tx['type'] ?? 'Unknown';
          final dynamic coinRaw = tx['coin'] ?? tx['asset'] ?? '';
          final String type = typeRaw is List ? (typeRaw.isNotEmpty ? typeRaw[0].toString() : 'Unknown') : typeRaw.toString();
          final String coin = coinRaw is List ? (coinRaw.isNotEmpty ? coinRaw[0].toString() : '') : coinRaw.toString();
          final double amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0;
          // Try multiple possible time field names from API
          final String? timeStr = tx['createdAt']?.toString() ??
                                   tx['created_at']?.toString() ??
                                   tx['timestamp']?.toString() ??
                                   tx['date']?.toString() ??
                                   tx['time']?.toString();
          final DateTime date = timeStr != null
              ? DateTime.tryParse(timeStr) ?? DateTime.now()
              : DateTime.now();
          // Convert to local time if the parsed time is UTC
          final DateTime localDate = date.isUtc ? date.toLocal() : date;
          final bool isCredit = amount > 0 || type.toLowerCase().contains('deposit') || type.toLowerCase().contains('credit');
          
          // Check for INR withdrawal details
          final bankDetails = tx['bankDetails'] ?? tx['withdrawDetails'] ?? tx['bank_details'];
          final upiId = tx['upiId'] ?? tx['upi_id'];
          final withdrawType = tx['withdrawType'] ?? tx['withdraw_type'];
          final category = tx['category']?.toString() ?? '';
          final bool isINRWithdrawal = category == 'inr' || (type == 'withdrawal' && bankDetails != null);
          final bool isUPI = withdrawType == 2 || upiId != null;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: (isCredit ? Colors.green : Colors.red).withValues(alpha: 0.1),
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
                            isINRWithdrawal ? '${type.toUpperCase()} ${isUPI ? 'UPI' : 'BANK'}' : type.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM dd, yyyy hh:mm a').format(localDate),
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isINRWithdrawal ? '₹${amount.toStringAsFixed(2)}' : '${isCredit ? '+' : ''}$amount $coin',
                          style: TextStyle(
                            color: isCredit ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Builder(
                          builder: (context) {
                            final dynamic txStatusRaw = tx['status'] ?? 'COMPLETED';
                            final String txStatus = txStatusRaw is List
                                ? (txStatusRaw.isNotEmpty ? txStatusRaw[0].toString().toUpperCase() : 'COMPLETED')
                                : txStatusRaw.toString().toUpperCase();
                            return Text(
                              txStatus,
                              style: const TextStyle(color: Colors.white38, fontSize: 10),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                // Show bank/UPI details for INR withdrawals
                if (isINRWithdrawal || bankDetails != null || upiId != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (bankDetails != null && bankDetails['accountHolderName']?.toString().isNotEmpty == true)
                          Text(
                            'Account Holder: ${bankDetails!['accountHolderName']}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        if (isUPI && upiId != null) ...[
                          Text(
                            'UPI ID: $upiId',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ] else if (bankDetails != null && bankDetails['bankName']?.toString().isNotEmpty == true) ...[
                          Text(
                            'Bank: ${bankDetails!['bankName']}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          if (bankDetails != null && bankDetails['accountNumber']?.toString().isNotEmpty == true)
                            Text(
                              'Account: XXXX${bankDetails!['accountNumber'].toString().substring(bankDetails!['accountNumber'].toString().length > 4 ? bankDetails!['accountNumber'].toString().length - 4 : 0)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          if (bankDetails != null && bankDetails['ifscCode']?.toString().isNotEmpty == true)
                            Text(
                              'IFSC: ${bankDetails!['ifscCode']}',
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
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
          final transfer = _transfers[index] is Map<String, dynamic>
              ? _transfers[index] as Map<String, dynamic>
              : Map<String, dynamic>.from(_transfers[index]);
          final dynamic fromRaw = transfer['fromWallet'] ?? transfer['from_wallet'] ?? transfer['from'] ?? 'Unknown';
          final dynamic toRaw = transfer['toWallet'] ?? transfer['to_wallet'] ?? transfer['to'] ?? 'Unknown';
          final dynamic coinRaw = transfer['coin'] ?? transfer['asset'] ?? 'USDT';
          final String from = fromRaw is List ? (fromRaw.isNotEmpty ? fromRaw[0].toString() : 'Unknown') : fromRaw.toString();
          final String to = toRaw is List ? (toRaw.isNotEmpty ? toRaw[0].toString() : 'Unknown') : toRaw.toString();
          final String coin = coinRaw is List ? (coinRaw.isNotEmpty ? coinRaw[0].toString() : 'USDT') : coinRaw.toString();
          final double amount = double.tryParse(transfer['amount']?.toString() ?? '0') ?? 0;
          final dynamic statusRaw = transfer['status'] ?? 'Completed';
          final String status = statusRaw is List ? (statusRaw.isNotEmpty ? statusRaw[0].toString() : 'Completed') : statusRaw.toString();
          final String? txId = transfer['transactionId']?.toString() ?? transfer['txId']?.toString() ?? transfer['id']?.toString();
          // Try multiple possible time field names from API
          final String? timeStr = transfer['createdAt']?.toString() ??
                                   transfer['created_at']?.toString() ??
                                   transfer['timestamp']?.toString() ??
                                   transfer['date']?.toString() ??
                                   transfer['time']?.toString();
          final DateTime date = timeStr != null
              ? DateTime.tryParse(timeStr) ?? DateTime.now()
              : DateTime.now();
          // Convert to local time if the parsed time is UTC
          final DateTime localDate = date.isUtc ? date.toLocal() : date;

          // Wallet colors
          final Color fromColor = _getWalletColor(from);
          final Color toColor = _getWalletColor(to);

          // Status color
          Color statusColor = const Color(0xFF84BD00);
          if (status.toLowerCase().contains('pending')) {
            statusColor = Colors.orange;
          } else if (status.toLowerCase().contains('fail')) {
            statusColor = Colors.red;
          } else if (status.toLowerCase().contains('success') || status.toLowerCase().contains('complete')) {
            statusColor = const Color(0xFF84BD00);
          }

          return _buildTransferCard(
            transfer: transfer,
            from: from,
            to: to,
            coin: coin,
            amount: amount,
            status: status,
            txId: txId,
            localDate: localDate,
            fromColor: fromColor,
            toColor: toColor,
            statusColor: statusColor,
          );
        },
      ),
    );
  }

  Widget _buildTransferCard({
    required Map<String, dynamic> transfer,
    required String from,
    required String to,
    required String coin,
    required double amount,
    required String status,
    required String? txId,
    required DateTime localDate,
    required Color fromColor,
    required Color toColor,
    required Color statusColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E1E24),
            const Color(0xFF16161A),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Top accent bar with gradient
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [fromColor, toColor],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    children: [
                      // Animated transfer icon
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              fromColor.withValues(alpha: 0.25),
                              toColor.withValues(alpha: 0.15),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(Icons.swap_horiz, color: Colors.white.withValues(alpha: 0.9), size: 26),
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF1E1E24), width: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Transfer',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: statusColor.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 11, color: Colors.white.withValues(alpha: 0.4)),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('MMM dd, yyyy • hh:mm a').format(localDate),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Amount display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.08),
                              Colors.white.withValues(alpha: 0.02),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.remove, color: Colors.red.withValues(alpha: 0.8), size: 12),
                                const SizedBox(width: 2),
                                Text(
                                  amount.toStringAsFixed(2),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              coin,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Transfer flow path
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // From side
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FROM',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          fromColor.withValues(alpha: 0.3),
                                          fromColor.withValues(alpha: 0.1),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: fromColor.withValues(alpha: 0.4),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      _getWalletIcon(from),
                                      color: fromColor,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _capitalizeWallet(from),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (txId != null && txId.isNotEmpty)
                                          Text(
                                            'ID: ${_shortenId(txId)}',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.35),
                                              fontSize: 9,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Arrow connector
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [fromColor.withValues(alpha: 0.5), toColor.withValues(alpha: 0.5)],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.arrow_forward,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  size: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 40,
                                height: 2,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [fromColor.withValues(alpha: 0.6), toColor.withValues(alpha: 0.6)],
                                  ),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // To side
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'TO',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _capitalizeWallet(to),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          '+${amount.toStringAsFixed(2)} $coin',
                                          style: TextStyle(
                                            color: Colors.green.withValues(alpha: 0.8),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          toColor.withValues(alpha: 0.3),
                                          toColor.withValues(alpha: 0.1),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: toColor.withValues(alpha: 0.4),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      _getWalletIcon(to),
                                      color: toColor,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (txId != null && txId.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: txId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Transaction ID copied'),
                            duration: Duration(seconds: 2),
                            backgroundColor: Color(0xFF2A2A30),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.copy,
                              size: 12,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'TX: $txId',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortenId(String id) {
    if (id.length <= 12) return id;
    return '${id.substring(0, 6)}...${id.substring(id.length - 6)}';
  }

  Color _getWalletColor(String wallet) {
    final normalized = wallet.toLowerCase().trim();
    switch (normalized) {
      case 'main': return const Color(0xFF84BD00);
      case 'spot': return const Color(0xFF627EEA);
      case 'p2p': return const Color(0xFF26A17B);
      case 'bot': return const Color(0xFFF7931A);
      default: return Colors.grey;
    }
  }

  IconData _getWalletIcon(String wallet) {
    final normalized = wallet.toLowerCase().trim();
    switch (normalized) {
      case 'main': return Icons.account_balance_wallet;
      case 'spot': return Icons.trending_up;
      case 'p2p': return Icons.people;
      case 'bot': return Icons.smart_toy;
      default: return Icons.wallet;
    }
  }

  String _capitalizeWallet(String wallet) {
    if (wallet.isEmpty) return 'Unknown';
    return wallet[0].toUpperCase() + wallet.substring(1).toLowerCase();
  }

  Widget _buildConversionList() {
    if (_conversions.isEmpty) {
      return _buildEmptyState('No conversions found');
    }

    return RefreshIndicator(
      onRefresh: _fetchHistory,
      color: const Color(0xFF84BD00),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _conversions.length,
        itemBuilder: (context, index) {
          final conversion = _conversions[index] is Map<String, dynamic>
              ? _conversions[index] as Map<String, dynamic>
              : Map<String, dynamic>.from(_conversions[index]);

          // API uses type field: 1 = INR to USDT, 2 = USDT to INR
          final int? conversionType = int.tryParse(conversion['type']?.toString() ?? '');
          String fromCurrency;
          String toCurrency;
          
          // Determine conversion direction from API type field
          String safeString(dynamic value, String defaultValue) {
            if (value == null) return defaultValue;
            if (value is List) return value.isNotEmpty ? value[0].toString() : defaultValue;
            return value.toString();
          }
          if (conversionType != null) {
            if (conversionType == 2) {
              // USDT to INR
              fromCurrency = 'USDT';
              toCurrency = 'INR';
            } else if (conversionType == 1) {
              // INR to USDT
              fromCurrency = 'INR';
              toCurrency = 'USDT';
            } else {
              // Fallback to field parsing for unknown types
              fromCurrency = safeString(conversion['fromCurrency'] ?? conversion['from_currency'], 'INR');
              toCurrency = safeString(conversion['toCurrency'] ?? conversion['to_currency'], 'USDT');
            }
          } else {
            // Fallback: try to read fromCurrency/toCurrency fields if type is not available
            fromCurrency = safeString(conversion['fromCurrency'] ?? conversion['from_currency'], 'INR');
            toCurrency = safeString(conversion['toCurrency'] ?? conversion['to_currency'], 'USDT');
          }
          final double fromAmount = double.tryParse(
              conversion['fromAmount']?.toString() ??
                  conversion['from_amount']?.toString() ?? '0') ?? 0;
          final double toAmount = double.tryParse(
              conversion['toAmount']?.toString() ??
                  conversion['to_amount']?.toString() ??
                  conversion['converted_amount']?.toString() ?? '0') ?? 0;
          final double rate = double.tryParse(
              conversion['rate']?.toString() ??
                  conversion['conversion_rate']?.toString() ?? '0') ?? 0;
          final dynamic statusRaw = conversion['status'] ?? 'Completed';
          final String status = statusRaw is List
              ? (statusRaw.isNotEmpty ? statusRaw[0].toString() : 'Completed')
              : statusRaw.toString();
          // Try multiple possible time field names from API
          final String? timeStr = conversion['createdAt']?.toString() ??
                                   conversion['created_at']?.toString() ??
                                   conversion['timestamp']?.toString() ??
                                   conversion['date']?.toString() ??
                                   conversion['time']?.toString();
          final DateTime date = timeStr != null
              ? DateTime.tryParse(timeStr) ?? DateTime.now()
              : DateTime.now();
          // Convert to local time if the parsed time is UTC
          final DateTime localDate = date.isUtc ? date.toLocal() : date;

          Color statusColor = const Color(0xFF84BD00);
          switch (status.toLowerCase()) {
            case 'pending':
              statusColor = Colors.orange;
              break;
            case 'failed':
            case 'rejected':
              statusColor = Colors.red;
              break;
            case 'completed':
            case 'success':
              statusColor = const Color(0xFF84BD00);
              break;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF26A17B).withValues(alpha: 0.1),
                      child: const Icon(Icons.currency_exchange, color: Color(0xFF26A17B), size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$fromCurrency ➔ $toCurrency',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM dd, yyyy hh:mm a').format(localDate),
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : 'Completed',
                          style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'From:',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Text(
                            '${fromAmount.toStringAsFixed(2)} $fromCurrency',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Icon(Icons.arrow_downward, color: Colors.white38, size: 16),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'To:',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Text(
                            '${toAmount.toStringAsFixed(4)} $toCurrency',
                            style: const TextStyle(color: Color(0xFF26A17B), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (rate > 0) ...[
                        const Divider(color: Colors.white12, height: 16),
                        Text(
                          'Rate: 1 $fromCurrency = ${rate.toStringAsFixed(4)} $toCurrency',
                          style: const TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                      ],
                    ],
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
