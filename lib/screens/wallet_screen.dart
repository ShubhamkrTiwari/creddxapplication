import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'coming_soon_screen.dart';
import 'deposit_screen.dart';
import 'wallet_transfer_screen.dart';
import 'wallet_history_screen.dart';
import '../services/wallet_service.dart';
import '../services/spot_service.dart';
import '../services/socket_service.dart';
import '../services/auth_service.dart';
import '../services/unified_wallet_service.dart' as unified;
import '../widgets/bitcoin_loading_indicator.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  StreamSubscription? _walletSubscription;
  StreamSubscription? _coinSubscription;
  StreamSubscription? _socketBalanceSubscription;
  
  bool _isLoading = true;
  String _walletAddress = 'Fetching...';
  
  unified.WalletBalance? _walletBalance;
  List<unified.CoinBalance> _coinBalances = [];
  double _inrBalance = 0.0; // Track INR for rebuilds

  List<Map<String, dynamic>> _transferHistory = [];
  List<Map<String, dynamic>> _transactionHistory = [];
  List<Map<String, dynamic>> _conversionHistory = [];


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    
    _setupStreams();
    _fetchUserData();
    _fetchHistoryData();

    // Initial fetch if not already initialized
    unified.UnifiedWalletService.initialize();
    
    // Force refresh balances after a short delay to ensure they load
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        debugPrint('Wallet Screen: Force refreshing balances...');
        unified.UnifiedWalletService.refreshAllBalances();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _walletSubscription?.cancel();
    _coinSubscription?.cancel();
    _socketBalanceSubscription?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    
    // Refresh history data when switching tabs
    _fetchHistoryData();
  }

  void _setupStreams() {
    _walletSubscription = unified.UnifiedWalletService.walletBalanceStream.listen((balance) {
      if (mounted) {
        debugPrint('Wallet Screen: Balance update received');
        debugPrint('Main USDT: ${unified.UnifiedWalletService.mainUSDTBalance}');
        debugPrint('Main INR: ${unified.UnifiedWalletService.mainINRBalance}');
        debugPrint('P2P Balance: ${balance?.p2pBalance}');
        debugPrint('Spot Balance: ${balance?.spotBalance}');
        debugPrint('Bot Balance: ${balance?.botBalance}');
        setState(() {
          _walletBalance = balance;
          _inrBalance = unified.UnifiedWalletService.totalINRBalance;
          _isLoading = false;
        });
      }
    });

    _coinSubscription = unified.UnifiedWalletService.coinBalanceStream.listen((coins) {
      if (mounted) {
        setState(() {
          _coinBalances = coins;
        });
      }
    });

    // Direct socket listener for wallet summary updates (including bot balance)
    _socketBalanceSubscription = SocketService.balanceStream.listen((data) {
      if (mounted && (data['type'] == 'wallet_summary_update' || data['type'] == 'wallet_summary')) {
        debugPrint('Wallet Screen: Wallet summary update received');
        unified.UnifiedWalletService.refreshAllBalances();
      }
    });

    // Initial state
    _walletBalance = unified.UnifiedWalletService.walletBalance;
    _coinBalances = unified.UnifiedWalletService.coinBalance;
    _inrBalance = unified.UnifiedWalletService.totalINRBalance;
    if (_walletBalance != null) {
      _isLoading = false;
    }
  }

  Future<void> _fetchUserData() async {
    final userData = await AuthService.getUserData();
    if (userData != null && mounted) {
      setState(() {
        _walletAddress = userData['walletAddress'] ?? userData['address'] ?? userData['_id'] ?? 'No Address';
      });
    }
  }

  Future<void> _fetchHistoryData() async {
    try {
      // Fetch history from WalletService
      final historyResult = await WalletService.getWalletTransferHistory();
      final transactionResult = await WalletService.getCompleteTransactionHistory(limit: 20);
      final conversionResult = await WalletService.getConversionHistory(limit: 20);

      if (mounted) {
        setState(() {
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

          // Process conversion history
          if (conversionResult['success'] == true && conversionResult['data'] != null) {
            final data = conversionResult['data'];
            List<Map<String, dynamic>> conversions = [];
            if (data is Map && data['conversions'] != null) {
              conversions = (data['conversions'] as List).map((item) {
                final conversion = Map<String, dynamic>.from(item);
                conversion['transactionType'] = 'conversion';
                conversion['isConversion'] = true;
                return conversion;
              }).toList();
            } else if (data is List) {
              conversions = data.map((item) {
                final conversion = Map<String, dynamic>.from(item);
                conversion['transactionType'] = 'conversion';
                conversion['isConversion'] = true;
                return conversion;
              }).toList();
            }
            _conversionHistory = conversions;
            _transactionHistory = [..._transactionHistory, ..._conversionHistory];
            _transactionHistory.sort((a, b) {
              final aDate = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime.now();
              final bDate = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime.now();
              return bDate.compareTo(aDate);
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching history data: $e');
    }
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      unified.UnifiedWalletService.refreshAllBalances(),
      _fetchHistoryData(),
    ]);
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
            onPressed: _onRefresh,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: BitcoinLoadingIndicator(size: 40))
          : RefreshIndicator(
              onRefresh: _onRefresh,
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
                    _buildCoinBalancesSection(),
                    const SizedBox(height: 16),
                    _buildActionButtons(),
                    const SizedBox(height: 16),
                    _buildHistorySection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBalanceSection() {
    final totalEquity = _walletBalance?.totalEquityUSDT ?? 0.0;

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
                      'Total Balance',
                      style: TextStyle(color: Color(0xFF84BD00), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _currencyFormat.format(totalEquity),
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text(
            'INR ₹${_inrBalance.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinBalancesSection() {
    // Filter coins with non-zero balance and sort by total value (highest first)
    final nonZeroCoins = _coinBalances
        .where((coin) => coin.total > 0)
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    if (nonZeroCoins.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Assets',
          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: nonZeroCoins.length,
          itemBuilder: (context, index) {
            final coin = nonZeroCoins[index];
            return _buildCoinItem(coin);
          },
        ),
      ],
    );
  }

  Widget _buildCoinItem(unified.CoinBalance coin) {
    final coinColor = _getCoinColor(coin.asset);
    final iconUrl = _getCoinIconUrl(coin.asset);
    final coinName = _getCoinFullName(coin.asset);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: coinColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: iconUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      iconUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Text(
                          coin.asset.isNotEmpty ? coin.asset[0] : '?',
                          style: TextStyle(
                            color: coinColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      coin.asset.isNotEmpty ? coin.asset[0] : '?',
                      style: TextStyle(
                        color: coinColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coin.asset,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  coinName,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                coin.total.toStringAsFixed(coin.asset == 'BTC' || coin.asset == 'ETH' ? 6 : 2),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              if (coin.locked > 0)
                Text(
                  '${coin.free.toStringAsFixed(2)} avail • ${coin.locked.toStringAsFixed(2)} locked',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 9,
                  ),
                )
              else
                Text(
                  'Available: ${coin.free.toStringAsFixed(coin.asset == 'BTC' || coin.asset == 'ETH' ? 6 : 2)}',
                  style: const TextStyle(
                    color: Color(0xFF84BD00),
                    fontSize: 9,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final actions = [
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
          Navigator.push(context, MaterialPageRoute(builder: (context) => const DepositScreen()));
        }),
        _actionButton(actions[2]['icon'] as IconData, actions[2]['label'] as String, actions[2]['color'] as Color, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const InternalTransferScreen()));
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

            double total = 0.0;
            double available = 0.0;
            double locked = 0.0;

            if (_walletBalance != null) {
              switch (walletCode) {
                case 'main':
                  // Show USDT balance for main wallet
                  total = available = unified.UnifiedWalletService.mainUSDTBalance;
                  break;
                case 'spot':
                  total = available = _walletBalance!.spotBalance;
                  // Look for locked in coin balances
                  final usdtCoin = _coinBalances.where((c) => c.asset == 'USDT').firstOrNull;
                  if (usdtCoin != null) {
                    locked = usdtCoin.locked;
                    total = usdtCoin.total;
                  }
                  break;
                case 'p2p':
                  total = available = _walletBalance!.p2pBalance;
                  break;
                case 'bot':
                  total = available = _walletBalance!.botBalance;
                  break;
              }
            }

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
                    Expanded(
                      child: Text(
                        '${available.toStringAsFixed(2)} avail • ${locked.toStringAsFixed(2)} locked',
                        style: const TextStyle(color: Color(0x66FFFFFF), fontSize: 7),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    )
                  else
                    Expanded(
                      child: Text(
                        walletCode == 'main' && unified.UnifiedWalletService.mainINRBalance > 0
                            ? 'USDT • ₹${unified.UnifiedWalletService.mainINRBalance.toStringAsFixed(2)}'
                            : 'USDT',
                        style: const TextStyle(color: Color(0x66FFFFFF), fontSize: 7),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
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
    final String dateStr = DateFormat('MMM dd, hh:mm a').format(localDate);
    final coinColor = _getCoinColor(coin);
    final iconUrl = _getCoinIconUrl(coin);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Title + Amount
          Row(
            children: [
              ClipOval(
                child: Image.network(
                  iconUrl,
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: coinColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        coin.isNotEmpty ? coin[0] : '?',
                        style: TextStyle(
                          color: coinColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Wallet Transfer',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(color: Colors.white54, fontSize: 9),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$amount USDT',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF84BD00).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(color: Color(0xFF84BD00), fontSize: 8, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          // From -> To Details
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                // FROM
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _getWalletColor(fromWallet),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_upward, color: Colors.red, size: 8),
                          const SizedBox(width: 2),
                          Text(
                            'FROM: ${_capitalizeFirst(fromWallet)}',
                            style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Icon(Icons.arrow_downward, color: Colors.white38, size: 12),
                const SizedBox(height: 4),
                // TO
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _getWalletColor(toWallet),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_downward, color: Colors.green, size: 8),
                          const SizedBox(width: 2),
                          Text(
                            'TO: ${_capitalizeFirst(toWallet)}',
                            style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
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

  String _getCoinFullName(String coin) {
    switch (coin.toUpperCase()) {
      case 'BTC': return 'Bitcoin';
      case 'ETH': return 'Ethereum';
      case 'USDT': return 'Tether';
      case 'BNB': return 'Binance Coin';
      case 'SOL': return 'Solana';
      case 'ADA': return 'Cardano';
      case 'DOT': return 'Polkadot';
      case 'MATIC': return 'Polygon';
      case 'AVAX': return 'Avalanche';
      case 'LINK': return 'Chainlink';
      case 'UNI': return 'Uniswap';
      case 'LTC': return 'Litecoin';
      case 'XRP': return 'Ripple';
      case 'INR': return 'Indian Rupee';
      default: return coin;
    }
  }

  Widget _transactionHistoryItem(Map<String, dynamic> transaction) {
    String type = transaction['transactionType']?.toString() ?? transaction['type']?.toString() ?? 'Transaction';
    
    // Handle conversion type - convert numeric type to proper text
    if (type == '2' || type == '1' || (type.toLowerCase() == 'conversion' && (transaction['type']?.toString() == '2' || transaction['type']?.toString() == '1'))) {
      type = 'Conversion';
    }
    
    // Also handle any other numeric types that might appear
    if (type == '2' || type == '1') {
      type = 'Conversion';
    }
    final String coin = transaction['coin']?.toString() ?? 'USDT';
    final double amount = double.tryParse(transaction['amount']?.toString() ?? '0') ?? 0.0;
    String status = transaction['status']?.toString() ?? 'Completed';
    
    // Handle numeric status values - convert to proper text
    if (status == '2' || status == '1') {
      status = 'Completed';
    } else if (status == '0') {
      status = 'Pending';
    }
    // Try multiple possible time field names from API
    final String? timeStr = transaction['createdAt']?.toString() ??
                             transaction['created_at']?.toString() ??
                             transaction['timestamp']?.toString() ??
                             transaction['date']?.toString() ??
                             transaction['time']?.toString();
    final DateTime date = timeStr != null
        ? DateTime.tryParse(timeStr) ?? DateTime.now()
        : DateTime.now();
    // Convert to local time if the parsed time is UTC
    final DateTime localDate = date.isUtc ? date.toLocal() : date;
    final String dateStr = DateFormat('dd MMM, hh:mm a').format(localDate);
    final String walletType = transaction['walletType']?.toString() ?? '';
    final bool isConversion = transaction['isConversion'] == true || type.toLowerCase() == 'conversion';

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
      case 'conversion':
        typeIcon = Icons.currency_exchange;
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

    // Extract bank/UPI details for INR withdrawals
    final bankDetails = transaction['bankDetails'] ?? transaction['withdrawDetails'] ?? transaction['bank_details'];
    final upiId = transaction['upiId'] ?? transaction['upi_id'];
    final withdrawType = transaction['withdrawType'] ?? transaction['withdraw_type'];
    final category = transaction['category']?.toString() ?? '';
    final bool isINRWithdrawal = category == 'inr' || type == 'withdrawal' && bankDetails != null;

    // Handle conversion transaction display
    if (isConversion) {
      // API uses type field: 1 = INR to USDT, 2 = USDT to INR
      final int? conversionType = int.tryParse(transaction['type']?.toString() ?? '');
      String fromCurrency = 'INR';
      String toCurrency = 'USDT';
      
      // Determine conversion direction from API type field
      if (conversionType != null) {
        if (conversionType == 2) {
          // USDT to INR
          fromCurrency = 'USDT';
          toCurrency = 'INR';
        } else if (conversionType == 1) {
          // INR to USDT
          fromCurrency = 'INR';
          toCurrency = 'USDT';
        }
      } else {
        // Fallback: try to read fromCurrency/toCurrency fields if type is not available
        fromCurrency = transaction['fromCurrency']?.toString() ?? transaction['from_currency']?.toString() ?? 'INR';
        toCurrency = transaction['toCurrency']?.toString() ?? transaction['to_currency']?.toString() ?? 'USDT';
      }
      
      final fromAmount = double.tryParse(transaction['fromAmount']?.toString() ?? transaction['from_amount']?.toString() ?? '0') ?? 0.0;
      final toAmount = double.tryParse(transaction['toAmount']?.toString() ?? transaction['to_amount']?.toString() ?? transaction['converted_amount']?.toString() ?? '0') ?? 0.0;
      final rate = double.tryParse(transaction['rate']?.toString() ?? transaction['conversion_rate']?.toString() ?? '0') ?? 0.0;

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
                color: const Color(0xFF26A17B).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.currency_exchange, color: Color(0xFF26A17B), size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$fromCurrency → $toCurrency',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                  if (rate > 0)
                    Text(
                      'Rate: 1 $fromCurrency = ${rate.toStringAsFixed(4)} $toCurrency',
                      style: const TextStyle(color: Colors.white38, fontSize: 9),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${fromAmount.toStringAsFixed(2)} $fromCurrency',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, decoration: TextDecoration.lineThrough),
                ),
                Text(
                  '${toAmount.toStringAsFixed(4)} $toCurrency',
                  style: const TextStyle(color: Color(0xFF26A17B), fontWeight: FontWeight.bold, fontSize: 12),
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

    // Handle INR withdrawal with bank/UPI details
    if (isINRWithdrawal || bankDetails != null || upiId != null) {
      final bankName = bankDetails?['bankName']?.toString() ?? bankDetails?['bank_name']?.toString() ?? '';
      final accountHolder = bankDetails?['accountHolderName']?.toString() ?? bankDetails?['account_holder_name']?.toString() ?? '';
      final accountNumber = bankDetails?['accountNumber']?.toString() ?? bankDetails?['account_number']?.toString() ?? '';
      final ifscCode = bankDetails?['ifscCode']?.toString() ?? bankDetails?['ifsc_code']?.toString() ?? '';
      final isUPI = withdrawType == 2 || upiId != null;

      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        '${type[0].toUpperCase() + type.substring(1)} ${isUPI ? 'UPI' : 'Bank'}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateStr,
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${amount.toStringAsFixed(2)}',
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
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (accountHolder.isNotEmpty)
                    Text(
                      'Account Holder: $accountHolder',
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  if (isUPI && upiId != null) ...[
                    Text(
                      'UPI ID: $upiId',
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ] else if (bankName.isNotEmpty) ...[
                    Text(
                      'Bank: $bankName',
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                    if (accountNumber.isNotEmpty)
                      Text(
                        'Account: XXXX${accountNumber.substring(accountNumber.length > 4 ? accountNumber.length - 4 : 0)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    if (ifscCode.isNotEmpty)
                      Text(
                        'IFSC: $ifscCode',
                        style: const TextStyle(color: Colors.white54, fontSize: 9),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
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
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '$dateStr${walletType.isNotEmpty ? ' • ${walletType.toUpperCase()}' : ''}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${amount.abs().toStringAsFixed(4)} ${coin.toUpperCase()}',
                style: TextStyle(
                  color: amount >= 0 ? Colors.green : Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
