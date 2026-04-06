import 'package:creddx/screens/user_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math' show pi, cos, sin, min, max, Random;
import 'coming_soon_screen.dart';
import 'deposit_screen.dart';
import 'notification_screen.dart';
import 'p2p_trading_screen.dart';
import 'internal_transfer_screen.dart';
import 'wallet_history_screen.dart';
import 'invite_friends_screen.dart';
import 'withdraw_screen.dart';
import 'inr_deposit_screen.dart';
import 'conversion_screen.dart';
import 'spot_screen.dart';
import '../services/user_service.dart';
import '../services/wallet_service.dart';
import '../services/spot_service.dart';
import '../services/binance_service.dart';
import '../utils/coin_icon_mapper.dart';
import '../widgets/bitcoin_loading_indicator.dart';

// Custom Crypto-themed Refresh Indicator
class CryptoRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const CryptoRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  @override
  State<CryptoRefreshIndicator> createState() => _CryptoRefreshIndicatorState();
}

class _CryptoRefreshIndicatorState extends State<CryptoRefreshIndicator>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  double _dragExtent = 0.0;
  bool _isRefreshing = false;
  static const double _maxDrag = 120.0;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    _rotationController.repeat();
    _pulseController.repeat(reverse: true);
    
    await widget.onRefresh();
    
    if (mounted) {
      setState(() {
        _isRefreshing = false;
        _dragExtent = 0.0;
      });
      _rotationController.stop();
      _pulseController.stop();
      _slideController.forward().then((_) => _slideController.reverse());
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          if (notification.metrics.pixels <= 0) {
            setState(() => _dragExtent = 0);
          }
        } else if (notification is OverscrollNotification) {
          if (notification.overscroll < 0 && !_isRefreshing) {
            setState(() {
              _dragExtent = (_dragExtent - notification.overscroll).clamp(0.0, _maxDrag);
            });
            if (_dragExtent >= _maxDrag * 0.6) {
              _rotationController.value = _dragExtent / _maxDrag;
            }
          }
        } else if (notification is ScrollEndNotification) {
          if (_dragExtent >= _maxDrag * 0.6 && !_isRefreshing) {
            _handleRefresh();
          } else if (!_isRefreshing) {
            setState(() => _dragExtent = 0);
          }
        }
        return false;
      },
      child: Stack(
        children: [
          widget.child,
          if (_dragExtent > 0 || _isRefreshing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _rotationController,
                  _pulseController,
                  _slideController,
                ]),
                builder: (context, child) {
                  double progress = _isRefreshing 
                    ? 1.0 
                    : (_dragExtent / _maxDrag).clamp(0.0, 1.0);
                  
                  double scale = _isRefreshing
                    ? 0.8 + (_pulseController.value * 0.2)
                    : 0.5 + (progress * 0.5);
                  
                  double opacity = progress.clamp(0.0, 1.0);
                  
                  double rotation = _isRefreshing
                    ? _rotationController.value * 2 * pi
                    : progress * 2 * pi;
                  
                  double slideOffset = _slideController.value * 20;
                  
                  return Container(
                    height: 80 + slideOffset,
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: Transform.rotate(
                          angle: rotation,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF84BD00),
                                  Color(0xFF6BA300),
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF84BD00).withOpacity(0.5 + (_pulseController.value * 0.3)),
                                  blurRadius: 15 + (_pulseController.value * 10),
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer ring
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D0D0D),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF84BD00).withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                // Inner coin design
                                const Icon(
                                  Icons.currency_bitcoin,
                                  color: Color(0xFF84BD00),
                                  size: 22,
                                ),
                                // Rotating dots
                                ...List.generate(4, (index) {
                                  double angle = (index * pi / 2) + rotation;
                                  return Transform.translate(
                                    offset: Offset(
                                      17 * cos(angle),
                                      17 * sin(angle),
                                    ),
                                    child: Container(
                                      width: 5,
                                      height: 5,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF84BD00),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

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
  
  // WebSocket for real-time favorites data
  Map<String, Map<String, dynamic>> _favoritesMarketData = {};
  bool _isWebSocketConnected = false;
  StreamSubscription<Map<String, dynamic>>? _marketDataSubscription;
  
  // Candlestick chart data for Std. Futures
  List<Map<String, dynamic>> _candleData = [];
  double _currentPrice = 4890.12;
  double _priceChange = 12.1;
  String _selectedTimeframe = '15 Min';
  final List<String> _timeframes = ['Line', '15 Min', '1 Hour', '4 Hour', '1 Day', 'More'];
  
  Timer? _priceTimer;
  final String _marketBaseUrl = 'http://13.202.34.205:9000';
  
  // Binance market data
  List<Map<String, dynamic>> _binanceMarketData = [];
  StreamSubscription<Map<String, dynamic>>? _binanceWsSubscription;
  
  // Market cap data from CoinGecko
  Map<String, double> _marketCapData = {};
  
  @override
  void initState() {
    super.initState();
    UserService().initUserData();
    _fetchInitialData();
    _startPriceUpdates();
    _generateMockCandleData();
    
    // Connect WebSocket for Favorites real-time data
    _connectWebSocketForFavorites();
  }

  // Connect WebSocket for real-time favorites market data from Binance
  Future<void> _connectWebSocketForFavorites() async {
    try {
      final favorites = ['BTCUSDT', 'ETHUSDT', 'BNBUSDT', 'SOLUSDT'];
      
      // Connect to multi-ticker stream for all favorites
      final stream = BinanceService.connectMultiTickerStream(favorites);
      
      if (stream != null) {
        _binanceWsSubscription = stream.listen(
          (data) {
            if (mounted) {
              setState(() {
                final symbol = data['symbol']?.toString() ?? '';
                _favoritesMarketData[symbol] = {
                  'price': data['price'] ?? 0.0,
                  'change': data['priceChangePercent'] ?? 0.0,
                  'volume': data['quoteVolume'] ?? 0.0,
                  'bid': data['bidPrice'] ?? 0.0,
                  'ask': data['askPrice'] ?? 0.0,
                  'updatedAt': DateTime.now(),
                };
              });
            }
          },
          onError: (error) {
            debugPrint('Binance WebSocket error: $error');
          },
        );
      }
      
      setState(() => _isWebSocketConnected = true);
      debugPrint('Binance WebSocket connected for Favorites');
    } catch (e) {
      debugPrint('Failed to connect Binance WebSocket: $e');
      setState(() => _isWebSocketConnected = false);
    }
  }
  
  // Update market data from WebSocket
  void _updateFavoritesMarketData(Map<String, dynamic> data) {
    try {
      final symbol = data['symbol']?.toString() ?? 'BTCUSDT';
      final bids = data['bids'] as List<dynamic>?;
      final asks = data['asks'] as List<dynamic>?;
      
      if (bids != null && bids.isNotEmpty && asks != null && asks.isNotEmpty) {
        final bestBid = double.tryParse(bids[0][0]?.toString() ?? '0') ?? 0.0;
        final bestAsk = double.tryParse(asks[0][0]?.toString() ?? '0') ?? 0.0;
        final midPrice = (bestBid + bestAsk) / 2;
        
        // Calculate change from previous price if available
        double change = 0.0;
        if (_favoritesMarketData.containsKey(symbol)) {
          final prevPrice = _favoritesMarketData[symbol]!['price'] ?? midPrice;
          if (prevPrice > 0) {
            change = ((midPrice - prevPrice) / prevPrice) * 100;
          }
        }
        
        setState(() {
          _favoritesMarketData[symbol] = {
            'price': midPrice,
            'change': change,
            'bid': bestBid,
            'ask': bestAsk,
            'volume': data['volume'] ?? 0.0,
            'updatedAt': DateTime.now(),
          };
        });
      }
    } catch (e) {
      debugPrint('Error updating favorites market data: $e');
    }
  }
  
  // Get real-time price for a symbol
  double _getRealtimePrice(String symbol, double fallbackPrice) {
    final wsData = _favoritesMarketData[symbol];
    if (wsData != null) {
      return wsData['price'] ?? fallbackPrice;
    }
    return fallbackPrice;
  }
  
  // Get real-time change for a symbol
  double _getRealtimeChange(String symbol, double fallbackChange) {
    final wsData = _favoritesMarketData[symbol];
    if (wsData != null) {
      return wsData['change'] ?? fallbackChange;
    }
    return fallbackChange;
  }

  void _generateMockCandleData() {
    final random = Random();
    final List<Map<String, dynamic>> candles = [];
    double price = _currentPrice * 0.85;
    
    for (int i = 0; i < 30; i++) {
      final open = price;
      final change = (random.nextDouble() - 0.5) * 200;
      final close = price + change;
      final high = max(open, close) + random.nextDouble() * 50;
      final low = min(open, close) - random.nextDouble() * 50;
      
      candles.add({
        'open': open,
        'close': close,
        'high': high,
        'low': low,
        'volume': 1000 + random.nextDouble() * 5000,
      });
      
      price = close;
    }
    
    setState(() => _candleData = candles);
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
      // Use getAllWalletBalances API to get all wallet balances
      final result = await WalletService.getAllWalletBalances();
      debugPrint('Home Screen - getAllWalletBalances Result: $result');
      
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        double totalAvailable = 0.0;
        
        // Handle flat format: {spotBalance: X, mainBalance: {USDT: Y}, p2pBalance: Z, botBalance: W}
        final walletTypeMap = {
          'spot': 'spotBalance',
          'main': 'mainBalance', 
          'p2p': 'p2pBalance',
          'bot': 'botBalance',
        };
        
        for (String type in walletTypeMap.keys) {
          final fieldName = walletTypeMap[type]!;
          final walletData = data[fieldName];
          
          if (walletData != null) {
            double available = 0.0;
            
            if (walletData is Map) {
              // Format: {INR: X, USDT: Y}
              if (walletData['USDT'] != null) {
                available = double.tryParse(walletData['USDT'].toString()) ?? 0.0;
              }
            } else if (walletData is num) {
              // Format: spotBalance: 0 (direct number)
              available = walletData.toDouble();
            }
            
            totalAvailable += available;
            debugPrint('Home Screen - $type available: $available');
          }
        }
        
        // Fallback: try nested format if flat format returned 0
        if (totalAvailable == 0) {
          final walletTypes = ['spot', 'p2p', 'bot', 'main'];
          for (String type in walletTypes) {
            if (data[type] != null) {
              final wallet = data[type];
              if (wallet['balances'] != null && wallet['balances'] is List) {
                final balances = wallet['balances'] as List;
                for (var b in balances) {
                  final coin = b['coin']?.toString().toUpperCase() ?? '';
                  if (coin == 'USDT') {
                    final available = double.tryParse(b['available']?.toString() ?? '0') ?? 0.0;
                    totalAvailable += available;
                    debugPrint('Home Screen (nested) - $type available: $available');
                  }
                }
              }
            }
          }
        }
        
        debugPrint('Home Screen - Total Available USDT: $totalAvailable');
        
        if (mounted) {
          setState(() {
            _totalBalance = totalAvailable;
          });
        }
      } else {
        // Fallback to SpotService if WalletService fails
        debugPrint('WalletService failed, trying SpotService...');
        final spotResult = await SpotService.getBalance();
        if (spotResult['success'] == true && spotResult['data'] != null) {
          final spotData = spotResult['data'];
          if (spotData['assets'] != null && spotData['assets'] is List) {
            final List assetsList = spotData['assets'];
            for (var assetItem in assetsList) {
              final assetName = assetItem['asset']?.toString().toUpperCase() ?? '';
              if (assetName == 'USDT') {
                final available = double.tryParse(assetItem['available']?.toString() ?? '0') ?? 0.0;
                if (mounted) {
                  setState(() {
                    _totalBalance = available;
                  });
                }
                debugPrint('Home Screen - SpotService USDT available: $available');
                break;
              }
            }
          }
        }
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
      // Fetch market cap data from CoinGecko
      final marketCaps = await BinanceService.getMarketCapData();
      
      // Fetch top trading pairs from Binance
      final topPairs = await BinanceService.getTopTradingPairs(limit: 50);
      
      if (mounted) {
        setState(() {
          _marketCapData = marketCaps;
          _binanceMarketData = topPairs;
          _cryptoData = topPairs.map((item) {
            final symbol = item['symbol']?.toString() ?? '';
            final baseSymbol = symbol.replaceAll('USDT', '');
            final marketCap = marketCaps[baseSymbol] ?? 0.0;
            
            return {
              'name': _getCoinName(symbol),
              'symbol': symbol,
              'price': item['price'],
              'change': item['priceChangePercent'],
              'volume': item['quoteVolume'],
              'marketCap': marketCap,
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching market data: $e');
    }
  }
  
  // Get coin name from symbol
  String _getCoinName(String symbol) {
    final names = {
      'BTCUSDT': 'Bitcoin',
      'ETHUSDT': 'Ethereum',
      'BNBUSDT': 'BNB',
      'SOLUSDT': 'Solana',
      'ADAUSDT': 'Cardano',
      'XRPUSDT': 'XRP',
      'DOTUSDT': 'Polkadot',
      'DOGEUSDT': 'Dogecoin',
      'AVAXUSDT': 'Avalanche',
      'MATICUSDT': 'Polygon',
      'LINKUSDT': 'Chainlink',
      'LTCUSDT': 'Litecoin',
      'ATOMUSDT': 'Cosmos',
      'UNIUSDT': 'Uniswap',
      'ETCUSDT': 'Ethereum Classic',
      'XLMUSDT': 'Stellar',
      'ALGOUSDT': 'Algorand',
      'VETUSDT': 'VeChain',
      'FILUSDT': 'Filecoin',
      'TRXUSDT': 'TRON',
    };
    return names[symbol] ?? symbol.replaceAll('USDT', '');
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
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ComingSoonScreen()));
    } else if (action == 'Receive') {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ComingSoonScreen()));
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
    _marketDataSubscription?.cancel();
    _binanceWsSubscription?.cancel();
    BinanceService.disconnectAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            // Fixed top section - doesn't scroll
            _buildHeader(),
            _buildBalanceCard(),
            _buildActionGrid(),
            _buildPromoBanner(),
            // Scrollable section - tabs + crypto list
            Expanded(
              child: CryptoRefreshIndicator(
                onRefresh: _fetchInitialData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const NotificationScreen())),
              icon: const Icon(Icons.notifications_none, color: Colors.white, size: 18),
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
                'Available Balance',
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
      {'label': 'Transfer', 'icon': 'transfericon.png', 'iconData': Icons.swap_horiz, 'customWidget': true},
      {'label': 'Conversion', 'icon': '', 'iconData': Icons.currency_exchange, 'customWidget': true},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4), // Reduced vertical padding
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Reduced vertical margin
      height: 100, // Reduced height slightly 
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
    // Show candlestick chart for Std. Futures tab
    if (_selectedTab == 'Std. Futures') {
      return _buildCandlestickChartSection();
    }
    
    // Show real-time WebSocket data for Favorites tab
    if (_selectedTab == 'Favorites') {
      return _buildFavoritesWebSocketList();
    }
    
    if (_isLoading) return const Padding(padding: EdgeInsets.all(40), child: Center(child: BitcoinLoadingIndicator(size: 40)));
    
    if (_cryptoData.isEmpty) {
      return const Center(
        child: Text(
          'No data available',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }
    
    return _buildCryptoDataList(_cryptoData);
  }
  
  // Build favorites list with WebSocket real-time data - shows all Binance coins
  Widget _buildFavoritesWebSocketList() {
    // Use Binance market data (50+ coins) instead of hardcoded 4
    final favorites = _binanceMarketData.isNotEmpty 
        ? _binanceMarketData 
        : [
            {'name': 'Bitcoin', 'symbol': 'BTCUSDT', 'icon': 'BTC', 'price': 0.0, 'priceChangePercent': 0.0, 'quoteVolume': 0.0},
            {'name': 'Ethereum', 'symbol': 'ETHUSDT', 'icon': 'ETH', 'price': 0.0, 'priceChangePercent': 0.0, 'quoteVolume': 0.0},
            {'name': 'BNB', 'symbol': 'BNBUSDT', 'icon': 'BNB', 'price': 0.0, 'priceChangePercent': 0.0, 'quoteVolume': 0.0},
            {'name': 'Solana', 'symbol': 'SOLUSDT', 'icon': 'SOL', 'price': 0.0, 'priceChangePercent': 0.0, 'quoteVolume': 0.0},
          ];
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(), // Better for nested scrolling
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final crypto = favorites[index];
        final cryptoName = crypto['name']?.toString() ?? _getCoinName(crypto['symbol']?.toString() ?? 'BTCUSDT');
        final cryptoSymbol = crypto['symbol']?.toString() ?? 'BTCUSDT';
        // Get real-time data from WebSocket or use the data from Binance API
        final wsData = _favoritesMarketData[cryptoSymbol];
        final apiPrice = double.tryParse(crypto['price']?.toString() ?? '0') ?? 0.0;
        final apiChange = double.tryParse(crypto['priceChangePercent']?.toString() ?? '0') ?? 0.0;
        final apiVolume = double.tryParse(crypto['quoteVolume']?.toString() ?? '0') ?? 0.0;
        
        // Get market cap from CoinGecko data
        final baseSymbol = cryptoSymbol.replaceAll('USDT', '');
        final apiMarketCap = _marketCapData[baseSymbol] ?? 0.0;
        
        // Use WebSocket data if available, otherwise use API data
        final price = wsData?['price'] ?? apiPrice;
        final change = wsData?['change'] ?? apiChange;
        
        // Use market cap from data
        final marketCap = apiMarketCap > 0 ? apiMarketCap : _getFallbackMarketCap(cryptoSymbol);
        final isPositive = change >= 0;
        final isRealtime = wsData != null;
        
        // Fallback values if no data yet
        final displayPrice = price > 0 ? price : _getFallbackPrice(cryptoSymbol);
        final displayChange = isRealtime || change != 0 ? change : _getFallbackChange(cryptoSymbol);
        final displayMarketCap = marketCap > 0 ? marketCap : _getFallbackMarketCap(cryptoSymbol);
        
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => SpotScreen(initialSymbol: cryptoSymbol),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
              CoinIconMapper.getCoinIcon(
                cryptoSymbol.replaceAll('USDT', ''),
                size: 48,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          cryptoSymbol.replaceAll('USDT', ''),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                        const Text(
                          '/USDT',
                          style: TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                          ),
                        ),
                        if (isRealtime) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00C087),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'MCap: ${_formatVolume(displayMarketCap)}',
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
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
                    '\$${_formatPrice(displayPrice)}',
                    style: TextStyle(
                      color: isRealtime 
                          ? (isPositive ? const Color(0xFF00C087) : const Color(0xFFFF3B30))
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: displayChange >= 0 
                          ? const Color(0xFF00C087).withOpacity(0.1) 
                          : const Color(0xFFFF3B30).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${displayChange >= 0 ? '+' : ''}${displayChange.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: displayChange >= 0 ? const Color(0xFF00C087) : const Color(0xFFFF3B30),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      },
    );
  }
  
  // Fallback values for when WebSocket data is not available
  double _getFallbackPrice(String symbol) {
    final prices = {
      'BTCUSDT': 43250.00,
      'ETHUSDT': 2650.00,
      'BNBUSDT': 315.00,
      'SOLUSDT': 98.50,
    };
    return prices[symbol] ?? 0.0;
  }
  
  double _getFallbackChange(String symbol) {
    final changes = {
      'BTCUSDT': 2.35,
      'ETHUSDT': -1.20,
      'BNBUSDT': 0.85,
      'SOLUSDT': 5.40,
    };
    return changes[symbol] ?? 0.0;
  }
  
  double _getFallbackMarketCap(String symbol) {
    final marketCaps = {
      'BTCUSDT': 850000000000.0,  // $850B
      'ETHUSDT': 280000000000.0,  // $280B
      'BNBUSDT': 50000000000.0,   // $50B
      'SOLUSDT': 45000000000.0,   // $45B
    };
    return marketCaps[symbol] ?? 0.0;
  }
  
  // Build regular crypto list from API data
  Widget _buildCryptoDataList(List<Map<String, dynamic>> cryptoData) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: cryptoData.length,
      itemBuilder: (context, index) {
        final crypto = cryptoData[index];
        final cryptoName = crypto['name']?.toString() ?? 'Unknown';
        final cryptoSymbol = crypto['symbol']?.toString() ?? '???';
        final baseSymbol = cryptoSymbol.replaceAll('USDT', '');
        final price = double.tryParse(crypto['price']?.toString() ?? '0.0') ?? 0.0;
        final change = double.tryParse(crypto['change']?.toString() ?? '0.0') ?? 0.0;
        final marketCap = double.tryParse(crypto['marketCap']?.toString() ?? '0.0') ?? 0.0;
        final isPositive = change >= 0;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 20), 
          child: Row(
            children: [
              CoinIconMapper.getCoinIcon(
                baseSymbol,
                size: 48,
              ),
              const SizedBox(width: 16), 
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cryptoSymbol.replaceAll('USDT', ''),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 18, 
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'MCap: ${_formatVolume(marketCap)}',
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

  Widget _buildCandlestickChartSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentPrice.toStringAsFixed(2),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_priceChange >= 0 ? '+' : ''}${_priceChange.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: _priceChange >= 0 ? const Color(0xFF84BD00) : const Color(0xFFFF3B30),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2C),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Text('BTC/USDT', style: TextStyle(color: Colors.white, fontSize: 12)),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Timeframe selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _timeframes.map((tf) {
                final isSelected = _selectedTimeframe == tf;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTimeframe = tf),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF84BD00).withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tf,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF84BD00) : Colors.white54,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          
          // Candlestick Chart
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(
                size: const Size(double.infinity, 200),
                painter: CandlestickPainter(_candleData, _currentPrice),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(const Color(0xFF84BD00), 'Buy'),
              const SizedBox(width: 16),
              _buildLegendItem(const Color(0xFFFF3B30), 'Sell'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11)),
      ],
    );
  }

  String _formatPrice(double price) {
    if (price >= 1) {
      return price.toStringAsFixed(2);
    } else {
      return price.toStringAsFixed(6);
    }
  }

  String _formatVolume(double volume) {
    if (volume >= 1e9) {
      return '\$${(volume / 1e9).toStringAsFixed(2)}B'; // Billions
    } else if (volume >= 1e6) {
      return '\$${(volume / 1e6).toStringAsFixed(2)}M'; // Millions
    } else if (volume >= 1e3) {
      return '\$${(volume / 1e3).toStringAsFixed(2)}K'; // Thousands
    } else {
      return '\$${volume.toStringAsFixed(2)}';
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

// Candlestick Chart Painter for Std. Futures
class CandlestickPainter extends CustomPainter {
  final List<Map<String, dynamic>> candles;
  final double currentPrice;
  
  CandlestickPainter(this.candles, this.currentPrice);
  
  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    
    final paint = Paint()
      ..strokeWidth = 1.0;
    
    final candleWidth = size.width / (candles.length + 2);
    
    // Find min and max for scaling
    double minPrice = double.infinity;
    double maxPrice = 0;
    for (var candle in candles) {
      minPrice = min(minPrice, candle['low'] as double);
      maxPrice = max(maxPrice, candle['high'] as double);
    }
    
    final priceRange = maxPrice - minPrice;
    final padding = priceRange * 0.1;
    minPrice -= padding;
    maxPrice += padding;
    
    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 0.5;
    
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    
    // Draw candles
    for (int i = 0; i < candles.length; i++) {
      final candle = candles[i];
      final x = (i + 1) * candleWidth;
      
      final open = candle['open'] as double;
      final close = candle['close'] as double;
      final high = candle['high'] as double;
      final low = candle['low'] as double;
      
      final isGreen = close >= open;
      final color = isGreen ? const Color(0xFF84BD00) : const Color(0xFFFF3B30);
      
      final yHigh = size.height - ((high - minPrice) / (maxPrice - minPrice)) * size.height;
      final yLow = size.height - ((low - minPrice) / (maxPrice - minPrice)) * size.height;
      final yOpen = size.height - ((open - minPrice) / (maxPrice - minPrice)) * size.height;
      final yClose = size.height - ((close - minPrice) / (maxPrice - minPrice)) * size.height;
      
      paint.color = color;
      
      // Draw wick
      canvas.drawLine(
        Offset(x + candleWidth / 2, yHigh),
        Offset(x + candleWidth / 2, yLow),
        paint,
      );
      
      // Draw body
      final bodyTop = min(yOpen, yClose);
      final bodyBottom = max(yOpen, yClose);
      final bodyHeight = max(bodyBottom - bodyTop, 2);
      
      final bodyRect = Rect.fromLTWH(
        x + candleWidth * 0.2,
        bodyTop,
        candleWidth * 0.6,
        bodyHeight.toDouble(),
      );
      
      canvas.drawRect(bodyRect, paint);
    }
    
    // Draw current price line
    final currentY = size.height - ((currentPrice - minPrice) / (maxPrice - minPrice)) * size.height;
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(
      Offset(0, currentY),
      Offset(size.width, currentY),
      linePaint,
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
