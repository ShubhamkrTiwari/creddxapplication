import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'market_screen.dart';
import 'send_screen.dart';
import 'receive_screen.dart';
import 'withdraw_screen.dart';
import 'notification_screen.dart';
import 'spot_screen.dart';
import 'chart_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCrypto = 'BTC';
  final List<String> _cryptoOptions = ['BTC', 'ETH', 'SOL', 'BNB'];
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final NumberFormat _cryptoFormat = NumberFormat.currency(symbol: '', decimalDigits: 6);
  
  Map<String, double> _cryptoPrices = {};
  Map<String, double> _cryptoChanges = {};
  bool _isLoading = true;
  Timer? _priceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchInitialData();
    _startPriceUpdates();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    await _fetchCryptoPrices();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchCryptoPrices() async {
    try {
      final symbols = ['BTCUSDT', 'ETHUSDT', 'SOLUSDT', 'BNBUSDT'];
      final futures = symbols.map((symbol) => _fetchPrice(symbol)).toList();
      final results = await Future.wait(futures);
      
      if (mounted) {
        setState(() {
          for (int i = 0; i < symbols.length; i++) {
            final crypto = symbols[i].replaceAll('USDT', '');
            _cryptoPrices[crypto] = results[i]['price'] ?? 0.0;
            _cryptoChanges[crypto] = results[i]['change'] ?? 0.0;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching prices: $e');
    }
  }

  Future<Map<String, double>> _fetchPrice(String symbol) async {
    try {
      final priceResponse = await http.get(Uri.parse('https://api.binance.com/api/v3/ticker/price?symbol=$symbol'));
      final statsResponse = await http.get(Uri.parse('https://api.binance.com/api/v3/ticker/24hr?symbol=$symbol'));
      
      if (priceResponse.statusCode == 200 && statsResponse.statusCode == 200) {
        final priceData = json.decode(priceResponse.body);
        final statsData = json.decode(statsResponse.body);
        
        return {
          'price': double.parse(priceData['price'] ?? '0.0'),
          'change': double.parse(statsData['priceChangePercent'] ?? '0.0'),
        };
      }
    } catch (e) {
      debugPrint('Error fetching $symbol: $e');
    }
    return {'price': 0.0, 'change': 0.0};
  }

  void _startPriceUpdates() {
    _priceTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) _fetchCryptoPrices();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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
            _buildHeader(),
            _buildQuickActions(),
            _buildMarketOverview(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildHomeTab(),
                  const MarketScreen(),
                  const SpotScreen(),
                  const ChartScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome back',
                style: TextStyle(color: Color(0xFF6C7278), fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                'CreddX Wallet',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const NotificationScreen()),
                  );
                },
              ),
              Container(
                width: 35,
                height: 35,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline, color: Colors.white, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF84BD00).withOpacity(0.1),
              const Color(0xFF84BD00).withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF84BD00).withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Total Balance',
              style: TextStyle(color: Color(0xFF6C7278), fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              _currencyFormat.format(_cryptoPrices.values.fold(0.0, (sum, price) => sum + price)),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _quickActionButton('Send', Icons.send, () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const SendScreen()),
                  );
                }),
                _quickActionButton('Receive', Icons.call_received, () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const ReceiveScreen()),
                  );
                }),
                _quickActionButton('Withdraw', Icons.call_made, () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const WithdrawScreen()),
                  );
                }),
                _quickActionButton('More', Icons.more_horiz, () {
                  _showMoreOptions(context);
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActionButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF84BD00), size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Color(0xFF6C7278), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMarketOverview() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Market Overview',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
          else
            Column(
              children: _cryptoOptions.map((crypto) => _cryptoTile(crypto)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _cryptoTile(String crypto) {
    final price = _cryptoPrices[crypto] ?? 0.0;
    final change = _cryptoChanges[crypto] ?? 0.0;
    final isPositive = change >= 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          _buildCryptoLogo(crypto),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  crypto,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  _cryptoFormat.format(price),
                  style: const TextStyle(color: Color(0xFF6C7278), fontSize: 14),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _currencyFormat.format(price),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  Icon(
                    isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isPositive ? const Color(0xFF84BD00) : Colors.red,
                    size: 16,
                  ),
                  Text(
                    '${isPositive ? '+' : ''}${change.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: isPositive ? const Color(0xFF84BD00) : Colors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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

  Widget _buildCryptoLogo(String symbol) {
    Color logoColor = _getSymbolColor(symbol);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            logoColor.withOpacity(0.4),
            logoColor.withOpacity(0.1),
          ],
        ),
      ),
      child: Center(
        child: Text(
          symbol.substring(0, 2),
          style: TextStyle(
            color: logoColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Color _getSymbolColor(String symbol) {
    if (symbol == 'BTC') return const Color(0xFFF7931A);
    if (symbol == 'ETH') return const Color(0xFF627EEA);
    if (symbol == 'SOL') return const Color(0xFF00FFA3);
    if (symbol == 'BNB') return const Color(0xFFEABD2F);
    return Colors.white;
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF84BD00),
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF6C7278),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        tabs: const [
          Tab(text: 'Home'),
          Tab(text: 'Market'),
          Tab(text: 'Spot'),
          Tab(text: 'Charts'),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPortfolioSection(),
          const SizedBox(height: 24),
          _buildRecentTransactions(),
          const SizedBox(height: 24),
          _buildNewsSection(),
        ],
      ),
    );
  }

  Widget _buildPortfolioSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Portfolio Performance',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Today', style: TextStyle(color: Color(0xFF6C7278), fontSize: 14)),
                  SizedBox(height: 4),
                  Text('+\$1,234.56', style: TextStyle(color: Color(0xFF84BD00), fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('This Week', style: TextStyle(color: Color(0xFF6C7278), fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('+\$5,678.90', style: TextStyle(color: const Color(0xFF84BD00), fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Transactions',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              _transactionTile('Sent BTC', '0.0234 BTC', '-\$1,234.56', Icons.call_made, Colors.red),
              _transactionTile('Received ETH', '0.5 ETH', '+\$1,678.90', Icons.call_received, const Color(0xFF84BD00)),
              _transactionTile('Withdraw USDT', '1,000 USDT', '-\$1,000.00', Icons.account_balance, Colors.red),
            ],
          ),
        ),
      ],
    );
  }

  Widget _transactionTile(String title, String amount, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
                Text(amount, style: const TextStyle(color: Color(0xFF6C7278), fontSize: 14)),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Crypto News',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              _newsTile('Bitcoin reaches new monthly high', '2 hours ago'),
              _newsTile('Ethereum upgrade completed successfully', '5 hours ago'),
              _newsTile('Solana announces new partnerships', '1 day ago'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _newsTile(String title, String time) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF84BD00),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
                Text(time, style: const TextStyle(color: Color(0xFF6C7278), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF84BD00),
        unselectedItemColor: const Color(0xFF6C7278),
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 0:
              // Already on home
              break;
            case 1:
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const MarketScreen()),
              );
              break;
            case 2:
              // Spot trading
              break;
            case 3:
              // Profile
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Market'),
          BottomNavigationBarItem(icon: Icon(Icons.candlestick_chart), label: 'Spot'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E20),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('More Options', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _moreOptionItem('Buy', Icons.shopping_cart),
                _moreOptionItem('Sell', Icons.sell),
                _moreOptionItem('Swap', Icons.swap_horiz),
                _moreOptionItem('Stake', Icons.trending_up),
                _moreOptionItem('Cards', Icons.credit_card),
                _moreOptionItem('Settings', Icons.settings),
                _moreOptionItem('Help', Icons.help),
                _moreOptionItem('About', Icons.info),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _moreOptionItem(String label, IconData icon) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        // Handle action
      },
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF84BD00), size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Color(0xFF6C7278), fontSize: 12)),
        ],
      ),
    );
  }
}
