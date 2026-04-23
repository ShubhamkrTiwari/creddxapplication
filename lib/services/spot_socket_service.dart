import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_config.dart';

/// Comprehensive WebSocket service for Spot trading
/// Features: auto-reconnect with exponential backoff, heartbeat, connection state management
class SpotSocketService {
  // WebSocket URL - using secure WebSocket
  static final String _wsUrl = ApiConfig.spotWebSocketUrl;
  
  // Connection settings
  static const Duration _heartbeatInterval = Duration(seconds: 20); // Reduced from 30s
  static const Duration _pongTimeout = Duration(seconds: 10); // Max time to wait for pong
  static const Duration _connectionTimeout = Duration(seconds: 10);
  static const int _maxReconnectAttempts = 10;
  static const Duration _initialReconnectDelay = Duration(seconds: 1);
  static const Duration _maxReconnectDelay = Duration(seconds: 60);
  static const Duration _connectionHealthCheckInterval = Duration(seconds: 45); // Max time without any message
  
  // Internal state
  static WebSocketChannel? _channel;
  static bool _isConnecting = false;
  static bool _isConnected = false;
  static int _reconnectAttempts = 0;
  static Timer? _heartbeatTimer;
  static Timer? _reconnectTimer;
  static Timer? _healthCheckTimer;
  static String? _currentSymbol;
  static final Set<String> _subscribedSymbols = {};
  static DateTime _lastMessageReceived = DateTime.now();
  static bool _isWaitingForPong = false;
  
  // Stream controllers
  static final StreamController<SocketConnectionState> _connectionController = 
      StreamController<SocketConnectionState>.broadcast();
  static final StreamController<Map<String, dynamic>> _balanceController = 
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _orderbookController = 
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _tradesController = 
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _ordersController = 
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _fillsController = 
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _tickerController = 
      StreamController<Map<String, dynamic>>.broadcast();

  // Public streams
  static Stream<SocketConnectionState> get connectionStream => _connectionController.stream;
  static Stream<Map<String, dynamic>> get balanceStream => _balanceController.stream;
  static Stream<Map<String, dynamic>> get orderbookStream => _orderbookController.stream;
  static Stream<Map<String, dynamic>> get tradesStream => _tradesController.stream;
  static Stream<Map<String, dynamic>> get ordersStream => _ordersController.stream;
  static Stream<Map<String, dynamic>> get fillsStream => _fillsController.stream;
  static Stream<Map<String, dynamic>> get tickerStream => _tickerController.stream;

  // Connection state
  static SocketConnectionState get connectionState => 
      _isConnected ? SocketConnectionState.connected : 
      _isConnecting ? SocketConnectionState.connecting : SocketConnectionState.disconnected;
  
  static bool get isConnected => _isConnected;
  static bool get isConnecting => _isConnecting;

  /// Connect to WebSocket server
  static Future<void> connect() async {
    if (_isConnected || _isConnecting) {
      debugPrint('SpotSocketService: Already connected or connecting');
      return;
    }

    _isConnecting = true;
    _connectionController.add(SocketConnectionState.connecting);
    
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        debugPrint('SpotSocketService: No auth token found');
        _isConnecting = false;
        _connectionController.add(SocketConnectionState.disconnected);
        return;
      }

      debugPrint('SpotSocketService: Connecting to $_wsUrl');
      
      // Create WebSocket connection with headers
      final uri = Uri.parse(_wsUrl);
      _channel = IOWebSocketChannel.connect(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
        pingInterval: _heartbeatInterval,
      );

      // Listen to messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: false,
      );

      // Wait for connection to establish
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Authenticate
      await _authenticate();
      
      // Mark as connected
      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      _lastMessageReceived = DateTime.now();
      _isWaitingForPong = false;
      _connectionController.add(SocketConnectionState.connected);
      
      // Subscribe to user channels immediately after connection
      subscribeUserChannels();
      
      // Start heartbeat
      _startHeartbeat();
      
      // Start connection health check
      _startHealthCheck();
      
      // Resubscribe to previously subscribed symbols
      _resubscribeAll();
      
      debugPrint('SpotSocketService: Connected successfully');
      
    } catch (e) {
      debugPrint('SpotSocketService Connection Error: $e');
      _isConnecting = false;
      _isConnected = false;
      _connectionController.add(SocketConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  /// Disconnect from WebSocket server
  static void disconnect() {
    debugPrint('SpotSocketService: Disconnecting...');
    
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _healthCheckTimer?.cancel();
    
    try {
      _channel?.sink.close();
    } catch (e) {
      debugPrint('SpotSocketService: Error closing channel: $e');
    }
    
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
    _connectionController.add(SocketConnectionState.disconnected);
    
    debugPrint('SpotSocketService: Disconnected');
  }

  /// Subscribe to a symbol for orderbook and trades
  /// Channels: book (L2 orderbook), trade (public trades), ticker (24h stats)
  static void subscribe(String symbol) {
    if (symbol.isEmpty) return;

    _currentSymbol = symbol;
    _subscribedSymbols.add(symbol);

    if (_isConnected) {
      _send({
        'type': 'subscribe',
        'channel': 'book',
        'symbol': symbol,
      });
      _send({
        'type': 'subscribe',
        'channel': 'trade',
        'symbol': symbol,
      });
      _send({
        'type': 'subscribe',
        'channel': 'ticker',
        'symbol': symbol,
      });
      debugPrint('SpotSocketService: Subscribed to $symbol (channels: book, trade, ticker)');
    }
  }

  /// Unsubscribe from a symbol
  static void unsubscribe(String symbol) {
    if (symbol.isEmpty) return;

    _subscribedSymbols.remove(symbol);

    if (_isConnected) {
      _send({
        'type': 'unsubscribe',
        'channel': 'book',
        'symbol': symbol,
      });
      _send({
        'type': 'unsubscribe',
        'channel': 'trade',
        'symbol': symbol,
      });
      _send({
        'type': 'unsubscribe',
        'channel': 'ticker',
        'symbol': symbol,
      });
      debugPrint('SpotSocketService: Unsubscribed from $symbol');
    }
  }

  /// Subscribe to user-specific channels (order_update, fill, balance_update)
  /// Private channels per-user: order lifecycle, trade fills, balance mutations
  static void subscribeUserChannels() {
    if (_isConnected) {
      _send({
        'type': 'subscribe',
        'channel': 'order_update',
      });
      _send({
        'type': 'subscribe',
        'channel': 'fill',
      });
      _send({
        'type': 'subscribe',
        'channel': 'balance_update',
      });
      debugPrint('SpotSocketService: Subscribed to user channels (order_update, fill, balance_update)');
    }
  }

  /// Send a message to the server
  static void _send(Map<String, dynamic> message) {
    if (_channel != null && _isConnected) {
      try {
        final jsonMessage = json.encode(message);
        _channel!.sink.add(jsonMessage);
        debugPrint('SpotSocketService: Sent: $jsonMessage');
      } catch (e) {
        debugPrint('SpotSocketService: Error sending message: $e');
      }
    }
  }

  /// Authenticate with the server
  static Future<void> _authenticate() async {
    final userId = await _getUserId();
    final token = await AuthService.getToken();
    
    _send({
      'auth': {
        'user_id': userId,
        'token': token,
      }
    });
    
    debugPrint('SpotSocketService: Auth sent for user $userId');
  }

  /// Handle incoming messages
  static void _handleMessage(dynamic message) {
    try {
      // Update last message received time for health check
      _lastMessageReceived = DateTime.now();
      _isWaitingForPong = false;
      
      final data = json.decode(message);
      final type = data['type'] ?? data['event'];
      
      debugPrint('SpotSocketService: Received [$type]: ${message.toString().substring(0, min(200, message.toString().length))}...');

      switch (type) {
        case 'auth_ok':
        case 'authenticated':
          debugPrint('SpotSocketService: Authenticated successfully');
          subscribeUserChannels();
          break;
          
        case 'auth_error':
          debugPrint('SpotSocketService: Auth failed - ${data['error']}');
          disconnect();
          break;
          
        case 'pong':
          debugPrint('SpotSocketService: Pong received');
          break;
          
        case 'balance_update':
        case 'balance':
          _balanceController.add(data);
          break;
          
        case 'book':
        case 'orderbook':
        case 'depth':
          _orderbookController.add(_normalizeOrderbookData(data));
          break;
          
        case 'trade':
        case 'trades':
          _tradesController.add(_normalizeTradeData(data));
          break;
          
        case 'order_update':
        case 'order':
          _ordersController.add(data);
          break;
          
        case 'fill':
        case 'fill_update':
          _fillsController.add(data);
          break;
          
        case 'ticker':
        case '24hrTicker':
          _tickerController.add(data);
          break;
          
        case 'error':
          debugPrint('SpotSocketService: Server error - ${data['error']}');
          break;
          
        default:
          debugPrint('SpotSocketService: Unknown message type: $type');
      }
    } catch (e) {
      debugPrint('SpotSocketService: Error parsing message: $e');
    }
  }

  /// Normalize orderbook data to consistent format
  static Map<String, dynamic> _normalizeOrderbookData(Map<String, dynamic> data) {
    final normalized = Map<String, dynamic>.from(data);
    
    // Ensure symbol is present
    if (normalized['symbol'] == null && normalized['data'] != null) {
      normalized['symbol'] = normalized['data']['symbol'];
    }
    
    // Ensure asks/bids are in correct format
    final rawData = normalized['data'] ?? normalized;
    if (rawData['asks'] != null || rawData['bids'] != null) {
      normalized['data'] = {
        'symbol': normalized['symbol'] ?? _currentSymbol,
        'asks': rawData['asks'] ?? [],
        'bids': rawData['bids'] ?? [],
        'timestamp': rawData['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      };
    }
    
    return normalized;
  }

  /// Normalize trade data to consistent format
  static Map<String, dynamic> _normalizeTradeData(Map<String, dynamic> data) {
    final normalized = Map<String, dynamic>.from(data);
    
    if (normalized['symbol'] == null && normalized['data'] != null) {
      normalized['symbol'] = normalized['data']['symbol'];
    }
    
    return normalized;
  }

  /// Handle WebSocket errors
  static void _handleError(error) {
    debugPrint('SpotSocketService Error: $error');
    _isConnected = false;
    _connectionController.add(SocketConnectionState.disconnected);
    _scheduleReconnect();
  }

  /// Handle WebSocket disconnection
  static void _handleDisconnect() {
    debugPrint('SpotSocketService: Connection closed by server');
    _isConnected = false;
    _connectionController.add(SocketConnectionState.disconnected);
    _scheduleReconnect();
  }

  /// Schedule reconnection with exponential backoff
  static void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('SpotSocketService: Max reconnect attempts reached');
      return;
    }

    _reconnectTimer?.cancel();
    
    // Calculate exponential backoff delay
    final delay = Duration(
      milliseconds: min(
        _initialReconnectDelay.inMilliseconds * pow(2, _reconnectAttempts).toInt(),
        _maxReconnectDelay.inMilliseconds,
      ),
    );
    
    _reconnectAttempts++;
    
    debugPrint('SpotSocketService: Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)');
    
    _reconnectTimer = Timer(delay, () {
      if (!_isConnected && !_isConnecting) {
        connect();
      }
    });
  }

  /// Start heartbeat to keep connection alive
  static void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (_isConnected) {
        // Check if we received pong from previous ping
        if (_isWaitingForPong) {
          debugPrint('SpotSocketService: Pong timeout - connection may be dead');
          _handleDisconnect();
          return;
        }
        
        _send({'type': 'ping'});
        _isWaitingForPong = true;
        debugPrint('SpotSocketService: Ping sent, waiting for pong');
      } else {
        timer.cancel();
      }
    });
  }

  /// Start connection health check to detect zombie connections
  static void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    
    _healthCheckTimer = Timer.periodic(_connectionHealthCheckInterval, (timer) {
      if (_isConnected) {
        final timeSinceLastMessage = DateTime.now().difference(_lastMessageReceived);
        if (timeSinceLastMessage > _connectionHealthCheckInterval) {
          debugPrint('SpotSocketService: Health check failed - no message for ${timeSinceLastMessage.inSeconds}s');
          _handleDisconnect();
        }
      } else {
        timer.cancel();
      }
    });
  }

  /// Resubscribe to all previously subscribed symbols after reconnection
  static void _resubscribeAll() {
    if (_currentSymbol != null) {
      subscribe(_currentSymbol!);
    }
    
    for (final symbol in _subscribedSymbols) {
      if (symbol != _currentSymbol) {
        subscribe(symbol);
      }
    }
  }

  /// Get user ID from storage
  static Future<String> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id') ?? 
           prefs.getInt('user_id')?.toString() ?? 
           '1';
  }

  /// Reset all state (useful for logout)
  static void reset() {
    disconnect();
    _currentSymbol = null;
    _subscribedSymbols.clear();
    _reconnectAttempts = 0;
  }
}

/// Connection states for the WebSocket
enum SocketConnectionState {
  disconnected,
  connecting,
  connected,
}
