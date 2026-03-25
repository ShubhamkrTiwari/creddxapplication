import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'notification_screen.dart';
import 'send_screen.dart';
import 'withdraw_screen.dart';
import 'receive_screen.dart';
import 'market_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedTab = 'Overview';
  final List<String> _tabs = ['Overview', 'Transactions', 'Analytics', 'Settings'];
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final NumberFormat _compactFormat = NumberFormat.compactCurrency(symbol: '', decimalDigits: 1);
  
  List<Map<String, dynamic>> _walletData = [];
  Map<String, double> _previousPrices = {};
  bool _isLoading = true;
  Timer? _priceTimer;

  @override
  void initState() {
    super.initState();
    _fetchWalletData();
    _startPriceUpdates();
  }

  Future<void> _fetchWalletData() async {
    setState(() => _isLoading = true);
    await _fetchPrices();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchPrices() async {
    try {
      final symbols = ['BTCUSDT', 'ETHUSDT', 'SOLUSDT', 'BNBUSDT', 'ADAUSDT', 'XRPUSDT', 'DOTUSDT', 'AVAXUSDT'];
      final futures = symbols.map((symbol) => _fetchPrice(symbol)).toList();
      final results = await Future.wait(futures);
      
      if (mounted) {
        setState(() {
          _walletData = results.map((result) {
            final symbol = result['symbol'] as String;
            final currentPrice = result['price'] as double;
            final previousPrice = _previousPrices[symbol] ?? currentPrice;
            
            // Add real-time direction and percentage change
            result['realTimeDirection'] = currentPrice > previousPrice ? 1 : (currentPrice < previousPrice ? -1 : 0);
            final priceDifference = currentPrice - previousPrice;
            final realTimeChangePercent = previousPrice > 0 ? (priceDifference / previousPrice) * 100 : 0.0;
            result['realTimeChangePercent'] = realTimeChangePercent;
            
            // Update previous price
            _previousPrices[symbol] = currentPrice;
            
            return result;
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching prices: $e');
    }
  }

  Future<Map<String, dynamic>> _fetchPrice(String symbol) async {
    try {
      final priceResponse = await http.get(Uri.parse('https://api.binance.com/api/v3/ticker/price?symbol=$symbol'));
      final statsResponse = await http.get(Uri.parse('https://api.binance.com/api/v3/ticker/24hr?symbol=$symbol'));
      
      if (priceResponse.statusCode == 200 && statsResponse.statusCode == 200) {
        final priceData = json.decode(priceResponse.body);
        final statsData = json.decode(statsResponse.body);
        
        return {
          'symbol': symbol,
          'price': double.parse(priceData['price'] ?? '0.0'),
          'change': double.parse(statsData['priceChangePercent'] ?? '0.0'),
          'volume': double.parse(statsData['volume'] ?? '0.0'),
          'high': double.parse(statsData['highPrice'] ?? '0.0'),
        };
      }
    } catch (e) {
      debugPrint('Error fetching $symbol: $e');
    }
    return {
      'symbol': symbol,
      'price': 0.0,
      'change': 0.0,
      'volume': 0.0,
      'high': 0.0,
    };
  }

  void _startPriceUpdates() {
    _priceTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) _fetchPrices();
    });
  }

  @override
  void dispose() {
    _priceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            _buildWalletHeader(),
            _buildBalanceCards(),
            _buildQuickActions(),
            _buildTabSection(),
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF84BD00).withOpacity(0.1),
            const Color(0xFF84BD00).withOpacity(0.05),
          ],
        ),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF84BD00),
                      const Color(0xFF6BA628),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'My Wallet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Ali Husni',
                    style: TextStyle(
                      color: const Color(0xFF6C7278),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.search, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.notifications_none, color: Colors.white, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCards() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)));
    }

    final totalBalance = _walletData.fold(0.0, (sum, crypto) => sum + (crypto['price'] as double));
    final todayChange = 1234.56; // Mock data
    final todayPercent = 2.34; // Mock data
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF84BD00).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Balance',
                            style: TextStyle(color: Color(0xFF6C7278), fontSize: 14),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: todayChange >= 0 ? const Color(0xFF84BD00).withOpacity(0.2) : Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              todayChange >= 0 ? '↑$todayPercent%' : '↓${todayPercent.abs()}%',
                              style: TextStyle(
                                color: todayChange >= 0 ? const Color(0xFF84BD00) : Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _currencyFormat.format(totalBalance),
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '≈ \$45,678.90 USD',
                        style: const TextStyle(color: Color(0xFF6C7278), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF6BA628).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Today\'s Profit/Loss',
                        style: TextStyle(color: Color(0xFF6C7278), fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        todayChange >= 0 ? '+\$${todayChange.toStringAsFixed(2)}' : '-\$${todayChange.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          color: todayChange >= 0 ? const Color(0xFF84BD00) : Colors.red,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total Gain: \$12,345.67',
                        style: const TextStyle(color: Color(0xFF6C7278), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'icon': 'send.png', 'label': 'Send', 'color': Color(0xFF84BD00)},
      {'icon': 'request.png', 'label': 'Receive', 'color': Color(0xFF6BA628)},
      {'icon': 'deposit.png', 'label': 'Deposit', 'color': Color(0xFF84BD00)},
      {'icon': 'withdraw.png', 'label': 'Withdraw', 'color': Colors.red},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: actions.map((action) {
          return Expanded(
            child: GestureDetector(
              onTap: () => _handleActionTap(action['label'] as String),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: action['color'] as Color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/${action['icon']}',
                      width: 24,
                      height: 24,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.help_outline,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      action['label'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: _tabs.map((tab) {
              final isSelected = tab == _selectedTab;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = tab),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected ? const Color(0xFF84BD00) : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      tab,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF6C7278),
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedTab) {
      case 'Overview':
        return _buildOverviewTab();
      case 'Transactions':
        return _buildTransactionsTab();
      case 'Analytics':
        return _buildAnalyticsTab();
      case 'Settings':
        return _buildSettingsTab();
      default:
        return _buildOverviewTab();
    }
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Portfolio Distribution',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E20),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildDistributionItem('Bitcoin', 'BTC', 45.2, const Color(0xFFF7931A)),
                _buildDistributionItem('Ethereum', 'ETH', 30.1, const Color(0xFF627EEA)),
                _buildDistributionItem('Solana', 'SOL', 15.3, const Color(0xFF00FFA3)),
                _buildDistributionItem('Others', 'OTH', 9.4, const Color(0xFF6C7278)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Recent Transactions',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ..._walletData.take(3).map((crypto) => _buildTransactionItem(crypto)).toList(),
        ],
      ),
    );
  }

  Widget _buildDistributionItem(String name, String symbol, double percentage, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  '$symbol% • ${percentage.toStringAsFixed(1)}%',
                  style: const TextStyle(color: Color(0xFF6C7278), fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            _currencyFormat.format(_walletData.where((c) => (c['symbol'] as String).contains(symbol)).fold(0.0, (sum, c) => sum + (c['price'] as double))),
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> crypto) {
    final symbol = (crypto['symbol'] as String).replaceAll('USDT', '');
    final price = crypto['price'] as double;
    final change = crypto['change'] as double;
    final realTimeDirection = crypto['realTimeDirection'] as int? ?? 0;
    final isRealTimePositive = realTimeDirection > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getSymbolColor(symbol).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                symbol[0],
                style: TextStyle(
                  color: _getSymbolColor(symbol),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${symbol} Transaction',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  _currencyFormat.format(price),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isRealTimePositive ? const Color(0xFF84BD00) : (realTimeDirection < 0 ? Colors.red : const Color(0xFF6C7278)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              realTimeDirection > 0 ? '+${(crypto['realTimeChangePercent'] as double? ?? 0.0).toStringAsFixed(2)}%' : 
              realTimeDirection < 0 ? '${(crypto['realTimeChangePercent'] as double? ?? 0.0).toStringAsFixed(2)}%' : 
              '${change.toStringAsFixed(2)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, color: Color(0xFF6C7278), size: 64),
          const SizedBox(height: 16),
          const Text(
            'Transaction History\nComing Soon!',
            style: TextStyle(color: Color(0xFF6C7278), fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics, color: Color(0xFF6C7278), size: 64),
          const SizedBox(height: 16),
          const Text(
            'Advanced Analytics\nComing Soon!',
            style: TextStyle(color: Color(0xFF6C7278), fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings, color: Color(0xFF6C7278), size: 64),
          const SizedBox(height: 16),
          const Text(
            'Wallet Settings\nComing Soon!',
            style: TextStyle(color: Color(0xFF6C7278), fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getSymbolColor(String symbol) {
    if (symbol == 'BTC') return const Color(0xFFF7931A);
    if (symbol == 'ETH') return const Color(0xFF627EEA);
    if (symbol == 'SOL') return const Color(0xFF00FFA3);
    if (symbol == 'BNB') return const Color(0xFFEABD2F);
    if (symbol == 'ADA') return const Color(0xFF0033AD);
    if (symbol == 'XRP') return const Color(0xFF23292F);
    if (symbol == 'DOT') return const Color(0xFFE6007A);
    if (symbol == 'AVAX') return const Color(0xFFE84142);
    return Colors.white;
  }

  void _handleActionTap(String action) {
    switch (action) {
      case 'Send':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const SendScreen()),
        );
        break;
      case 'Receive':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const ReceiveScreen()),
        );
        break;
      case 'Deposit':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const ReceiveScreen()),
        );
        break;
      case 'Withdraw':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const WithdrawScreen()),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$action coming soon!')),
        );
        break;
    }
  }
}
