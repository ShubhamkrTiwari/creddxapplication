import 'package:flutter/material.dart';
import '../services/wallet_service.dart';
import 'package:intl/intl.dart';

class InternalTransferScreen extends StatefulWidget {
  const InternalTransferScreen({super.key});

  @override
  State<InternalTransferScreen> createState() => _InternalTransferScreenState();
}

class _InternalTransferScreenState extends State<InternalTransferScreen> {
  String _fromWallet = 'spot';
  String _toWallet = 'p2p';
  String _selectedCoin = 'USDT';
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;
  bool _isFetchingBalances = true;
  bool _isFetchingHistory = false;
  Map<String, dynamic> _balances = {};
  List<Map<String, dynamic>> _transferHistory = [];

  final List<Map<String, String>> _walletTypes = [
    {'code': 'spot', 'name': 'Spot Wallet (4)'},
    {'code': 'p2p', 'name': 'P2P Wallet (2)'},
    {'code': 'bot', 'name': 'Bot Wallet (3)'},
    {'code': 'main', 'name': 'Main Wallet (1)'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchBalances();
    _fetchTransferHistory();
  }

  Future<void> _fetchBalances() async {
    setState(() => _isFetchingBalances = true);
    final result = await WalletService.getAllWalletBalances();
    if (mounted) {
      setState(() {
        if (result['success'] == true && result['data'] != null) {
          final data = result['data'];
          _balances = {};
          
          // Extract USDT balances from all wallet types
          final walletTypes = ['spot', 'p2p', 'bot', 'demo_bot', 'main'];
          for (String walletType in walletTypes) {
            if (data[walletType] != null && data[walletType]['balances'] != null) {
              final balances = data[walletType]['balances'] as List;
              final usdtBalance = balances.firstWhere(
                (balance) => balance['coin']?.toString().toUpperCase() == 'USDT',
                orElse: () => null,
              );
              if (usdtBalance != null) {
                _balances[walletType] = {
                  'available': usdtBalance['available']?.toString() ?? '0.00',
                  'locked': usdtBalance['locked']?.toString() ?? '0.00',
                  'total': usdtBalance['total']?.toString() ?? '0.00',
                };
              } else {
                _balances[walletType] = {'available': '0.00', 'locked': '0.00', 'total': '0.00'};
              }
            } else {
              _balances[walletType] = {'available': '0.00', 'locked': '0.00', 'total': '0.00'};
            }
          }
        }
        _isFetchingBalances = false;
      });
    }
  }

  Future<void> _fetchTransferHistory() async {
    setState(() => _isFetchingHistory = true);
    final result = await WalletService.getWalletTransferHistory(
      coin: _selectedCoin,
      limit: 10,
    );
    if (mounted) {
      setState(() {
        if (result['success'] == true && result['data'] != null) {
          final data = result['data'];
          if (data['transfers'] != null) {
            _transferHistory = List<Map<String, dynamic>>.from(data['transfers']);
          } else if (data is List) {
            _transferHistory = List<Map<String, dynamic>>.from(data);
          }
        }
        _isFetchingHistory = false;
      });
    }
  }

  void _swapWallets() {
    setState(() {
      final temp = _fromWallet;
      _fromWallet = _toWallet;
      _toWallet = temp;
    });
  }

  Future<void> _handleTransfer() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter amount'), backgroundColor: Colors.red),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount'), backgroundColor: Colors.red),
      );
      return;
    }

    // Check available balance
    final availableBalance = double.tryParse(_getWalletBalance(_fromWallet)) ?? 0;
    if (amount > availableBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient balance. Available: $availableBalance USDT'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Prevent same wallet transfer
    if (_fromWallet == _toWallet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot transfer to the same wallet'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final result = await WalletService.transferBetweenWallets(
        fromWallet: _fromWallet,
        toWallet: _toWallet,
        coin: _selectedCoin,
        amount: amount,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        
        if (result['success'] == true) {
          // Show success message with details
          String message = result['message'] ?? 'Transfer Successful';
          if (result['data'] != null) {
            final data = result['data'];
            if (data['transactionId'] != null) {
              message += '\nTransaction ID: ${data['transactionId']}';
            }
            if (data['newBalance'] != null) {
              message += '\nNew Balance: ${data['newBalance']} $_selectedCoin';
            }
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
          
          _amountController.clear();
          _fetchBalances(); // Refresh balances
          _fetchTransferHistory(); // Refresh transfer history
        } else {
          // Show detailed error message
          String errorMessage = result['error'] ?? 'Transfer failed';
          if (result['details'] != null) {
            final details = result['details'];
            if (details['field'] != null) {
              errorMessage += '\nField: ${details['field']}';
            }
            if (details['code'] != null) {
              errorMessage += '\nCode: ${details['code']}';
            }
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double available = 0.0;
    if (_balances[_fromWallet] != null) {
      available = double.tryParse(_balances[_fromWallet]['available']?.toString() ?? '0') ?? 0.0;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Internal Transfer', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // From/To Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  Column(
                    children: [
                      _buildWalletSelector('From', _fromWallet, (val) {
                        setState(() => _fromWallet = val!);
                      }),
                      const Divider(color: Colors.white10, height: 32),
                      _buildWalletSelector('To', _toWallet, (val) {
                        setState(() => _toWallet = val!);
                      }),
                    ],
                  ),
                  Positioned(
                    right: 0,
                    child: GestureDetector(
                      onTap: _swapWallets,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF252525),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.swap_vert, color: Color(0xFF84BD00)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Available Balance Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF84BD00).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: Color(0xFF84BD00), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Available Balance', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            const Spacer(),
                            if (_isFetchingBalances)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(color: Color(0xFF84BD00), strokeWidth: 2),
                              )
                            else
                              GestureDetector(
                                onTap: _fetchBalances,
                                child: const Icon(Icons.refresh, color: Color(0xFF84BD00), size: 16),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_getWalletBalance(_fromWallet)} USDT',
                          style: const TextStyle(color: Color(0xFF84BD00), fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Coin', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCoin,
                  dropdownColor: const Color(0xFF1A1A1A),
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white),
                  items: ['USDT', 'BTC', 'ETH'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setState(() => _selectedCoin = val!),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Amount', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                hintText: '0.00',
                hintStyle: const TextStyle(color: Colors.white24),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                suffixText: _selectedCoin,
                suffixStyle: const TextStyle(color: Color(0xFF84BD00)),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Available: ${available.toStringAsFixed(2)} $_selectedCoin',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                GestureDetector(
                  onTap: () => _amountController.text = available.toString(),
                  child: const Text('Max', style: TextStyle(color: Color(0xFF84BD00), fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleTransfer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF84BD00),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('Confirm Transfer', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
            // Transfer History Section
            Container(
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
                      const Text(
                        'Recent Transfers',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_isFetchingHistory)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Color(0xFF84BD00), strokeWidth: 2),
                        )
                      else
                        GestureDetector(
                          onTap: _fetchTransferHistory,
                          child: const Icon(Icons.refresh, color: Color(0xFF84BD00), size: 20),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_transferHistory.isEmpty && !_isFetchingHistory)
                    const Center(
                      child: Text(
                        'No transfer history found',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _transferHistory.length > 5 ? 5 : _transferHistory.length,
                      itemBuilder: (context, index) {
                        final transfer = _transferHistory[index];
                        return _buildTransferHistoryItem(transfer);
                      },
                    ),
                  if (_transferHistory.length > 5)
                    Center(
                      child: TextButton(
                        onPressed: () {
                          // TODO: Navigate to full transfer history
                        },
                        child: const Text(
                          'View All',
                          style: TextStyle(color: Color(0xFF84BD00)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getWalletBalance(String walletType) {
    final balance = _balances[walletType];
    return balance?['available']?.toString() ?? '0.00';
  }

  Widget _buildTransferHistoryItem(Map<String, dynamic> transfer) {
    final fromWallet = transfer['fromWallet']?.toString() ?? 'Unknown';
    final toWallet = transfer['toWallet']?.toString() ?? 'Unknown';
    final amount = transfer['amount']?.toString() ?? '0.00';
    final coin = transfer['coin']?.toString() ?? 'USDT';
    final status = transfer['status']?.toString() ?? 'completed';
    final createdAt = transfer['createdAt']?.toString();
    
    String formattedDate = 'Unknown';
    if (createdAt != null) {
      try {
        final dateTime = DateTime.parse(createdAt);
        formattedDate = DateFormat('MMM dd, yyyy - HH:mm').format(dateTime);
      } catch (e) {
        formattedDate = createdAt;
      }
    }
    
    Color statusColor = status == 'completed' ? const Color(0xFF84BD00) : 
                       status == 'pending' ? Colors.orange : Colors.red;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$fromWallet → $toWallet',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$amount $coin',
                    style: const TextStyle(
                      color: Color(0xFF84BD00),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWalletSelector(String label, String value, ValueChanged<String?> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        ),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: const Color(0xFF1A1A1A),
              isExpanded: true,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              items: _walletTypes.map((wallet) {
                final walletCode = wallet['code']!;
                final balance = _balances[walletCode];
                final available = balance?['available']?.toString() ?? '0.00';
                return DropdownMenuItem(
                  value: walletCode,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(wallet['name']!),
                      Text(
                        'Available: $available USDT',
                        style: const TextStyle(color: Color(0xFF84BD00), fontSize: 10),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
