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
import 'internal_deposit_screen.dart';
import 'send_screen.dart';
import 'notification_screen.dart';
import 'p2p_trading_screen.dart';
import 'wallet_transfer_screen.dart';
import 'wallet_history_screen.dart';
import 'invite_friends_screen.dart';
import 'withdraw_screen.dart';
import 'withdraw_crypto_screen.dart';
import 'withdraw_inr_screen.dart';
import 'inr_deposit_screen.dart';
import 'conversion_screen.dart';
import 'spot_screen.dart';
import '../services/socket_service.dart';
import '../services/user_service.dart';
import '../services/wallet_service.dart';
import '../services/spot_service.dart';
import '../services/binance_service.dart';
import '../services/unified_wallet_service.dart' as unified;
import '../services/auto_refresh_service.dart';
import '../services/balance_sync_service.dart';
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String _selectedTab = 'Favorites';
  final List<String> _tabs = ['Market', 'Perp Futures', 'Std. Futures'];
  final NumberFormat _compactFormat = NumberFormat.compactCurrency(symbol: '', decimalDigits: 1);
  
  List<Map<String, dynamic>> _cryptoData = [];
  bool _isLoading = true;
  double _totalBalance = 0.0;
  double _availableBalance = 0.0;
  bool _isBalanceVisible = false; // Balance hidden by default after login
  
  // WebSocket for real-time favorites data
  Map<String, Map<String, dynamic>> _favoritesMarketData = {};
  bool _isWebSocketConnected = false;
  StreamSubscription<Map<String, dynamic>>? _marketDataSubscription;
  StreamSubscription<unified.WalletBalance?>? _balanceSubscription;
  StreamSubscription<double>? _balanceSyncSubscription;
  StreamSubscription<Map<String, dynamic>>? _socketBalanceSubscription;
  
  // Candlestick chart data for Std. Futures
  List<Map<String, dynamic>> _candleData = [];
  double _currentPrice = 4890.12;
  double _priceChange = 12.1;
  String _selectedTimeframe = '15 Min';
  final List<String> _timeframes = ['Line', '15 Min', '1 Hour', '4 Hour', '1 Day', 'More'];
  
  Timer? _priceTimer;
  Timer? _balanceRefreshTimer;
  final String _marketBaseUrl = 'http://13.202.34.205:9000';
  
  // Binance market data
  List<Map<String, dynamic>> _binanceMarketData = [];
  StreamSubscription<Map<String, dynamic>>? _binanceWsSubscription;
  
  // Market cap data from CoinGecko
  Map<String, double> _marketCapData = {};

  String _selectedSpotSymbol = 'BTCUSDT';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    UserService().initUserData();
    _startPriceUpdates();
    _generateMockCandleData();

    // Set up balance subscriptions FIRST before any async initialization
    // to avoid missing initial stream emissions from UnifiedWalletService
    _subscribeToBalance();
    _subscribeToBalanceSync();
    _subscribeToSocketBalance();

    // Initialize BalanceSyncService for app-wide balance sync
    BalanceSyncService().initialize();

    // Connect WebSocket for Favorites real-time data
    _connectWebSocketForFavorites();

    // Start periodic balance refresh timer
    _startBalanceRefreshTimer();

    // Initialize wallet services and fetch balance AFTER subscriptions are ready
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint('Home Screen: Post-frame initialization starting...');

      // Initialize UnifiedWalletService and fetch balances
      await unified.UnifiedWalletService.initialize();

      // Force refresh all balances to ensure latest data after login
      await unified.UnifiedWalletService.refreshAllBalances();

      // Fetch initial data (market + wallet balance via API)
      await _fetchInitialData();

      // Connect to Socket Service for real-time balance updates
      await _connectSocketService();

      debugPrint('Home Screen: Post-frame initialization complete');
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _priceTimer?.cancel();
    _balanceRefreshTimer?.cancel();
    _marketDataSubscription?.cancel();
    _binanceWsSubscription?.cancel();
    _balanceSubscription?.cancel();
    _balanceSyncSubscription?.cancel();
    _socketBalanceSubscription?.cancel();
    BinanceService.disconnectAll();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      // Refresh balance when app comes to foreground (with rate limiting)
      debugPrint('Home Screen: App resumed, refreshing balance');
      final now = DateTime.now();
      if (_lastApiFetchTime == null || now.difference(_lastApiFetchTime!) > _minApiFetchInterval) {
        _lastApiFetchTime = now;
        _fetchWalletBalance();
      } else {
        debugPrint('Home Screen: Skipping resume refresh, too soon');
      }
    }
  }

  // Track last API fetch time to prevent rapid successive calls
  DateTime? _lastApiFetchTime;
  static const _minApiFetchInterval = Duration(seconds: 10);

  void _subscribeToBalance() {
    _balanceSubscription = unified.UnifiedWalletService.walletBalanceStream.listen((balance) {
      if (mounted && balance != null) {
        // Immediately update from unified wallet stream data
        final total = balance.totalBalance;
        final equity = balance.totalEquityUSDT;

        setState(() {
          _totalBalance = total;
          // Show total balance in available balance section (user requested)
          _availableBalance = total;
        });

        debugPrint('Home Screen: Balance updated from UnifiedWalletService stream - Total: $total, Equity: $equity');

        // Only trigger API refresh if enough time has passed (avoid race conditions)
        // The periodic timer will handle regular sync anyway
        final now = DateTime.now();
        if (_lastApiFetchTime == null || now.difference(_lastApiFetchTime!) > _minApiFetchInterval) {
          _lastApiFetchTime = now;
          _fetchWalletBalance();
        } else {
          debugPrint('Home Screen: Skipping API fetch, too soon since last call');
        }
      }
    });

    // Socket listener removed - UnifiedWalletService already handles socket updates internally
  }

  void _subscribeToBalanceSync() {
    _balanceSyncSubscription = BalanceSyncService().balanceStream.listen((balance) {
      if (mounted) {
        debugPrint('Home Screen: Balance sync service update: $balance');

        // Update available balance from sync service directly
        setState(() {
          _availableBalance = balance;
        });

        // Only trigger API refresh if enough time has passed
        final now = DateTime.now();
        if (_lastApiFetchTime == null || now.difference(_lastApiFetchTime!) > _minApiFetchInterval) {
          _lastApiFetchTime = now;
          _fetchWalletBalance();
        } else {
          debugPrint('Home Screen: Skipping API fetch from sync service, too soon');
        }
      }
    });
  }

  // Connect to Socket Service for real-time balance updates
  Future<void> _connectSocketService() async {
    try {
      debugPrint('🔌 Home Screen: Starting WALLET socket connection...');
      
      // Force disconnect first to ensure clean connection
      await _forceDisconnectSocket();
      
      // Connect to socket with retry logic
      for (int attempt = 1; attempt <= 3; attempt++) {
        debugPrint('🔌 Home Screen: WALLET Socket connection attempt $attempt/3');
        
        await SocketService.connect();
        await Future.delayed(const Duration(seconds: 3));
        
        if (SocketService.isConnected) {
          debugPrint('🔌✅ Home Screen: WALLET Socket connected successfully on attempt $attempt');
          
          // Join wallet room and request initial data
          await Future.delayed(const Duration(seconds: 1));
          debugPrint('🔌📡 Joining wallet room and requesting initial data...');
          SocketService.requestWalletSummary();
          SocketService.requestWalletBalance();
          
          // Test connection and request balance updates
          await Future.delayed(const Duration(seconds: 2));
          if (SocketService.isConnected) {
            debugPrint('🔌💚 Home Screen: WALLET Socket connection stable and ready');
            debugPrint('🔌📊 Subscribing to wallet balance events...');
            return;
          }
        } else {
          debugPrint('🔌❌ Home Screen: WALLET Socket connection failed on attempt $attempt');
          await Future.delayed(const Duration(seconds: 2));
        }
      }
      
      debugPrint('🔌🚨 Home Screen: All WALLET socket connection attempts failed');
    } catch (e) {
      debugPrint('🔌🚨 Home Screen: Critical error in WALLET socket connection: $e');
    }
  }

  // Force disconnect socket for clean reconnection
  Future<void> _forceDisconnectSocket() async {
    try {
      debugPrint('🔌 Home Screen: Force disconnecting socket...');
      // Note: SocketService doesn't have a disconnect method, so we'll rely on reconnect logic
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('🔌 Home Screen: Error during force disconnect: $e');
    }
  }

  void _subscribeToSocketBalance() {
    debugPrint('🔌📡 Home Screen: Setting up WALLET socket balance subscription...');

    _socketBalanceSubscription = SocketService.balanceStream.listen(
      (balanceData) {
        if (mounted) {
          debugPrint('🔌💰 Home Screen: WALLET BALANCE UPDATE RECEIVED: $balanceData');

          // Try to extract and update balance directly from socket data first
          _processWalletSocketBalanceData(balanceData);

          // Only trigger API refresh if enough time has passed
          final now = DateTime.now();
          if (_lastApiFetchTime == null || now.difference(_lastApiFetchTime!) > _minApiFetchInterval) {
            _lastApiFetchTime = now;
            debugPrint('🔌⚡ Home Screen: Balance refresh triggered by wallet socket');
            _fetchWalletBalance();
          } else {
            debugPrint('🔌⏱️ Home Screen: Skipping API fetch from socket, too soon');
          }

          // Also update balance sync service to notify other parts of app
          BalanceSyncService().forceRefreshBalance();
        }
      },
      onError: (error) {
        debugPrint('🔌❌ Home Screen: WALLET socket balance stream ERROR: $error');
        debugPrint('🔌🔄 Home Screen: Attempting to reconnect wallet socket...');
        // Fallback to API refresh on socket error (with rate limiting)
        final now = DateTime.now();
        if (_lastApiFetchTime == null || now.difference(_lastApiFetchTime!) > _minApiFetchInterval) {
          _lastApiFetchTime = now;
          _fetchWalletBalance();
        }
        // Attempt to reconnect
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            _connectSocketService();
          }
        });
      },
      onDone: () {
        debugPrint('🔌⚠️ Home Screen: WALLET socket balance stream CLOSED');
        debugPrint('🔌🔄 Home Screen: Reconnecting wallet socket...');
        // Attempt to reconnect when stream closes
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            _connectSocketService();
          }
        });
      },
    );
    
    debugPrint('🔌✅ Home Screen: WALLET socket balance subscription ACTIVE');
  }

  // Process WALLET socket balance data and attempt direct UI update
  void _processWalletSocketBalanceData(Map<String, dynamic> balanceData) {
    try {
      final type = balanceData['type']?.toString() ?? 'unknown';
      final data = balanceData['data'] ?? {};
      
      debugPrint('🔌📊 Home Screen: Processing WALLET socket data - Type: $type, Data: $data');
      
      // Handle different wallet socket event types
      switch (type) {
        case 'wallet_summary':
          debugPrint('🔌💼 Home Screen: Processing wallet summary event');
          _processWalletSummaryData(data);
          break;
          
        case 'balance_update':
          debugPrint('🔌💰 Home Screen: Processing balance update event');
          _processBalanceUpdateData(data);
          break;
          
        case 'wallet summary update socket':
          debugPrint('🔌🔄 Home Screen: Processing wallet summary update socket event');
          _processWalletSummaryData(data);
          break;
          
        default:
          debugPrint('🔌❓ Home Screen: Unknown wallet socket event type: $type');
          _processGenericBalanceData(data);
      }
    } catch (e) {
      debugPrint('🔌❌ Home Screen: Error processing WALLET socket balance data: $e');
    }
  }

  // Process wallet summary specific data
  void _processWalletSummaryData(dynamic data) {
    try {
      if (data is Map) {
        debugPrint('🔌💼 Home Screen: Extracting balances from wallet summary...');
        
        // Try to extract both available and total balance
        final extractedBalances = _extractBothBalancesFromData(data);
        final newTotalBalance = extractedBalances['total'] ?? 0.0;
        final newAvailableBalance = extractedBalances['available'] ?? 0.0;
        
        // Update UI if balances changed significantly
        if ((newTotalBalance - _totalBalance).abs() > 0.01 || 
            (newAvailableBalance - _availableBalance).abs() > 0.01) {
          debugPrint('🔌🔄 Home Screen: WALLET SUMMARY UPDATE - Total: $_totalBalance → $newTotalBalance, Available: $_availableBalance → $newAvailableBalance');
          setState(() {
            _totalBalance = newTotalBalance;
            _availableBalance = newAvailableBalance;
          });
          BalanceSyncService().updateBalance(newTotalBalance, source: 'WalletSocket');
        }
      }
    } catch (e) {
      debugPrint('🔌❌ Home Screen: Error processing wallet summary data: $e');
    }
  }

  // Process balance update specific data
  void _processBalanceUpdateData(dynamic data) {
    try {
      debugPrint('🔌💰 Home Screen: Processing balance update - triggering full refresh');
      // For balance_update events, do a full API refresh to get accurate data (with rate limiting)
      final now = DateTime.now();
      if (_lastApiFetchTime == null || now.difference(_lastApiFetchTime!) > _minApiFetchInterval) {
        _lastApiFetchTime = now;
        _fetchWalletBalance();
      } else {
        debugPrint('🔌⏱️ Home Screen: Skipping balance update API fetch, too soon');
      }
    } catch (e) {
      debugPrint('🔌❌ Home Screen: Error processing balance update data: $e');
    }
  }

  // Process generic balance data
  void _processGenericBalanceData(dynamic data) {
    try {
      debugPrint('🔌❓ Home Screen: Processing generic balance data...');
      final extractedBalances = _extractBothBalancesFromData(data);
      final newTotalBalance = extractedBalances['total'] ?? 0.0;
      final newAvailableBalance = extractedBalances['available'] ?? 0.0;
      
      if ((newTotalBalance - _totalBalance).abs() > 0.01 || 
          (newAvailableBalance - _availableBalance).abs() > 0.01) {
        setState(() {
          _totalBalance = newTotalBalance;
          _availableBalance = newAvailableBalance;
        });
        debugPrint('🔌🔄 Home Screen: Generic balance update applied');
      }
    } catch (e) {
      debugPrint('🔌❌ Home Screen: Error processing generic balance data: $e');
    }
  }

  // Test socket connection and request balance updates
  void _testSocketConnection() {
    debugPrint('🧪 Home Screen: Testing socket connection...');
    debugPrint('🧪 Socket connected: ${SocketService.isConnected}');
    debugPrint('🧪 Socket connecting: ${SocketService.isConnecting}');
    
    if (SocketService.isConnected) {
      debugPrint('🧪 Socket is connected, requesting balance updates...');
      SocketService.requestWalletSummary();
      SocketService.requestWalletBalance();
    } else {
      debugPrint('🧪 Socket not connected, attempting reconnection...');
      _connectSocketService();
    }
  }

  // Manual trigger for testing real-time balance updates
  void _manualBalanceUpdateTest() {
    debugPrint('🎯🧪 Home Screen: MANUAL BALANCE UPDATE TEST');
    debugPrint('🎯🧪 Current balance: $_totalBalance');
    
    // Force fetch from API
    _fetchWalletBalance();
    
    // Request socket updates
    if (SocketService.isConnected) {
      debugPrint('🎯🔌 Requesting socket balance updates...');
      SocketService.requestWalletSummary();
      SocketService.requestWalletBalance();
    } else {
      debugPrint('🎯❌ Socket not connected, attempting connection...');
      _connectSocketService();
    }
    
    // Update balance sync service
    BalanceSyncService().forceRefreshBalance();
    
    debugPrint('🎯✅ Manual balance update test completed');
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
      debugPrint('💰 Home Screen: Starting comprehensive balance fetch...');
      debugPrint('💰 Current balances before fetch - Total: $_totalBalance, Available: $_availableBalance');
      
      // Initialize both balances
      double newTotalBalance = 0.0;
      double newAvailableBalance = 0.0;
      
      // Method 1: Try getAllWalletBalances API
      debugPrint('💰 Method 1: Fetching from all-wallet-balance API...');
      final result = await WalletService.getAllWalletBalances();
      debugPrint('💰 API Response: $result');
      
      if (result['success'] == true && result['data'] != null) {
        debugPrint('💰 API success, extracting balance data...');
        
        // Method 1a: Try getTotalUSDTBalance for total balance
        try {
          final totalBalance = await WalletService.getTotalUSDTBalance();
          debugPrint('💰 Method 1a - Total USDT Balance: $totalBalance');
          newTotalBalance = totalBalance;
        } catch (e) {
          debugPrint('💰❌ Method 1a failed: $e');
        }
        
        // Method 1b: Try getTotalAvailableUSDTBalance for available balance
        try {
          final availableBalance = await WalletService.getTotalAvailableUSDTBalance();
          debugPrint('💰 Method 1b - Available USDT Balance: $availableBalance');
          newAvailableBalance = availableBalance;
        } catch (e) {
          debugPrint('💰❌ Method 1b failed: $e');
        }
        
        // Method 1c: Manual extraction from API data
        try {
          final extractedBalances = _extractBothBalancesFromData(result['data']);
          debugPrint('💰 Method 1c - Manual extraction - Total: ${extractedBalances['total']}, Available: ${extractedBalances['available']}');
          
          if (newTotalBalance == 0.0) newTotalBalance = extractedBalances['total'] ?? 0.0;
          if (newAvailableBalance == 0.0) newAvailableBalance = extractedBalances['available'] ?? 0.0;
        } catch (e) {
          debugPrint('💰❌ Method 1c failed: $e');
        }
      } else {
        debugPrint('💰❌ API returned error: ${result['error']}');
      }
      
      // Method 2: Try individual wallet APIs if still 0
      if (newTotalBalance == 0.0 || newAvailableBalance == 0.0) {
        debugPrint('💰 Method 2: Trying individual wallet APIs...');
        final individualBalances = await _fetchFromIndividualWallets();
        debugPrint('💰 Method 2 - Individual wallets: $individualBalances');
        
        if (newTotalBalance == 0.0) newTotalBalance = individualBalances;
        if (newAvailableBalance == 0.0) newAvailableBalance = individualBalances;
      }
      
      // Method 3: All methods returned 0
      if (newTotalBalance == 0.0 && newAvailableBalance == 0.0) {
        debugPrint('💰 Method 3: API returned 0 balances');
      }

      // Update UI ONLY if we got valid data OR if current balance is already 0
      // This prevents overwriting a valid stream balance with 0 from API race conditions
      if (mounted) {
        final hasValidApiData = newTotalBalance > 0 || newAvailableBalance > 0;
        final currentBalanceIsZero = _totalBalance == 0.0 && _availableBalance == 0.0;

        if (hasValidApiData || currentBalanceIsZero) {
          // Only update if API gave us valid data, or if we have nothing to show yet
          setState(() {
            _totalBalance = newTotalBalance;
            _availableBalance = newAvailableBalance;
          });
          debugPrint('💰✅ Balances updated - Total: $newTotalBalance, Available: $newAvailableBalance');
        } else {
          debugPrint('💰🛡️ Skipping UI update: API returned 0 but we have valid balance from stream - Current Total: $_totalBalance, Current Available: $_availableBalance');
        }
      }
      
    } catch (e) {
      debugPrint('💰❌ Critical error in balance fetch: $e');

      // Do not set fake test values - keep previous or show 0
      if (mounted) {
        debugPrint('💰🚨 Balance fetch failed, retaining current values - Total: $_totalBalance, Available: $_availableBalance');
      }
    }
  }

  // Extract both total and available balance manually from API data
  Map<String, double> _extractBothBalancesFromData(dynamic data) {
    double total = 0.0;
    double available = 0.0;
    
    try {
      debugPrint('💰🔍 Extracting both balances from data: $data');
      
      if (data is Map) {
        // Check different possible structures
        final walletTypes = ['spot', 'p2p', 'bot', 'demo_bot', 'main'];
        
        for (String walletType in walletTypes) {
          if (data[walletType] != null) {
            final wallet = data[walletType];
            debugPrint('💰🔍 Checking $walletType wallet: $wallet');
            
            // Check for balances array
            if (wallet['balances'] != null) {
              final balances = wallet['balances'];
              if (balances is List) {
                for (var balance in balances) {
                  if (balance['coin']?.toString().toUpperCase() == 'USDT') {
                    final availableBal = double.tryParse(balance['available']?.toString() ?? '0') ?? 0.0;
                    final totalBal = double.tryParse(balance['total']?.toString() ?? '0') ?? 0.0;
                    final lockedBal = double.tryParse(balance['locked']?.toString() ?? '0') ?? 0.0;
                    
                    available += availableBal;
                    total += totalBal > 0 ? totalBal : (availableBal + lockedBal);
                    
                    debugPrint('💰💰 Found USDT in $walletType: available=$availableBal, total=$totalBal, locked=$lockedBal');
                  }
                }
              }
            }
            
            // Check for direct USDT field
            if (wallet['USDT'] != null) {
              final usdtData = wallet['USDT'];
              final availableBal = double.tryParse(usdtData['available']?.toString() ?? '0') ?? 0.0;
              final totalBal = double.tryParse(usdtData['total']?.toString() ?? '0') ?? 0.0;
              
              available += availableBal;
              total += totalBal > 0 ? totalBal : availableBal;
              
              debugPrint('💰💰 Found direct USDT in $walletType: available=$availableBal, total=$totalBal');
            }
          }
        }
        
        // Check for direct balance fields
        if (data['totalEquityUSDT'] != null) {
          final equity = double.tryParse(data['totalEquityUSDT'].toString()) ?? 0.0;
          total = equity;
          debugPrint('💰💰 Found totalEquityUSDT: $equity');
        }
        
        if (data['totalBalance'] != null) {
          final totalBal = double.tryParse(data['totalBalance'].toString()) ?? 0.0;
          total = totalBal;
          debugPrint('💰💰 Found totalBalance: $totalBal');
        }
        
        if (data['availableBalance'] != null) {
          final availableBal = double.tryParse(data['availableBalance'].toString()) ?? 0.0;
          available = availableBal;
          debugPrint('💰💰 Found availableBalance: $availableBal');
        }
      }
      
      debugPrint('💰✅ Manual extraction result - Total: $total, Available: $available');
    } catch (e) {
      debugPrint('💰❌ Manual extraction error: $e');
    }
    
    return {'total': total, 'available': available};
  }

  // Extract balance manually from API data (legacy method for fallback)
  double _extractBalanceFromData(dynamic data) {
    final balances = _extractBothBalancesFromData(data);
    return balances['total'] ?? 0.0;
  }

  // Fetch from individual wallet APIs as fallback
  Future<double> _fetchFromIndividualWallets() async {
    double total = 0.0;
    
    try {
      debugPrint('💰🔄 Fetching from individual wallet APIs...');
      
      // Try spot wallet
      try {
        final spotResult = await WalletService.getWalletBalance();
        if (spotResult['success'] == true && spotResult['data'] != null) {
          final spotData = spotResult['data'];
          if (spotData['balances'] != null) {
            final balances = spotData['balances'];
            if (balances is List) {
              for (var balance in balances) {
                if (balance['coin']?.toString().toUpperCase() == 'USDT') {
                  total += double.tryParse(balance['available']?.toString() ?? '0') ?? 0.0;
                  debugPrint('💰💰 Spot USDT: ${balance['available']}');
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('💰❌ Spot wallet failed: $e');
      }
      
      // Try other wallet types similarly...
      // (Add more wallet types as needed)
      
      debugPrint('💰✅ Individual wallets total: $total');
    } catch (e) {
      debugPrint('💰❌ Individual wallets error: $e');
    }
    
    return total;
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    UserService().initUserData();
    // Force refresh balance when screen becomes active (with rate limiting)
    debugPrint('Home Screen: didChangeDependencies called, refreshing balance');
    final now = DateTime.now();
    if (_lastApiFetchTime == null || now.difference(_lastApiFetchTime!) > _minApiFetchInterval) {
      _lastApiFetchTime = now;
      _fetchWalletBalance();
    } else {
      debugPrint('Home Screen: Skipping didChangeDependencies refresh, too soon');
    }
  }

    
  Future<void> _fetchMarketData() async {
    if (_isFetchingMarketData) return; // Prevent concurrent fetches
    _isFetchingMarketData = true;
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
      // Only log once — don't spam on DNS/network failures
      debugPrint('Market data fetch failed (network may be unavailable): $e');
    } finally {
      _isFetchingMarketData = false;
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
  
  bool _isFetchingMarketData = false;

  void _startPriceUpdates() {
    // Use 60s interval to avoid spamming Binance/CoinGecko when network is unstable
    _priceTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted && !_isFetchingMarketData) {
        _fetchMarketData();
      }
    });
  }

  void _startBalanceRefreshTimer() {
    // Refresh balance every 8 seconds for more responsive updates
    _balanceRefreshTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (mounted) {
        debugPrint('🔄⚡ Home Screen: WALLET-AWARE balance refresh tick ${timer.tick}');

        // Only fetch balance if enough time has passed since last fetch
        final now = DateTime.now();
        if (_lastApiFetchTime == null || now.difference(_lastApiFetchTime!) > _minApiFetchInterval) {
          _lastApiFetchTime = now;
          _fetchWalletBalance();
        } else {
          debugPrint('🔄⏱️ Home Screen: Skipping timer-based API fetch, too soon');
        }
        
        // Monitor WALLET socket connection health
        if (!SocketService.isConnected) {
          debugPrint('🔄❌ Home Screen: WALLET Socket disconnected, attempting reconnect...');
          _connectSocketService();
        } else {
          debugPrint('🔄✅ Home Screen: WALLET Socket connected, requesting updates...');
          // Periodically request wallet balance updates even if connected
          if (timer.tick % 3 == 0) { // Every 24 seconds
            debugPrint('🔄📡 Home Screen: Requesting WALLET balance updates...');
            SocketService.requestWalletSummary();
            SocketService.requestWalletBalance();
          }
        }
        
        // Comprehensive WALLET socket health check every 2 minutes
        if (timer.tick % 15 == 0) {
          _comprehensiveWalletSocketHealthCheck();
        }
      }
    });
  }

  // Comprehensive WALLET socket health check and recovery
  void _comprehensiveWalletSocketHealthCheck() {
    debugPrint('🔧🏥 Home Screen: Comprehensive WALLET socket health check...');
    
    final isConnected = SocketService.isConnected;
    final isConnecting = SocketService.isConnecting;
    
    debugPrint('🔧🏥 WALLET Socket Status - Connected: $isConnected, Connecting: $isConnecting');
    
    if (!isConnected && !isConnecting) {
      debugPrint('🔧🔄 Home Screen: WALLET Socket completely disconnected, forcing reconnection...');
      _connectSocketService();
    } else if (isConnected) {
      debugPrint('🔧💓 Home Screen: WALLET Socket heartbeat - requesting balance updates...');
      SocketService.requestWalletSummary();
      SocketService.requestWalletBalance();
      debugPrint('🔧✅ Home Screen: WALLET Socket health confirmed');
    }
  }
  
  void _showWithdrawalSelectionMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Withdrawal Type',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _buildWithdrawalOption(
                icon: Icons.currency_bitcoin,
                title: 'Withdraw Crypto',
                subtitle: 'Send crypto to external wallet',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const WithdrawCryptoScreen()));
                },
              ),
              const SizedBox(height: 16),
              _buildWithdrawalOption(
                icon: Icons.currency_rupee,
                title: 'Withdraw INR',
                subtitle: 'Withdraw to bank account',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const WithdrawINRScreen()));
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWithdrawalOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF84BD00).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF84BD00),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white54,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _handleActionTap(String action) {
    if (action == 'Deposit') {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const DepositScreen()));
    } else if (action == 'INR Deposit') {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const InrDepositScreen()));
    } else if (action == 'Withdraw') {
      _showWithdrawalSelectionMenu();
    } else if (action == 'Internal Deposit' || action == 'Inter send') {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SendScreen()));
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
            // Scrollable section - coin balances + tabs + crypto list
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
          // Available Balance Section
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
                _isBalanceVisible ? _availableBalance.toStringAsFixed(2) : '****',
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
            future: _getAvailableUSDEquivalent(),
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

  Future<double> _getAvailableUSDEquivalent() async {
    return _availableBalance;
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
      {'label': 'Inter send', 'icon': 'sendicon.png', 'iconData': Icons.arrow_circle_up},
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
          // Special handling for Spot tab with dropdown
          if (tab == 'Spot') {
            return GestureDetector(
              onTap: () => setState(() => _selectedTab = tab),
              child: Container(
                margin: const EdgeInsets.only(right: 30),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          'Spot',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white54,
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                          )
                        ),
                      ],
                    ),
                    if (isSelected) Container(margin: const EdgeInsets.only(top: 8), height: 3, width: 24, color: const Color(0xFF84BD00)),
                  ],
                ),
              ),
            );
          }
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

  // Show market selector dialog for Spot tab
  void _showSpotMarketSelector() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E20),
          title: const Text(
            'Select Market',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: _binanceMarketData.isEmpty
              ? const Center(
                  child: Text(
                    'No markets available',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  itemCount: _binanceMarketData.length,
                  itemBuilder: (context, index) {
                    final market = _binanceMarketData[index];
                    final symbol = market['symbol']?.toString() ?? 'BTCUSDT';
                    final baseSymbol = symbol.replaceAll('USDT', '');
                    final price = double.tryParse(market['price']?.toString() ?? '0.0') ?? 0.0;
                    final change = double.tryParse(market['priceChangePercent']?.toString() ?? '0.0') ?? 0.0;
                    final isSelected = symbol == _selectedSpotSymbol;

                    return ListTile(
                      leading: CoinIconMapper.getCoinIcon(baseSymbol, size: 32),
                      title: Text(
                        baseSymbol,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF84BD00) : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        '\$${_formatPrice(price)}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: change >= 0
                            ? const Color(0xFF00C087).withOpacity(0.2)
                            : const Color(0xFFFF3B30).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: change >= 0 ? const Color(0xFF00C087) : const Color(0xFFFF3B30),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedSpotSymbol = symbol;
                        });
                        Navigator.pop(context);
                      },
                      tileColor: isSelected ? const Color(0xFF84BD00).withOpacity(0.1) : null,
                    );
                  },
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
          ],
        );
      },
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

    // Show selected market data for Spot tab
    if (_selectedTab == 'Spot') {
      return _buildSpotMarketList();
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

  // Build market selector dropdown for Spot screen
  Widget _buildSpotMarketDropdown() {
    return GestureDetector(
      onTap: _showSpotMarketSelector,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF84BD00).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            CoinIconMapper.getCoinIcon(_selectedSpotSymbol.replaceAll('USDT', ''), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedSpotSymbol.replaceAll('USDT', ''),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '/USDT',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              color: Color(0xFF84BD00),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  // Build Spot tab market list - shows selected symbol details
  Widget _buildSpotMarketList() {
    // Find selected symbol data
    final selectedMarket = _binanceMarketData.firstWhere(
      (m) => m['symbol']?.toString() == _selectedSpotSymbol,
      orElse: () => <String, dynamic>{},
    );

    final hasData = selectedMarket.isNotEmpty;
    final symbol = hasData ? selectedMarket['symbol']?.toString() ?? _selectedSpotSymbol : _selectedSpotSymbol;
    final baseSymbol = symbol.replaceAll('USDT', '');
    final price = hasData ? double.tryParse(selectedMarket['price']?.toString() ?? '0.0') ?? 0.0 : 0.0;
    final change = hasData ? double.tryParse(selectedMarket['priceChangePercent']?.toString() ?? '0.0') ?? 0.0 : 0.0;
    final high24h = hasData ? double.tryParse(selectedMarket['highPrice']?.toString() ?? '0.0') ?? 0.0 : 0.0;
    final low24h = hasData ? double.tryParse(selectedMarket['lowPrice']?.toString() ?? '0.0') ?? 0.0 : 0.0;
    final volume = hasData ? double.tryParse(selectedMarket['quoteVolume']?.toString() ?? '0.0') ?? 0.0 : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Market selector dropdown - always visible
          _buildSpotMarketDropdown(),
          const SizedBox(height: 16),
          // Market data - shown when available
          if (hasData) ...[
            // Market header with large price
            Row(
            children: [
              CoinIconMapper.getCoinIcon(baseSymbol, size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      baseSymbol,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '/USDT',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
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
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: change >= 0
                        ? const Color(0xFF00C087).withOpacity(0.2)
                        : const Color(0xFFFF3B30).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: change >= 0 ? const Color(0xFF00C087) : const Color(0xFFFF3B30),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Market stats grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMarketStatItem('24h High', '\$${_formatPrice(high24h)}', Colors.white),
                    ),
                    Expanded(
                      child: _buildMarketStatItem('24h Low', '\$${_formatPrice(low24h)}', Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildMarketStatItem('24h Volume', _formatVolume(volume), Colors.white),
                    ),
                    Expanded(
                      child: _buildMarketStatItem('24h Change', '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%', 
                        change >= 0 ? const Color(0xFF00C087) : const Color(0xFFFF3B30)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Trade button
          if (hasData)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SpotScreen(initialSymbol: symbol),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF84BD00),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  'Trade $baseSymbol',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMarketStatItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
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
