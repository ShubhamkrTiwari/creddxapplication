import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/wallet_service.dart';
import '../services/socket_service.dart';
import '../services/unified_wallet_service.dart' as unified;
import 'otp_verification_screen.dart';

class InternalDepositScreen extends StatefulWidget {
  const InternalDepositScreen({super.key});

  @override
  State<InternalDepositScreen> createState() => _InternalDepositScreenState();
}

class _InternalDepositScreenState extends State<InternalDepositScreen> with SingleTickerProviderStateMixin {
  final _recipientUidController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _selectedCoin = 'USDT';
  List<String> _coinOptions = ['USDT'];
  bool _isLoading = false;
  bool _isHistoryLoading = false;
  double _availableBalance = 0.0;
  List<Map<String, dynamic>> _transferHistory = [];
  late TabController _tabController;
  StreamSubscription? _balanceSubscription;
  StreamSubscription? _unifiedWalletSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchBalance();
    _fetchTransferHistory();
    _subscribeToBalance();
    _subscribeToUnifiedWallet();
  }

  void _subscribeToUnifiedWallet() {
    _unifiedWalletSubscription = unified.UnifiedWalletService.walletBalanceStream.listen((walletBalance) {
      if (mounted && walletBalance != null) {
        setState(() {
          // Show Main wallet USDT balance only (same as send_screen.dart)
          final mainBalance = unified.UnifiedWalletService.mainUSDTBalance;
          _availableBalance = mainBalance;
          debugPrint('Internal Deposit Screen: Main wallet balance updated: $_availableBalance USDT');
        });
      }
    });
  }

  Future<void> _fetchBalance() async {
    // Use UnifiedWalletService for consistent and accurate balance data
    await unified.UnifiedWalletService.refreshAllBalances();
    
    if (mounted) {
      setState(() {
        // Show Main wallet USDT balance only (same as send_screen.dart)
        final mainBalance = unified.UnifiedWalletService.mainUSDTBalance;
        _availableBalance = mainBalance;
        debugPrint('Internal Deposit Screen: Main wallet balance fetched: $_availableBalance USDT');
      });
    }
  }

  void _subscribeToBalance() {
    _balanceSubscription = SocketService.balanceStream.listen((data) {
      if (mounted && (data['type'] == 'wallet_summary_update' || data['type'] == 'wallet_summary')) {
        // Socket updates are handled by UnifiedWalletService, which will trigger _subscribeToUnifiedWallet
        debugPrint('Internal Deposit Screen: Socket balance update received, will be processed by UnifiedWalletService');
      }
    });
  }

  Future<void> _fetchTransferHistory() async {
    setState(() => _isHistoryLoading = true);
    try {
      // Use internal transfer history API
      final result = await WalletService.getInternalTransferHistory(
        limit: 20,
      );

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        List<Map<String, dynamic>> transactions = [];

        // Handle various API response formats
        if (data is List) {
          // Direct list of transactions
          transactions = List<Map<String, dynamic>>.from(data);
        } else if (data is Map) {
          // Check common nested fields
          if (data['transactions'] != null && data['transactions'] is List) {
            transactions = List<Map<String, dynamic>>.from(data['transactions']);
          } else if (data['data'] != null && data['data'] is List) {
            transactions = List<Map<String, dynamic>>.from(data['data']);
          } else if (data['docs'] != null && data['docs'] is List) {
            transactions = List<Map<String, dynamic>>.from(data['docs']);
          } else if (data['results'] != null && data['results'] is List) {
            transactions = List<Map<String, dynamic>>.from(data['results']);
          }
        }

        setState(() {
          _transferHistory = transactions;
        });
      }
    } catch (e) {
      print('Error fetching transfer history: $e');
    } finally {
      setState(() => _isHistoryLoading = false);
    }
  }

  Future<void> _sendInternalDeposit() async {
    if (_recipientUidController.text.isEmpty) {
      _showError('Please enter recipient UID');
      return;
    }

    if (_amountController.text.isEmpty) {
      _showError('Please enter amount');
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    if (amount > _availableBalance) {
      _showError('Insufficient balance');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Step 1: Send OTP
      final otpResult = await WalletService.sendOtp(purpose: 'internal_transfer');
      
      if (otpResult['success'] == true) {
        if (!mounted) return;
        
        // Step 2: Navigate to OTP Verification Screen
        final bool? verified = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(
              onVerify: (otp) async {
                final result = await WalletService.internalTransfer(
                  receiverUid: _recipientUidController.text.trim(),
                  amount: amount,
                  otp: otp,
                );

                if (result['success'] == true) {
                  // Trigger global balance refresh after success
                  WalletService.getAllWalletBalances();
                }

                return result;
              },
              onResend: () => WalletService.sendOtp(purpose: 'internal_transfer'),
            ),
          ),
        );

        if (verified == true) {
          if (mounted) {
            _showSuccess('Transfer successful!');
            Navigator.pop(context);
          }
        }
      } else {
        _showError(otpResult['error'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      if (mounted) {
        _showError('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF84BD00),
        ),
      );
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
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Internal Transfer',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF84BD00),
          indicatorWeight: 3,
          labelColor: const Color(0xFF84BD00),
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
          tabs: const [
            Tab(text: 'Send'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Send Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF84BD00).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF84BD00).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send,
                      color: Color(0xFF84BD00),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Internal Transfer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Send crypto instantly to another CreddX user with 0 fees',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Coin Selection
            const Text(
              'Select Coin',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A2C)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCoin,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1C1C1E),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  items: _coinOptions.map((coin) {
                    return DropdownMenuItem(
                      value: coin,
                      child: Row(
                        children: [
                          _buildCoinIcon(coin),
                          const SizedBox(width: 12),
                          Text(coin),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCoin = value!;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Recipient UID
            const Text(
              'Recipient UID',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A2C)),
              ),
              child: TextField(
                controller: _recipientUidController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter recipient UID (e.g., CRDX123456)',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.paste, color: Color(0xFF84BD00)),
                        onPressed: () async {
                          final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
                          if (clipboardData?.text != null) {
                            _recipientUidController.text = clipboardData!.text!;
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF84BD00)),
                        onPressed: () {
                          // TODO: Implement QR scanner for UID
                          _showError('QR scanner coming soon');
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Amount
            const Text(
              'Amount',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A2C)),
              ),
              child: TextField(
                controller: _amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 18),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: Text(
                      _selectedCoin,
                      style: const TextStyle(
                        color: Color(0xFF84BD00),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Available balance
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Available: ${_availableBalance.toStringAsFixed(2)} $_selectedCoin',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _amountController.text = _availableBalance.toStringAsFixed(2);
                    },
                    child: const Text(
                      'MAX',
                      style: TextStyle(
                        color: Color(0xFF84BD00),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),


            const SizedBox(height: 32),

            // Send Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendInternalDeposit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF84BD00),
                  disabledBackgroundColor: const Color(0xFF84BD00).withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Send Now',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Info text
            Center(
              child: Text(
                'Transfers are instant and irreversible',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(height: 32),

              ],
            ),
          ),
          // History Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildHistorySection(),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Recent Transfers',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF84BD00).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_transferHistory.length}',
                    style: const TextStyle(
                      color: Color(0xFF84BD00),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (_isHistoryLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Color(0xFF84BD00),
                  strokeWidth: 2,
                ),
              )
            else
              GestureDetector(
                onTap: _fetchTransferHistory,
                child: const Icon(
                  Icons.refresh,
                  color: Color(0xFF84BD00),
                  size: 20,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFF2A2A2C), width: 1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Date',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'From/To',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Type',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Amt',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Coin',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Status',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_transferHistory.isEmpty && !_isHistoryLoading)
          Container(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.history,
                    color: Colors.white.withOpacity(0.3),
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No transfer history yet',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _transferHistory.length,
            separatorBuilder: (context, index) => const SizedBox.shrink(),
            itemBuilder: (context, index) {
              final transaction = _transferHistory[index];
              return _buildHistoryItem(transaction);
            },
          ),
      ],
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> transaction) {
    // Debug: print transaction data
    print('Transaction data: $transaction');
    
    final coin = transaction['coin']?.toString() ?? 
                transaction['currency']?.toString() ?? 
                'USDT';
    final amount = double.tryParse(transaction['amount']?.toString() ?? '0') ?? 0.0;
    
    // Try multiple possible field names for receiver
    final receiverUid = transaction['receiverUid']?.toString() ?? 
                       transaction['receiverUID']?.toString() ??
                       transaction['toUserId']?.toString() ?? 
                       transaction['toUID']?.toString() ??
                       transaction['recipientId']?.toString() ?? 
                       transaction['recipient']?.toString() ??
                       transaction['receiver']?.toString() ?? 
                       transaction['to']?.toString() ??
                       'Unknown';
    
    // Try multiple possible field names for sender
    final senderUid = transaction['senderUid']?.toString() ?? 
                     transaction['senderUID']?.toString() ??
                     transaction['fromUserId']?.toString() ?? 
                     transaction['fromUID']?.toString() ??
                     transaction['sender']?.toString() ??
                     transaction['from']?.toString();
    
    final statusRaw = transaction['status']?.toString() ?? 'completed';
    final status = statusRaw.toLowerCase();
    
    // Try multiple possible field names for timestamp
    final timestamp = transaction['createdAt']?.toString() ?? 
                     transaction['created_at']?.toString() ??
                     transaction['timestamp']?.toString() ?? 
                     transaction['date']?.toString() ?? 
                     transaction['time']?.toString() ??
                     transaction['transactionDate']?.toString() ?? '';
    
    final type = transaction['type']?.toString()?.toLowerCase() ?? 
                transaction['transactionType']?.toString()?.toLowerCase() ??
                (transaction['direction']?.toString()?.toLowerCase() ?? 'sent');

    // Determine if sent or received
    final isReceived = type == 'received' || type == 'receive' || type == 'incoming';
    
    // Format date: "Apr 15, 2026, 04:49 PM"
    String formattedDate = timestamp;
    if (timestamp.isNotEmpty) {
      try {
        final date = DateTime.parse(timestamp);
        // Convert to local time if the parsed time is UTC
        final localDate = date.isUtc ? date.toLocal() : date;
        formattedDate = _formatDateTime(localDate);
      } catch (e) {
        // Keep original timestamp if parsing fails
      }
    }

    // Format UID display (first 8 chars)
    String displayUid = receiverUid.length > 8 ? receiverUid.substring(0, 8) : receiverUid;
    
    // Debug: if still Unknown, print all transaction keys
    if (displayUid == 'Unknown') {
      print('UID Unknown! Transaction keys: ${transaction.keys.toList()}');
    }
    
    // Try to get any ID from transaction if receiver is still Unknown
    if (displayUid == 'Unknown') {
      for (var key in transaction.keys) {
        var value = transaction[key];
        if (value is String && value.isNotEmpty && value.length >= 6) {
          displayUid = value.substring(0, 8 > value.length ? value.length : 8);
          break;
        }
      }
    }
    
    final fromToText = isReceived ? '← $displayUid' : '→ $displayUid';
    
    // Status display
    String statusDisplay;
    switch (status) {
      case 'pending':
      case 'processing':
        statusDisplay = 'Pending';
        break;
      case 'completed':
      case 'success':
      case 'done':
        statusDisplay = 'Completed';
        break;
      case 'failed':
      case 'error':
      case 'cancelled':
        statusDisplay = 'Failed';
        break;
      default:
        statusDisplay = 'Completed';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF2A2A2C), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Date
          Expanded(
            flex: 2,
            child: Text(
              formattedDate,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 10,
              ),
            ),
          ),
          // From/To
          Expanded(
            flex: 2,
            child: Text(
              fromToText,
              style: const TextStyle(
                color: Color(0xFF84BD00),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Type
          Expanded(
            flex: 1,
            child: Text(
              isReceived ? 'Received' : 'Sent',
              style: TextStyle(
                color: isReceived ? Colors.blue : const Color(0xFFFF6B6B),
                fontSize: 10,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
                decorationColor: isReceived ? Colors.blue : const Color(0xFFFF6B6B),
              ),
            ),
          ),
          // Amount
          Expanded(
            flex: 1,
            child: Text(
              isReceived ? '+${amount.toStringAsFixed(0)}' : '-${amount.toStringAsFixed(0)}',
              style: TextStyle(
                color: isReceived ? Colors.green : const Color(0xFFFF6B6B),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Currency
          Expanded(
            flex: 1,
            child: Text(
              coin,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 10,
              ),
            ),
          ),
          // Status
          Expanded(
            flex: 1,
            child: Text(
              statusDisplay,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: status.startsWith('1') ? Colors.orange : 
                       status.startsWith('3') ? Colors.red : 
                       const Color(0xFF84BD00),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[date.month - 1];
    final day = date.day;
    final year = date.year;
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$month $day, $year, $hour:$minute $period';
  }

  Widget _buildCoinIcon(String coin) {
    String imagePath = 'assets/images/';
    switch (coin) {
      case 'BTC':
        imagePath += 'btc.png';
        break;
      case 'ETH':
        imagePath += 'eth.png';
        break;
      case 'BNB':
        imagePath += 'bnb.png';
        break;
      case 'USDT':
        imagePath += 'usdt.png';
        break;
      default:
        imagePath += 'btc.png';
    }

    return Image.asset(
      imagePath,
      width: 24,
      height: 24,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF84BD00).withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              coin[0],
              style: const TextStyle(
                color: Color(0xFF84BD00),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _balanceSubscription?.cancel();
    _unifiedWalletSubscription?.cancel();
    _tabController.dispose();
    _recipientUidController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}
