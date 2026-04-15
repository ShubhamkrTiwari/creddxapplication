import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/wallet_service.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchBalance();
    _fetchTransferHistory();
  }

  Future<void> _fetchBalance() async {
    try {
      final result = await WalletService.getAllWalletBalances();
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        double totalAvailable = 0.0;

        // Sum up USDT from all wallet types
        final walletTypeMap = {
          'spot': 'spotBalance',
          'main': 'mainBalance',
          'p2p': 'p2pBalance',
          'bot': 'botBalance',
        };

        for (String type in walletTypeMap.keys) {
          final fieldName = walletTypeMap[type]!;
          final walletData = data[fieldName];

          if (walletData != null) {
            if (walletData is Map && walletData['USDT'] != null) {
              totalAvailable += double.tryParse(walletData['USDT'].toString()) ?? 0.0;
            } else if (walletData is num) {
              totalAvailable += walletData.toDouble();
            }
          }
        }

        setState(() {
          _availableBalance = totalAvailable;
        });
      }
    } catch (e) {
      print('Error fetching balance: $e');
    }
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
      // Call wallet service for internal transfer
      final result = await WalletService.internalTransfer(
        receiverUid: _recipientUidController.text.trim(),
        amount: amount,
      ) as Map<String, dynamic>;

      if (result['success'] == true) {
        if (mounted) {
          _showSuccess('Transfer successful!');
          Navigator.pop(context);;
        }
      } else {
        _showError(result['message'] ?? 'Transfer failed');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() => _isLoading = false);
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
        // Header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Transfer History',
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
        const SizedBox(height: 12),
        // Table with horizontal scroll
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF2A2A2C), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      _tableHeader('Date', width: 100),
                      _tableHeader('From/To', width: 110),
                      _tableHeader('Type', width: 50),
                      _tableHeader('Amt', width: 40),
                      _tableHeader('Sts', width: 60),
                    ],
                  ),
                ),
                // Table Body
                if (_transferHistory.isEmpty && !_isHistoryLoading)
                  Container(
                    width: 360,
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.history,
                            color: Colors.white.withOpacity(0.3),
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No transfer history yet',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: 360,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _transferHistory.length,
                      separatorBuilder: (context, index) => const Divider(
                        color: Color(0xFF2A2A2C),
                        height: 1,
                        indent: 8,
                        endIndent: 8,
                      ),
                      itemBuilder: (context, index) {
                        final transaction = _transferHistory[index];
                        return _buildHistoryRow(transaction);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Pagination
        if (_transferHistory.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _paginationButton(Icons.chevron_left, false),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF84BD00),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '1',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _paginationButton(Icons.chevron_right, false),
              ],
            ),
          ),
      ],
    );
  }

  Widget _tableHeader(String text, {required double width}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _paginationButton(IconData icon, bool isActive) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        icon,
        color: Colors.white.withOpacity(0.5),
        size: 20,
      ),
    );
  }

  Widget _buildHistoryRow(Map<String, dynamic> transaction) {
    final coin = transaction['coin']?.toString() ?? 'USDT';
    final amount = double.tryParse(transaction['amount']?.toString() ?? '0') ?? 0.0;
    final receiverUid = transaction['receiverUid']?.toString() ?? transaction['toUserId']?.toString() ?? transaction['recipientId']?.toString() ?? 'Unknown';
    final status = transaction['status']?.toString() ?? 'completed';
    final timestamp = transaction['createdAt']?.toString() ?? transaction['timestamp']?.toString() ?? '';
    final type = transaction['type']?.toString() ?? 'sent';
    final senderUid = transaction['senderUid']?.toString() ?? 'UID';

    // Determine if sent or received
    final isReceived = type.toLowerCase() == 'received';

    // Format timestamp
    String formattedDate = '';
    if (timestamp.isNotEmpty) {
      try {
        final date = DateTime.parse(timestamp);
        formattedDate = '${_monthName(date.month)} ${date.day}, ${date.year}, ${_formatTime(date)}';
      } catch (e) {
        formattedDate = timestamp;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          // Date (100px)
          SizedBox(
            width: 100,
            child: Text(
              formattedDate,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 10,
              ),
            ),
          ),
          // From/To (110px)
          SizedBox(
            width: 110,
            child: Text(
              isReceived ? '$receiverUid \u2192 UID' : 'UID \u2192 $receiverUid',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 10,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Type (50px)
          SizedBox(
            width: 50,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isReceived ? Colors.blue : const Color(0xFF84BD00),
                    width: 1,
                  ),
                ),
              ),
              child: Text(
                isReceived ? 'Rcv' : 'Sent',
                style: TextStyle(
                  color: isReceived ? Colors.blue : const Color(0xFF84BD00),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // Amount (40px)
          SizedBox(
            width: 40,
            child: Text(
              isReceived ? '+${amount.toStringAsFixed(0)}' : '-${amount.toStringAsFixed(0)}',
              style: TextStyle(
                color: isReceived ? Colors.green : Colors.red,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Status (60px)
          SizedBox(
            width: 60,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF84BD00).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : 'Done',
                style: const TextStyle(
                  color: Color(0xFF84BD00),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
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
    _tabController.dispose();
    _recipientUidController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}
