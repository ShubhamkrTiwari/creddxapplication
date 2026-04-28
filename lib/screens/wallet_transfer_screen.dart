import 'package:flutter/material.dart';
import 'dart:async';
import '../services/wallet_service.dart';
import '../services/spot_service.dart';
import '../services/socket_service.dart';
import '../services/bot_service.dart';
import '../services/user_service.dart';
import '../services/unified_wallet_service.dart' as unified;
import '../utils/kyc_unlock_mixin.dart';
import 'package:intl/intl.dart';
import 'user_profile_screen.dart';

class InternalTransferScreen extends StatefulWidget {
  const InternalTransferScreen({super.key});

  @override
  State<InternalTransferScreen> createState() => _InternalTransferScreenState();
}

class _InternalTransferScreenState extends State<InternalTransferScreen> with KYCUnlockMixin {
  String _fromWallet = 'spot';
  String _toWallet = 'p2p';
  String _selectedCoin = 'USDT';
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;
  bool _isFetchingBalances = true;
  bool _isFetchingCoins = true;
  Map<String, dynamic> _balances = {};
  List<Map<String, dynamic>> _coins = [];
  Map<String, String> _coinSymbolToId = {};
  StreamSubscription? _balanceSubscription;
  StreamSubscription? _unifiedWalletSubscription;
  
  final UserService _userService = UserService();

  final List<Map<String, String>> _walletTypes = [
    {'code': 'main', 'name': 'Main Wallet'},
    {'code': 'p2p', 'name': 'P2P Wallet'},
    {'code': 'bot', 'name': 'Bot Wallet'},
    {'code': 'spot', 'name': 'Spot Wallet'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchCoins();
    _fetchBalances();
    _subscribeToSocketBalance();
    _subscribeToUnifiedWallet();
  }

  @override
  void dispose() {
    _balanceSubscription?.cancel();
    _unifiedWalletSubscription?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  void _subscribeToUnifiedWallet() {
    _unifiedWalletSubscription = unified.UnifiedWalletService.walletBalanceStream.listen((walletBalance) {
      if (mounted && walletBalance != null) {
        setState(() {
          // Update balances from UnifiedWalletService for consistency with WalletScreen
          final spotBalance = unified.UnifiedWalletService.spotUSDTBalance;
          final spotCoin = unified.UnifiedWalletService.usdtCoinBalance;
          final spotAvailable = spotCoin?.free ?? spotBalance;
          final spotLocked = spotCoin?.locked ?? 0.0;

          _balances['spot'] = {
            'available': spotAvailable.toStringAsFixed(2),
            'locked': spotLocked.toStringAsFixed(2),
            'total': (spotAvailable + spotLocked).toStringAsFixed(2),
          };

          _balances['main'] = {
            'available': unified.UnifiedWalletService.mainUSDTBalance.toStringAsFixed(2),
            'locked': '0.00',
            'total': unified.UnifiedWalletService.mainUSDTBalance.toStringAsFixed(2),
          };

          _balances['p2p'] = {
            'available': unified.UnifiedWalletService.p2pUSDTBalance.toStringAsFixed(2),
            'locked': '0.00',
            'total': unified.UnifiedWalletService.p2pUSDTBalance.toStringAsFixed(2),
          };

          _balances['bot'] = {
            'available': unified.UnifiedWalletService.botUSDTBalance.toStringAsFixed(2),
            'locked': '0.00',
            'total': unified.UnifiedWalletService.botUSDTBalance.toStringAsFixed(2),
          };

          _isFetchingBalances = false;
        });
      }
    });
  }

  void _subscribeToSocketBalance() {
    _balanceSubscription?.cancel();
    _balanceSubscription = SocketService.balanceStream.listen((data) {
      if (mounted) {
        debugPrint('=== SOCKET BALANCE UPDATE IN TRANSFER SCREEN ===');
        debugPrint('Event type: ${data['type']}');
        debugPrint('Full data: $data');

        // Handle wallet_summary_update for all wallets including bot
        if (data['type'] == 'wallet_summary_update' || data['type'] == 'wallet_summary') {
          final balanceData = data['data'];
          if (balanceData != null && balanceData is Map) {
            // Update bot balance from wallet summary - use availableBalance to show only investable amount
            final availableBalance = balanceData['availableBalance'] ?? balanceData['available'];
            if (availableBalance != null) {
              double botAvailable = 0.0;
              if (availableBalance is num) {
                botAvailable = availableBalance.toDouble();
              } else if (availableBalance is Map) {
                botAvailable = double.tryParse(availableBalance['USDT']?.toString() ?? '0') ?? 0.0;
              } else {
                botAvailable = double.tryParse(availableBalance.toString()) ?? 0.0;
              }
              setState(() {
                _balances['bot'] = {
                  'available': botAvailable.toStringAsFixed(2),
                  'locked': '0.00',
                  'total': botAvailable.toStringAsFixed(2),
                };
              });
              debugPrint('✅ Bot available balance updated from wallet summary: $botAvailable');
            }

            // Update other wallets from wallet summary
            final mainBalance = balanceData['mainBalance'] ?? balanceData['main'];
            if (mainBalance != null) {
              double mainAvailable = 0.0;
              if (mainBalance is num) {
                mainAvailable = mainBalance.toDouble();
              } else if (mainBalance is Map) {
                mainAvailable = double.tryParse(mainBalance['USDT']?.toString() ?? '0') ?? 0.0;
              }
              setState(() {
                _balances['main'] = {
                  'available': mainAvailable.toStringAsFixed(2),
                  'locked': '0.00',
                  'total': mainAvailable.toStringAsFixed(2),
                };
              });
            }

            final p2pBalance = balanceData['p2pBalance'] ?? balanceData['p2p'];
            if (p2pBalance != null) {
              double p2pAvailable = 0.0;
              if (p2pBalance is num) {
                p2pAvailable = p2pBalance.toDouble();
              } else if (p2pBalance is Map) {
                p2pAvailable = double.tryParse(p2pBalance['USDT']?.toString() ?? '0') ?? 0.0;
              }
              setState(() {
                _balances['p2p'] = {
                  'available': p2pAvailable.toStringAsFixed(2),
                  'locked': '0.00',
                  'total': p2pAvailable.toStringAsFixed(2),
                };
              });
            }
          }
        }

        // Handle balance_update for spot wallet
        if (data['type'] == 'balance_update') {
          setState(() {
            final assets = data['assets'] as List?;
            if (assets != null) {
              // Find the selected coin (usually USDT) in the socket update
              final assetData = assets.firstWhere(
                (a) => a['asset'] == _selectedCoin,
                orElse: () => null,
              );

              if (assetData != null) {
                final available = double.tryParse(assetData['available']?.toString() ?? '0.0') ?? 0.0;
                final locked = double.tryParse(assetData['locked']?.toString() ?? '0.0') ?? 0.0;
                final total = available + locked;

                // The socket balance update specifically updates the Spot Wallet
                _balances['spot'] = {
                  'available': available.toStringAsFixed(2),
                  'locked': locked.toStringAsFixed(2),
                  'total': total.toStringAsFixed(2),
                };

                debugPrint('✅ Spot balance updated from socket: $available $_selectedCoin');
              }
            }
          });
        }
      }
    });
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

    // Use UnifiedWalletService for consistent balance data (same as WalletScreen)
    await unified.UnifiedWalletService.refreshAllBalances();

    if (mounted) {
      setState(() {
        // Get balances from UnifiedWalletService for consistency
        final spotBalance = unified.UnifiedWalletService.spotUSDTBalance;
        final spotCoin = unified.UnifiedWalletService.usdtCoinBalance;
        final spotAvailable = spotCoin?.free ?? spotBalance;
        final spotLocked = spotCoin?.locked ?? 0.0;

        _balances['spot'] = {
          'available': spotAvailable.toStringAsFixed(2),
          'locked': spotLocked.toStringAsFixed(2),
          'total': (spotAvailable + spotLocked).toStringAsFixed(2),
        };

        _balances['main'] = {
          'available': unified.UnifiedWalletService.mainUSDTBalance.toStringAsFixed(2),
          'locked': '0.00',
          'total': unified.UnifiedWalletService.mainUSDTBalance.toStringAsFixed(2),
        };

        _balances['p2p'] = {
          'available': unified.UnifiedWalletService.p2pUSDTBalance.toStringAsFixed(2),
          'locked': '0.00',
          'total': unified.UnifiedWalletService.p2pUSDTBalance.toStringAsFixed(2),
        };

        _balances['bot'] = {
          'available': unified.UnifiedWalletService.botUSDTBalance.toStringAsFixed(2),
          'locked': '0.00',
          'total': unified.UnifiedWalletService.botUSDTBalance.toStringAsFixed(2),
        };

        _isFetchingBalances = false;
        debugPrint('Balances updated from UnifiedWalletService - Main: ${unified.UnifiedWalletService.mainUSDTBalance}, Spot: $spotAvailable (locked: $spotLocked), P2P: ${unified.UnifiedWalletService.p2pUSDTBalance}, Bot: ${unified.UnifiedWalletService.botUSDTBalance}');
      });
    }
  }

  // Fallback method for fetching balances directly from APIs (kept for reference if needed)
  Future<void> _fetchBalancesFallback() async {
    setState(() => _isFetchingBalances = true);

    // Fetch bot balance specifically from BotService to get availableBalance
    final botBalanceResult = await BotService.getBotBalance();

    // Fetch both WalletService and SpotService balances
    final result = await WalletService.getAllWalletBalances();
    final spotResult = await SpotService.getBalance();

    if (mounted) {
      setState(() {
        _balances = {};

        // Step 0: Set bot balance from BotService (has correct availableBalance)
        if (botBalanceResult['success'] == true && botBalanceResult['data'] != null) {
          final data = botBalanceResult['data'];
          double botAvailable = 0.0;
          // Prefer availableBalance to show only investable amount
          if (data['availableBalance'] != null) {
            botAvailable = double.tryParse(data['availableBalance'].toString()) ?? 0.0;
          } else if (data['balance'] != null) {
            botAvailable = double.tryParse(data['balance'].toString()) ?? 0.0;
          } else if (data['totalBalance'] != null) {
            botAvailable = double.tryParse(data['totalBalance'].toString()) ?? 0.0;
          }
          _balances['bot'] = {
            'available': botAvailable.toStringAsFixed(2),
            'locked': '0.00',
            'total': botAvailable.toStringAsFixed(2),
          };
          debugPrint('Bot balance from BotService API: $botAvailable');
        }

        // Step 1: Fetch spot balance from SpotService API (GET /balance/:user_id)
        if (spotResult['success'] == true && spotResult['data'] != null) {
          final spotData = spotResult['data'];
          double spotAvailable = double.tryParse(spotData['usdt_available']?.toString() ?? '0.0') ?? 0.0;
          double spotLocked = double.tryParse(spotData['usdt_locked']?.toString() ?? '0.0') ?? 0.0;
          double spotTotal = spotAvailable + spotLocked;

          _balances['spot'] = {
            'available': spotAvailable.toStringAsFixed(2),
            'locked': spotLocked.toStringAsFixed(2),
            'total': spotTotal.toStringAsFixed(2),
          };
          debugPrint('SpotService spot balance - Available: $spotAvailable, Locked: $spotLocked, Total: $spotTotal');
        }

        // Step 2: Fetch wallet balances from WalletService (main, p2p, bot, spot)
        if (result['success'] == true && result['data'] != null) {
          final data = result['data'];

          // Parse spotBalance from API response if not already set from SpotService
          if (_balances['spot'] == null && data['spotBalance'] != null) {
            final spotTotal = double.tryParse(data['spotBalance'].toString()) ?? 0.0;
            _balances['spot'] = {
              'available': spotTotal.toStringAsFixed(2),
              'locked': '0.00',
              'total': spotTotal.toStringAsFixed(2),
            };
            debugPrint('Spot balance from WalletService API: $spotTotal');
          }

          // Handle flat format: {mainBalance: {USDT: Y}, p2pBalance: Z, botBalance: W}
          final walletTypeMap = {
            'main': 'mainBalance',
            'p2p': 'p2pBalance',
            'bot': 'botBalance',
            'demo_bot': 'demoBalance',
          };

          bool foundBalances = false;

          for (String type in walletTypeMap.keys) {
            // Skip bot if already set from BotService (has correct availableBalance)
            if (type == 'bot' && _balances['bot'] != null) {
              debugPrint('Skipping bot balance from WalletService (already set from BotService)');
              continue;
            }

            final fieldName = walletTypeMap[type]!;
            final walletData = data[fieldName];

            if (walletData != null) {
              double available = 0.0;
              double total = 0.0;
              double inrTotal = 0.0;

              if (walletData is Map) {
                // Format: {INR: X, USDT: Y}
                if (walletData['USDT'] != null) {
                  total = double.tryParse(walletData['USDT'].toString()) ?? 0.0;
                  available = total; // For main wallet, assume all is available
                }
                if (walletData['INR'] != null) {
                  inrTotal = double.tryParse(walletData['INR'].toString()) ?? 0.0;
                }
              } else if (walletData is num) {
                // Format: p2pBalance: 0 (direct number)
                total = walletData.toDouble();
                available = total;
              }

              _balances[type] = {
                'available': available.toStringAsFixed(2),
                'locked': '0.00',
                'total': total.toStringAsFixed(2),
                'inr_total': inrTotal.toStringAsFixed(2),
              };

              foundBalances = true;
              debugPrint('$type USDT - Available: $available, Total: $total, INR: $inrTotal');
            }
          }

          // Fallback to nested format if flat format doesn't work
          if (!foundBalances) {
            // Extract USDT balances from all wallet types
            final walletTypes = ['p2p', 'bot', 'demo_bot', 'main'];
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
        }
        
        // Set default zero balances for any missing wallets
        final defaultWallets = ['spot', 'main', 'p2p', 'bot'];
        for (String type in defaultWallets) {
          if (_balances[type] == null) {
            _balances[type] = {'available': '0.00', 'locked': '0.00', 'total': '0.00'};
          }
        }
        
        _isFetchingBalances = false;
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

  
  // Check if profile is complete
  bool _isProfileComplete() {
    return _userService.hasEmail() && 
           _userService.userPhone != null && 
           _userService.userPhone!.isNotEmpty;
  }

  
  // Show profile completion required dialog
  void _showProfileRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Profile Completion Required',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Please complete your profile information (email and phone number) to transfer funds.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(context, MaterialPageRoute(builder: (context) => const UserProfileScreen()));
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF84BD00)),
              child: const Text('Complete Profile', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  // Validate user requirements before proceeding (KYC removed for wallet transfers)
  bool _validateUserRequirements() {
    // KYC verification removed for wallet-to-wallet transfers
    
    if (!_isProfileComplete()) {
      _showProfileRequiredDialog();
      return false;
    }
    
    return true;
  }

  // Get coin ID from coin symbol using real API data
  String _getCoinId(String coinSymbol) {
    final upperSymbol = coinSymbol.toUpperCase();
    final coinId = _coinSymbolToId[upperSymbol];
    
    if (coinId != null && coinId.isNotEmpty) {
      debugPrint('Using real coin ID: $upperSymbol -> $coinId');
      return coinId;
    } else {
      debugPrint('ERROR: Coin ID not found for: $upperSymbol');
      debugPrint('Available coin mappings: $_coinSymbolToId');
      // Return empty string to trigger proper validation error
      return '';
    }
  }

  Future<void> _handleTransfer() async {
    // Check KYC and profile requirements first
    if (!_validateUserRequirements()) {
      return;
    }

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
      // Perform transfer directly without OTP
      int fromWalletNumber = _getWalletTypeNumber(_fromWallet);
      int toWalletNumber = _getWalletTypeNumber(_toWallet);
      String coinId = _getCoinId(_selectedCoin);

      final result = await WalletService.transferBetweenWallets(
        coinId: coinId,
        from: fromWalletNumber,
        to: toWalletNumber,
        amount: amount,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        _amountController.clear();

        // If transfer was from or to bot wallet, fetch bot balance specifically
        if (_fromWallet == 'bot' || _toWallet == 'bot') {
          // Trigger socket requests for real-time update
          SocketService.requestWalletBalance();
          SocketService.requestWalletSummary();

          // Wait a bit for socket to update
          await Future.delayed(const Duration(milliseconds: 300));

          // Directly fetch bot balance from API to ensure it's updated
          try {
            final botBalanceResult = await BotService.getBotBalance();
            if (botBalanceResult['success'] == true && botBalanceResult['data'] != null) {
              final data = botBalanceResult['data'];
              double balance = 0.0;
              // Prefer availableBalance to show only investable amount
              if (data['availableBalance'] != null) {
                balance = double.tryParse(data['availableBalance'].toString()) ?? 0.0;
              } else if (data['balance'] != null) {
                balance = double.tryParse(data['balance'].toString()) ?? 0.0;
              } else if (data['totalBalance'] != null) {
                balance = double.tryParse(data['totalBalance'].toString()) ?? 0.0;
              }
              setState(() {
                _balances['bot'] = {
                  'available': balance.toStringAsFixed(2),
                  'locked': '0.00',
                  'total': balance.toStringAsFixed(2),
                };
              });
              debugPrint('✅ Bot available balance fetched directly from API: $balance');
            }
          } catch (e) {
            debugPrint('Error fetching bot balance: $e');
          }
        }

        await _fetchBalances(); // Refresh all balances

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transfer Successful'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        _showError(result['error'] ?? 'Transfer failed');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show selected "From" wallet balance as available
    double available = double.tryParse(_balances[_fromWallet]?['available']?.toString() ?? '0') ?? 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Wallet Transfer', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
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
                            Text('Available (${_getWalletDisplayName(_fromWallet)})', style: TextStyle(color: Colors.white54, fontSize: 12)),
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
                          '${_balances[_fromWallet]?['available'] ?? '0.00'} USDT',
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
            const SizedBox(height: 32),
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
          ],
        ),
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
      case 4:
        return 'Spot Wallet';
      case 2:
        return 'P2P Wallet';
      case 3:
        return 'Bot Wallet';
      case 1:
        return 'Main Wallet';

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
                      Row(
                        children: [
                          Text(
                            'Available: $available USDT',
                            style: const TextStyle(color: Color(0xFF84BD00), fontSize: 10),
                          ),
                          if (walletCode == 'main' && balance['inr_total'] != null && balance['inr_total'] != '0.00')
                            Text(
                              ' | ₹${balance['inr_total']}',
                              style: const TextStyle(color: Colors.orange, fontSize: 10),
                            ),
                        ],
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
      case 'main':
        return 1; // Main wallet type
      case 'p2p':
        return 2;
      case 'bot':
        return 3;
      case 'spot':
        return 4;
      case 'demo_bot':
        return 5; // Demo bot wallet type
      default:
        return 1; // Default to Spot
    }
  }
}
