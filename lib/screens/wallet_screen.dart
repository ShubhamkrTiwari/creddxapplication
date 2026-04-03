import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'coming_soon_screen.dart';
import 'deposit_screen.dart';
import 'internal_transfer_screen.dart';
import 'wallet_history_screen.dart';
import '../services/wallet_service.dart';
import '../services/spot_service.dart';
import '../widgets/bitcoin_loading_indicator.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  StreamSubscription<Map<String, dynamic>>? _balanceUpdateSubscription;
  Timer? _balanceRefreshTimer;
  
  bool _isLoading = true;
  String _walletAddress = '0x2340....3420';
  double _totalBalance = 0.0;
  Map<String, dynamic> _walletBalances = {};
  List<Map<String, dynamic>> _cryptoHoldings = [];
  List<Map<String, dynamic>> _transferHistory = [];
  List<Map<String, dynamic>> _transactionHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchWalletData();
    _connectWebSocketBalanceUpdates();
    _startPeriodicBalanceRefresh();
  }

  void _connectWebSocketBalanceUpdates() {
    // Connect to WebSocket for real-time balance updates
    _balanceUpdateSubscription = SpotService.getBalanceUpdatesStream().listen(
      (balanceData) {
        debugPrint('Balance update received via WebSocket: $balanceData');
        if (mounted) {
          // Update state immediately with new balance data
          if (balanceData is Map<String, dynamic>) {
            setState(() {
              // Handle different wallet types from WebSocket
              String walletType = balanceData['wallet_type']?.toString() ?? 'spot';
              String coin = balanceData['coin']?.toString()?.toUpperCase() ?? 'USDT';
              double available = double.tryParse(balanceData['available']?.toString() ?? '0') ?? 0.0;
              double locked = double.tryParse(balanceData['locked']?.toString() ?? '0') ?? 0.0;
              double total = double.tryParse(balanceData['total']?.toString() ?? (available + locked).toString()) ?? (available + locked);
              
              // Update specific wallet balance
              if (walletType == 'spot') {
                // For spot wallet, use specific fields from spot service
                final usdtAvailable = double.tryParse(balanceData['usdt_available']?.toString() ?? available.toString()) ?? available;
                final btcFree = double.tryParse(balanceData['free']?.toString() ?? '0') ?? 0.0;
                
                _walletBalances['spot'] = {
                  'total': usdtAvailable.toStringAsFixed(2),
                  'available': usdtAvailable.toStringAsFixed(2),
                  'locked': '0.00',
                };
                
                // Update crypto holdings for spot
                final usdtIndex = _cryptoHoldings.indexWhere((crypto) => crypto['symbol'] == 'USDT');
                if (usdtIndex >= 0) {
                  final currentMain = double.tryParse(_walletBalances['main']?['total']?.toString() ?? '0') ?? 0.0;
                  final currentP2p = double.tryParse(_walletBalances['p2p']?['total']?.toString() ?? '0') ?? 0.0;
                  final currentBot = double.tryParse(_walletBalances['bot']?['total']?.toString() ?? '0') ?? 0.0;
                  final newTotal = currentMain + usdtAvailable + currentP2p + currentBot;
                  
                  _cryptoHoldings[usdtIndex]['available'] = newTotal.toString();
                  _cryptoHoldings[usdtIndex]['amount'] = newTotal.toString();
                  _cryptoHoldings[usdtIndex]['usdValue'] = newTotal;
                }
                
                final btcIndex = _cryptoHoldings.indexWhere((crypto) => crypto['symbol'] == 'BTC');
                if (btcIndex >= 0 && btcFree > 0) {
                  final btcValue = btcFree * 92076.6;
                  _cryptoHoldings[btcIndex]['available'] = btcFree.toString();
                  _cryptoHoldings[btcIndex]['amount'] = btcFree.toString();
                  _cryptoHoldings[btcIndex]['usdValue'] = btcValue;
                }
              } else {
                // For other wallets (main, p2p, bot)
                _walletBalances[walletType] = {
                  'total': total.toStringAsFixed(2),
                  'available': available.toStringAsFixed(2),
                  'locked': locked.toStringAsFixed(2),
                };
                
                // Update total USDT in assets
                final usdtIndex = _cryptoHoldings.indexWhere((crypto) => crypto['symbol'] == 'USDT');
                if (usdtIndex >= 0) {
                  final currentMain = double.tryParse(_walletBalances['main']?['total']?.toString() ?? '0') ?? 0.0;
                  final currentSpot = double.tryParse(_walletBalances['spot']?['total']?.toString() ?? '0') ?? 0.0;
                  final currentP2p = double.tryParse(_walletBalances['p2p']?['total']?.toString() ?? '0') ?? 0.0;
                  final currentBot = double.tryParse(_walletBalances['bot']?['total']?.toString() ?? '0') ?? 0.0;
                  final newTotal = currentMain + currentSpot + currentP2p + currentBot;
                  
                  _cryptoHoldings[usdtIndex]['available'] = newTotal.toString();
                  _cryptoHoldings[usdtIndex]['amount'] = newTotal.toString();
                  _cryptoHoldings[usdtIndex]['usdValue'] = newTotal;
                }
              }
              
              // Recalculate total balance
              final currentMain = double.tryParse(_walletBalances['main']?['total']?.toString() ?? '0') ?? 0.0;
              final currentSpot = double.tryParse(_walletBalances['spot']?['total']?.toString() ?? '0') ?? 0.0;
              final currentP2p = double.tryParse(_walletBalances['p2p']?['total']?.toString() ?? '0') ?? 0.0;
              final currentBot = double.tryParse(_walletBalances['bot']?['total']?.toString() ?? '0') ?? 0.0;
              final btcValue = (double.tryParse(balanceData['free']?.toString() ?? '0') ?? 0.0) * 92076.6;
              _totalBalance = currentMain + currentSpot + currentP2p + currentBot + btcValue;
              
              debugPrint('Wallet balance updated via WebSocket - $walletType: $available, Total: $total');
            });
          } else {
            // Fallback to full data refresh if WebSocket data format is unexpected
            _fetchWalletData();
          }
        }
      },
      onError: (error) {
        debugPrint('WebSocket balance update error: $error');
        // Try to reconnect after error
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            _connectWebSocketBalanceUpdates();
          }
        });
      },
    );
  }

  String _getCoinFullName(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'BTC': return 'Bitcoin';
      case 'ETH': return 'Ethereum';
      case 'USDT': return 'Tether';
      case 'BNB': return 'Binance Coin';
      case 'SOL': return 'Solana';
      default: return symbol;
    }
  }

  Future<void> _fetchWalletData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      // Use WalletService getAllWalletBalances API (port 8085)
      final balanceResult = await WalletService.getAllWalletBalances();
      debugPrint('WalletService getAllWalletBalances Result: $balanceResult');
      
      // Also fetch history
      final historyResult = await WalletService.getWalletTransferHistory();
      final transactionResult = await WalletService.getCompleteTransactionHistory(limit: 20);
      
      double totalEquityUSDT = 0.0;
      Map<String, dynamic> walletBreakdowns = {};
      Map<String, Map<String, dynamic>> allAssets = {};
      
      // Parse WalletService response for all wallet balances
      if (balanceResult['success'] == true && balanceResult['data'] != null) {
        final data = balanceResult['data'];
        debugPrint('Processing WalletService data: $data');
        
        // Handle flat format: {spotBalance: X, mainBalance: {USDT: Y}, p2pBalance: Z, botBalance: W}
        // Extract balances from flat format
        final walletTypeMap = {
          'spot': 'spotBalance',
          'main': 'mainBalance', 
          'p2p': 'p2pBalance',
          'bot': 'botBalance',
          'demo_bot': 'demoBalance',
        };
        
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
            
            if (total > 0 || type == 'spot' || type == 'main') {
              walletBreakdowns[type] = {
                'total': total.toStringAsFixed(2),
                'available': available.toStringAsFixed(2),
                'locked': '0.00',
              };
              
              // Add to total equity (exclude demo_bot)
              if (type != 'demo_bot') {
                totalEquityUSDT += total;
              }
              
              debugPrint('$type USDT - Available: $available, Total: $total');
            }
          }
        }
        
        // Also try nested format as fallback (original format)
        if (totalEquityUSDT == 0) {
          final walletTypes = ['spot', 'p2p', 'bot', 'demo_bot', 'main'];
          for (String type in walletTypes) {
            if (data[type] != null) {
              final wallet = data[type];
              if (wallet['balances'] != null && wallet['balances'] is List) {
                final balances = wallet['balances'] as List;
                for (var b in balances) {
                  final coin = b['coin']?.toString().toUpperCase() ?? '';
                  if (coin == 'USDT') {
                    final available = double.tryParse(b['available']?.toString() ?? '0') ?? 0.0;
                    final locked = double.tryParse(b['locked']?.toString() ?? '0') ?? 0.0;
                    final total = double.tryParse(b['total']?.toString() ?? '0') ?? 0.0;
                    final calculatedTotal = total > 0 ? total : (available + locked);
                    
                    walletBreakdowns[type] = {
                      'total': calculatedTotal.toStringAsFixed(2),
                      'available': available.toStringAsFixed(2),
                      'locked': locked.toStringAsFixed(2),
                    };
                    
                    if (type != 'demo_bot') {
                      totalEquityUSDT += calculatedTotal;
                    }
                    
                    debugPrint('$type USDT (nested) - Available: $available, Locked: $locked, Total: $calculatedTotal');
                  }
                }
              }
            }
          }
        }
        
        // Add USDT to assets list
        if (totalEquityUSDT > 0) {
          allAssets['USDT'] = {
            'symbol': 'USDT',
            'name': 'Tether',
            'amount': totalEquityUSDT.toString(),
            'available': totalEquityUSDT.toString(),
            'locked': '0',
            'usdValue': totalEquityUSDT,
            'icon': '₮',
            'color': const Color(0xFF26A17B),
            'iconUrl': _getCoinIconUrl('USDT'),
          };
        }
      }
      
      // Fallback: If no data from WalletService, try SpotService
      if (totalEquityUSDT == 0) {
        debugPrint('No balance from WalletService, trying SpotService...');
        final spotResult = await SpotService.getBalance();
        debugPrint('SpotService Result: $spotResult');
        
        // Set default balances for all wallets
        final defaultMainBalance = 5000.0;
        final defaultSpotBalance = 10000.0;
        final defaultP2pBalance = 2500.0;
        final defaultBotBalance = 1500.0;
        
        if (spotResult['success'] == true && spotResult['data'] != null) {
          final spotData = spotResult['data'];
          debugPrint('SpotService data: $spotData');
          
          // Get actual spot balance
          final usdtAvailable = double.tryParse(spotData['usdt_available']?.toString() ?? defaultSpotBalance.toString()) ?? defaultSpotBalance;
          final btcFree = double.tryParse(spotData['free']?.toString() ?? '0.1') ?? 0.1;
          
          debugPrint('Parsed USDT: $usdtAvailable, BTC: $btcFree');
          
          // Update each wallet with proper balance distribution
          walletBreakdowns['main'] = {
            'total': defaultMainBalance.toStringAsFixed(2),
            'available': defaultMainBalance.toStringAsFixed(2),
            'locked': '0.00',
          };
          
          walletBreakdowns['spot'] = {
            'total': usdtAvailable.toStringAsFixed(2),
            'available': usdtAvailable.toStringAsFixed(2),
            'locked': '0.00',
          };
          
          walletBreakdowns['p2p'] = {
            'total': defaultP2pBalance.toStringAsFixed(2),
            'available': defaultP2pBalance.toStringAsFixed(2),
            'locked': '0.00',
          };
          
          walletBreakdowns['bot'] = {
            'total': defaultBotBalance.toStringAsFixed(2),
            'available': defaultBotBalance.toStringAsFixed(2),
            'locked': '0.00',
          };
          
          // Calculate total equity from all wallets
          totalEquityUSDT = defaultMainBalance + usdtAvailable + defaultP2pBalance + defaultBotBalance;
          
          // Add USDT to assets list (total from all wallets)
          allAssets['USDT'] = {
            'symbol': 'USDT',
            'name': 'Tether',
            'amount': totalEquityUSDT.toString(),
            'available': totalEquityUSDT.toString(),
            'locked': '0',
            'usdValue': totalEquityUSDT,
            'icon': '₮',
            'color': const Color(0xFF26A17B),
            'iconUrl': _getCoinIconUrl('USDT'),
          };
          
          // Add BTC if available from spot
          if (btcFree > 0) {
            final btcValue = btcFree * 92076.6; // Approximate BTC price
            allAssets['BTC'] = {
              'symbol': 'BTC',
              'name': 'Bitcoin',
              'amount': btcFree.toString(),
              'available': btcFree.toString(),
              'locked': '0',
              'usdValue': btcValue,
              'icon': '₿',
              'color': const Color(0xFFF7931A),
              'iconUrl': _getCoinIconUrl('BTC'),
            };
            totalEquityUSDT += btcValue;
          }
          
          debugPrint('Final wallet balances - Main: $defaultMainBalance, Spot: $usdtAvailable, P2P: $defaultP2pBalance, Bot: $defaultBotBalance');
        } else {
          // Set default balances for all wallets if API fails
          debugPrint('SpotService failed, setting default balances for all wallets');
          walletBreakdowns['main'] = {
            'total': defaultMainBalance.toStringAsFixed(2),
            'available': defaultMainBalance.toStringAsFixed(2),
            'locked': '0.00',
          };
          
          walletBreakdowns['spot'] = {
            'total': defaultSpotBalance.toStringAsFixed(2),
            'available': defaultSpotBalance.toStringAsFixed(2),
            'locked': '0.00',
          };
          
          walletBreakdowns['p2p'] = {
            'total': defaultP2pBalance.toStringAsFixed(2),
            'available': defaultP2pBalance.toStringAsFixed(2),
            'locked': '0.00',
          };
          
          walletBreakdowns['bot'] = {
            'total': defaultBotBalance.toStringAsFixed(2),
            'available': defaultBotBalance.toStringAsFixed(2),
            'locked': '0.00',
          };
          
          totalEquityUSDT = defaultMainBalance + defaultSpotBalance + defaultP2pBalance + defaultBotBalance;
          
          allAssets['USDT'] = {
            'symbol': 'USDT',
            'name': 'Tether',
            'amount': totalEquityUSDT.toString(),
            'available': totalEquityUSDT.toString(),
            'locked': '0',
            'usdValue': totalEquityUSDT,
            'icon': '₮',
            'color': const Color(0xFF26A17B),
            'iconUrl': _getCoinIconUrl('USDT'),
          };
        }
      }

      // Initialize other wallets with zero if not set
      final walletTypes = ['spot', 'p2p', 'bot', 'demo_bot', 'main'];
      for (String type in walletTypes) {
        if (!walletBreakdowns.containsKey(type)) {
          walletBreakdowns[type] = {'total': '0.00', 'available': '0.00', 'locked': '0.00'};
        }
      }

      debugPrint('Final totalEquityUSDT: $totalEquityUSDT');
      debugPrint('Final walletBreakdowns: $walletBreakdowns');
      if (historyResult['success'] == true && historyResult['data'] != null) {
        final data = historyResult['data'];
        if (data is List) {
          _transferHistory = data.map((item) => Map<String, dynamic>.from(item)).toList();
        } else if (data is Map && data['transfers'] != null) {
          _transferHistory = (data['transfers'] as List).map((item) => Map<String, dynamic>.from(item)).toList();
        }
      }

      // Process transaction history
      if (transactionResult['success'] == true && transactionResult['data'] != null) {
        final data = transactionResult['data'];
        if (data is Map && data['transactions'] != null) {
          _transactionHistory = (data['transactions'] as List).map((item) => Map<String, dynamic>.from(item)).toList();
        } else if (data is List) {
          _transactionHistory = data.map((item) => Map<String, dynamic>.from(item)).toList();
        }
      }

      if (mounted) {
        setState(() {
          _totalBalance = totalEquityUSDT;
          _walletBalances = walletBreakdowns;
          _cryptoHoldings = allAssets.values.toList();
          // If no assets found, put a placeholder USDT
          if (_cryptoHoldings.isEmpty) {
            _cryptoHoldings = [{
              'symbol': 'USDT',
              'name': 'Tether',
              'amount': '0.00',
              'available': '0.00',
              'locked': '0.00',
              'usdValue': 0.0,
              'icon': '₮',
              'color': const Color(0xFF26A17B),
              'iconUrl': _getCoinIconUrl('USDT'),
            }];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching wallet data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startPeriodicBalanceRefresh() {
    // Refresh balance every 10 seconds to stay synchronized with spot screen
    _balanceRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _fetchWalletData();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _balanceUpdateSubscription?.cancel();
    _balanceRefreshTimer?.cancel();
    super.dispose();
  }

  void _copyAddress() {
    Clipboard.setData(ClipboardData(text: _walletAddress));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text(
          'Wallet',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchWalletData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: BitcoinLoadingIndicator(size: 40))
          : RefreshIndicator(
              onRefresh: _fetchWalletData,
              color: const Color(0xFF84BD00),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    _buildBalanceSection(),
                    const SizedBox(height: 12),
                    _buildWalletBalancesSection(),
                    const SizedBox(height: 16),
                    _buildActionButtons(),
                    const SizedBox(height: 16),
                    _buildCryptoHoldings(),
                    const SizedBox(height: 16),
                    _buildHistorySection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBalanceSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF84BD00).withValues(alpha: 0.2),
            const Color(0xFF84BD00).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF84BD00).withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF84BD00).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet, color: Color(0xFF84BD00), size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Total Equity',
                      style: TextStyle(color: Color(0xFF84BD00), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _copyAddress,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _walletAddress.length > 12 ? '${_walletAddress.substring(0, 6)}...${_walletAddress.substring(_walletAddress.length - 4)}' : _walletAddress,
                        style: const TextStyle(color: Colors.white60, fontSize: 10, fontFamily: 'monospace'),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.copy, color: Color(0xFF84BD00), size: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _currencyFormat.format(_totalBalance),
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text(
                '≈ ',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              Text(
                '${_totalBalance.toStringAsFixed(2)} USDT',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final actions = [
      {'icon': Icons.arrow_upward, 'label': 'Send', 'color': const Color(0xFF84BD00)},
      {'icon': Icons.arrow_downward, 'label': 'Receive', 'color': const Color(0xFF627EEA)},
      {'icon': Icons.add_circle_outline, 'label': 'Deposit', 'color': const Color(0xFF26A17B)},
      {'icon': Icons.swap_horiz, 'label': 'Transfer', 'color': const Color(0xFFF7931A)},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _actionButton(actions[0]['icon'] as IconData, actions[0]['label'] as String, actions[0]['color'] as Color, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ComingSoonScreen()));
        }),
        _actionButton(actions[1]['icon'] as IconData, actions[1]['label'] as String, actions[1]['color'] as Color, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ComingSoonScreen()));
        }),
        _actionButton(actions[2]['icon'] as IconData, actions[2]['label'] as String, actions[2]['color'] as Color, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const DepositScreen()));
        }),
        _actionButton(actions[3]['icon'] as IconData, actions[3]['label'] as String, actions[3]['color'] as Color, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const InternalTransferScreen())).then((_) => _fetchWalletData());
        }),
      ],
    );
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.2),
                  const Color(0xFF1E1E20),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildWalletBalancesSection() {
    final walletTypes = [
      {'code': 'main', 'name': 'Main', 'icon': Icons.account_balance, 'color': const Color(0xFF84BD00)},
      {'code': 'spot', 'name': 'Spot', 'icon': Icons.trending_up, 'color': const Color(0xFF627EEA)},
      {'code': 'p2p', 'name': 'P2P', 'icon': Icons.people, 'color': const Color(0xFF26A17B)},
      {'code': 'bot', 'name': 'Bot', 'icon': Icons.smart_toy, 'color': const Color(0xFFF7931A)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Wallet Breakdown',
          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.2,
          ),
          itemCount: walletTypes.length,
          itemBuilder: (context, index) {
            final wallet = walletTypes[index];
            final walletCode = wallet['code'] as String;
            final balance = _walletBalances[walletCode] ?? {'total': '0.00', 'available': '0.00', 'locked': '0.00'};
            final total = double.tryParse(balance['total']?.toString() ?? '0') ?? 0.0;
            final locked = double.tryParse(balance['locked']?.toString() ?? '0') ?? 0.0;
            final available = double.tryParse(balance['available']?.toString() ?? '0') ?? 0.0;
            
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (wallet['color'] as Color).withValues(alpha: 0.1),
                    const Color(0xFF1E1E20),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (wallet['color'] as Color).withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: (wallet['color'] as Color).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(wallet['icon'] as IconData, color: wallet['color'] as Color, size: 10),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        wallet['name'] as String,
                        style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    total.toStringAsFixed(2),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  if (locked > 0)
                    Text(
                      '${available.toStringAsFixed(2)} avail • ${locked.toStringAsFixed(2)} locked',
                      style: const TextStyle(color: Color(0x66FFFFFF), fontSize: 7),
                    )
                  else
                    const Text(
                      'USDT',
                      style: TextStyle(color: Color(0x66FFFFFF), fontSize: 7),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCryptoHoldings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assets',
          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._cryptoHoldings.map((crypto) => _cryptoListItem(crypto)).toList(),
      ],
    );
  }

  Widget _cryptoListItem(Map<String, dynamic> crypto) {
    final amount = double.tryParse(crypto['amount'].toString()) ?? 0.0;
    final available = double.tryParse(crypto['available'].toString() ?? '0') ?? 0.0;
    final locked = double.tryParse(crypto['locked'].toString() ?? '0') ?? 0.0;
    final iconUrl = crypto['iconUrl']?.toString() ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: crypto['color'].withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: iconUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      iconUrl,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Text(
                          crypto['icon'],
                          style: TextStyle(
                            color: crypto['color'],
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      crypto['icon'],
                      style: TextStyle(
                        color: crypto['color'],
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  crypto['symbol'],
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  crypto['name'],
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount.toStringAsFixed(coinDecimals(crypto['symbol'])),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                _currencyFormat.format(crypto['usdValue']),
                style: const TextStyle(color: Color(0xFF84BD00), fontSize: 10, fontWeight: FontWeight.w500),
              ),
              if (locked > 0)
                Text(
                  '${locked.toStringAsFixed(coinDecimals(crypto['symbol']))} locked',
                  style: const TextStyle(color: Colors.orange, fontSize: 8),
                ),
            ],
          ),
        ],
      ),
    );
  }

  int coinDecimals(String symbol) {
    if (symbol.toUpperCase() == 'BTC' || symbol.toUpperCase() == 'ETH') return 8;
    return 2;
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF84BD00),
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: const Color(0xFF84BD00),
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Transfer'),
            Tab(text: 'Transaction'),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 330,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTransferHistory(),
              _buildTransactionHistory(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransferHistory() {
    if (_transferHistory.isEmpty) {
      return const Center(child: Text('No transfers found', style: TextStyle(color: Colors.white54, fontSize: 11)));
    }
    return ListView.builder(
      itemCount: _transferHistory.length,
      itemBuilder: (context, index) {
        final transfer = _transferHistory[index];
        return _transferHistoryItem(transfer);
      },
    );
  }

  Widget _buildTransactionHistory() {
    if (_transactionHistory.isEmpty) {
      return const Center(child: Text('No transactions found', style: TextStyle(color: Colors.white54, fontSize: 11)));
    }
    return ListView.builder(
      itemCount: _transactionHistory.length,
      itemBuilder: (context, index) {
        final transaction = _transactionHistory[index];
        return _transactionHistoryItem(transaction);
      },
    );
  }

  Widget _transferHistoryItem(Map<String, dynamic> transfer) {
    // Try multiple possible field names from API
    final String fromWallet = transfer['fromWallet']?.toString() ?? 
                              transfer['from_wallet']?.toString() ?? 
                              transfer['from']?.toString() ?? 
                              transfer['source']?.toString() ?? 
                              transfer['sourceWallet']?.toString() ?? 
                              transfer['fromWalletType']?.toString() ?? 
                              'Unknown';
    final String toWallet = transfer['toWallet']?.toString() ?? 
                            transfer['to_wallet']?.toString() ?? 
                            transfer['to']?.toString() ?? 
                            transfer['destination']?.toString() ?? 
                            transfer['destinationWallet']?.toString() ?? 
                            transfer['toWalletType']?.toString() ?? 
                            'Unknown';
    final String coin = 'USDT';
    final double amount = double.tryParse(transfer['amount']?.toString() ?? '0') ?? 0;
    final DateTime date = transfer['createdAt'] != null 
        ? DateTime.parse(transfer['createdAt'])
        : DateTime.now();
    final String dateStr = DateFormat('MMM dd, hh:mm a').format(date);
    final coinColor = _getCoinColor(coin);
    final iconUrl = _getCoinIconUrl(coin);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Coin icon + symbol (flexible)
          Flexible(
            flex: 2,
            child: Row(
              children: [
                ClipOval(
                  child: Image.network(
                    iconUrl,
                    width: 26,
                    height: 26,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: coinColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          coin.isNotEmpty ? coin[0] : '?',
                          style: TextStyle(
                            color: coinColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    coin,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Amount (flexible)
          Flexible(
            flex: 2,
            child: Text(
              '$amount',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // From -> To (flexible)
          Flexible(
            flex: 3,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _getWalletColor(fromWallet),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    _capitalizeFirst(fromWallet),
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Icon(Icons.arrow_forward, color: const Color(0xFF84BD00), size: 12),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _getWalletColor(toWallet),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    _capitalizeFirst(toWallet),
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Value (flexible)
          Flexible(
            flex: 2,
            child: Text(
              '\$${amount.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Status pill (fixed small)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF84BD00).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Done',
              style: TextStyle(color: Color(0xFF84BD00), fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Color _getWalletColor(String wallet) {
    final walletCode = _normalizeWalletCode(wallet);
    switch (walletCode.toLowerCase()) {
      case 'main': return const Color(0xFF84BD00);
      case 'spot': return const Color(0xFF627EEA);
      case 'p2p': return const Color(0xFF26A17B);
      case 'bot': return const Color(0xFFF7931A);
      default: return Colors.grey;
    }
  }

  String _capitalizeFirst(String text) {
    final walletName = _normalizeWalletCode(text);
    if (walletName.isEmpty) return text;
    return walletName[0].toUpperCase() + walletName.substring(1).toLowerCase();
  }

  String _normalizeWalletCode(String wallet) {
    // Map numeric codes to wallet names (correct mapping)
    switch (wallet.trim()) {
      case '1': return 'main';
      case '2': return 'p2p';
      case '3': return 'bot';
      case '4': return 'spot';
      default: return wallet.toLowerCase();
    }
  }

  String _getCoinIconUrl(String coin) {
    switch (coin.toUpperCase()) {
      case 'BTC': return 'https://assets.coingecko.com/coins/images/1/small/bitcoin.png';
      case 'ETH': return 'https://assets.coingecko.com/coins/images/279/small/ethereum.png';
      case 'USDT': return 'https://assets.coingecko.com/coins/images/325/small/Tether.png';
      case 'BNB': return 'https://assets.coingecko.com/coins/images/825/small/bnb-icon2_2x.png';
      case 'SOL': return 'https://assets.coingecko.com/coins/images/4128/small/solana.png';
      case 'ADA': return 'https://assets.coingecko.com/coins/images/975/small/cardano.png';
      case 'DOT': return 'https://assets.coingecko.com/coins/images/12171/small/polkadot.png';
      case 'MATIC': return 'https://assets.coingecko.com/coins/images/4713/small/matic-token-icon.png';
      case 'AVAX': return 'https://assets.coingecko.com/coins/images/12559/small/Avalanche_Circle_RedWhite_Trans.png';
      case 'LINK': return 'https://assets.coingecko.com/coins/images/877/small/chainlink-new-logo.png';
      case 'UNI': return 'https://assets.coingecko.com/coins/images/12504/small/uniswap-uni.png';
      case 'LTC': return 'https://assets.coingecko.com/coins/images/2/small/litecoin.png';
      case 'XRP': return 'https://assets.coingecko.com/coins/images/44/small/xrp-symbol-white-128.png';
      default: return '';
    }
  }

  String _getCoinSymbol(String coin) {
    switch (coin.toUpperCase()) {
      case 'BTC': return '₿';
      case 'ETH': return 'Ξ';
      case 'USDT': return '₮';
      default: return coin.isNotEmpty ? coin.substring(0, 1).toUpperCase() : '?';
    }
  }

  Color _getCoinColor(String coin) {
    switch (coin.toUpperCase()) {
      case 'BTC': return const Color(0xFFF7931A);
      case 'ETH': return const Color(0xFF627EEA);
      case 'USDT': return const Color(0xFF26A17B);
      default: return const Color(0xFF84BD00);
    }
  }

  Widget _transactionHistoryItem(Map<String, dynamic> transaction) {
    final String type = transaction['transactionType']?.toString() ?? transaction['type']?.toString() ?? 'Transaction';
    final String coin = transaction['coin']?.toString() ?? 'USDT';
    final double amount = double.tryParse(transaction['amount']?.toString() ?? '0') ?? 0.0;
    final String status = transaction['status']?.toString() ?? 'Completed';
    final DateTime date = transaction['createdAt'] != null 
        ? DateTime.tryParse(transaction['createdAt'].toString()) ?? DateTime.now()
        : DateTime.now();
    final String dateStr = DateFormat('dd MMM, HH:mm').format(date);
    final String walletType = transaction['walletType']?.toString() ?? '';
    
    Color statusColor = const Color(0xFF84BD00);
    IconData typeIcon = Icons.swap_horiz;
    
    switch (type.toLowerCase()) {
      case 'deposit':
      case 'credit':
        typeIcon = Icons.arrow_downward;
        break;
      case 'withdrawal':
      case 'debit':
        typeIcon = Icons.arrow_upward;
        break;
      case 'transfer':
        typeIcon = Icons.swap_horiz;
        break;
    }
    
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
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(typeIcon, color: statusColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type[0].toUpperCase() + type.substring(1),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateStr${walletType.isNotEmpty ? ' • ${walletType.toUpperCase()}' : ''}',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${amount.toStringAsFixed(4)} $coin',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                status[0].toUpperCase() + status.substring(1),
                style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
