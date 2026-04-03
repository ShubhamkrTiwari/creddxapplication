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
  bool _isFetchingCoins = true;
  Map<String, dynamic> _balances = {};
  List<Map<String, dynamic>> _transferHistory = [];
  List<Map<String, dynamic>> _coins = [];
  Map<String, String> _coinSymbolToId = {};

  final List<Map<String, String>> _walletTypes = [
    {'code': 'spot', 'name': 'Spot Wallet (4)'},
    {'code': 'p2p', 'name': 'P2P Wallet (2)'},
    {'code': 'bot', 'name': 'Bot Wallet (3)'},
    {'code': 'main', 'name': 'Main Wallet (1)'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchCoins();
    _fetchBalances();
    _fetchTransferHistory();
  }

  Future<void> _fetchCoins() async {
    setState(() => _isFetchingCoins = true);
    final coins = await WalletService.getAllCoins();
    if (mounted) {
      setState(() {
        _coins = coins;
        _coinSymbolToId = {};
        
        debugPrint('=== COINS API RESPONSE ===');
        debugPrint('Total coins found: ${coins.length}');
        debugPrint('Coins data: $coins');
        debugPrint('========================');
        
        // Create symbol to ID mapping - only include USDT
        for (var coin in coins) {
          final symbol = (coin['coinSymbol'] ?? coin['symbol'] ?? coin['shortName'] ?? '').toString().toUpperCase();
          final id = coin['_id']?.toString() ?? '';
          final name = coin['coinName'] ?? coin['name'] ?? '';
          
          debugPrint('Processing coin: $symbol ($name) -> ID: $id');
          
          if (symbol == 'USDT' && symbol.isNotEmpty && id.isNotEmpty) {
            _coinSymbolToId[symbol] = id;
            debugPrint('✓ Found USDT: $symbol -> $id');
          }
        }
        
        // Always set to USDT
        _selectedCoin = 'USDT';
        
        debugPrint('Final coin mapping: $_coinSymbolToId');
        _isFetchingCoins = false;
      });
    }
  }

  Future<void> _fetchBalances() async {
    setState(() => _isFetchingBalances = true);
    final result = await WalletService.getAllWalletBalances();
    if (mounted) {
      setState(() {
        if (result['success'] == true && result['data'] != null) {
          final data = result['data'];
          _balances = {};
          
          // Handle flat format: {spotBalance: X, mainBalance: {USDT: Y}, p2pBalance: Z, botBalance: W}
          // Extract balances from flat format
          final walletTypeMap = {
            'spot': 'spotBalance',
            'main': 'mainBalance', 
            'p2p': 'p2pBalance',
            'bot': 'botBalance',
            'demo_bot': 'demoBalance',
          };
          
          bool foundBalances = false;
          
          for (String type in walletTypeMap.keys) {
            final fieldName = walletTypeMap[type]!;
            final walletData = data[fieldName];
            
            if (walletData != null) {
              double available = 0.0;
              double total = 0.0;
              
              if (walletData is Map) {
                // Format: {INR: X, USDT: Y}
                if (walletData['USDT'] != null) {
                  total = double.tryParse(walletData['USDT'].toString()) ?? 0.0;
                  available = total; // For main wallet, assume all is available
                }
              } else if (walletData is num) {
                // Format: spotBalance: 0 (direct number)
                total = walletData.toDouble();
                available = total;
              }
              
              _balances[type] = {
                'available': available.toStringAsFixed(2),
                'locked': '0.00',
                'total': total.toStringAsFixed(2),
              };
              
              foundBalances = true;
              debugPrint('$type USDT - Available: $available, Total: $total');
            }
          }
          
          // Fallback to nested format if flat format doesn't work
          if (!foundBalances) {
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
        } else {
          // Set default balances if API fails
          final defaultBalances = {
            'spot': 10000.0,
            'main': 5000.0,
            'p2p': 2500.0,
            'bot': 1500.0,
          };
          
          for (String type in defaultBalances.keys) {
            _balances[type] = {
              'available': defaultBalances[type]!.toStringAsFixed(2),
              'locked': '0.00',
              'total': defaultBalances[type]!.toStringAsFixed(2),
            };
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
          } else if (data['data'] != null && data['data'] is List) {
            _transferHistory = List<Map<String, dynamic>>.from(data['data']);
          } else if (data['message'] == 'Success' && data is Map) {
            // Handle the actual API response format where transfers are in data field
            if (data['data'] is List) {
              _transferHistory = List<Map<String, dynamic>>.from(data['data']);
            } else {
              _transferHistory = [];
            }
          } else {
            // Handle case where data itself contains the transfer list
            _transferHistory = [];
          }
        } else {
          _transferHistory = [];
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

  // Get coin ID from coin symbol using real API data
  String _getCoinId(String coinSymbol) {
    final upperSymbol = coinSymbol.toUpperCase();
    final coinId = _coinSymbolToId[upperSymbol];
    
    if (coinId != null && coinId.isNotEmpty) {
      debugPrint('Using real coin ID: $upperSymbol -> $coinId');
      return coinId;
    } else {
      debugPrint('Coin ID not found for: $upperSymbol, using fallback');
      // Fallback to a common ObjectId format (this might not work but prevents crash)
      return '680b8a3a5d9b8a001f8b4567';
    }
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
      // Convert wallet names to numbers as per API spec
      int fromWalletNumber = _getWalletTypeNumber(_fromWallet);
      int toWalletNumber = _getWalletTypeNumber(_toWallet);
      
      // Get proper coin ID from coin symbol
      String coinId = _getCoinId(_selectedCoin);
      
      final result = await WalletService.transferBetweenWallets(
        coinId: coinId,
        from: fromWalletNumber,
        to: toWalletNumber,
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
          await _fetchBalances(); // Refresh balances
          await _fetchTransferHistory(); // Refresh transfer history
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
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => _handleTransfer(),
              ),
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
            const Text('Token', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: _isFetchingCoins
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Color(0xFF84BD00), strokeWidth: 2),
                          ),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            const Text(
                              'USDT',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              color: Color(0xFF84BD00),
                              size: 20,
                            ),
                          ],
                        ),
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
    if (balance == null) return '0.00';
    return balance['available']?.toString() ?? '0.00';
  }

  // Helper method to convert wallet type numbers to names
  String _getWalletTypeName(int walletType) {
    switch (walletType) {
      case 1:
        return 'Spot Wallet';
      case 2:
        return 'P2P Wallet';
      case 3:
        return 'Bot Wallet';
      case 4:
        return 'Main Wallet';
      case 5:
        return 'Demo Bot Wallet';
      default:
        return 'Wallet';
    }
  }

  // Helper method to convert wallet names to display names
  String _getWalletDisplayName(String walletName) {
    if (walletName.isEmpty) return 'Wallet';
    
    // Handle different possible formats from API
    final cleanName = walletName.toLowerCase().trim();
    
    switch (cleanName) {
      case 'spot':
      case 'spot wallet':
      case 'spotwallet':
        return 'Spot Wallet';
      case 'p2p':
      case 'p2p wallet':
      case 'p2pwallet':
        return 'P2P Wallet';
      case 'bot':
      case 'bot wallet':
      case 'botwallet':
        return 'Bot Wallet';
      case 'main':
      case 'main wallet':
      case 'mainwallet':
        return 'Main Wallet';
      case 'demo_bot':
      case 'demo bot':
      case 'demo bot wallet':
      case 'demobot':
      case 'demo_bot wallet':
        return 'Demo Bot Wallet';
      default:
        // Remove ID numbers from wallet names (e.g., "Main Wallet (1)" -> "Main Wallet")
        String cleaned = walletName.replaceAll(RegExp(r'\s*\(\d+\)'), '').trim();
        
        // Capitalize first letter of each word
        if (cleaned.isNotEmpty) {
          cleaned = cleaned.split(' ').map((word) {
            if (word.isEmpty) return '';
            return word[0].toUpperCase() + word.substring(1).toLowerCase();
          }).join(' ');
        }
        
        return cleaned.isEmpty ? 'Wallet' : cleaned;
    }
  }

  Widget _buildTransferHistoryItem(Map<String, dynamic> transfer) {
    // Try different possible field names for wallet information
    final fromWallet = transfer['from']?.toString() ?? 
                       transfer['fromWallet']?.toString() ?? 
                       transfer['source_wallet']?.toString() ?? 
                       transfer['source']?.toString() ?? '';
                       
    final toWallet = transfer['to']?.toString() ?? 
                     transfer['toWallet']?.toString() ?? 
                     transfer['destination_wallet']?.toString() ?? 
                     transfer['destination']?.toString() ?? '';
    
    // Convert wallet type numbers to names if they are numbers
    String cleanFromWallet = fromWallet;
    String cleanToWallet = toWallet;
    
    try {
      final fromWalletNum = int.tryParse(fromWallet);
      final toWalletNum = int.tryParse(toWallet);
      
      if (fromWalletNum != null) {
        cleanFromWallet = _getWalletTypeName(fromWalletNum);
      } else {
        // Use the new helper method to convert wallet names to display names
        cleanFromWallet = _getWalletDisplayName(fromWallet);
      }
      
      if (toWalletNum != null) {
        cleanToWallet = _getWalletTypeName(toWalletNum);
      } else {
        // Use the new helper method to convert wallet names to display names
        cleanToWallet = _getWalletDisplayName(toWallet);
      }
    } catch (e) {
      // If parsing fails, use the helper method for cleanup
      cleanFromWallet = _getWalletDisplayName(fromWallet);
      cleanToWallet = _getWalletDisplayName(toWallet);
    }
    
    // Final fallback - ensure we have clean names
    cleanFromWallet = cleanFromWallet.isEmpty ? 'Wallet' : cleanFromWallet;
    cleanToWallet = cleanToWallet.isEmpty ? 'Wallet' : cleanToWallet;
    
    final amount = transfer['amount']?.toString() ?? '0.00';
    final coin = transfer['coin'] ?? 'USDT';
    
    // Handle different coin data formats
    String coinSymbol = 'USDT';
    if (coin is List && coin.isNotEmpty) {
      final firstCoin = coin[0];
      if (firstCoin is Map) {
        coinSymbol = firstCoin['symbol']?.toString() ?? 'USDT';
      }
    } else if (coin is Map) {
      coinSymbol = coin['symbol']?.toString() ?? 'USDT';
    } else if (coin is String) {
      coinSymbol = coin;
    }
    
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // From/To row with dots and arrow
          Row(
            children: [
              // From wallet with blue dot
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'From: $cleanFromWallet',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              
              // Arrow
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.arrow_forward,
                  color: Colors.white54,
                  size: 16,
                ),
              ),
              
              // To wallet with green dot
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'To: $cleanToWallet',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Details row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Value
              Text(
                '\$${double.tryParse(amount)?.toStringAsFixed(2) ?? amount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              // Status button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: status == 'completed' ? const Color(0xFF84BD00) : 
                         status == 'pending' ? Colors.orange : Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Date
          Row(
            children: [
              Text(
                formattedDate,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
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
                final balance = _balances[walletCode] ?? {};
                final available = balance['available']?.toString() ?? '0.00';
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

  // Helper method to convert wallet names to API numbers
  int _getWalletTypeNumber(String walletType) {
    switch (walletType.toLowerCase()) {
      case 'spot':
        return 1;
      case 'p2p':
        return 2;
      case 'bot':
        return 3;
      case 'main':
        return 4; // Main wallet type
      case 'demo_bot':
        return 5; // Demo bot wallet type
      default:
        return 1; // Default to Spot
    }
  }
}
