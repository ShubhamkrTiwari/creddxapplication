import 'package:flutter/material.dart';
import 'dart:async';
import '../services/wallet_service.dart';
import '../services/spot_service.dart';
import '../services/socket_service.dart';
import '../services/bot_service.dart';
import '../services/user_service.dart';
import '../services/unified_wallet_service.dart' as unified;
import '../services/auto_refresh_service.dart';
import 'package:intl/intl.dart';

class BotTransferScreen extends StatefulWidget {
  const BotTransferScreen({super.key});

  @override
  State<BotTransferScreen> createState() => _BotTransferScreenState();
}

class _BotTransferScreenState extends State<BotTransferScreen> {
  String _fromWallet = 'main';
  String _toWallet = 'bot';
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

  final List<Map<String, String>> _walletTypes = [
    {'code': 'main', 'name': 'Main Wallet'},
    {'code': 'p2p', 'name': 'P2P Wallet'},
    {'code': 'spot', 'name': 'Spot Wallet'},
    {'code': 'bot', 'name': 'Bot Wallet'},
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
          _updateBalancesFromUnified();
          _isFetchingBalances = false;
        });
      }
    });
  }

  void _updateBalancesFromUnified() {
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
  }

  void _subscribeToSocketBalance() {
    _balanceSubscription?.cancel();
    _balanceSubscription = SocketService.balanceStream.listen((data) {
      if (mounted) {
        if (data['type'] == 'wallet_summary_update' || data['type'] == 'wallet_summary') {
          final balanceData = data['data'];
          if (balanceData != null && balanceData is Map) {
            _handleWalletSummaryUpdate(balanceData);
          }
        }

        if (data['type'] == 'balance_update') {
          _handleSpotBalanceUpdate(data);
        }
      }
    });
  }

  void _handleWalletSummaryUpdate(Map balanceData) {
    final availableBalance = balanceData['availableBalance'] ?? balanceData['available'];
    if (availableBalance != null) {
      double botAvailable = _parseAmount(availableBalance);
      setState(() {
        _balances['bot'] = {
          'available': botAvailable.toStringAsFixed(2),
          'locked': '0.00',
          'total': botAvailable.toStringAsFixed(2),
        };
      });
    }

    final mainBalance = balanceData['mainBalance'] ?? balanceData['main'];
    if (mainBalance != null) {
      double mainAvailable = _parseAmount(mainBalance);
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
      double p2pAvailable = _parseAmount(p2pBalance);
      setState(() {
        _balances['p2p'] = {
          'available': p2pAvailable.toStringAsFixed(2),
          'locked': '0.00',
          'total': p2pAvailable.toStringAsFixed(2),
        };
      });
    }
  }

  double _parseAmount(dynamic val) {
    if (val is num) return val.toDouble();
    if (val is Map) return double.tryParse(val['USDT']?.toString() ?? '0') ?? 0.0;
    return double.tryParse(val?.toString() ?? '0') ?? 0.0;
  }

  void _handleSpotBalanceUpdate(Map data) {
    final assets = data['assets'] as List?;
    if (assets != null) {
      final assetData = assets.firstWhere(
        (a) => a['asset'] == _selectedCoin,
        orElse: () => null,
      );

      if (assetData != null) {
        final available = double.tryParse(assetData['available']?.toString() ?? '0.0') ?? 0.0;
        final locked = double.tryParse(assetData['locked']?.toString() ?? '0.0') ?? 0.0;
        setState(() {
          _balances['spot'] = {
            'available': available.toStringAsFixed(2),
            'locked': locked.toStringAsFixed(2),
            'total': (available + locked).toStringAsFixed(2),
          };
        });
      }
    }
  }

  Future<void> _fetchCoins() async {
    setState(() => _isFetchingCoins = true);
    final coins = await WalletService.getAllCoins();
    if (mounted) {
      setState(() {
        _coins = coins;
        _coinSymbolToId = {};
        for (var coin in coins) {
          final symbol = (coin['coinSymbol'] ?? coin['symbol'] ?? coin['shortName'] ?? '').toString().toUpperCase();
          final id = coin['_id']?.toString() ?? '';
          if (symbol == 'USDT' && id.isNotEmpty) {
            _coinSymbolToId[symbol] = id;
          }
        }
        _selectedCoin = 'USDT';
        _isFetchingCoins = false;
      });
    }
  }

  Future<void> _fetchBalances() async {
    setState(() => _isFetchingBalances = true);
    await unified.UnifiedWalletService.refreshAllBalances();
    if (mounted) {
      setState(() {
        _updateBalancesFromUnified();
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

  String _getCoinId(String coinSymbol) {
    return _coinSymbolToId[coinSymbol.toUpperCase()] ?? '';
  }

  Future<void> _handleTransfer() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showError('Please enter amount');
      return;
    }

    final amount = double.tryParse(amountText) ?? 0;
    if (amount <= 0) {
      _showError('Enter a valid amount');
      return;
    }

    if (_fromWallet == _toWallet) {
      _showError('Cannot transfer to the same wallet');
      return;
    }

    final availableBalance = double.tryParse(_balances[_fromWallet]?['available']?.toString() ?? '0') ?? 0;
    if (amount > availableBalance) {
      _showError('Insufficient balance');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final coinId = _getCoinId(_selectedCoin);
      final result = await WalletService.transferBetweenWallets(
        coinId: coinId,
        from: _getWalletTypeNumber(_fromWallet),
        to: _getWalletTypeNumber(_toWallet),
        amount: amount,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        _amountController.clear();
        
        // Immediate refresh
        SocketService.requestWalletBalance();
        SocketService.requestWalletSummary();
        await Future.delayed(const Duration(milliseconds: 300));
        await unified.UnifiedWalletService.refreshAllBalances();
        await AutoRefreshService.forceRefreshAll();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transfer Successful'), backgroundColor: Colors.green),
          );
        }
      } else {
        _showError(result['error'] ?? 'Transfer failed');
      }
    } catch (e) {
      if (mounted) _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  int _getWalletTypeNumber(String walletType) {
    switch (walletType.toLowerCase()) {
      case 'main': return 1;
      case 'p2p': return 2;
      case 'bot': return 3;
      case 'spot': return 4;
      default: return 1;
    }
  }

  String _getWalletDisplayName(String walletName) {
    switch (walletName) {
      case 'main': return 'Main Wallet';
      case 'p2p': return 'P2P Wallet';
      case 'bot': return 'Bot Wallet';
      case 'spot': return 'Spot Wallet';
      default: return 'Wallet';
    }
  }

  @override
  Widget build(BuildContext context) {
    double available = double.tryParse(_balances[_fromWallet]?['available']?.toString() ?? '0') ?? 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Bot Internal Transfer', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2C2C2E)),
              ),
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  Column(
                    children: [
                      _buildWalletSelector('From', _fromWallet, (val) => setState(() => _fromWallet = val!)),
                      const Divider(color: Colors.white10, height: 32),
                      _buildWalletSelector('To', _toWallet, (val) => setState(() => _toWallet = val!)),
                    ],
                  ),
                  Positioned(
                    right: 0,
                    child: GestureDetector(
                      onTap: _swapWallets,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Color(0xFF2C2C2E), shape: BoxShape.circle),
                        child: const Icon(Icons.swap_vert, color: Color(0xFF84BD00)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
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
                            Text('Available (${_getWalletDisplayName(_fromWallet)})', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            const Spacer(),
                            if (_isFetchingBalances)
                              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Color(0xFF84BD00), strokeWidth: 2))
                            else
                              GestureDetector(onTap: _fetchBalances, child: const Icon(Icons.refresh, color: Color(0xFF84BD00), size: 16)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${_balances[_fromWallet]?['available'] ?? '0.00'} USDT', style: const TextStyle(color: Color(0xFF84BD00), fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
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
                fillColor: const Color(0xFF1C1C1E),
                hintText: '0.00',
                hintStyle: const TextStyle(color: Colors.white24),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                suffixText: 'USDT',
                suffixStyle: const TextStyle(color: Color(0xFF84BD00)),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Available: ${available.toStringAsFixed(2)} USDT', style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
    );
  }

  Widget _buildWalletSelector(String label, String value, ValueChanged<String?> onChanged) {
    return Row(
      children: [
        SizedBox(width: 60, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14))),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: const Color(0xFF1C1C1E),
              isExpanded: true,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              items: _walletTypes.map((wallet) {
                final walletCode = wallet['code']!;
                final balance = _balances[walletCode] ?? {};
                return DropdownMenuItem(
                  value: walletCode,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(wallet['name']!),
                      Text('Available: ${balance['available'] ?? '0.00'} USDT', style: const TextStyle(color: Color(0xFF84BD00), fontSize: 10)),
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
