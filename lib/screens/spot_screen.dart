import 'dart:async';

import 'package:flutter/material.dart';
import '../services/spot_service.dart';
import '../services/binance_service.dart';
import '../widgets/bitcoin_loading_indicator.dart';
import '../utils/coin_icon_mapper.dart';
import 'chart_screen.dart';

class SpotScreen extends StatefulWidget {
  final String? initialSymbol;
  
  const SpotScreen({super.key, this.initialSymbol});

  @override
  State<SpotScreen> createState() => _SpotScreenState();
}

class _SpotScreenState extends State<SpotScreen> {
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
  final List<Map<String, dynamic>> _availableCoins = [
    {'symbol': 'BTC', 'name': 'Bitcoin'},
    {'symbol': 'USDT', 'name': 'Tether'},
  ];
  String _selectedAmountCoin = 'BTC';
  
  // API data
  List<Map<String, dynamic>> _sellOrders = [];
  List<Map<String, dynamic>> _buyOrders = [];
  List<Map<String, dynamic>> _openOrders = [];
  List<Map<String, dynamic>> _recentTrades = [];
  List<Map<String, dynamic>> _symbols = [];
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

  Timer? _connectionCheckTimer;

  @override
  void initState() {
    super.initState();
    
    // Use initial symbol if provided
    if (widget.initialSymbol != null && widget.initialSymbol!.isNotEmpty) {
      _selectedSymbol = widget.initialSymbol!;
      SpotService.currentSymbol = _selectedSymbol;
    }
    
    // Initialize with default balance immediately
    _balance = {
      'user_id': 1,
      'usdt_available': 10000.0,
      'usdt_locked': 0.0,
      'free': 10000.0,
    };
    
    // Restore persistent user orders
    _buyOrders = List<Map<String, dynamic>>.from(SpotService.userBuyOrders);
    _sellOrders = List<Map<String, dynamic>>.from(SpotService.userSellOrders);
    _recentTrades = List<Map<String, dynamic>>.from(SpotService.userTrades);
    _selectedSymbol = SpotService.currentSymbol;
    
    // Initialize price controller
    _priceController.text = _currentPrice.toStringAsFixed(2);
    
    // Add fallback order book data initially to prevent empty display
    if (_sellOrders.isEmpty && _buyOrders.isEmpty) {
      _addFallbackOrderBookData();
    }
    
    // Load real market price immediately from Binance
    _loadRealMarketPrice();
    
    _loadSpotData();
    _initializeWebSocket();
    
    // Start continuous price updates for order book
    _startPriceUpdateTimer();
  }
  
  // Start timer to update price every 2 seconds
  void _startPriceUpdateTimer() {
    _priceUpdateTimer?.cancel();
    _priceUpdateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _updateOrderBookPrice();
      }
    });
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

  @override
  void dispose() {
    _connectionCheckTimer?.cancel();
    _priceUpdateTimer?.cancel();
    _priceController.dispose();
    _amountController.dispose();
    SpotService.disconnectWebSocket();
    super.dispose();
  }

  // Initialize WebSocket for real-time data
  void _initializeWebSocket() {
    try {
      // Disconnect existing connection
      SpotService.disconnectWebSocket();
      
      // Connect to WebSocket
      SpotService.connectWebSocket();
      
      // Update connection status
      setState(() {
        _isWebSocketConnected = SpotService.isConnected();
      });
      
      // Start periodic connection check
      _startConnectionCheck();
      
      // Subscribe to symbol for order book and trades
      SpotService.getSymbolStream(_selectedSymbol).listen((data) {
        if (mounted) {
          if (data['type'] == 'book') {
            setState(() {
              final orderBookData = data['data'];
              print('Order book data received: $orderBookData');
              
              // Check if order book data is valid
              if (orderBookData != null && 
                  (orderBookData['asks'] != null || orderBookData['bids'] != null)) {
                // Convert [price, quantity] arrays to maps for existing UI
                // Limit to top 10 levels for better performance
                final asks = (orderBookData['asks'] as List? ?? [])
                    .take(10) // Limit to top 10 ask levels
                    .map((level) => {'price': level[0], 'amount': level[1]})
                    .toList();
                final bids = (orderBookData['bids'] as List? ?? [])
                    .take(10) // Limit to top 10 bid levels
                    .map((level) => {'price': level[0], 'amount': level[1]})
                    .toList();
                
                print('Parsed asks: ${asks.length}, bids: ${bids.length}');
                
                // Preserve user's orders (marked with isMyOrder)
                final mySellOrders = _sellOrders.where((o) => o['isMyOrder'] == true).toList();
                final myBuyOrders = _buyOrders.where((o) => o['isMyOrder'] == true).toList();
                
                _sellOrders = [...mySellOrders, ...List<Map<String, dynamic>>.from(asks)];
                _buyOrders = [...myBuyOrders, ...List<Map<String, dynamic>>.from(bids)];
                
                print('Final sellOrders: ${_sellOrders.length}, buyOrders: ${_buyOrders.length}');
                
                // Sort to maintain proper order
                _sellOrders.sort((a, b) => (a['price'] as double).compareTo(b['price'] as double));
                _buyOrders.sort((a, b) => (b['price'] as double).compareTo(a['price'] as double));
              } else {
                print('Invalid or empty order book data received');
                // Add fallback data if order book is empty
                if (_sellOrders.isEmpty && _buyOrders.isEmpty) {
                  _addFallbackOrderBookData();
                }
              }
              
              // Track previous prices for animation
              final newBestBid = getBestBid();
              final newBestAsk = getBestAsk();
              
              // Update price direction indicator
              if (newBestBid != null && _previousBid > 0) {
                _isPriceUp = newBestBid > _previousBid;
              }
              
              // Store previous prices before updating
              if (newBestBid != null) _previousBid = newBestBid;
              if (newBestAsk != null) _previousAsk = newBestAsk;
              
              // Update current price to market price (mid price from order book)
              if (newBestBid != null && newBestAsk != null && newBestBid > 0 && newBestAsk > 0) {
                final midPrice = (newBestBid + newBestAsk) / 2;
                if (midPrice > 0) {
                  _currentPrice = midPrice;
                }
              }
              
              _isWebSocketConnected = true;
            });
          } else if (data['type'] == 'trade') {
            setState(() {
              _recentTrades.insert(0, data['data']);
              // Keep only last 50 trades
              if (_recentTrades.length > 50) {
                _recentTrades = _recentTrades.take(50).toList();
              }
              _isWebSocketConnected = true;
            });
          }
        }
      }, onError: (error) {
        print('WebSocket stream error: $error');
        if (mounted) {
          setState(() {
            _isWebSocketConnected = false;
          });
        }
      });
      
      // Subscribe to order updates (requires auth)
      SpotService.getOrderUpdatesStream().listen((data) {
        if (mounted) {
          setState(() {
            _isWebSocketConnected = true;
          });
          // Handle order status updates
          final orderData = data['data'];
          final status = orderData['status'];
          
          switch (status) {
            case 'pending':
              // Add to open orders
              _loadOpenOrders();
              break;
            case 'filled':
              // Remove from open orders, show success
              _loadOpenOrders();
              _showMessage('Order filled successfully!', isError: false);
              break;
            case 'cancelled':
              // Remove from open orders
              _loadOpenOrders();
              break;
            case 'rejected':
              // Show error message
              final reason = orderData['reason'] ?? 'Order rejected';
              _showMessage('Order rejected: $reason', isError: true);
              break;
          }
        }
      }, onError: (error) {
        print('WebSocket order updates error: $error');
      });
      
      // Subscribe to fill events (requires auth)
      SpotService.getFillsStream().listen((data) {
        if (mounted) {
          setState(() {
            _isWebSocketConnected = true;
          });
          // Handle fill notifications
          final fillData = data['data'];
          print('Fill received: $fillData');
          // Update balance after fill
          _loadBalance();
        }
      }, onError: (error) {
        print('WebSocket fills error: $error');
      });
    } catch (e) {
      print('Error initializing WebSocket: $e');
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
        final isConnected = SpotService.isConnected();
        if (_isWebSocketConnected != isConnected) {
          setState(() {
            _isWebSocketConnected = isConnected;
          });
        }
        // Removed auto-reconnect to prevent flickering
      }
    });
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
      _loadRecentTrades(),
      _loadOpenOrders(),
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
              .map((level) => {'price': level[0], 'amount': level[1]})
              .toList();
          final bids = (data['bids'] as List? ?? [])
              .map((level) => {'price': level[0], 'amount': level[1]})
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

  // Load recent trades
  Future<void> _loadRecentTrades() async {
    try {
      final result = await SpotService.getRecentTrades(_selectedSymbol);
      if (result['success'] && result['data'] != null) {
        setState(() {
          _recentTrades = List<Map<String, dynamic>>.from(result['data']);
        });
      }
    } catch (e) {
      print('Error loading recent trades: $e');
    }
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

  // Load balance
  Future<void> _loadBalance() async {
    try {
      setState(() {
        _isLoadingBalance = true;
        _balanceError = null;
      });
      print('Loading balance...');
      final result = await SpotService.getBalance();
      print('Balance API result: $result');
      
      if (result['success'] && result['data'] != null) {
        setState(() {
          _balance = result['data'];
          _isLoadingBalance = false;
          print('Balance loaded: $_balance');
          print('USDT Available: ${_balance?['usdt_available']}');
          print('USDT Locked: ${_balance?['usdt_locked']}');
          print('Free: ${_balance?['free']}');
        });
      } else {
        print('Balance API error: ${result['error']}');
        setState(() {
          _isLoadingBalance = false;
          _balanceError = result['error'] ?? 'Failed to load balance';
          // Keep existing balance or set default
          _balance ??= {
            'user_id': 1,
            'usdt_available': 0.0,
            'usdt_locked': 0.0,
            'free': 0.0,
          };
        });
      }
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

  // Place order
  Future<void> _placeOrder() async {
    if (_amount <= 0) {
      _showMessage('Please enter a valid amount', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Refresh balance before placing order to get latest available amount
      await _loadBalance();
      
      // Validate amount - max 5 decimal places for quantity
      final amount = double.tryParse(_amount.toStringAsFixed(5)) ?? 0.0;
      if (amount <= 0) {
        _showMessage('Invalid amount format', isError: true);
        setState(() { _isLoading = false; });
        return;
      }

      // Validate price for limit orders
      final price = _orderType == 'Market' ? 0.0 : double.tryParse(_currentPrice.toStringAsFixed(2)) ?? 0.0;
      
      // Client-side balance validation
      final orderTotal = amount * price;
      if (_isBuy) {
        final availableUsdt = _balance?['usdt_available'] ?? 0.0;
        if (orderTotal > availableUsdt) {
          _showMessage(
            'Insufficient balance. Required: ${orderTotal.toStringAsFixed(2)} USDT, Available: ${availableUsdt.toStringAsFixed(2)} USDT',
            isError: true,
          );
          setState(() { _isLoading = false; });
          return;
        }
      } else {
        final availableBtc = _balance?['free'] ?? 0.0;
        if (amount > availableBtc) {
          _showMessage(
            'Insufficient balance. Required: ${amount.toStringAsFixed(5)} BTC, Available: ${availableBtc.toStringAsFixed(5)} BTC',
            isError: true,
          );
          setState(() { _isLoading = false; });
          return;
        }
      }
      
      print('=== ORDER PLACEMENT ===');
      print('Amount: $amount');
      print('Price: $price');
      print('Order Type: $_orderType');
      print('Side: ${_isBuy ? 'Buy' : 'Sell'}');
      print('Symbol: $_selectedSymbol');
      print('Balance: $_balance');
      print('====================');
      
      final result = await SpotService.placeOrder(
        symbol: _selectedSymbol,
        side: _isBuy ? 'Buy' : 'Sell',
        orderType: _orderType,
        qty: amount,
        price: price,
      );

      print('Order result: $result');

      if (result['success']) {
        _showMessage('Order placed successfully!');
        
        // Add order to order book and recent trades immediately for visual feedback
        final orderData = result['data'];
        if (orderData != null) {
          final newTrade = {
            'price': _orderType == 'Market' ? _currentPrice : price,
            'amount': amount,
            'side': _isBuy ? 'Buy' : 'Sell',
            'timestamp': DateTime.now().toIso8601String(),
            'isMyOrder': true,
          };
          
          setState(() {
            // Add to recent trades
            _recentTrades.insert(0, newTrade);
            if (_recentTrades.length > 50) {
              _recentTrades = _recentTrades.take(50).toList();
            }
            
            // Add to order book for limit orders
            if (_orderType == 'Limit') {
              final newOrder = {
                'price': price,
                'amount': amount,
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
            SpotService.userTrades = List<Map<String, dynamic>>.from(_recentTrades);
          });
        }
        
        _loadOpenOrders(); // Refresh open orders
        _loadBalance(); // Refresh balance
        setState(() {
          _amount = 0.0;
          _sliderValue = 0.0;
        });
      } else {
        _showMessage(result['error'], isError: true);
      }
    } catch (e) {
      print('Error placing order: $e');
      _showMessage('Error placing order: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
                                setState(() {
                                  _selectedSymbol = symbolName;
                                });
                                Navigator.pop(context);
                                _loadSpotData(); // Reload data for new symbol
                                _initializeWebSocket(); // Reconnect WebSocket for new symbol
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
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildTradingSection(),
                  const SizedBox(height: 20),
                  _buildRecentTradesSection(),
                  const SizedBox(height: 20),
                  _buildOpenOrdersSection(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0D0D0D),
      elevation: 0,
      title: GestureDetector(
        onTap: _showSymbolSelector,
        child: Row(
          children: [
            Text(
              _selectedSymbol.replaceAll('USDT', '/USDT'),
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Icon(Icons.keyboard_arrow_down, color: Colors.white.withValues(alpha: 0.6), size: 20),
            if (_isLoadingSymbols)
              const SizedBox(
                width: 16,
                height: 16,
                child: BitcoinLoadingIndicator(size: 16),
              ),
          ],
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
          _buildAmountInput(),
          const SizedBox(height: 12),
          _buildPercentageButtons(),
          const SizedBox(height: 12),
          const SizedBox(height: 16),
          _buildTotalInfo(),
          const SizedBox(height: 20),
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
                    if (_isBuy) {
                      final availableUsdt = double.tryParse(_balance?['usdt_available']?.toString() ?? '10000') ?? 10000;
                      // 2% fee buffer for 100% to ensure sufficient balance
                      final feeBuffer = percentage >= 1.0 ? 0.98 : 1.0;
                      // If USDT selected, show USDT amount directly; else convert to BTC quantity
                      if (_selectedAmountCoin == 'USDT') {
                        _amount = availableUsdt * percentage * feeBuffer;
                      } else {
                        _amount = (availableUsdt * percentage * feeBuffer) / _currentPrice;
                      }
                    } else {
                      final availableBtc = double.tryParse(_balance?['free']?.toString() ?? '0.1') ?? 0.1;
                      // 2% fee buffer for 100% to ensure sufficient balance
                      final feeBuffer = percentage >= 1.0 ? 0.98 : 1.0;
                      final btcValue = availableBtc * _currentPrice;
                      // If USDT selected, show USDT value; else show BTC quantity
                      if (_selectedAmountCoin == 'USDT') {
                        _amount = btcValue * percentage * feeBuffer;
                      } else {
                        _amount = (btcValue * percentage * feeBuffer) / _currentPrice;
                      }
                    }
                    // Ensure minimum order quantity for BTCUSDT (0.001 BTC) only when BTC selected
                    if (_selectedAmountCoin == 'BTC') {
                      const minQty = 0.001;
                      if (_amount < minQty && _selectedSymbol == 'BTCUSDT') {
                        _amount = minQty;
                      }
                    }
                    _amountController.text = _amount.toStringAsFixed(_selectedAmountCoin == 'USDT' ? 2 : 8);
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
    // Calculate funds required based on selected coin type
    final fundsRequired = _orderType == 'Limit'
        ? (_selectedAmountCoin == 'USDT' ? _amount : _currentPrice * _amount)
        : 0.0;

    // Calculate total for Market orders
    final total = _selectedAmountCoin == 'USDT' ? _amount : _currentPrice * _amount;
    
    // Get available balance - show actual value or default
    String availableBalanceText;
    if (_isBuy) {
      final usdtBalance = _balance?['usdt_available'] ?? 0.0;
      availableBalanceText = '${usdtBalance.toStringAsFixed(2)} USDT';
    } else {
      final btcBalance = _balance?['free'] ?? 0.0;
      availableBalanceText = '${btcBalance.toStringAsFixed(8)} BTC';
    }
    
    return Column(
      children: [
        if (_orderType == 'Limit')
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Funds req.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
              ),
              Flexible(
                child: Text(
                  '~${fundsRequired.toStringAsFixed(6)} USDT',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        if (_orderType == 'Limit') const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Available',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
            ),
            Flexible(
              child: Text(
                availableBalanceText,
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
      onTap: _isLoading ? null : _placeOrder,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: _isBuy ? const Color(0xFF84BD00) : Colors.red,
          borderRadius: BorderRadius.circular(8),
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
              : Text(
                  '${_isBuy ? 'Buy' : 'Sell'} ${_selectedSymbol.replaceAll('USDT', '')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
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

  Widget _buildRecentTradesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Trades',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'View All',
                    style: TextStyle(color: Color(0xFF84BD00), fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildRecentTradesTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTradesTable() {
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
                Expanded(flex: 2, child: _tableHeader('Price')),
                Expanded(flex: 2, child: _tableHeader('Amount')),
                Expanded(flex: 2, child: _tableHeader('Time')),
                Expanded(flex: 2, child: _tableHeader('Side')),
              ],
            ),
          ),
          // Table Rows
          ..._recentTrades.take(10).map((trade) => _buildTradeRow(trade)),
        ],
      ),
    );
  }

  Widget _buildTradeRow(Map<String, dynamic> trade) {
    final price = trade['price'] ?? 0.0;
    final qty = trade['qty'] ?? trade['amount'] ?? 0.0;
    final timestamp = trade['timestamp'] ?? 0;
    final side = trade['taker_side'] ?? trade['side'] ?? 'Buy';
    final isBuy = side == 'Buy';
    final isMyOrder = trade['isMyOrder'] == true;
    
    // Convert timestamp to readable time
    String timeStr;
    if (timestamp is int) {
      final time = DateTime.fromMillisecondsSinceEpoch(timestamp);
      timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (timestamp is String) {
      final time = DateTime.parse(timestamp);
      timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      timeStr = 'Now';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        border: const Border(bottom: BorderSide(color: Colors.white10)),
        color: isMyOrder ? (isBuy ? const Color(0xFF84BD00).withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15)) : null,
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: _tableCell('${price.toStringAsFixed(2)}', 10, isBuy ? const Color(0xFF84BD00) : Colors.red)),
          Expanded(flex: 2, child: _tableCell('${qty.toStringAsFixed(4)}', 10)),
          Expanded(flex: 2, child: _tableCell(timeStr, 10)),
          Expanded(flex: 2, child: _tableCell(isMyOrder ? '$side (You)' : side, 10, isBuy ? const Color(0xFF84BD00) : Colors.red)),
        ],
      ),
    );
  }

  Widget _buildOpenOrdersSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          minHeight: 400, // Increased minimum height
          maxHeight: 500, // Added maximum height
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Open Orders',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'All',
                    style: TextStyle(color: Color(0xFF84BD00), fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
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
}
