import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class SpotService {
  static const String _baseUrl = 'http://13.235.89.109:9000';
  static const String _wsUrl = 'ws://13.235.89.109:9001';
  static WebSocketChannel? _channel;
  static StreamController<Map<String, dynamic>>? _tickerController;
  static StreamController<Map<String, dynamic>>? _orderbookController;
  static StreamController<Map<String, dynamic>>? _tradesController;
  static StreamController<Map<String, dynamic>>? _ordersController;
  static StreamController<Map<String, dynamic>>? _fillsController;
  
  // Persistent order data across screen navigation
  static List<Map<String, dynamic>> userBuyOrders = [];
  static List<Map<String, dynamic>> userSellOrders = [];
  static List<Map<String, dynamic>> userTrades = [];
  static String currentSymbol = 'BTCUSDT';

  // Get ticker data (market summary)
  static Future<Map<String, dynamic>> getTicker(String symbol) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/ticker/$symbol'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      print('Ticker Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'],
            'error': null
          };
        } else {
          return {
            'success': false,
            'data': null,
            'error': responseData['error'] ?? 'Failed to get ticker data'
          };
        }
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'error': errorData['error'] ?? 'Failed to get ticker data'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'data': null,
        'error': 'Error fetching ticker: ${e.toString()}'
      };
    }
  }

  // Get order book (L2 orderbook snapshot)
  static Future<Map<String, dynamic>> getOrderBook(String symbol) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/book/$symbol'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      print('OrderBook Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'],
            'error': null
          };
        } else {
          return {
            'success': false,
            'data': null,
            'error': responseData['error'] ?? 'Failed to get order book'
          };
        }
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'error': errorData['error'] ?? 'Failed to get order book'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'data': null,
        'error': 'Error fetching order book: ${e.toString()}'
      };
    }
  }

  // Place spot order
  static Future<Map<String, dynamic>> placeOrder({
    required String symbol,
    required String side, // 'Buy' or 'Sell'
    required String orderType, // 'Limit' or 'Market'
    required double qty,
    double price = 0.0, // Use 0 for market orders
    bool reduceOnly = false,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'data': null,
          'error': 'Authentication required'
        };
      }

      // Get user_id from token or storage (assuming it's stored during login)
      final userId = await _getUserId();

      final requestBody = jsonEncode({
        'user_id': userId,
        'symbol': symbol,
        'side': side,
        'price': price,
        'qty': qty,
        'order_type': orderType,
        'reduce_only': reduceOnly,
      });

      print('Place Order Request: $requestBody');
      print('Token: $token');
      print('Authorization Header: Bearer $token');

      final response = await http.post(
        Uri.parse('$_baseUrl/order/new'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: requestBody,
      ).timeout(const Duration(seconds: 30));

      print('Place Order Response: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'],
            'error': null
          };
        } else {
          return {
            'success': false,
            'data': null,
            'error': responseData['error'] ?? 'Failed to place order'
          };
        }
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'error': errorData['error'] ?? 'Failed to place order'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'data': null,
        'error': 'Error placing order: ${e.toString()}'
      };
    }
  }

  // Get open orders
  static Future<Map<String, dynamic>> getOpenOrders({String? symbol}) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'data': null,
          'error': 'Authentication required'
        };
      }

      final userId = await _getUserId();

      String url = '$_baseUrl/orders/open/$userId';
      if (symbol != null) {
        url += '?symbol=$symbol';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      print('Open Orders Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'],
            'error': null
          };
        } else {
          return {
            'success': false,
            'data': null,
            'error': responseData['error'] ?? 'Failed to get open orders'
          };
        }
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'error': errorData['error'] ?? 'Failed to get open orders'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'data': null,
        'error': 'Error fetching open orders: ${e.toString()}'
      };
    }
  }

  // Cancel order
  static Future<Map<String, dynamic>> cancelOrder({
    required String orderId,
    required String symbol,
    required double price,
    required String side,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'data': null,
          'error': 'Authentication required'
        };
      }

      // Get user_id from storage
      final userId = await _getUserId();

      final requestBody = jsonEncode({
        'user_id': userId,
        'symbol': symbol,
        'order_id': int.tryParse(orderId) ?? 0,
        'price': price,
        'side': side,
      });

      print('Cancel Order Request: $requestBody');

      final response = await http.post(
        Uri.parse('$_baseUrl/order/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: requestBody,
      ).timeout(const Duration(seconds: 30));

      print('Cancel Order Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'],
            'error': null
          };
        } else {
          return {
            'success': false,
            'data': null,
            'error': responseData['error'] ?? 'Failed to cancel order'
          };
        }
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'error': errorData['error'] ?? 'Failed to cancel order'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'data': null,
        'error': 'Error cancelling order: ${e.toString()}'
      };
    }
  }

  // Get user balance
  static Future<Map<String, dynamic>> getBalance() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'data': null,
          'error': 'Authentication required'
        };
      }

      // Get user_id from storage
      final userId = await _getUserId();

      final response = await http.get(
        Uri.parse('$_baseUrl/balance/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      print('Balance Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'],
            'error': null
          };
        } else {
          return {
            'success': false,
            'data': null,
            'error': responseData['error'] ?? 'Failed to get balance'
          };
        }
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'error': errorData['error'] ?? 'Failed to get balance'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'data': null,
        'error': 'Error fetching balance: ${e.toString()}'
      };
    }
  }

  // Get user positions
  static Future<Map<String, dynamic>> getPositions() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'data': null,
          'error': 'Authentication required'
        };
      }

      final userId = await _getUserId();

      final response = await http.get(
        Uri.parse('$_baseUrl/positions/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      print('Positions Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'],
            'error': null
          };
        } else {
          return {
            'success': false,
            'data': null,
            'error': responseData['error'] ?? 'Failed to get positions'
          };
        }
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'error': errorData['error'] ?? 'Failed to get positions'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'data': null,
        'error': 'Error fetching positions: ${e.toString()}'
      };
    }
  }

  // Get 24hr ticker statistics for all symbols
  static Future<Map<String, dynamic>> get24hrTickerStats() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/ticker/24hr'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      print('24hr Ticker Stats Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'],
            'error': null
          };
        } else {
          return {
            'success': false,
            'data': null,
            'error': responseData['error'] ?? 'Failed to get 24hr ticker stats'
          };
        }
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'error': errorData['error'] ?? 'Failed to get 24hr ticker stats'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'data': null,
        'error': 'Error fetching 24hr ticker stats: ${e.toString()}'
      };
    }
  }

  // Get server time
  static Future<Map<String, dynamic>> getServerTime() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/time'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('Server Time Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'data': responseData,
          'error': null
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'error': errorData['error'] ?? 'Failed to get server time'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'data': null,
        'error': 'Error fetching server time: ${e.toString()}'
      };
    }
  }

  // Get exchange information
  static Future<Map<String, dynamic>> getExchangeInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/exchangeInfo'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      print('Exchange Info Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'],
            'error': null
          };
        } else {
          return {
            'success': false,
            'data': null,
            'error': responseData['error'] ?? 'Failed to get exchange info'
          };
        }
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'error': errorData['error'] ?? 'Failed to get exchange info'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'data': null,
        'error': 'Error fetching exchange info: ${e.toString()}'
      };
    }
  }

  // Get user trade history
  static Future<Map<String, dynamic>> getUserTradeHistory({String? symbol}) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'data': null,
          'error': 'Authentication required'
        };
      }

      final userId = await _getUserId();

      String url = '$_baseUrl/trades/user/$userId';
      if (symbol != null) {
        url += '?symbol=$symbol';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      print('User Trade History Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'],
            'error': null
          };
        } else {
          return {
            'success': false,
            'data': null,
            'error': responseData['error'] ?? 'Failed to get user trade history'
          };
        }
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'error': errorData['error'] ?? 'Failed to get user trade history'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'data': null,
        'error': 'Error fetching user trade history: ${e.toString()}'
      };
    }
  }

  // Get order history
  static Future<Map<String, dynamic>> getOrderHistory({
    String? symbol,
    int? limit,
    int? offset,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'data': null,
          'error': 'Authentication required'
        };
      }

      String url = '$_baseUrl/v1/spot/orders/history';
      List<String> queryParams = [];
      
      if (symbol != null) queryParams.add('symbol=$symbol');
      if (limit != null) queryParams.add('limit=$limit');
      if (offset != null) queryParams.add('offset=$offset');
      
      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      print('Order History Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'],
            'error': null
          };
        } else {
          return {
            'success': false,
            'data': null,
            'error': responseData['error'] ?? 'Failed to get order history'
          };
        }
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'error': errorData['error'] ?? 'Failed to get order history'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'data': null,
        'error': 'Error fetching order history: ${e.toString()}'
      };
    }
  }

  // Get all tradeable symbols
  static Future<Map<String, dynamic>> getSymbols() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/symbols'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      print('Symbols Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'],
            'error': null
          };
        } else {
          return {
            'success': false,
            'data': null,
            'error': responseData['error'] ?? 'Failed to get symbols'
          };
        }
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'error': errorData['error'] ?? 'Failed to get symbols'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'data': null,
        'error': 'Error fetching symbols: ${e.toString()}'
      };
    }
  }

  // Get recent trades (last 50)
  static Future<Map<String, dynamic>> getRecentTrades(String symbol) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/trades/$symbol'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      print('Recent Trades Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'],
            'error': null
          };
        } else {
          return {
            'success': false,
            'data': null,
            'error': responseData['error'] ?? 'Failed to get recent trades'
          };
        }
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'error': errorData['error'] ?? 'Failed to get recent trades'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'data': null,
        'error': 'Error fetching recent trades: ${e.toString()}'
      };
    }
  }

  // Get exchange fees
  static Future<Map<String, dynamic>> getFees() async {
    try {
      final url = Uri.parse('$_baseUrl/fees');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('Fees Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'],
            'error': null
          };
        } else {
          return {
            'success': false,
            'data': null,
            'error': responseData['error'] ?? 'Failed to get fees'
          };
        }
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'error': errorData['error'] ?? 'Failed to get fees'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'data': null,
        'error': 'Error fetching fees: ${e.toString()}'
      };
    }
  }
  
  // Get health status
  static Future<Map<String, dynamic>> getHealth() async {
    try {
      final url = Uri.parse('$_baseUrl/health');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('Health Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'data': responseData,
          'error': null
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'error': errorData['error'] ?? 'Failed to get health status'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'data': null,
        'error': 'Error fetching health status: ${e.toString()}'
      };
    }
  }

  // Get ready status
  static Future<Map<String, dynamic>> getReady() async {
    try {
      final url = Uri.parse('$_baseUrl/ready');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('Ready Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'data': responseData,
          'error': null
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'error': errorData['error'] ?? 'Failed to get ready status'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'data': null,
        'error': 'Error fetching ready status: ${e.toString()}'
      };
    }
  }

  // WebSocket Connection Methods
  
  // Connect to WebSocket for real-time data
  static Future<void> connectWebSocket() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        print('Authentication required for WebSocket connection');
        return;
      }

      _channel = WebSocketChannel.connect(
        Uri.parse('$_wsUrl/ws'),
        protocols: ['websocket'],
      );

      print('WebSocket connected successfully');

      // Initialize stream controllers
      _tickerController = StreamController<Map<String, dynamic>>.broadcast();
      _orderbookController = StreamController<Map<String, dynamic>>.broadcast();
      _tradesController = StreamController<Map<String, dynamic>>.broadcast();
      _ordersController = StreamController<Map<String, dynamic>>.broadcast();
      _fillsController = StreamController<Map<String, dynamic>>.broadcast();

      // Listen for messages
      _channel!.stream.listen(
        _handleWebSocketMessage,
        onError: (error) {
          print('WebSocket error: $error');
        },
        onDone: () {
          print('WebSocket disconnected');
          _channel = null;
        },
      );
    } catch (e) {
      print('WebSocket connection error: $e');
    }
  }

  // Handle incoming WebSocket messages
  static void _handleWebSocketMessage(dynamic message) {
    try {
      final data = json.decode(message);
      final type = data['type'] as String?;
      
      print('WebSocket message received: type=$type, data=$data');
      
      switch (type) {
        case 'book':
          _orderbookController?.add(data);
          print('Order book updated');
          break;
        case 'trade':
          _tradesController?.add(data);
          print('Trade received: ${data['data']}');
          break;
        case 'order_update':
          _ordersController?.add(data);
          print('Order update: ${data['data']}');
          break;
        case 'fill':
          _fillsController?.add(data);
          print('Fill received: ${data['data']}');
          break;
        case 'auth_ok':
          print('WebSocket authenticated for user ${data['user_id']}');
          break;
        default:
          print('Unknown WebSocket message type: $type');
      }
    } catch (e) {
      print('Error parsing WebSocket message: $e');
    }
  }

  // Subscribe to symbol for order book and trades
  static Stream<Map<String, dynamic>> getSymbolStream(String symbol) {
    if (_channel == null) {
      connectWebSocket();
      // Wait for connection
      Future.delayed(Duration(seconds: 1));
    }
    
    // Send subscription message
    _sendWebSocketMessage({
      'subscribe': symbol,
    });
    
    print('Subscribed to symbol: $symbol');
    return _orderbookController?.stream ?? Stream.empty();
  }

  // Subscribe to order book updates
  static Stream<Map<String, dynamic>> getOrderBookStream(String symbol) {
    if (_channel == null) {
      connectWebSocket();
      Future.delayed(Duration(seconds: 1));
    }
    
    _sendWebSocketMessage({
      'subscribe': symbol,
    });
    
    print('Subscribed to order book: $symbol');
    return _orderbookController?.stream ?? Stream.empty();
  }

  // Subscribe to trade updates
  static Stream<Map<String, dynamic>> getTradesStream(String symbol) {
    if (_channel == null) {
      connectWebSocket();
      Future.delayed(Duration(seconds: 1));
    }
    
    _sendWebSocketMessage({
      'subscribe': symbol,
    });
    
    print('Subscribed to trades: $symbol');
    return _tradesController?.stream ?? Stream.empty();
  }

  // Subscribe to order updates (requires auth)
  static Stream<Map<String, dynamic>> getOrderUpdatesStream() {
    if (_channel == null) {
      connectWebSocket();
      Future.delayed(Duration(seconds: 1));
    }
    
    // Authenticate for private events
    _authenticateWebSocket();
    
    print('Subscribed to order updates');
    return _ordersController?.stream ?? Stream.empty();
  }

  // Subscribe to fill events (requires auth)
  static Stream<Map<String, dynamic>> getFillsStream() {
    if (_channel == null) {
      connectWebSocket();
      Future.delayed(Duration(seconds: 1));
    }
    
    // Authenticate for private events
    _authenticateWebSocket();
    
    print('Subscribed to fill events');
    return _fillsController?.stream ?? Stream.empty();
  }

  // Authenticate WebSocket for private events
  static Future<void> _authenticateWebSocket() async {
    final userId = await _getUserId();
    _sendWebSocketMessage({
      'auth': {'user_id': userId},
    });
    print('WebSocket authentication sent for user: $userId');
  }

  // Send message through WebSocket
  static void _sendWebSocketMessage(Map<String, dynamic> message) {
    if (_channel != null) {
      final encodedMessage = json.encode(message);
      _channel!.sink.add(encodedMessage);
    }
  }

  // Disconnect WebSocket
  static void disconnectWebSocket() {
    _channel?.sink.close();
    _channel = null;
    
    _tickerController?.close();
    _orderbookController?.close();
    _tradesController?.close();
    _ordersController?.close();
    _fillsController?.close();
    
    _tickerController = null;
    _orderbookController = null;
    _tradesController = null;
    _ordersController = null;
    _fillsController = null;
  }

  // Check WebSocket connection status
  static bool isConnected() {
    return _channel != null;
  }
  
  // Helper method to get user ID from storage
  static Future<String> _getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Try to get as String first (new way)
      String? userId = prefs.getString('user_id');
      if (userId != null) return userId;
      
      // Fallback for migration: try getting as int and converting
      int? userIdInt = prefs.getInt('user_id');
      if (userIdInt != null) return userIdInt.toString();
      
      return '1'; // Default fallback
    } catch (e) {
      return '1'; // Default fallback
    }
  }
}
