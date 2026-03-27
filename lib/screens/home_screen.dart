import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'notification_screen.dart';
import 'send_screen.dart';
import 'receive_screen.dart';
import 'deposit_screen.dart';
import 'inr_deposit_screen.dart';
import 'withdraw_screen.dart';
import 'p2p_trading_screen.dart';
import 'user_profile_screen.dart';
import 'invite_friends_screen.dart';
import 'internal_transfer_screen.dart';
import 'wallet_history_screen.dart';
import 'conversion_screen.dart';
import '../services/user_service.dart';
import '../services/wallet_service.dart';
import '../utils/websocket_test.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedTab = 'Favorites';
  final List<String> _tabs = ['Favorites', 'Perp Futures', 'Std. Futures', 'Innovation '];
  final NumberFormat _compactFormat = NumberFormat.compactCurrency(symbol: '', decimalDigits: 1);
  
  List<Map<String, dynamic>> _cryptoData = [];
  bool _isLoading = true;
  double _totalBalance = 0.0;
  bool _isBalanceVisible = true;
  
  Timer? _priceTimer;
  final String _marketBaseUrl = 'http://13.235.89.109:9000';
  
  @override
  void initState() {
    super.initState();
    UserService().initUserData();
    _fetchInitialData();
    _startPriceUpdates();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchMarketData(),
      _fetchWalletBalance(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchWalletBalance() async {
    try {
      // Fetching total balance using the wallet/get API integrated method
      final balance = await WalletService.getTotalUSDTBalance();
      if (mounted) {
        setState(() {
          _totalBalance = balance;
        });
      }
    } catch (e) {
      debugPrint('Error fetching wallet balance in Home: $e');
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    UserService().initUserData();
    _fetchWalletBalance();
  }
  
  Future<void> _fetchMarketData() async {
    try {
      final response = await http.get(Uri.parse('$_marketBaseUrl/ticker/24hr'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          if (responseData['data'] is List) {
            _cryptoData = List<Map<String, dynamic>>.from(responseData['data']);
          } else if (responseData['data'] is Map && responseData['data']['symbol'] != null) {
            _cryptoData = [Map<String, dynamic>.from(responseData['data'])];
          } else {
            _cryptoData = [];
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching home market data: $e');
    }
  }
  
  void _startPriceUpdates() {
    _priceTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _fetchMarketData();
        _fetchWalletBalance();
      }
    });
  }
  
  void _handleActionTap(String action) {
    if (action == 'Deposit') {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const DepositScreen()));
    } else if (action == 'INR Deposit') {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const InrDepositScreen()));
    } else if (action == 'Withdraw') {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const WithdrawScreen()));
    } else if (action == 'Send') {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SendScreen()));
    } else if (action == 'Receive') {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ReceiveScreen()));
    } else if (action == 'P2P') {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const P2PTradingScreen()));
    } else if (action == 'Transfer') {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const InternalTransferScreen()));
    } else if (action == 'History') {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const WalletHistoryScreen()));
    } else if (action == 'Invite') {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const InviteFriendsScreen()));
    } else if (action == 'Conversion') {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ConversionScreen()));
    }
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
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchInitialData,
                color: const Color(0xFF84BD00),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBalanceCard(),
                      _buildActionGrid(),
                      _buildPromoBanner(),
                      _buildTabSection(),
                      _buildCryptoList(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final userService = UserService();
    final hasEmail = userService.hasEmail();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => const UserProfileScreen()));
                },
                child: Container(
                  width: 36, height: 36,
                  decoration: const BoxDecoration(color: Color(0xFF1E1E20), shape: BoxShape.circle),
                  child: const Icon(Icons.person, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Creddx',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (hasEmail) ...[
                    const SizedBox(height: 1),
                    Text(
                      userService.userEmail ?? '',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.notifications_none, color: Colors.white, size: 18),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const NotificationScreen())),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Total Balance',
                style: TextStyle(color: Colors.white54, fontSize: 10),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() => _isBalanceVisible = !_isBalanceVisible),
                child: Icon(
                  _isBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: Colors.white38,
                  size: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _isBalanceVisible ? _totalBalance.toStringAsFixed(2) : '****',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'USDT',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 2),
          FutureBuilder<double>(
            future: _getUSDEquivalent(),
            builder: (context, snapshot) {
              final usdEquivalent = snapshot.data ?? 0.0;
              return Text(
                '≈ \$${_isBalanceVisible ? usdEquivalent.toStringAsFixed(2) : '****'} USD',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<double> _getUSDEquivalent() async {
    return _totalBalance;
  }

  Widget _buildTransferIcon() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF2A2A2C), width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left arrow
          Positioned(
            left: 6,
            child: Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 16,
            ),
          ),
          // Right arrow
          Positioned(
            right: 6,
            child: Icon(
              Icons.arrow_forward,
              color: Colors.white,
              size: 16,
            ),
          ),
          // Horizontal line
          Container(
            width: 20,
            height: 2,
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildP2PIcon() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF2A2A2C), width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left person
          Positioned(
            left: 8,
            child: Icon(
              Icons.person,
              color: Colors.white,
              size: 14,
            ),
          ),
          // Right person
          Positioned(
            right: 8,
            child: Icon(
              Icons.person,
              color: Colors.white,
              size: 14,
            ),
          ),
          // Connection dots
          Positioned(
            left: 16,
            child: Container(
              width: 2,
              height: 2,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 16,
            child: Container(
              width: 2,
              height: 2,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversionIcon() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF2A2A2C), width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Currency symbol 1 (left)
          Positioned(
            left: 6,
            child: Text(
              '₹',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Arrow
          Icon(
            Icons.arrow_forward,
            color: Colors.white,
            size: 11,
          ),
          // Currency symbol 2 (right)
          Positioned(
            right: 6,
            child: Icon(
              Icons.attach_money,
              color: Colors.white,
              size: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionGrid() {
    final actions = [
      {'label': 'Send', 'icon': 'sendicon.png', 'iconData': Icons.arrow_circle_up},
      {'label': 'Receive', 'icon': 'receiveicon.png', 'iconData': Icons.request_page},
      {'label': 'Deposit', 'icon': 'depositeicon.png', 'iconData': Icons.account_balance_wallet},
      {'label': 'INR Deposit', 'icon': 'inrdeposit.png', 'iconData': Icons.currency_rupee},
      {'label': 'Withdraw', 'icon': 'withdrawicon.png', 'iconData': Icons.money},
      {'label': 'P2P', 'icon': '', 'iconData': Icons.people, 'customWidget': true},
      {'label': 'Transfer', 'icon': '', 'iconData': Icons.swap_horiz, 'customWidget': true},
      {'label': 'Conversion', 'icon': '', 'iconData': Icons.currency_exchange, 'customWidget': true},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, 
          crossAxisSpacing: 10,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8, // Adjusted for icons with text
        ),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final action = actions[index];
          final String label = action['label'] as String;
          bool isHistory = label == 'History';
          bool isCustomWidget = action['customWidget'] == true;
          
          double containerSize = 56;
          // Reduced padding for P2P and INR Deposit to make icons larger
          double padding = (label == 'INR Deposit' || label == 'P2P') ? 6 : 8;
          
          return GestureDetector(
            onTap: () => _handleActionTap(label),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: containerSize, 
                  height: containerSize, 
                  padding: EdgeInsets.all(padding),
                  child: isCustomWidget 
                    ? (label == 'Transfer' 
                        ? _buildTransferIcon() 
                        : label == 'Conversion' 
                            ? _buildConversionIcon()
                            : _buildP2PIcon())
                    : Image.asset(
                        'assets/images/${action['icon']}', 
                        fit: BoxFit.contain,
                        color: (isHistory || label == 'Transfer') ? const Color(0xFF84BD00) : null,
                        errorBuilder: (c, e, s) => Icon(
                          action['iconData'] as IconData, 
                          color: const Color(0xFF84BD00), 
                          size: (label == 'INR Deposit' || label == 'P2P') ? 38 : 34 
                        )
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      height: 120, 
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        image: const DecorationImage(image: AssetImage('assets/images/adhome.png'), fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildTabSection() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: _tabs.map((tab) {
          bool isSelected = _selectedTab == tab;
          return GestureDetector(
            onTap: () => setState(() => _selectedTab = tab),
            child: Container(
              margin: const EdgeInsets.only(right: 30), 
              child: Column(
                children: [
                  Text(
                    tab, 
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54, 
                      fontSize: 16, 
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                    )
                  ),
                  if (isSelected) Container(margin: const EdgeInsets.only(top: 8), height: 3, width: 24, color: const Color(0xFF84BD00)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCryptoList() {
    if (_isLoading) return const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFF84BD00)));
    
    if (_cryptoData.isEmpty) {
      return const Center(
        child: Text(
          'No data available',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _cryptoData.length,
      itemBuilder: (context, index) {
        final crypto = _cryptoData[index];
        final cryptoName = crypto['name']?.toString() ?? 'Unknown';
        final cryptoSymbol = crypto['symbol']?.toString() ?? '???';
        final price = double.tryParse(crypto['price']?.toString() ?? '0.0') ?? 0.0;
        final change = double.tryParse(crypto['change']?.toString() ?? '0.0') ?? 0.0;
        final volume = double.tryParse(crypto['volume']?.toString() ?? '0.0') ?? 0.0;
        final isPositive = change >= 0;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 20), 
          child: Row(
            children: [
              Container(
                width: 48, 
                height: 48, 
                decoration: BoxDecoration(
                  color: _getCoinColor(cryptoName),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    cryptoName.isNotEmpty ? cryptoName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22, 
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
                      cryptoSymbol,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 18, 
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vol: ${_compactFormat.format(volume)}',
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 14, 
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${_formatPrice(price)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16, 
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPositive ? const Color(0xFF00C087).withOpacity(0.1) : const Color(0xFFFF3B30).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${isPositive ? '+' : ''}${change.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: isPositive ? const Color(0xFF00C087) : const Color(0xFFFF3B30),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatPrice(double price) {
    if (price >= 1) {
      return price.toStringAsFixed(2);
    } else {
      return price.toStringAsFixed(6);
    }
  }

  Color _getCoinColor(String name) {
    switch (name.toLowerCase()) {
      case 'bitcoin': return const Color(0xFFF7931A);
      case 'ethereum': return const Color(0xFF627EEA);
      case 'tether': return const Color(0xFF26A17B);
      case 'bnb': return const Color(0xFFF3BA2F);
      case 'solana': return const Color(0xFF14F195);
      default: return const Color(0xFF1E1E20);
    }
  }
}
