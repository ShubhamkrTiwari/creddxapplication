import 'dart:async';

import 'package:flutter/material.dart';
import '../services/spot_service.dart';
import '../services/spot_socket_service.dart';
import '../services/binance_service.dart';
import '../services/wallet_service.dart';
import '../widgets/bitcoin_loading_indicator.dart';
import '../utils/coin_icon_mapper.dart';
import 'chart_screen.dart';

class SpotScreen extends StatefulWidget {
  final String? initialSymbol;
  
  const SpotScreen({super.key, this.initialSymbol});

  @override
  State<SpotScreen> createState() => _SpotScreenState();
}

class _SpotScreenState extends State<SpotScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // Temporary flag for Coming Soon mode - set to false when feature goes live
  final bool _isComingSoon = true;
  
  // Animation controllers for Coming Soon screen
  late AnimationController _comingSoonController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _fadeAnimation;
  
  bool _isBuy = true;
  double _currentPrice = 92076.6;
  double _amount = 0.0;
  double _sliderValue = 0.0;
  bool _isLoading = false;
  String _selectedSymbol = 'BTCUSDT';
  String _orderType = 'Limit'; // 'Limit' or 'Market'
  bool _isManualPrice = false; // Track if user manually entered price
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  
  // Available coins for amount dropdown
  List<Map<String, dynamic>> _availableCoins = [
    {'symbol': 'BTC', 'name': 'Bitcoin'},
    {'symbol': 'USDT', 'name': 'Tether'},
  ];
  String _selectedAmountCoin = 'BTC';
  
  // API data
  List<Map<String, dynamic>> _sellOrders = [];
  List<Map<String, dynamic>> _buyOrders = [];
  List<Map<String, dynamic>> _openOrders = [];
  List<Map<String, dynamic>> _closedOrders = [];
  List<Map<String, dynamic>> _symbols = [];
  
  // Slider expansion states
  bool _isOpenOrdersExpanded = true;
  bool _isClosedOrdersExpanded = true;
  Map<String, dynamic>? _balance;
  bool _isLoadingBalance = true;
  String? _balanceError;
  Map<String, dynamic>? _ticker;
  
  // Price tracking for order book animations
  double _previousBid = 0.0;
  double _previousAsk = 0.0;
  bool _isPriceUp = false;
  
  // Price flash animation
  bool _isPriceFlashing = false;
  Color _flashColor = Colors.white;
  Timer? _priceUpdateTimer;
  Map<String, dynamic>? _fees;
  Map<String, dynamic>? _healthStatus;
  bool _isWebSocketConnected = false;
  bool _isLoadingSymbols = false;
  StreamSubscription? _balanceSubscription;
  StreamSubscription? _orderbookSubscription;
  StreamSubscription? _ordersSubscription;
  StreamSubscription? _fillsSubscription;
  StreamSubscription? _tickerSubscription;
  StreamSubscription? _connectionSubscription;

  Timer? _connectionCheckTimer;
  bool _isScreenVisible = true;
  
  // Binance market data for dropdown
  List<Map<String, dynamic>> _binanceMarketData = [];
  bool _isLoadingMarkets = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize Coming Soon animations
    _comingSoonController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: -20).animate(
      CurvedAnimation(
        parent: _comingSoonController,
        curve: Curves.easeInOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _comingSoonController,
        curve: Curves.easeInOut,
      ),
    );
    
    // If Coming Soon mode is enabled, skip the rest of initialization
    if (_isComingSoon) {
      return;
    }
    
    // Use initial symbol if provided
    if (widget.initialSymbol != null && widget.initialSymbol!.isNotEmpty) {
      _selectedSymbol = widget.initialSymbol!;
      SpotService.currentSymbol = _selectedSymbol;
    }
    
    // Initialize with default balance immediately (will be updated via SocketService)
    _balance = null;
    _isLoadingBalance = true;
    
    // Restore persistent user orders
    _buyOrders = List<Map<String, dynamic>>.from(SpotService.userBuyOrders);
    _sellOrders = List<Map<String, dynamic>>.from(SpotService.userSellOrders);
    _selectedSymbol = SpotService.currentSymbol;
    
    // Initialize price controller
    _priceController.text = _currentPrice.toStringAsFixed(2);
    
    // Add listener to amount controller to update funds required display
    _amountController.addListener(_onAmountChanged);
    
    // Add fallback order book data initially to prevent empty display
    if (_sellOrders.isEmpty && _buyOrders.isEmpty) {
      _addFallbackOrderBookData();
    }
    
    // Load real market price immediately from Binance
    _loadRealMarketPrice();
    
    // Load market data for dropdown
    _loadBinanceMarketData();
    
    _updateAvailableCoins();
    _loadSpotData();
    _initializeWebSocket();
    _subscribeToBalance();
    _subscribeToConnectionState();
    
    // Register lifecycle observer
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        // App is visible again, reconnect socket if needed
        _isScreenVisible = true;
        debugPrint('SpotScreen: App resumed, checking socket connection...');
        if (!SpotSocketService.isConnected) {
          debugPrint('SpotScreen: Socket not connected, reconnecting...');
          SpotSocketService.connect();
          SpotSocketService.subscribe(_selectedSymbol);
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // App is not visible
        _isScreenVisible = false;
        break;
      case AppLifecycleState.hidden:
        _isScreenVisible = false;
        break;
    }
  }

  // Handle amount text changes to update funds required display
  void _onAmountChanged() {
    final value = _amountController.text;
    final newAmount = double.tryParse(value) ?? 0.0;
    if (newAmount != _amount) {
      setState(() {
        _amount = newAmount;
        // Update slider based on new amount
        final baseAsset = _selectedSymbol.endsWith('USDT')
            ? _selectedSymbol.substring(0, _selectedSymbol.length - 4)
            : _selectedSymbol.split('/').first;
        final isBaseAsset = _selectedAmountCoin == baseAsset;
        if (_isBuy) {
          if (isBaseAsset) {
            // Buying with BTC amount - check against max BTC we can buy with USDT
            final maxBtc = _balance != null
                ? (double.tryParse(_balance!['usdt_available']?.toString() ?? '0') ?? 0.0) / _currentPrice
                : 0.0;
            _sliderValue = maxBtc > 0 ? (newAmount / maxBtc).clamp(0.0, 1.0) : 0.0;
          } else {
            // Buying with USDT amount
            final maxUsdt = double.tryParse(_balance?['usdt_available']?.toString() ?? '0') ?? 0.0;
            _sliderValue = maxUsdt > 0 ? (newAmount / maxUsdt).clamp(0.0, 1.0) : 0.0;
          }
        } else {
          // Selling
          if (isBaseAsset) {
            // Selling BTC - check against available BTC
            final availableBase = _balance != null
                ? (double.tryParse(_balance!['free']?.toString() ?? '0') ?? 0.0)
                : 0.0;
            _sliderValue = availableBase > 0 ? (newAmount / availableBase).clamp(0.0, 1.0) : 0.0;
          } else {
            // Selling with USDT value - convert to BTC and check
            final availableBase = _balance != null
                ? (double.tryParse(_balance!['free']?.toString() ?? '0') ?? 0.0)
                : 0.0;
            final btcValue = _currentPrice > 0 ? newAmount / _currentPrice : 0.0;
            _sliderValue = availableBase > 0 ? (btcValue / availableBase).clamp(0.0, 1.0) : 0.0;
          }
        }
      });
    }
  }

  // Update price from Binance with animation
  Future<void> _updateOrderBookPrice() async {
    try {
      final binanceTicker = await BinanceService.getTickerData(_selectedSymbol);
      if (binanceTicker != null && binanceTicker['price'] != null) {
        final newPrice = binanceTicker['price'] as double;
        final oldPrice = _currentPrice;
        
        if (newPrice > 0 && mounted && newPrice != oldPrice) {
          // Determine price direction
          final isUp = newPrice > oldPrice;
          
          setState(() {
            _currentPrice = newPrice;
            _isPriceUp = isUp;
            _isPriceFlashing = true;
            _flashColor = isUp ? const Color(0xFF84BD00) : Colors.red;
            
            // Update ticker data
            _ticker ??= {};
            _ticker!['last_price'] = newPrice;
            _ticker!['price_change_24h'] = binanceTicker['priceChange'];
            _ticker!['price_change_percent_24h'] = binanceTicker['priceChangePercent'];
            _ticker!['volume_24h'] = binanceTicker['volume'];
            _ticker!['high_24h'] = binanceTicker['highPrice'];
            _ticker!['low_24h'] = binanceTicker['lowPrice'];
          });
          
          // Stop flash after 500ms
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() {
                _isPriceFlashing = false;
              });
            }
          });
        }
      }
    } catch (e) {
      print('Error updating order book price: $e');
    }
  }
  
  // Load real market price from Binance API immediately
  Future<void> _loadRealMarketPrice() async {
    try {
      print('Loading real market price for $_selectedSymbol from Binance...');
      final binanceTicker = await BinanceService.getTickerData(_selectedSymbol);
      if (binanceTicker != null && binanceTicker['price'] != null) {
        final realPrice = binanceTicker['price'] as double;
        if (realPrice > 0 && mounted) {
          setState(() {
            _currentPrice = realPrice;
            _ticker ??= {};
            _ticker!['last_price'] = realPrice;
            _ticker!['price_change_24h'] = binanceTicker['priceChange'];
            _ticker!['price_change_percent_24h'] = binanceTicker['priceChangePercent'];
            _ticker!['volume_24h'] = binanceTicker['volume'];
            _ticker!['high_24h'] = binanceTicker['highPrice'];
            _ticker!['low_24h'] = binanceTicker['lowPrice'];
          });
          print('Real market price loaded: $_currentPrice');
        }
      }
    } catch (e) {
      print('Error loading real market price: $e');
    }
  }

  void _updateAvailableCoins() {
    if (!mounted) return;
    setState(() {
      String baseAsset;
      String quoteAsset;
      
      if (_selectedSymbol.contains('/')) {
        final parts = _selectedSymbol.split('/');
        baseAsset = parts[0];
        quoteAsset = parts[1];
      } else if (_selectedSymbol.endsWith('USDT')) {
        baseAsset = _selectedSymbol.substring(0, _selectedSymbol.length - 4);
        quoteAsset = 'USDT';
      } else {
        baseAsset = 'BTC';
        quoteAsset = 'USDT';
      }
      
      _availableCoins = [
        {'symbol': baseAsset, 'name': baseAsset},
        {'symbol': quoteAsset, 'name': quoteAsset},
      ];
      
      // Ensure selected amount coin is valid for the new pair
      if (_selectedAmountCoin != baseAsset && _selectedAmountCoin != quoteAsset) {
        _selectedAmountCoin = baseAsset;
      }
    });
  }

  void _subscribeToConnectionState() {
    _connectionSubscription?.cancel();
    _connectionSubscription = SpotSocketService.connectionStream.listen((state) {
      setState(() {
        _isWebSocketConnected = state == SocketConnectionState.connected;
      });
    });
  }

  void _subscribeToBalance() {
    _balanceSubscription?.cancel();
    _balanceSubscription = SpotSocketService.balanceStream.listen((data) {
      debugPrint('Socket balance update received: $data');
      if (mounted && data['type'] == 'balance_update') {
        setState(() {
          // Handle both formats: data['assets'] or data['data']['assets']
          final assets = data['assets'] as List? ??
                        (data['data'] as Map<String, dynamic>?)?['assets'] as List?;
          debugPrint('Parsed assets from socket: $assets');
          if (assets != null && assets.isNotEmpty) {
            // Parse symbol to get base and quote assets (e.g., BTCUSDT -> BTC, USDT)
            String baseAssetStr;
            String quoteAssetStr;
            
            if (_selectedSymbol.contains('/')) {
              // Format: BTC/USDT
              final parts = _selectedSymbol.split('/');
              baseAssetStr = parts[0];
              quoteAssetStr = parts[1];
            } else if (_selectedSymbol.endsWith('USDT')) {
              // Format: BTCUSDT
              baseAssetStr = _selectedSymbol.substring(0, _selectedSymbol.length - 4);
              quoteAssetStr = 'USDT';
            } else {
              // Default fallback
              baseAssetStr = 'BTC';
              quoteAssetStr = 'USDT';
            }

            debugPrint('Looking for base: $baseAssetStr, quote: $quoteAssetStr in assets');

            final quoteAsset = assets.firstWhere(
              (a) => a['asset'] == quoteAssetStr,
              orElse: () => null,
            );
            final baseAsset = assets.firstWhere(
              (a) => a['asset'] == baseAssetStr,
              orElse: () => null,
            );

            _balance = {
              'usdt_available': double.tryParse(quoteAsset?['available']?.toString() ?? '0.0') ?? 0.0,
              'usdt_locked': double.tryParse(quoteAsset?['locked']?.toString() ?? '0.0') ?? 0.0,
              'free': double.tryParse(baseAsset?['available']?.toString() ?? '0.0') ?? 0.0,
              'btc_locked': double.tryParse(baseAsset?['locked']?.toString() ?? '0.0') ?? 0.0,
            };
            _isLoadingBalance = false;
            debugPrint('Balance updated from socket: $_balance');
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _comingSoonController.dispose();
    _connectionCheckTimer?.cancel();
    _priceUpdateTimer?.cancel();
    _priceController.dispose();
    _amountController.dispose();
    _balanceSubscription?.cancel();
    _orderbookSubscription?.cancel();
    _ordersSubscription?.cancel();
    _fillsSubscription?.cancel();
    _tickerSubscription?.cancel();
    _connectionSubscription?.cancel();
    SpotSocketService.unsubscribe(_selectedSymbol);
    
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    
    super.dispose();
  }

  // Initialize WebSocket for real-time data
  void _initializeWebSocket() {
    try {
      // Connect to SpotSocketService
      SpotSocketService.connect();
      
      // Subscribe to symbol for order book and trades
      SpotSocketService.subscribe(_selectedSymbol);
      
      // Listen to order book updates (WebSocket event type: 'book')
      _orderbookSubscription?.cancel();
      _orderbookSubscription = SpotSocketService.orderbookStream.listen((data) {
        final eventType = data['type'] ?? data['event'];
        final symbol = data['symbol'] ?? data['data']?['symbol'];
        if (mounted && eventType == 'book' && symbol == _selectedSymbol) {
          setState(() {
            final orderBookData = data['data'];
            
            if (orderBookData != null && 
                (orderBookData['asks'] != null || orderBookData['bids'] != null)) {
              final asks = (orderBookData['asks'] as List? ?? [])
                  .take(10)
                  .map((level) {
                    if (level is List && level.length >= 2) {
                      return {'price': level[0], 'amount': level[1]};
                    } else if (level is Map) {
                      return {'price': level['price'], 'amount': level['amount']};
                    }
                    return {'price': 0.0, 'amount': 0.0};
                  })
                  .toList();
              final bids = (orderBookData['bids'] as List? ?? [])
                  .take(10)
                  .map((level) {
                    if (level is List && level.length >= 2) {
                      return {'price': level[0], 'amount': level[1]};
                    } else if (level is Map) {
                      return {'price': level['price'], 'amount': level['amount']};
                    }
                    return {'price': 0.0, 'amount': 0.0};
                  })
                  .toList();
              
              final mySellOrders = _sellOrders.where((o) => o['isMyOrder'] == true).toList();
              final myBuyOrders = _buyOrders.where((o) => o['isMyOrder'] == true).toList();
              
              _sellOrders = [...mySellOrders, ...List<Map<String, dynamic>>.from(asks)];
              _buyOrders = [...myBuyOrders, ...List<Map<String, dynamic>>.from(bids)];
              
              _sellOrders.sort((a, b) => (a['price'] as double).compareTo(b['price'] as double));
              _buyOrders.sort((a, b) => (b['price'] as double).compareTo(a['price'] as double));
            }
            
            final newBestBid = getBestBid();
            final newBestAsk = getBestAsk();
            
            if (newBestBid != null && _previousBid > 0) {
              _isPriceUp = newBestBid > _previousBid;
            }
            
            if (newBestBid != null) _previousBid = newBestBid;
            if (newBestAsk != null) _previousAsk = newBestAsk;
            
            if (newBestBid != null && newBestAsk != null && newBestBid > 0 && newBestAsk > 0) {
              final midPrice = (newBestBid + newBestAsk) / 2;
              if (midPrice > 0) {
                _currentPrice = midPrice;
              }
            }
            
            _isWebSocketConnected = true;
          });
        }
      });
      
      // Subscribe to order updates
      _ordersSubscription?.cancel();
      _ordersSubscription = SpotSocketService.ordersStream.listen((data) {
        if (mounted && data['type'] == 'order_update') {
          setState(() {
            _isWebSocketConnected = true;
          });
          final orderData = data['data'];
          final status = orderData['status'];
          final symbol = orderData['symbol'] ?? _selectedSymbol;
          final side = orderData['side'] ?? 'Buy';
          final qty = orderData['qty'] ?? 0.0;

          switch (status) {
            case 'pending':
              _loadOpenOrders();
              break;
            case 'partially_filled':
              final filledQty = orderData['filled_qty'] ?? 0.0;
              final remainingQty = qty - filledQty;
              _loadOpenOrders();
              _loadBalance(forceRefresh: true);
              _showMessage(
                '$symbol: Partially filled ${filledQty.toStringAsFixed(6)} / ${qty.toStringAsFixed(6)}. Remaining: ${remainingQty.toStringAsFixed(6)}',
                isError: false,
              );
              break;
            case 'filled':
              _loadOpenOrders();
              _loadClosedOrders();
              _loadBalance(forceRefresh: true);
              _showMessage('$symbol: Order fully filled ${qty.toStringAsFixed(6)}', isError: false);
              break;
            case 'cancelled':
              _loadOpenOrders();
              _loadClosedOrders();
              _loadBalance(forceRefresh: true);
              _showMessage('$symbol: Order cancelled', isError: false);
              break;
            case 'rejected':
              final reason = orderData['reason'] ?? 'Order rejected';
              _loadOpenOrders();
              _loadClosedOrders();
              _loadBalance(forceRefresh: true);
              _showMessage('$symbol: Order rejected - $reason', isError: true);
              break;
          }
        }
      });

      // Subscribe to fill events - shows trade execution with fee details
      _fillsSubscription?.cancel();
      _fillsSubscription = SpotSocketService.fillsStream.listen((data) {
        if (mounted && data['type'] == 'fill') {
          setState(() {
            _isWebSocketConnected = true;
          });
          final fillData = data['data'] ?? data;
          final symbol = fillData['symbol'] ?? _selectedSymbol;
          final side = fillData['side'] ?? 'Buy';
          final qty = fillData['qty'] ?? fillData['quantity'] ?? 0.0;
          final price = fillData['price'] ?? 0.0;
          final fee = fillData['fee'] ?? 0.0;
          final feeAsset = fillData['fee_asset'] ?? 'USDT';
          final isMaker = fillData['is_maker'] ?? false;

          debugPrint('Fill received: $fillData');

          
          // Show fill notification with fee info
          final total = qty * price;
          _showMessage(
            '$symbol: ${side.toUpperCase()} filled ${qty.toStringAsFixed(6)} @ \$${price.toStringAsFixed(2)} '
            '(Total: \$${total.toStringAsFixed(2)}, Fee: ${fee.toStringAsFixed(4)} $feeAsset)',
            isError: false,
          );

          // Refresh balance after fill
          _loadBalance(forceRefresh: true);
        }
      });

      // Subscribe to ticker updates from spot socket
      _tickerSubscription?.cancel();
      _tickerSubscription = SpotSocketService.tickerStream.listen((data) {
        if (mounted) {
          final tickerData = data['data'] ?? data;
          final symbol = tickerData['symbol'] ?? data['symbol'];
          
          // Only update if it's for our selected symbol
          if (symbol == _selectedSymbol) {
            final newPrice = double.tryParse(tickerData['last_price']?.toString() ?? '');
            final oldPrice = _currentPrice;
            
            if (newPrice != null && newPrice > 0) {
              final isUp = newPrice > oldPrice;
              
              setState(() {
                _currentPrice = newPrice;
                _isPriceUp = isUp;
                _isPriceFlashing = true;
                _flashColor = isUp ? const Color(0xFF84BD00) : Colors.red;
                
                // Update ticker data from socket
                _ticker = {
                  'last_price': newPrice,
                  'best_bid': tickerData['best_bid'],
                  'best_ask': tickerData['best_ask'],
                  'volume_24h': tickerData['volume_24h'],
                  'high_24h': tickerData['high_24h'],
                  'low_24h': tickerData['low_24h'],
                  'price_change_24h': tickerData['change_24h'],
                  'price_change_percent_24h': tickerData['change_pct_24h'],
                  'trade_count': tickerData['trade_count'],
                };
                
                // Update price controller if not manually entered
                if (!_isManualPrice && _orderType == 'Market') {
                  _priceController.text = newPrice.toStringAsFixed(2);
                }
              });
              
              // Stop flash after 500ms
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  setState(() {
                    _isPriceFlashing = false;
                  });
                }
              });
            }
          }
        }
      });
    } catch (e) {
      debugPrint('Error initializing WebSocket: $e');
      if (mounted) {
        setState(() {
          _isWebSocketConnected = false;
        });
      }
    }
  }

  // Start periodic connection check
  void _startConnectionCheck() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        // SocketService handles its own connection/reconnection
        // We can just keep _isWebSocketConnected as true if we trust SocketService
        if (!_isWebSocketConnected) {
          setState(() {
            _isWebSocketConnected = true;
          });
        }
      }
    });
  }

  // Load Binance market data for dropdown
  Future<void> _loadBinanceMarketData() async {
    try {
      setState(() {
        _isLoadingMarkets = true;
      });
      
      final marketData = await BinanceService.getTopTradingPairs(limit: 50);
      
      if (mounted) {
        setState(() {
          _binanceMarketData = marketData;
          _isLoadingMarkets = false;
        });
      }
    } catch (e) {
      print('Error loading Binance market data: $e');
      if (mounted) {
        setState(() {
          _isLoadingMarkets = false;
        });
      }
    }
  }

  // Refresh all data
  Future<void> _refreshData() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      await _loadSpotData();
      _initializeWebSocket();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showMessage('Data refreshed successfully!', isError: false);
      }
    } catch (e) {
      print('Error refreshing data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showMessage('Error refreshing data: $e', isError: true);
      }
    }
  }

  // Load all spot data
  Future<void> _loadSpotData() async {
    await Future.wait([
      _loadTicker(),
      _loadOrderBook(),
      _loadOpenOrders(),
      _loadClosedOrders(),
      _loadBalance(),
      _loadSymbols(),
      _loadFees(),
      _loadHealthStatus(),
    ]);
  }

  // Load symbols
  Future<void> _loadSymbols() async {
    try {
      setState(() {
        _isLoadingSymbols = true;
      });
      
      final result = await SpotService.getSymbols();
      if (result['success'] && result['data'] != null) {
        setState(() {
          _symbols = List<Map<String, dynamic>>.from(result['data'] ?? []);
          _isLoadingSymbols = false;
        });
      } else {
        setState(() {
          _isLoadingSymbols = false;
        });
      }
    } catch (e) {
      print('Error loading symbols: $e');
      setState(() {
        _isLoadingSymbols = false;
      });
    }
  }

  // Load fees
  Future<void> _loadFees() async {
    try {
      final result = await SpotService.getFees();
      if (result['success'] && result['data'] != null) {
        setState(() {
          _fees = result['data'];
        });
      }
    } catch (e) {
      print('Error loading fees: $e');
    }
  }

  // Load health status
  Future<void> _loadHealthStatus() async {
    try {
      final result = await SpotService.getHealth();
      if (result['success'] && result['data'] != null) {
        setState(() {
          _healthStatus = result['data'];
        });
      }
    } catch (e) {
      print('Error loading health status: $e');
    }
  }

  // Load ticker data - uses real market price from Binance only
  Future<void> _loadTicker() async {
    try {
      // Always try to get real price from Binance first
      print('Loading real market price for $_selectedSymbol from Binance...');
      final binanceTicker = await BinanceService.getTickerData(_selectedSymbol);
      if (binanceTicker != null && binanceTicker['price'] != null) {
        final realPrice = binanceTicker['price'] as double;
        if (realPrice > 0) {
          setState(() {
            _currentPrice = realPrice;
            _ticker ??= {};
            _ticker!['last_price'] = realPrice;
            _ticker!['price_change_24h'] = binanceTicker['priceChange'];
            _ticker!['price_change_percent_24h'] = binanceTicker['priceChangePercent'];
            _ticker!['volume_24h'] = binanceTicker['volume'];
            _ticker!['high_24h'] = binanceTicker['highPrice'];
            _ticker!['low_24h'] = binanceTicker['lowPrice'];
          });
          print('Real market price loaded: $_currentPrice');
          return; // Exit early since we got real price
        }
      }
      
      // Fallback to SpotService only if Binance fails
      final result = await SpotService.getTicker(_selectedSymbol);
      if (result['success']) {
        final data = result['data'];
        if (data != null && data['last_price'] != null) {
          final price = double.tryParse(data['last_price'].toString()) ?? 0.0;
          if (price > 0) {
            setState(() {
              _currentPrice = price;
              _ticker = data;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading ticker: $e');
    }
  }

  // Load order book
  Future<void> _loadOrderBook() async {
    try {
      final result = await SpotService.getOrderBook(_selectedSymbol);
      if (result['success'] && result['data'] != null) {
        setState(() {
          final data = result['data'];
          // Convert [price, quantity] arrays to maps for existing UI
          final asks = (data['asks'] as List? ?? [])
              .map((level) {
                if (level is List && level.length >= 2) {
                  return {'price': level[0], 'amount': level[1]};
                } else if (level is Map) {
                  return {'price': level['price'], 'amount': level['amount']};
                }
                return {'price': 0.0, 'amount': 0.0};
              })
              .toList();
          final bids = (data['bids'] as List? ?? [])
              .map((level) {
                if (level is List && level.length >= 2) {
                  return {'price': level[0], 'amount': level[1]};
                } else if (level is Map) {
                  return {'price': level['price'], 'amount': level['amount']};
                }
                return {'price': 0.0, 'amount': 0.0};
              })
              .toList();
          
          _sellOrders = List<Map<String, dynamic>>.from(asks);
          _buyOrders = List<Map<String, dynamic>>.from(bids);
          
          print('Order book loaded: ${_sellOrders.length} asks, ${_buyOrders.length} bids');
        });
      } else {
        print('Order book API failed: ${result['error']}');
        // Add fallback mock data to prevent empty order book
        _addFallbackOrderBookData();
      }
    } catch (e) {
      print('Error loading order book: $e');
      // Add fallback mock data to prevent empty order book
      _addFallbackOrderBookData();
    }
  }

  // Add fallback order book data when API fails
  void _addFallbackOrderBookData() {
    final basePrice = _currentPrice > 0 ? _currentPrice : 92076.6;
    final List<Map<String, dynamic>> mockSellOrders = [];
    final List<Map<String, dynamic>> mockBuyOrders = [];
    
    // Generate mock sell orders (asks) - prices above current price
    for (int i = 0; i < 10; i++) {
      final price = basePrice + (i + 1) * 10;
      final amount = (0.1 + (i * 0.05)) * (1 - (i * 0.1)); // Decreasing amounts
      mockSellOrders.add({
        'price': price,
        'amount': amount,
        'isMyOrder': false,
      });
    }
    
    // Generate mock buy orders (bids) - prices below current price
    for (int i = 0; i < 10; i++) {
      final price = basePrice - (i + 1) * 10;
      final amount = (0.1 + (i * 0.05)) * (1 - (i * 0.1)); // Decreasing amounts
      mockBuyOrders.add({
        'price': price,
        'amount': amount,
        'isMyOrder': false,
      });
    }
    
    setState(() {
      // Preserve user orders if they exist
      final mySellOrders = _sellOrders.where((o) => o['isMyOrder'] == true).toList();
      final myBuyOrders = _buyOrders.where((o) => o['isMyOrder'] == true).toList();
      
      _sellOrders = [...mySellOrders, ...mockSellOrders];
      _buyOrders = [...myBuyOrders, ...mockBuyOrders];
      
      // Sort properly
      _sellOrders.sort((a, b) => (a['price'] as double).compareTo(b['price'] as double));
      _buyOrders.sort((a, b) => (b['price'] as double).compareTo(a['price'] as double));
      
      print('Fallback order book data added');
    });
  }

  
  // Load open orders
  Future<void> _loadOpenOrders() async {
    try {
      print('Loading open orders for symbol: $_selectedSymbol');
      final result = await SpotService.getOpenOrders(symbol: _selectedSymbol);
      print('Open orders result: $result');
      
      if (result['success'] && result['data'] != null) {
        final ordersData = result['data'];
        print('Orders data type: ${ordersData.runtimeType}');
        print('Orders data: $ordersData');
        setState(() {
          if (ordersData is List) {
            _openOrders = List<Map<String, dynamic>>.from(ordersData);
          } else {
            _openOrders = [];
          }
          print('Open orders loaded: ${_openOrders.length} orders');
        });
      } else {
        print('Open orders error: ${result['error']}');
        setState(() {
          _openOrders = [];
        });
      }
    } catch (e) {
      print('Error loading open orders: $e');
      setState(() {
        _openOrders = [];
      });
    }
  }

  // Load closed orders
  Future<void> _loadClosedOrders() async {
    try {
      print('Loading closed orders for symbol: $_selectedSymbol');
      final result = await SpotService.getUserTradeHistory(symbol: _selectedSymbol);
      print('Closed orders result: $result');
      
      if (result['success'] && result['data'] != null) {
        final ordersData = result['data'];
        print('Closed orders data type: ${ordersData.runtimeType}');
        
        setState(() {
          if (ordersData is List) {
            _closedOrders = List<Map<String, dynamic>>.from(ordersData);
          } else {
            _closedOrders = [];
          }
          print('Loaded ${_closedOrders.length} closed orders');
        });
      } else {
        print('Failed to load closed orders: ${result['error']}');
        setState(() {
          _closedOrders = [];
        });
      }
    } catch (e) {
      print('Error loading closed orders: $e');
      setState(() {
        _closedOrders = [];
      });
    }
  }

  // Load balance with optional force refresh
  Future<void> _loadBalance({bool forceRefresh = false}) async {
    try {
      setState(() {
        _isLoadingBalance = true;
        _balanceError = null;
      });
      print('Loading balance... (forceRefresh: $forceRefresh)');
      
      // Try SpotService first
      final result = await SpotService.getBalance(forceRefresh: forceRefresh);
      print('SpotService Balance API result: $result');
      
      // Also fetch from WalletService as fallback for spotBalance
      final walletResult = await WalletService.getAllWalletBalances();
      print('WalletService Balance API result: $walletResult');
      
      double usdtAvailable = 0.0;
      double usdtLocked = 0.0;
      double btcFree = 0.0;
      bool gotBalance = false;
      
      // Try to get balance from SpotService
      if (result['success'] == true && result['data'] != null) {
        final spotData = result['data'];
        usdtAvailable = double.tryParse(spotData['usdt_available']?.toString() ?? '0.0') ?? 0.0;
        usdtLocked = double.tryParse(spotData['usdt_locked']?.toString() ?? '0.0') ?? 0.0;
        btcFree = double.tryParse(spotData['free']?.toString() ?? '0.0') ?? 0.0;
        gotBalance = true;
        print('Balance from SpotService: USDT=$usdtAvailable, BTC=$btcFree');
      }
      
      // If SpotService failed or returned 0, try WalletService spotBalance
      if ((!gotBalance || usdtAvailable == 0.0) && 
          walletResult['success'] == true && 
          walletResult['data'] != null &&
          walletResult['data']['spotBalance'] != null) {
        final spotBalance = double.tryParse(walletResult['data']['spotBalance'].toString()) ?? 0.0;
        if (spotBalance > 0) {
          usdtAvailable = spotBalance;
          print('Balance from WalletService spotBalance: $spotBalance');
        }
      }
      
      setState(() {
        _balance = {
          'user_id': 1,
          'usdt_available': usdtAvailable,
          'usdt_locked': usdtLocked,
          'free': btcFree,
        };
        _isLoadingBalance = false;
        print('Final Balance loaded: $_balance');
        print('USDT Available: ${_balance?['usdt_available']}');
        print('USDT Locked: ${_balance?['usdt_locked']}');
        print('Free: ${_balance?['free']}');
      });
    } catch (e) {
      print('Error loading balance: $e');
      setState(() {
        _isLoadingBalance = false;
        _balanceError = 'Error: $e';
        // Keep existing balance or set default
        _balance ??= {
          'user_id': 1,
          'usdt_available': 0.0,
          'usdt_locked': 0.0,
          'free': 0.0,
        };
      });
    }
  }

  // Check if user has sufficient balance for the order
  bool _hasSufficientBalance() {
    final baseAsset = _selectedSymbol.endsWith('USDT')
        ? _selectedSymbol.substring(0, _selectedSymbol.length - 4)
        : _selectedSymbol.split('/').first;
    final isBaseAsset = _selectedAmountCoin == baseAsset;
    final effectivePrice = _orderType == 'Market' ? _currentPrice :
                          (double.tryParse(_priceController.text) ?? _currentPrice);
    
    if (_isBuy) {
      // Buying: need sufficient USDT
      final requiredUsdt = isBaseAsset ? (_amount * effectivePrice) : _amount;
      final availableUsdt = double.tryParse(_balance?['usdt_available']?.toString() ?? '0') ?? 0.0;
      return availableUsdt >= requiredUsdt;
    } else {
      // Selling: need sufficient base asset (BTC)
      final requiredBase = isBaseAsset ? _amount : (_amount / effectivePrice);
      final availableBase = double.tryParse(_balance?['free']?.toString() ?? '0') ?? 0.0;
      return availableBase >= requiredBase;
    }
  }

  // Get required and available amounts for error messages
  Map<String, double> _getBalanceInfo() {
    final baseAsset = _selectedSymbol.endsWith('USDT')
        ? _selectedSymbol.substring(0, _selectedSymbol.length - 4)
        : _selectedSymbol.split('/').first;
    final isBaseAsset = _selectedAmountCoin == baseAsset;
    final effectivePrice = _orderType == 'Market' ? _currentPrice :
                          (double.tryParse(_priceController.text) ?? _currentPrice);
    
    if (_isBuy) {
      final requiredUsdt = isBaseAsset ? (_amount * effectivePrice) : _amount;
      final availableUsdt = double.tryParse(_balance?['usdt_available']?.toString() ?? '0') ?? 0.0;
      return {'required': requiredUsdt, 'available': availableUsdt};
    } else {
      final requiredBase = isBaseAsset ? _amount : (_amount / effectivePrice);
      final availableBase = double.tryParse(_balance?['free']?.toString() ?? '0') ?? 0.0;
      return {'required': requiredBase, 'available': availableBase};
    }
  }

  // Place order
  Future<void> _placeOrder() async {
    if (_amount <= 0) {
      _showMessage('Please enter a valid amount', isError: true);
      return;
    }

    // Calculate minimum quantity validation
    final baseAsset = _selectedSymbol.endsWith('USDT')
        ? _selectedSymbol.substring(0, _selectedSymbol.length - 4)
        : _selectedSymbol.split('/').first;
    final isBaseAsset = _selectedAmountCoin == baseAsset;
    final effectivePrice = _orderType == 'Market' ? _currentPrice :
                          (double.tryParse(_priceController.text) ?? _currentPrice);

    // For Market orders, ensure price is valid
    if (_orderType == 'Market' && (effectivePrice <= 0 || effectivePrice.isNaN)) {
      _showMessage('Market price not available. Please try again.', isError: true);
      return;
    }

    final minQty = _getMinQty(_selectedSymbol);
    final currentQty = isBaseAsset ? _amount : (_amount / effectivePrice);

    // Debug print for Market orders
    if (_orderType == 'Market') {
      print('Market Order Validation: amount=$_amount, price=$effectivePrice, qty=$currentQty, minQty=$minQty');
    }

    if (currentQty < minQty) {
      _showMessage('Order quantity is below minimum ($minQty $baseAsset)', isError: true);
      return;
    }

    // Check sufficient balance
    if (!_hasSufficientBalance()) {
      final balanceInfo = _getBalanceInfo();
      final asset = _isBuy ? 'USDT' : baseAsset;
      _showMessage(
        'Insufficient balance. Required: ${balanceInfo['required']?.toStringAsFixed(4)} $asset, '
        'Available: ${balanceInfo['available']?.toStringAsFixed(4)} $asset',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Standard spot trading logic:
      // In a real exchange, if you have USDT and want BTC, you "Buy BTC" (Side: Buy, Qty in BTC)
      // If you have BTC and want USDT, you "Sell BTC" (Side: Sell, Qty in BTC)
      // Regardless of what coin you entered in the UI, the API side is determined by your intention relative to the base asset.

      final baseAsset = _selectedSymbol.endsWith('USDT') 
          ? _selectedSymbol.substring(0, _selectedSymbol.length - 4) 
          : _selectedSymbol.split('/').first;
      
      final isBaseAsset = _selectedAmountCoin == baseAsset;

      // API Side is always relative to the Base Asset (e.g. BTC)
      // If user selected BTC and clicks Buy -> Side: Buy
      // If user selected BTC and clicks Sell -> Side: Sell
      // If user selected USDT and clicks Buy -> Side: Sell (Selling BTC to get USDT)
      // If user selected USDT and clicks Sell -> Side: Buy (Buying BTC using USDT)
      final String apiSide;
      if (isBaseAsset) {
        apiSide = _isBuy ? 'Buy' : 'Sell';
      } else {
        // We are trading the quote asset (USDT)
        apiSide = _isBuy ? 'Sell' : 'Buy';
      }

      // The qty for the API must ALWAYS be the base asset (BTC)
      final double qty;
      final priceInput = double.tryParse(_priceController.text) ?? _currentPrice;
      final effectivePrice = _orderType == 'Market' ? _currentPrice : priceInput;
      
      if (isBaseAsset) {
        qty = _amount;
      } else {
        // User entered amount in USDT, convert to BTC
        qty = _amount / effectivePrice;
      }
      
      
      // Calculate total value
      final total = isBaseAsset ? (qty * effectivePrice) : _amount;
      
      // Show order confirmation dialog
      final confirmed = await _showOrderConfirmation(
        side: apiSide,
        orderType: _orderType,
        qty: qty,
        price: effectivePrice,
        symbol: _selectedSymbol,
        total: total,
      );
      
      if (!confirmed) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      print('=== ORDER PLACEMENT ===');
      print('Amount (input): $_amount $_selectedAmountCoin');
      print('Qty (Base Asset): $qty');
      print('Price: $effectivePrice');
      print('Order Type: $_orderType');
      print('Side (User): ${_isBuy ? 'Buy' : 'Sell'}');
      print('Side (API): $apiSide');
      print('Symbol: $_selectedSymbol');
      print('Total: \$$total');
      print('====================');
      
      final result = await SpotService.placeOrder(
        symbol: _selectedSymbol,
        side: apiSide,
        orderType: _orderType,
        qty: qty,
        price: _orderType == 'Market' ? 0.0 : (double.tryParse(_priceController.text) ?? 0.0),
      );

      print('Order result: $result');
      print('Result data type: ${result['data']?.runtimeType}');

      // Handle both bool and String types for success
      final isSuccess = result['success'] is bool ? result['success'] : result['success']?.toString() == 'true';
      if (isSuccess) {
        final dynamic rawData = result['data'];
        Map<String, dynamic>? orderData;
        
        // Handle if data is List or Map
        if (rawData is List && rawData.isNotEmpty) {
          orderData = rawData.first as Map<String, dynamic>?;
        } else if (rawData is Map<String, dynamic>) {
          orderData = rawData;
        }
        
        final orderId = orderData?['order_id']?.toString() ?? orderData?['id']?.toString();

        // Show success message with cancel action
        if (orderId != null && _orderType == 'Limit') {
          _showOrderPlacedWithCancel(orderId, _selectedSymbol, effectivePrice, apiSide);
        } else {
          _showMessage('Order placed successfully!');
        }
        
        // Add order to order book immediately for visual feedback
        if (orderData != null) {
          final displayPrice = _orderType == 'Market' ? _currentPrice : effectivePrice;
          
          setState(() {
            
            // Add to order book for limit orders
            if (_orderType == 'Limit') {
              final newOrder = {
                'price': displayPrice,
                'amount': _amount,
                'side': _isBuy ? 'Buy' : 'Sell',
                'order_type': _orderType,
                'isMyOrder': true,
              };
              if (_isBuy) {
                _buyOrders.insert(0, newOrder);
                _buyOrders.sort((a, b) => (b['price'] as double).compareTo(a['price'] as double));
              } else {
                _sellOrders.insert(0, newOrder);
                _sellOrders.sort((a, b) => (a['price'] as double).compareTo(b['price'] as double));
              }
            }
            
            // Save to persistent storage
            SpotService.userBuyOrders = List<Map<String, dynamic>>.from(_buyOrders.where((o) => o['isMyOrder'] == true));
            SpotService.userSellOrders = List<Map<String, dynamic>>.from(_sellOrders.where((o) => o['isMyOrder'] == true));
          });
        }
        
        _loadOpenOrders(); // Refresh open orders
        _loadOrderBook(); // Refresh order book to show new order
        _loadBalance(forceRefresh: true); // Refresh balance with force
        
        // Multiple delayed retries to ensure backend has processed balance update
        for (int i = 1; i <= 3; i++) {
          Future.delayed(Duration(milliseconds: 500 * i), () {
            if (mounted) {
              print('Delayed balance refresh #$i');
              _loadBalance(forceRefresh: true);
            }
          });
        }
        
        setState(() {
          _amount = 0.0;
          _sliderValue = 0.0;
        });
      } else {
        // Enhanced error handling with specific messages
        final errorMsg = result['error']?.toString() ?? 'Order placement failed';
        final errorLower = errorMsg.toLowerCase();
        
        String userFriendlyError;
        if (errorLower.contains('insufficient') || errorLower.contains('balance')) {
          userFriendlyError = 'Insufficient balance to place this order';
        } else if (errorLower.contains('margin') || errorLower.contains('position')) {
          userFriendlyError = 'Margin requirement not met. Please check your positions';
        } else if (errorLower.contains('price') || errorLower.contains('range')) {
          userFriendlyError = 'Invalid price. Please check current market price';
        } else if (errorLower.contains('quantity') || errorLower.contains('min')) {
          userFriendlyError = 'Order quantity is below minimum required';
        } else if (errorLower.contains('market') && errorLower.contains('closed')) {
          userFriendlyError = 'Trading is currently suspended for this pair';
        } else if (errorLower.contains('rate') || errorLower.contains('limit')) {
          userFriendlyError = 'Too many orders. Please wait a moment';
        } else if (errorLower.contains('unauthorized') || errorLower.contains('auth')) {
          userFriendlyError = 'Session expired. Please login again';
        } else {
          userFriendlyError = 'Order failed: $errorMsg';
        }
        
        _showMessage(userFriendlyError, isError: true);
      }
    } catch (e) {
      print('Error placing order: $e');
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('timeout') || errorStr.contains('socket')) {
        _showMessage('Network timeout. Please check your connection and try again', isError: true);
      } else if (errorStr.contains('handshake') || errorStr.contains('ssl') || errorStr.contains('certificate')) {
        _showMessage('Secure connection failed. Please try again later', isError: true);
      } else {
        _showMessage('Failed to place order. Please try again', isError: true);
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Show order confirmation dialog
  Future<bool> _showOrderConfirmation({
    required String side,
    required String orderType,
    required double qty,
    required double price,
    required String symbol,
    required double total,
  }) async {
    final baseAsset = symbol.endsWith('USDT') 
        ? symbol.substring(0, symbol.length - 4) 
        : symbol.split('/').first;
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: side == 'Buy' ? const Color(0xFF84BD00) : Colors.red,
              width: 2,
            ),
          ),
          title: Row(
            children: [
              Icon(
                side == 'Buy' ? Icons.arrow_upward : Icons.arrow_downward,
                color: side == 'Buy' ? const Color(0xFF84BD00) : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                'Confirm ${side == 'Buy' ? 'Buy' : 'Sell'} Order',
                style: TextStyle(
                  color: side == 'Buy' ? const Color(0xFF84BD00) : Colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConfirmRow('Symbol', symbol),
              const SizedBox(height: 8),
              _buildConfirmRow('Type', orderType),
              const SizedBox(height: 8),
              _buildConfirmRow('Side', side, isHighlight: true, isBuy: side == 'Buy'),
              const SizedBox(height: 8),
              _buildConfirmRow('Quantity', '${qty.toStringAsFixed(6)} $baseAsset'),
              const SizedBox(height: 8),
              if (orderType == 'Limit') ...[
                _buildConfirmRow('Price', '\$${price.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
              ],
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              _buildConfirmRow(
                'Total', 
                '\$${total.toStringAsFixed(2)}',
                isBold: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: side == 'Buy' ? const Color(0xFF84BD00) : Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Confirm ${side == 'Buy' ? 'Buy' : 'Sell'}'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Widget _buildConfirmRow(String label, String value, {bool isBold = false, bool isHighlight = false, bool isBuy = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isHighlight ? (isBuy ? const Color(0xFF84BD00) : Colors.red) : Colors.white,
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // Cancel order
  Future<void> _cancelOrder(String orderId, {required String symbol, required double price, required String side}) async {
    try {
      final result = await SpotService.cancelOrder(
        orderId: orderId,
        symbol: symbol,
        price: price,
        side: side,
      );
      if (result['success']) {
        _showMessage('Order cancelled successfully!');
        _loadOpenOrders(); // Refresh open orders
      } else {
        _showMessage(result['error'], isError: true);
      }
    } catch (e) {
      _showMessage('Error cancelling order: $e', isError: true);
    }
  }

  // Show symbol selector dialog
  void _showSymbolSelector() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Select Trading Pair',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: _isLoadingSymbols
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF84BD00)),
                    ),
                  )
                : ListView.builder(
                    itemCount: _symbols.length,
                    itemBuilder: (context, index) {
                      final symbol = _symbols[index];
                      final symbolName = symbol['symbol'] ?? 'Unknown';
                      final isActive = symbol['status'] == 'TRADING';
                      
                      return ListTile(
                        title: Text(
                          symbolName.replaceAll('USDT', '/USDT'),
                          style: TextStyle(
                            color: isActive ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'Status: ${symbol['status'] ?? 'Unknown'}',
                          style: TextStyle(
                            color: isActive ? const Color(0xFF84BD00) : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        trailing: symbolName == _selectedSymbol
                            ? const Icon(
                                Icons.check,
                                color: Color(0xFF84BD00),
                                size: 20,
                              )
                            : null,
                        onTap: isActive
                            ? () {
                                final oldSymbol = _selectedSymbol;
                                setState(() {
                                  _selectedSymbol = symbolName;
                                  SpotService.currentSymbol = symbolName;
                                });
                                Navigator.pop(context);
                                // Unsubscribe from old symbol and subscribe to new
                                SpotSocketService.unsubscribe(oldSymbol);
                                SpotSocketService.subscribe(symbolName);
                                _loadSpotData(); // Reload data for new symbol
                              }
                            : null,
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF84BD00)),
              ),
            ),
          ],
        );
      },
    );
  }

  // Show market dropdown with Binance market data
  void _showMarketDropdown() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Market',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              // Market List
              Expanded(
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
                          final isSelected = symbol == _selectedSymbol;

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
                              '\$${price.toStringAsFixed(2)}',
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
                            tileColor: isSelected ? const Color(0xFF84BD00).withOpacity(0.1) : null,
                            onTap: () {
                                final oldSymbol = _selectedSymbol;
                              setState(() {
                                _selectedSymbol = symbol;
                                SpotService.currentSymbol = symbol;
                              });
                              _updateAvailableCoins();
                              Navigator.pop(context);
                              // Unsubscribe from old symbol and subscribe to new
                              SpotSocketService.unsubscribe(oldSymbol);
                              SpotSocketService.subscribe(symbol);
                              _loadSpotData();
                              _initializeWebSocket();
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Show message
  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF84BD00),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show Coming Soon screen when feature is not yet live
    if (_isComingSoon) {
      return _buildComingSoonScreen();
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildTradingSection(),
                  const SizedBox(height: 20),
                  const SizedBox(height: 20),
                  _buildOpenOrdersSection(),
                  const SizedBox(height: 20),
                  _buildClosedOrdersSection(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  // Coming Soon screen - similar to FuturesScreen
  Widget _buildComingSoonScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text(
          'Spot Trading',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _bounceAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _bounceAnimation.value),
                  child: AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFF84BD00).withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF84BD00).withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.show_chart,
                            size: 60,
                            color: Color(0xFF84BD00),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            const Text(
              'Coming Soon',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Spot trading is under development. Stay tuned for advanced trading features!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF84BD00).withOpacity(0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule,
                    color: Color(0xFF84BD00),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Launching Soon',
                    style: TextStyle(
                      color: Color(0xFF84BD00),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0D0D0D),
      elevation: 0,
      title: GestureDetector(
        onTap: _showMarketDropdown,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CoinIconMapper.getCoinIcon(_selectedSymbol.replaceAll('USDT', ''), size: 20),
              const SizedBox(width: 8),
              Text(
                _selectedSymbol.replaceAll('USDT', '/USDT'),
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, color: Colors.white.withValues(alpha: 0.6), size: 20),
              if (_isLoadingMarkets)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: BitcoinLoadingIndicator(size: 16),
                ),
            ],
          ),
        ),
      ),
      actions: [
        // Chart Button
        IconButton(
          onPressed: () {
            // Navigate to chart screen
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ChartScreen()),
            );
          },
          icon: const Icon(
            Icons.show_chart,
            color: Colors.white,
            size: 20,
          ),
          tooltip: 'Chart',
        ),
        // WebSocket Connection Status Indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _isWebSocketConnected ? const Color(0xFF84BD00) : Colors.red.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isWebSocketConnected ? Icons.wifi : Icons.wifi_off,
                color: Colors.white,
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                _isWebSocketConnected ? 'Live' : 'Offline',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildTradingSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // Market Statistics
          _buildMarketStats(),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 1, child: _buildBuySellSection()),
              const SizedBox(width: 12),
              Expanded(flex: 1, child: _buildOrderBook()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMarketStats() {
    final priceChange24h = _ticker?['price_change_24h'] ?? 0.0;
    final priceChangePercent24h = _ticker?['price_change_percent_24h'] ?? 0.0;
    final volume24h = _ticker?['volume_24h'] ?? 0.0;
    final high24h = _ticker?['high_24h'] ?? 0.0;
    final low24h = _ticker?['low_24h'] ?? 0.0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedSymbol,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                  ),
                  _currentPrice > 0
                    ? Text(
                        _currentPrice.toStringAsFixed(2),
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      )
                    : Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF84BD00)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Loading...',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: priceChange24h >= 0 ? const Color(0xFF84BD00).withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${priceChange24h >= 0 ? '+' : ''}${priceChangePercent24h.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: priceChange24h >= 0 ? const Color(0xFF84BD00) : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '24h Volume: ${volume24h.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('24h High', high24h.toStringAsFixed(2)),
              _buildStatItem('24h Low', low24h.toStringAsFixed(2)),
              _buildStatItem('24h Change', '${priceChange24h >= 0 ? '+' : ''}${priceChange24h.toStringAsFixed(2)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildBuySellSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBuySellToggle(),
          const SizedBox(height: 20),
          _buildOrderTypeToggle(),
          const SizedBox(height: 20),
          if (_orderType == 'Limit') ...[
            _buildPriceInput(),
            const SizedBox(height: 16),
          ],
          if (_orderType == 'Market') ...[
            _buildMarketAmountInput(),
            const SizedBox(height: 12),
            _buildMarketPercentageButtons(),
            const SizedBox(height: 16),
            _buildMarketAmountInfo(),
            const SizedBox(height: 20),
          ] else ...[
            _buildAmountInput(),
            const SizedBox(height: 12),
            _buildPercentageButtons(),
            const SizedBox(height: 12),
            const SizedBox(height: 16),
            _buildTotalInfo(),
            const SizedBox(height: 20),
          ],
          _buildBuySellButton(),
        ],
      ),
    );
  }

  Widget _buildOrderTypeToggle() {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _orderType = 'Limit';
                });
              },
              child: Container(
                height: 32,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: _orderType == 'Limit' 
                      ? (_isBuy ? const Color(0xFF84BD00) : Colors.red)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    'Limit',
                    style: TextStyle(
                      color: _orderType == 'Limit' ? Colors.white : Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _orderType = 'Market';
                });
              },
              child: Container(
                height: 32,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: _orderType == 'Market' 
                      ? (_isBuy ? const Color(0xFF84BD00) : Colors.red)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    'Market',
                    style: TextStyle(
                      color: _orderType == 'Market' ? Colors.white : Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuySellToggle() {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isBuy = true),
              child: Container(
                height: 32,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: _isBuy ? const Color(0xFF84BD00) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text(
                    'Buy ',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isBuy = false),
              child: Container(
                height: 32,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: !_isBuy ? Colors.red : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text(
                    'Sell',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceInput() {
    if (_orderType == 'Market') {
      // Calculate market price from order book
      final bestBid = getBestBid();
      final bestAsk = getBestAsk();
      final marketPrice = (bestBid != null && bestAsk != null) 
          ? ((bestBid + bestAsk) / 2).toStringAsFixed(2)
          : _currentPrice.toStringAsFixed(2);
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Market Price',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    marketPrice,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  'USDT',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show Market Price reference above Limit Price
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Limit Price',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
            ),
            Text(
              'MP: ${_currentPrice.toStringAsFixed(2)}',
              style: const TextStyle(color: Color(0xFF84BD00), fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: _isManualPrice 
                    ? TextField(
                        controller: _priceController,
                        onChanged: (value) {
                          final newPrice = double.tryParse(value);
                          if (newPrice != null && newPrice > 0) {
                            setState(() {
                              _currentPrice = newPrice;
                            });
                          } else if (value.isEmpty) {
                            setState(() {
                              _isManualPrice = false;
                              // Reset to best bid/ask price
                              _currentPrice = _isBuy ? (getBestBid() ?? _currentPrice) : (getBestAsk() ?? _currentPrice);
                              _priceController.text = _currentPrice.toStringAsFixed(2);
                            });
                          }
                        },
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                          suffixText: 'USDT',
                          suffixStyle: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      )
                    : GestureDetector(
                        onTap: () {
                          setState(() {
                            _isManualPrice = true;
                            _priceController.clear();
                          });
                        },
                        child: Text(
                          _isBuy ? 'Best Bid' : 'Best Ask',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                      ),
              ),
              GestureDetector(
                onTap: () => setState(() => _currentPrice -= 100),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: const Text(
                    '-',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w300),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() => _currentPrice += 100),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: const Text(
                    '+',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w300),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Amount',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedAmountCoin,
                  dropdownColor: const Color(0xFF2A2A2A),
                  icon: Icon(Icons.keyboard_arrow_down, color: Colors.white.withValues(alpha: 0.6), size: 14),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                  isDense: true,
                  selectedItemBuilder: (BuildContext context) {
                    return _availableCoins.map((coin) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CoinIconMapper.getCoinIcon(coin['symbol'], size: 12),
                          const SizedBox(width: 3),
                          Text(coin['symbol']),
                        ],
                      );
                    }).toList();
                  },
                  items: _availableCoins.map((coin) {
                    return DropdownMenuItem<String>(
                      value: coin['symbol'],
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CoinIconMapper.getCoinIcon(coin['symbol'], size: 12),
                          const SizedBox(width: 3),
                          Text(coin['symbol']),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedAmountCoin = newValue;
                      });
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  onChanged: (value) {
                    // Limit to 5 decimal places for BTC
                    if (value.contains('.')) {
                      final decimalPart = value.split('.').last;
                      if (decimalPart.length > 5) {
                        final trimmedValue = value.substring(0, value.indexOf('.') + 6);
                        _amountController.value = TextEditingValue(
                          text: trimmedValue,
                          selection: TextSelection.collapsed(offset: trimmedValue.length),
                        );
                        setState(() {
                          _amount = double.tryParse(trimmedValue) ?? 0.0;
                          _sliderValue = _amount > 0 ? (_amount / 1.0).clamp(0.0, 1.0) : 0.0;
                        });
                        return;
                      }
                    }
                    setState(() {
                      _amount = double.tryParse(value) ?? 0.0;
                      _sliderValue = _amount > 0 ? (_amount / 1.0).clamp(0.0, 1.0) : 0.0;
                    });
                  },
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '0.00',
                    hintStyle: const TextStyle(color: Color(0xFF6C7278)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                    suffixText: _selectedAmountCoin,
                    suffixStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() => _amount = (_amount - 0.01).clamp(0.0, double.infinity)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: const Text(
                    '-',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w300),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() => _amount += 0.01),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: const Text(
                    '+',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w300),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMarketAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Amount',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedAmountCoin,
                  dropdownColor: const Color(0xFF2A2A2A),
                  icon: Icon(Icons.keyboard_arrow_down, color: Colors.white.withValues(alpha: 0.6), size: 14),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                  isDense: true,
                  selectedItemBuilder: (BuildContext context) {
                    return _availableCoins.map((coin) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CoinIconMapper.getCoinIcon(coin['symbol'], size: 12),
                          const SizedBox(width: 3),
                          Text(coin['symbol']),
                        ],
                      );
                    }).toList();
                  },
                  items: _availableCoins.map((coin) {
                    return DropdownMenuItem<String>(
                      value: coin['symbol'],
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CoinIconMapper.getCoinIcon(coin['symbol'], size: 12),
                          const SizedBox(width: 3),
                          Text(coin['symbol']),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedAmountCoin = newValue;
                      });
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  onChanged: (value) {
                    if (value.contains('.')) {
                      final decimalPart = value.split('.').last;
                      if (decimalPart.length > 5) {
                        final trimmedValue = value.substring(0, value.indexOf('.') + 6);
                        _amountController.value = TextEditingValue(
                          text: trimmedValue,
                          selection: TextSelection.collapsed(offset: trimmedValue.length),
                        );
                        setState(() {
                          _amount = double.tryParse(trimmedValue) ?? 0.0;
                          _sliderValue = _amount > 0 ? (_amount / 1.0).clamp(0.0, 1.0) : 0.0;
                        });
                        return;
                      }
                    }
                    setState(() {
                      _amount = double.tryParse(value) ?? 0.0;
                      _sliderValue = _amount > 0 ? (_amount / 1.0).clamp(0.0, 1.0) : 0.0;
                    });
                  },
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '0.00',
                    hintStyle: const TextStyle(color: Color(0xFF6C7278)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                    suffixText: _selectedAmountCoin,
                    suffixStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() => _amount = (_amount - 0.01).clamp(0.0, double.infinity)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: const Text(
                    '-',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w300),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() => _amount += 0.01),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: const Text(
                    '+',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w300),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMarketAmountInfo() {
    // Calculate funds required
    final baseAsset = _selectedSymbol.endsWith('USDT')
        ? _selectedSymbol.substring(0, _selectedSymbol.length - 4)
        : _selectedSymbol.split('/').first;
    final isBaseAsset = _selectedAmountCoin == baseAsset;
    final effectivePrice = _currentPrice;

    double fundsReq = 0.0;
    String reqUnit = isBaseAsset ? 'USDT' : baseAsset;
    if (isBaseAsset) {
      fundsReq = _amount * effectivePrice;
    } else {
      fundsReq = effectivePrice > 0 ? (_amount / effectivePrice) : 0.0;
    }

    // Get available balance
    double availableVal = 0.0;
    String availableUnit = '';
    if (_isBuy) {
      availableVal = double.tryParse(_balance?['usdt_available']?.toString() ?? '0') ?? 0.0;
      availableUnit = 'USDT';
    } else {
      availableVal = double.tryParse(_balance?['free']?.toString() ?? '0') ?? 0.0;
      availableUnit = baseAsset;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Funds required row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Funds req.',
                style: TextStyle(color: Color(0xFF6C7278), fontSize: 12),
              ),
              Flexible(
                child: Text(
                  '~${fundsReq.toStringAsFixed(4)} $reqUnit',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Available row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Available',
                style: TextStyle(color: Color(0xFF6C7278), fontSize: 12),
              ),
              Flexible(
                child: Text(
                  '${availableVal.toStringAsFixed(4)} $availableUnit',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMarketPercentageButton(String label, double percentage) {
    final baseAsset = _selectedSymbol.endsWith('USDT')
        ? _selectedSymbol.substring(0, _selectedSymbol.length - 4)
        : _selectedSymbol.split('/').first;
    final isBaseAsset = _selectedAmountCoin == baseAsset;
    final bool isActive = _sliderValue == percentage;
    final activeColor = _isBuy ? const Color(0xFF84BD00) : Colors.red;

    return GestureDetector(
      onTap: () {
        setState(() {
          _sliderValue = percentage;
          print('Market% tap: label=$label, percentage=$percentage, isBaseAsset=$isBaseAsset');
          print('Market% tap: _currentPrice=$_currentPrice, _balance=$_balance');
          if (_isBuy) {
            if (isBaseAsset) {
              // BTC selected - calculate BTC amount from available USDT
              final availableUsdt = double.tryParse(_balance?['usdt_available']?.toString() ?? '0') ?? 0.0;
              final usdtToSpend = availableUsdt * percentage;
              print('Market% tap: availableUsdt=$availableUsdt, usdtToSpend=$usdtToSpend');
              // Show actual calculated value (proportional to percentage)
              _amount = _currentPrice > 0 ? (usdtToSpend / _currentPrice) : 0.0;
              print('Market% tap: calculated _amount=$_amount');
            } else {
              // USDT selected - show USDT amount directly
              final availableUsdt = double.tryParse(_balance?['usdt_available']?.toString() ?? '0') ?? 0.0;
              _amount = availableUsdt * percentage;
            }
          } else {
            // Sell - always show percentage of available base asset (BTC)
            final availableBase = double.tryParse(_balance?['free']?.toString() ?? '0') ?? 0.0;
            _amount = availableBase * percentage;
          }
          _amountController.text = _amount.toStringAsFixed(isBaseAsset ? 5 : 2);
        });
      },
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? activeColor : const Color(0xFF6C7278),
          fontSize: 10,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildMarketPercentageButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildMarketPercentageButton('10%', 0.1),
        _buildMarketPercentageButton('25%', 0.25),
        _buildMarketPercentageButton('50%', 0.5),
        _buildMarketPercentageButton('75%', 0.75),
        _buildMarketPercentageButton('100%', 1.0),
      ],
    );
  }

  Widget _buildPercentageButtons() {
    final percentages = [0.1, 0.25, 0.5, 0.75, 1.0];
    final labels = ['10%', '25%', '50%', '75%', '100%'];
    final activeColor = _isBuy ? const Color(0xFF84BD00) : Colors.red;
    
    return Container(
      height: 44,
      child: Column(
        children: [
          // Labels row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (index) {
              final percentage = percentages[index];
              final isSelected = (_sliderValue - percentage).abs() < 0.05;
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _sliderValue = percentage;
                    
                    final baseAsset = _selectedSymbol.endsWith('USDT') 
                        ? _selectedSymbol.substring(0, _selectedSymbol.length - 4) 
                        : _selectedSymbol.split('/').first;
                    
                    final isBaseAsset = _selectedAmountCoin == baseAsset;
                    
                    // Get available balances
                    final availableUsdt = double.tryParse(_balance?['usdt_available']?.toString() ?? '0') ?? 0.0;
                    final availableBase = double.tryParse(_balance?['free']?.toString() ?? '0') ?? 0.0;
                    
                    // Slider percentage applied to relevant balance
                    if (_isBuy) {
                      // Buying: We spend USDT
                      if (isBaseAsset) {
                        // Input is BTC, calculate based on USDT available
                        // e.g., 10% of 100 USDT = 10 USDT worth of BTC
                        final usdtToSpend = availableUsdt * percentage;
                        _amount = _currentPrice > 0 ? (usdtToSpend / _currentPrice) : 0.0;
                      } else {
                        // Input is USDT, directly use USDT balance
                        // e.g., 10% of 100 USDT = 10 USDT
                        _amount = availableUsdt * percentage;
                      }
                    } else {
                      // Selling: We spend BTC
                      if (isBaseAsset) {
                        // Input is BTC, directly use BTC balance
                        // e.g., 10% of 0.5 BTC = 0.05 BTC
                        _amount = availableBase * percentage;
                      } else {
                        // Input is USDT, calculate based on BTC available
                        // e.g., 10% of 0.5 BTC = 0.05 BTC worth of USDT
                        final btcToSell = availableBase * percentage;
                        _amount = btcToSell * _currentPrice;
                      }
                    }

                    // Push calculated amount to UI
                    _amountController.text = _amount.toStringAsFixed(isBaseAsset ? 5 : 2);
                  });
                },
                child: Text(
                  labels[index],
                  style: TextStyle(
                    color: isSelected ? activeColor : Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          // Green line progress bar
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(2),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    // Green progress line
                    Container(
                      width: constraints.maxWidth * _sliderValue,
                      decoration: BoxDecoration(
                        color: activeColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalInfo() {
    // Calculate effective price for quantity calculation
    final effectivePrice = _orderType == 'Market' ? _currentPrice : 
                          (double.tryParse(_priceController.text) ?? _currentPrice);
    
    final baseAsset = _selectedSymbol.endsWith('USDT') 
        ? _selectedSymbol.substring(0, _selectedSymbol.length - 4) 
        : _selectedSymbol.split('/').first;
        
    final isBaseAsset = _selectedAmountCoin == baseAsset;

    // Calculate funds req (what you'll spend or receive in opposite currency)
    // If amount is BTC → show USDT cost/value
    // If amount is USDT → show BTC you'll get
    double fundsReq = 0.0;
    String reqUnit = isBaseAsset ? 'USDT' : baseAsset;
    
    if (isBaseAsset) {
      // Amount is in BTC, show USDT cost
      fundsReq = _amount * effectivePrice;
      reqUnit = 'USDT';
    } else {
      // Amount is in USDT, show BTC you'll receive
      fundsReq = effectivePrice > 0 ? (_amount / effectivePrice) : 0.0;
      reqUnit = baseAsset;
    }
    
    // Get available balance from state
    double availableVal = 0.0;
    String availableUnit = '';
    
    if (_isBuy) {
      availableVal = double.tryParse(_balance?['usdt_available']?.toString() ?? '0') ?? 0.0;
      availableUnit = 'USDT';
    } else {
      availableVal = double.tryParse(_balance?['free']?.toString() ?? '0') ?? 0.0;
      availableUnit = baseAsset;
    }
    
    // Calculate final stats for display
    final total = _isBuy ? (_selectedAmountCoin == 'USDT' ? _amount : _amount * effectivePrice) : 
                          (_selectedAmountCoin == 'USDT' ? _amount : _amount * effectivePrice);
    
    final minQty = _getMinQty(_selectedSymbol);
    final currentQty = isBaseAsset ? _amount : (_amount / effectivePrice);
    final isBelowMin = _amount > 0 && currentQty < minQty;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Funds receive',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
            ),
            Flexible(
              child: Text(
                '~${fundsReq.toStringAsFixed(isBaseAsset ? 2 : 4)} $reqUnit',
                style: const TextStyle(color: Colors.white, fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Available',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
            ),
            Flexible(
              child: Text(
                '${availableVal.toStringAsFixed(availableUnit == 'USDT' ? 2 : 8)} $availableUnit',
                style: const TextStyle(color: Colors.white, fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (_orderType == 'Market') const SizedBox(height: 4),
        if (_orderType == 'Market')
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
              ),
              Flexible(
                child: Text(
                  '${total.toStringAsFixed(2)} USDT',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildBuySellButton() {
    // Check if user needs verification (mock check)
    final needsVerification = false; // Change this based on your verification logic
    
    print('_buildBuySellButton: _isLoading=$_isLoading, _amount=$_amount, _orderType=$_orderType');

    // Calculate if quantity is below minimum (only check for Limit orders)
    bool isBelowMin = false;
    if (_amount > 0 && _orderType == 'Limit') {
      final baseAsset = _selectedSymbol.endsWith('USDT')
          ? _selectedSymbol.substring(0, _selectedSymbol.length - 4)
          : _selectedSymbol.split('/').first;
      final isBaseAsset = _selectedAmountCoin == baseAsset;
      final effectivePrice = double.tryParse(_priceController.text) ?? _currentPrice;
      print('Button check: _orderType=$_orderType, effectivePrice=$effectivePrice');
      if (effectivePrice > 0) {
        final minQty = _getMinQty(_selectedSymbol);
        final currentQty = isBaseAsset ? _amount : (_amount / effectivePrice);
        isBelowMin = currentQty < minQty;
        print('Button check: minQty=$minQty, currentQty=$currentQty, isBelowMin=$isBelowMin');
      }
    }

    if (needsVerification) {
      return Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF84BD00),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            'Get Verified to Trade',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: (_isLoading || isBelowMin) ? null : () {
        print('Buy button tapped: _isLoading=$_isLoading, isBelowMin=$isBelowMin, _amount=$_amount');
        _placeOrder();
      },
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF84BD00), Color(0xFF6B9B00)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF84BD00).withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Place Spot Order',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  // Helper methods to get best prices
  double? getBestBid() {
    if (_buyOrders.isNotEmpty) {
      return double.tryParse(_buyOrders.first['price'].toString());
    }
    return null;
  }

  double? getBestAsk() {
    if (_sellOrders.isNotEmpty) {
      return double.tryParse(_sellOrders.first['price'].toString());
    }
    return null;
  }

  double _getMinQty(String symbol) {
    try {
      final symbolData = _symbols.firstWhere(
        (s) => s['symbol'] == symbol,
        orElse: () => <String, dynamic>{},
      );
      
      if (symbolData.isEmpty) {
        // Hardcoded fallbacks for common pairs if symbols aren't loaded
        if (symbol == 'BTCUSDT' || symbol == 'BTC/USDT') return 0.00001;
        if (symbol == 'ETHUSDT' || symbol == 'ETH/USDT') return 0.0001;
        return 0.00001;
      }

      if (symbolData.containsKey('min_qty')) {
        return double.tryParse(symbolData['min_qty'].toString()) ?? 0.00001;
      }
      
      if (symbolData.containsKey('filters')) {
        final filters = symbolData['filters'] as List?;
        final lotSize = filters?.firstWhere(
          (f) => f['filterType'] == 'LOT_SIZE',
          orElse: () => null,
        );
        if (lotSize != null) {
          return double.tryParse(lotSize['minQty'].toString()) ?? 0.00001;
        }
      }
    } catch (_) {}
    
    // Default fallback based on common pair rules
    if (symbol.contains('BTC')) return 0.00001;
    if (symbol.contains('ETH')) return 0.0001;
    return 0.00001;
  }

  double _getMinNotional(String symbol) {
    // Most exchanges have a minimum 5 or 10 USDT rule
    return 5.0;
  }

  // Show order placed message with cancel action
  void _showOrderPlacedWithCancel(String orderId, String symbol, double price, String side) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order placed: $orderId'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'CANCEL',
          textColor: Colors.white,
          onPressed: () async {
            final result = await SpotService.cancelOrder(
              orderId: orderId,
              symbol: symbol,
              price: price,
              side: side,
            );
            // Handle both bool and String types for success
            final cancelSuccess = result['success'] is bool ? result['success'] : result['success']?.toString() == 'true';
            if (cancelSuccess) {
              _showMessage('Order cancelled successfully!');
              _loadOpenOrders();
            } else {
              _showMessage(result['error']?.toString() ?? 'Failed to cancel order', isError: true);
            }
          },
        ),
      ),
    );
  }

  // Show price selector dialog
  void _showPriceSelector() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Select Price',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 200,
            child: Column(
              children: [
                // Best bid/ask options
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          final bestBid = getBestBid();
                          if (bestBid != null) {
                            setState(() {
                              _currentPrice = bestBid;
                              _isManualPrice = false;
                              _priceController.text = _currentPrice.toStringAsFixed(2);
                            });
                          }
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Best Bid',
                                style: TextStyle(color: Color(0xFF84BD00), fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                getBestBid()?.toStringAsFixed(2) ?? _currentPrice.toStringAsFixed(2),
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          final bestAsk = getBestAsk();
                          if (bestAsk != null) {
                            setState(() {
                              _currentPrice = bestAsk;
                              _isManualPrice = false;
                              _priceController.text = _currentPrice.toStringAsFixed(2);
                            });
                          }
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Best Ask',
                                style: TextStyle(color: Colors.red, fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                getBestAsk()?.toStringAsFixed(2) ?? _currentPrice.toStringAsFixed(2),
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Manual price input
                TextField(
                  onChanged: (value) {
                    final newPrice = double.tryParse(value);
                    if (newPrice != null && newPrice > 0) {
                      setState(() {
                        _currentPrice = newPrice;
                        _isManualPrice = true;
                        _priceController.text = newPrice.toStringAsFixed(2);
                      });
                    }
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Enter Price',
                    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF84BD00)),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF84BD00)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Apply',
                style: TextStyle(color: Color(0xFF84BD00)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrderBook() {
    return Container(
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(
        maxHeight: 420,
        minHeight: 360,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Order Book',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'Top 10',
                  style: TextStyle(color: Color(0xFF84BD00), fontSize: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Column Headers
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Price (USDT)',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 8),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Amount (BTC)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 8),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Total',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // Sell Orders (Asks) - Red
          Flexible(
            flex: 1,
            child: _buildSellOrders(),
          ),
          // Market Price Display
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: const BoxDecoration(
              border: Border.symmetric(horizontal: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
                  decoration: BoxDecoration(
                    color: _isPriceFlashing ? _flashColor.withValues(alpha: 0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: _currentPrice > 0
                    ? Text(
                        _currentPrice.toStringAsFixed(2),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _isPriceFlashing 
                            ? _flashColor 
                            : (_isPriceUp ? const Color(0xFF84BD00) : Colors.red), 
                          fontSize: 16, 
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          // Buy Orders (Bids) - Green
          Flexible(
            flex: 1,
            child: _buildBuyOrders(),
          ),
        ],
      ),
    );
  }

  Widget _buildSellOrders() {
    print('Building sell orders: ${_sellOrders.length} orders');
    if (_sellOrders.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: _sellOrders.take(10).map((order) {
        final price = (order['price'] ?? 0.0) as double;
        final amount = (order['amount'] ?? 0.0) as double;
        final total = price * amount;
        final isMyOrder = order['isMyOrder'] == true;
        
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 0.5),
          decoration: BoxDecoration(
            color: isMyOrder ? Colors.red.withValues(alpha: 0.1) : null,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          price.toStringAsFixed(2),
                          style: TextStyle(
                            color: isMyOrder ? Colors.red : Colors.red.withValues(alpha: 0.9), 
                            fontSize: 9,
                            fontWeight: isMyOrder ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                    if (isMyOrder) ...[
                      const SizedBox(width: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 6,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  amount.toStringAsFixed(6),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isMyOrder ? Colors.red : Colors.red.withValues(alpha: 0.7), 
                    fontSize: 9,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  total.toStringAsFixed(2),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: isMyOrder ? Colors.red : Colors.red.withValues(alpha: 0.7), 
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBuyOrders() {
    print('Building buy orders: ${_buyOrders.length} orders');
    if (_buyOrders.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: _buyOrders.take(10).map((order) {
        final price = (order['price'] ?? 0.0) as double;
        final amount = (order['amount'] ?? 0.0) as double;
        final total = price * amount;
        final isMyOrder = order['isMyOrder'] == true;
        
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 0.5),
          decoration: BoxDecoration(
            color: isMyOrder ? const Color(0xFF84BD00).withValues(alpha: 0.1) : null,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          price.toStringAsFixed(2),
                          style: TextStyle(
                            color: isMyOrder ? const Color(0xFF84BD00) : const Color(0xFF84BD00).withValues(alpha: 0.9), 
                            fontSize: 9,
                            fontWeight: isMyOrder ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                    if (isMyOrder) ...[
                      const SizedBox(width: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF84BD00).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            color: Color(0xFF84BD00),
                            fontSize: 6,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  amount.toStringAsFixed(6),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isMyOrder ? const Color(0xFF84BD00) : const Color(0xFF84BD00).withValues(alpha: 0.7), 
                    fontSize: 9,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  total.toStringAsFixed(2),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: isMyOrder ? const Color(0xFF84BD00) : const Color(0xFF84BD00).withValues(alpha: 0.7), 
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOpenOrdersSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with expand/collapse
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Open Orders',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          'All',
                          style: TextStyle(color: Color(0xFF84BD00), fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isOpenOrdersExpanded = !_isOpenOrdersExpanded;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            _isOpenOrdersExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Expandable content
            if (_isOpenOrdersExpanded)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                constraints: BoxConstraints(
                  minHeight: 300,
                  maxHeight: 400,
                ),
                child: _buildOpenOrdersTable(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenOrdersTable() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Expanded(flex: 2, child: _tableHeader('Price(USDT)')),
                Expanded(flex: 2, child: _tableHeader('Amount(BTC)')),
                Expanded(flex: 2, child: _tableHeader('Executed(BTC)')),
                Expanded(flex: 2, child: _tableHeader('Total')),
                Expanded(flex: 3, child: _tableHeader('Type')),
                Expanded(flex: 2, child: _tableHeader('Action')),
              ],
            ),
          ),
          // Table Rows with scroll
          Expanded(
            child: _openOrders.isEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          color: Colors.white.withValues(alpha: 0.3),
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No open orders',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Place an order to see it here',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: _openOrders.map((order) => _buildOrderRow(order)).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(String text) {
    return Text(
      text,
      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.w500),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildOrderRow(Map<String, dynamic> order) {
    final orderId = order['order_id']?.toString() ?? '';
    final orderPrice = order['price'] ?? 0.0;
    final orderSide = order['side'] ?? 'Buy';
    final orderQty = order['qty'] ?? 0.0;
    final remaining = order['remaining'] ?? 0.0;
    final executed = orderQty - remaining;
    final total = orderPrice * orderQty;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: _tableCell('${orderPrice.toStringAsFixed(1)} USDT', 10)),
          Expanded(flex: 2, child: _tableCell('${orderQty.toStringAsFixed(2)} BTC', 10)),
          Expanded(flex: 2, child: _tableCell('${executed.toStringAsFixed(2)} BTC', 10)),
          Expanded(flex: 2, child: _tableCell('${total.toStringAsFixed(2)} USDT', 10)),
          Expanded(flex: 3, child: _tableCell(order['order_type'] ?? 'Limit', 10)),
          Expanded(flex: 2, child: _buildActionCell(remaining == 0, orderId, symbol: _selectedSymbol, price: orderPrice, side: orderSide)),
        ],
      ),
    );
  }

  Widget _tableCell(String text, double fontSize, [Color? textColor]) {
    return Text(
      text,
      style: TextStyle(
        color: textColor ?? Colors.white,
        fontSize: fontSize,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildActionCell(bool isFilled, String? orderId, {required String symbol, required double price, required String side}) {
    if (isFilled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Filled',
          style: TextStyle(color: Colors.green, fontSize: 8),
          textAlign: TextAlign.center,
        ),
      );
    } else {
      return GestureDetector(
        onTap: orderId != null ? () => _cancelOrder(orderId, symbol: symbol, price: price, side: side) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.red, fontSize: 8),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
  }

  Widget _buildClosedOrdersSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with expand/collapse
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Closed Orders',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          'All',
                          style: TextStyle(color: Color(0xFF84BD00), fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isClosedOrdersExpanded = !_isClosedOrdersExpanded;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            _isClosedOrdersExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Expandable content
            if (_isClosedOrdersExpanded)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                constraints: BoxConstraints(
                  minHeight: 250,
                  maxHeight: 350,
                ),
                child: _buildClosedOrdersTable(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildClosedOrdersTable() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Expanded(flex: 2, child: _tableHeader('Price(USDT)')),
                Expanded(flex: 2, child: _tableHeader('Amount(BTC)')),
                Expanded(flex: 2, child: _tableHeader('Executed(BTC)')),
                Expanded(flex: 2, child: _tableHeader('Total')),
                Expanded(flex: 3, child: _tableHeader('Type')),
                Expanded(flex: 2, child: _tableHeader('Status')),
              ],
            ),
          ),
          // Table Rows with scroll
          Expanded(
            child: _closedOrders.isEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_outlined,
                          color: Colors.white.withValues(alpha: 0.3),
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No closed orders',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Completed orders will appear here',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: _closedOrders.map((order) => _buildClosedOrderRow(order)).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildClosedOrderRow(Map<String, dynamic> order) {
    final orderId = order['order_id']?.toString() ?? order['id']?.toString() ?? '';
    final orderPrice = order['price'] ?? 0.0;
    final orderSide = order['side'] ?? 'Buy';
    final orderQty = order['qty'] ?? order['quantity'] ?? 0.0;
    final executed = order['executed'] ?? orderQty;
    final total = orderPrice * executed;
    final status = order['status'] ?? 'filled';
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: _tableCell('${orderPrice.toStringAsFixed(1)} USDT', 10)),
          Expanded(flex: 2, child: _tableCell('${orderQty.toStringAsFixed(2)} BTC', 10)),
          Expanded(flex: 2, child: _tableCell('${executed.toStringAsFixed(2)} BTC', 10)),
          Expanded(flex: 2, child: _tableCell('${total.toStringAsFixed(2)} USDT', 10)),
          Expanded(flex: 3, child: _tableCell(order['order_type'] ?? 'Limit', 10)),
          Expanded(flex: 2, child: _buildStatusCell(status)),
        ],
      ),
    );
  }

  Widget _buildStatusCell(String status) {
    Color statusColor;
    String statusText;
    
    switch (status.toLowerCase()) {
      case 'filled':
        statusColor = Colors.green;
        statusText = 'Filled';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'Cancelled';
        break;
      case 'rejected':
        statusColor = Colors.orange;
        statusText = 'Rejected';
        break;
      default:
        statusColor = Colors.grey;
        statusText = status;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        statusText,
        style: TextStyle(color: statusColor, fontSize: 8),
        textAlign: TextAlign.center,
      ),
    );
  }
}
