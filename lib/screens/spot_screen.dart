import 'dart:async';

import 'package:flutter/material.dart';
import '../services/spot_service.dart';
import 'chart_screen.dart';

class SpotScreen extends StatefulWidget {
  const SpotScreen({super.key});

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
  
  // API data
  List<Map<String, dynamic>> _sellOrders = [];
  List<Map<String, dynamic>> _buyOrders = [];
  List<Map<String, dynamic>> _openOrders = [];
  List<Map<String, dynamic>> _recentTrades = [];
  List<Map<String, dynamic>> _symbols = [];
  Map<String, dynamic>? _balance;
  Map<String, dynamic>? _ticker;
  Map<String, dynamic>? _fees;
  Map<String, dynamic>? _healthStatus;
  bool _isWebSocketConnected = false;
  bool _isLoadingSymbols = false;

  Timer? _connectionCheckTimer;

  @override
  void initState() {
    super.initState();
    
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
    
    _loadSpotData();
    _initializeWebSocket();
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel();
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
              
              // Preserve user's orders (marked with isMyOrder)
              final mySellOrders = _sellOrders.where((o) => o['isMyOrder'] == true).toList();
              final myBuyOrders = _buyOrders.where((o) => o['isMyOrder'] == true).toList();
              
              _sellOrders = [...mySellOrders, ...List<Map<String, dynamic>>.from(asks)];
              _buyOrders = [...myBuyOrders, ...List<Map<String, dynamic>>.from(bids)];
              
              // Sort to maintain proper order
              _sellOrders.sort((a, b) => (a['price'] as double).compareTo(b['price'] as double));
              _buyOrders.sort((a, b) => (b['price'] as double).compareTo(a['price'] as double));
              
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

  // Load ticker data
  Future<void> _loadTicker() async {
    try {
      final result = await SpotService.getTicker(_selectedSymbol);
      if (result['success']) {
        setState(() {
          _ticker = result['data'];
          if (_ticker != null && _ticker!['last_price'] != null) {
            _currentPrice = double.tryParse(_ticker!['last_price'].toString()) ?? _currentPrice;
          }
        });
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
        });
      }
    } catch (e) {
      print('Error loading order book: $e');
    }
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
      print('Loading balance...');
      final result = await SpotService.getBalance();
      print('Balance API result: $result');
      
      if (result['success'] && result['data'] != null) {
        setState(() {
          _balance = result['data'];
          print('Balance loaded: $_balance');
          print('USDT Available: ${_balance?['usdt_available']}');
          print('USDT Locked: ${_balance?['usdt_locked']}');
          print('Free: ${_balance?['free']}');
        });
      } else {
        print('Balance API error: ${result['error']}');
        // Set default balance for testing
        setState(() {
          _balance = {
            'user_id': 1,
            'usdt_available': 10000.0,
            'usdt_locked': 0.0,
            'free': 10000.0,
          };
          print('Using default balance for testing');
        });
      }
    } catch (e) {
      print('Error loading balance: $e');
      // Set default balance for testing
      setState(() {
        _balance = {
          'user_id': 1,
          'usdt_available': 10000.0,
          'usdt_locked': 0.0,
          'free': 10000.0,
        };
        print('Using default balance due to error');
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
      // Validate amount
      final amount = double.tryParse(_amount.toStringAsFixed(8)) ?? 0.0;
      if (amount <= 0) {
        _showMessage('Invalid amount format', isError: true);
        setState(() { _isLoading = false; });
        return;
      }

      // Validate price for limit orders
      final price = _orderType == 'Market' ? 0.0 : double.tryParse(_currentPrice.toStringAsFixed(2)) ?? 0.0;
      
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
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF84BD00)),
                ),
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
                  Text(
                    _currentPrice.toStringAsFixed(2),
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
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
          _buildPriceInput(),
          const SizedBox(height: 16),
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
                    'Market Price',
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
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
        Text(
          'Limit Price',
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
                          suffixText: 'USD',
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
        Text(
          'Amount',
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
                child: TextField(
                  controller: _amountController,
                  onChanged: (value) {
                    setState(() {
                      _amount = double.tryParse(value) ?? 0.0;
                      _sliderValue = _amount > 0 ? (_amount / 1.0).clamp(0.0, 1.0) : 0.0;
                    });
                  },
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '0.00',
                    hintStyle: TextStyle(color: Color(0xFF6C7278)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                    suffixText: 'BTC',
                    suffixStyle: TextStyle(
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
    if (_orderType != 'Limit') return const SizedBox.shrink();
    
    return Container(
      height: 32,
      child: Row(
        children: ['10%', '25%', '50%', '75%', '100%'].map((percent) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: GestureDetector(
                onTap: () {
                  final percentage = double.parse(percent.replaceAll('%', '')) / 100;
                  setState(() {
                    _sliderValue = percentage;
                    if (_isBuy) {
                      // Calculate amount based on available USDT divided by limit price
                      final availableUsdt = double.tryParse(_balance?['usdt_available']?.toString() ?? '10000') ?? 10000;
                      _amount = (availableUsdt * percentage) / _currentPrice;
                    } else {
                      // Calculate amount based on available BTC value divided by limit price
                      final availableBtc = double.tryParse(_balance?['free']?.toString() ?? '0.1') ?? 0.1;
                      final btcValue = availableBtc * _currentPrice; // Convert BTC to USDT value
                      _amount = (btcValue * percentage) / _currentPrice; // Calculate BTC amount based on percentage of value
                    }
                    // Update the amount controller to show the calculated amount
                    _amountController.text = _amount.toStringAsFixed(8);
                  });
                },
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: _sliderValue == double.parse(percent.replaceAll('%', '')) / 100
                        ? (_isBuy ? const Color(0xFF84BD00) : Colors.red)
                        : const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      percent,
                      style: TextStyle(
                        color: _sliderValue == double.parse(percent.replaceAll('%', '')) / 100
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTotalInfo() {
    final total = _currentPrice * _amount;
    final fundsRequired = _orderType == 'Limit' ? total : 0.0;
    
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
                _isBuy 
                    ? '${(_balance?['usdt_available']?.toStringAsFixed(2) ?? '500.00')} USDT'
                    : '${(_balance?['free']?.toStringAsFixed(8) ?? '0.10000000')} BTC',
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
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: 350, // Maximum height constraint
        minHeight: 250, // Minimum height constraint
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Use minimum size
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Order Book',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Top 5',
                  style: TextStyle(color: Color(0xFF84BD00), fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSellOrders(),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: const BoxDecoration(
                      border: Border.symmetric(horizontal: BorderSide(color: Colors.white10)),
                    ),
                    child: Text(
                      _currentPrice.toStringAsFixed(1),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildBuyOrders(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellOrders() {
    return Column(
      mainAxisSize: MainAxisSize.min, // Use minimum size
      children: _sellOrders.take(5).map((order) { // Limit to top 5 sell orders
        final isMyOrder = order['isMyOrder'] == true;
        return Container(
          constraints: const BoxConstraints(
            minHeight: 20, // Minimum height for each order row
          ),
          decoration: BoxDecoration(
            color: isMyOrder ? Colors.red.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(2),
            border: isMyOrder ? Border.all(color: Colors.red, width: 1) : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    (order['price'] ?? 0.0).toStringAsFixed(1),
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                    overflow: TextOverflow.ellipsis, // Prevent overflow
                  ),
                ),
                Expanded(
                  child: Text(
                    (order['amount'] ?? 0.0).toStringAsFixed(4),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                    overflow: TextOverflow.ellipsis, // Prevent overflow
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBuyOrders() {
    return Column(
      mainAxisSize: MainAxisSize.min, // Use minimum size
      children: _buyOrders.take(5).map((order) { // Limit to top 5 buy orders
        final isMyOrder = order['isMyOrder'] == true;
        return Container(
          constraints: const BoxConstraints(
            minHeight: 20, // Minimum height for each order row
          ),
          decoration: BoxDecoration(
            color: isMyOrder ? const Color(0xFF84BD00).withValues(alpha: 0.3) : const Color(0xFF84BD00).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(2),
            border: isMyOrder ? Border.all(color: const Color(0xFF84BD00), width: 1) : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    (order['price'] ?? 0.0).toStringAsFixed(1),
                    style: const TextStyle(color: Color(0xFF84BD00), fontSize: 12),
                    overflow: TextOverflow.ellipsis, // Prevent overflow
                  ),
                ),
                Expanded(
                  child: Text(
                    (order['amount'] ?? 0.0).toStringAsFixed(4),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                    overflow: TextOverflow.ellipsis, // Prevent overflow
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
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
          Expanded(flex: 2, child: _tableCell('${orderQty.toStringAsFixed(4)} BTC', 10)),
          Expanded(flex: 2, child: _tableCell('${executed.toStringAsFixed(4)} BTC', 10)),
          Expanded(flex: 2, child: _tableCell('${total.toStringAsFixed(2)} USDT', 10)),
          Expanded(flex: 3, child: _tableCell(order['order_type'] ?? 'Limit', 10)),
          Expanded(flex: 2, child: _buildActionCell(remaining > 0, orderId, symbol: _selectedSymbol, price: orderPrice, side: orderSide)),
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
