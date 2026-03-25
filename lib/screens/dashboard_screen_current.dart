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
import '../services/wallet_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedTab = 'Portfolio';
  final List<String> _tabs = ['Portfolio', 'Assets', 'History', 'Settings'];
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final NumberFormat _compactFormat = NumberFormat.compactCurrency(symbol: '', decimalDigits: 1);
  
  List<Map<String, dynamic>> _walletData = [];
  Map<String, double> _previousPrices = {};
  bool _isLoading = true;
  Timer? _priceTimer;
  double _totalWalletBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchWalletData();
    _startPriceUpdates();
  }

  Future<void> _fetchWalletData() async {
    setState(() => _isLoading = true);
    
    // Fetch Total Balance from Wallet API
    final totalBalance = await WalletService.getTotalUSDTBalance();
    
    await _fetchPrices();
    
    if (mounted) {
      setState(() {
        _totalWalletBalance = totalBalance;
        _isLoading = false;
      });
    }
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
    _priceTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _fetchPrices();
        // Also refresh wallet balance periodically
        WalletService.getTotalUSDTBalance().then((balance) {
          if (mounted) setState(() => _totalWalletBalance = balance);
        });
      }
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
            _buildHeader(),
            _buildActionGrid(),
            _buildPromoBanner(),
            _buildTabSection(),
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'User Profile',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    'Total Wallet Balance',
                    style: const TextStyle(
                      color: Color(0xFF6C7278),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white, size: 24),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.white, size: 24),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const NotificationScreen()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionGrid() {
    final actions = [
      {'icon': 'send.png', 'label': 'Send'},
      {'icon': 'request.png', 'label': 'Request'},
      {'icon': 'deposit.png', 'label': 'Deposit'},
      {'icon': 'addwallet.png', 'label': 'Add wallet'},
      {'icon': 'withdraw.png', 'label': 'Withdraw'},
      {'icon': 'editwallet.png', 'label': 'Edit Wallet'},
      {'icon': 'more.png', 'label': 'Transfer'},
      {'icon': 'sellcrypto.png', 'label': 'Sell Crypto'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.9,
        ),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final action = actions[index];
          return GestureDetector(
            onTap: () => _handleActionTap(action['label'] as String),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E20),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/${action['icon']}',
                        width: 20,
                        height: 20,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.help_outline,
                          color: Color(0xFF84BD00),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: Text(
                      action['label'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'assets/images/adhome.png',
          width: double.infinity,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF84BD00).withOpacity(0.2),
                    const Color(0xFF84BD00).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF84BD00).withOpacity(0.3)),
              ),
              child: const Center(
                child: Text(
                  'Portfolio Overview',
                  style: TextStyle(color: Color(0xFF84BD00)),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _tabs.map((tab) {
              final isSelected = tab == _selectedTab;
              return GestureDetector(
                onTap: () => setState(() => _selectedTab = tab),
                child: Column(
                  children: [
                    Text(
                      tab,
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF6C7278),
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isSelected)
                      Container(
                        height: 2,
                        width: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFF84BD00),
                          borderRadius: BorderRadius.all(Radius.circular(1)),
                        ),
                      ),
                  ],
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
      case 'Portfolio':
        return _buildPortfolioTab();
      case 'Assets':
        return _buildAssetsTab();
      case 'History':
        return _buildHistoryTab();
      case 'Settings':
        return _buildSettingsTab();
      default:
        return _buildPortfolioTab();
    }
  }

  Widget _buildPortfolioTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF84BD00).withOpacity(0.2),
                  const Color(0xFF84BD00).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF84BD00).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Wallet Balance (USDT)',
                  style: TextStyle(color: Color(0xFF6C7278), fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  _currencyFormat.format(_totalWalletBalance),
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Across Spot, P2P & Bot Wallets',
                  style: TextStyle(color: Color(0xFF84BD00), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Market Overview',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ..._walletData.map((crypto) => _cryptoListItem(crypto)).toList(),
        ],
      ),
    );
  }

  Widget _buildAssetsTab() {
    return const Center(
      child: Text(
        'Assets Management\nComing Soon!',
        style: TextStyle(color: Colors.white, fontSize: 18),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildHistoryTab() {
    return const Center(
      child: Text(
        'Transaction History\nComing Soon!',
        style: TextStyle(color: Colors.white, fontSize: 18),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSettingsTab() {
    return const Center(
      child: Text(
        'Wallet Settings\nComing Soon!',
        style: TextStyle(color: Colors.white, fontSize: 18),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _cryptoListItem(Map<String, dynamic> crypto) {
    final symbol = crypto['symbol'] as String;
    final baseSymbol = symbol.replaceAll('USDT', '');
    final price = crypto['price'] as double;
    final change = crypto['change'] as double;
    final volume = crypto['volume'] as double;
    final high = crypto['high'] as double;
    final realTimeDirection = crypto['realTimeDirection'] as int? ?? 0;
    
    // Use real-time direction for button color
    final isRealTimePositive = realTimeDirection > 0;
    final is24hPositive = change >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _buildCryptoLogo(baseSymbol),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  symbol,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _compactFormat.format(volume),
                  style: const TextStyle(
                    color: Color(0xFF6C7278),
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
                price.toStringAsFixed(2),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _currencyFormat.format(high),
                style: const TextStyle(
                  color: Color(0xFF6C7278),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isRealTimePositive ? const Color(0xFF84BD00) : (realTimeDirection < 0 ? Colors.red : const Color(0xFF6C7278)),
              borderRadius: BorderRadius.circular(8),
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

  Widget _buildCryptoLogo(String symbol) {
    Color logoColor = _getSymbolColor(symbol);
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: logoColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          symbol[0],
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
      case 'Request':
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
      case 'Edit Wallet':
        _showWalletSettings(context);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$action coming soon!')),
        );
        break;
    }
  }

  void _showWalletSettings(BuildContext context) {
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
                const Text('Wallet Settings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                _walletOptionItem('Security', 'security'),
                _walletOptionItem('Backup', 'backup'),
                _walletOptionItem('Export', 'export'),
                _walletOptionItem('Import', 'import'),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _walletOptionItem(String label, String iconKey) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label coming soon!')),
        );
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
            child: Icon(
              _getWalletIcon(iconKey),
              color: Color(0xFF84BD00),
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF6C7278), fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getWalletIcon(String key) {
    switch (key) {
      case 'security': return Icons.security;
      case 'backup': return Icons.backup;
      case 'export': return Icons.file_download;
      case 'import': return Icons.file_upload;
      default: return Icons.settings;
    }
  }
}
