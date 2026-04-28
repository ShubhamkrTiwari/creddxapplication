import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_config.dart';

class SocketService {
  static final String _baseUrl = ApiConfig.socketUrl;
  static final String _socketPath = ApiConfig.socketPath;
  static IO.Socket? _socket;
  static final StreamController<Map<String, dynamic>> _balanceController = StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _orderbookController = StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _tradesController = StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _ordersController = StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _fillsController = StreamController<Map<String, dynamic>>.broadcast();
  static bool _isConnecting = false;
  static int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;

  static Stream<Map<String, dynamic>> get balanceStream => _balanceController.stream;
  static Stream<Map<String, dynamic>> get orderbookStream => _orderbookController.stream;
  static Stream<Map<String, dynamic>> get tradesStream => _tradesController.stream;
  static Stream<Map<String, dynamic>> get ordersStream => _ordersController.stream;
  static Stream<Map<String, dynamic>> get fillsStream => _fillsController.stream;
  
  static bool get isConnected => _socket?.connected ?? false;
  static bool get isConnecting => _isConnecting;

  get kycStatusStream => null;

  static Future<void> connect() async {
    if (_socket != null && _socket!.connected) {
      debugPrint('SocketService: Already connected, emitting join');
      await _joinWalletRoom();
      return;
    }
    if (_isConnecting) return;
    _isConnecting = true;

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        debugPrint('SocketService: No auth token found');
        _isConnecting = false;
        return;
      }

      debugPrint('SocketService: Connecting to $_baseUrl with path $_socketPath');

      _socket = IO.io(
        _baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .setPath(_socketPath)
            .enableAutoConnect()
            .setReconnectionDelay(5000)
            .setReconnectionDelayMax(30000)
            .setTimeout(10000)
            .setExtraHeaders({'Authorization': 'Bearer $token'})
            .build(),
      );

      _socket!.onConnect((_) {
        debugPrint('SocketService: Connected to server');
        _isConnecting = false;
        _joinWalletRoom();
      });

      _socket!.onDisconnect((reason) {
        debugPrint('SocketService: Disconnected from server - reason: $reason');
        _isConnecting = false;
        _reconnect();
      });

      _socket!.onConnectError((error) {
        debugPrint('SocketService Connection Error: $error');
        _isConnecting = false;
        // Back-off reconnect: wait longer on repeated failures
        final delay = Duration(seconds: 15 + (_reconnectAttempts * 5).clamp(0, 45));
        Future.delayed(delay, () => _reconnect());
      });

      _socket!.onError((error) {
        debugPrint('SocketService Error: $error');
      });

      _socket!.onConnectTimeout((_) {
        debugPrint('SocketService: Connection timeout');
        _isConnecting = false;
        _reconnect();
      });

      // Handle incoming events
      _socket!.on('wallet summary update socket', (data) {
        debugPrint('SocketService: wallet summary update socket received: $data');
        _balanceController.add({'type': 'wallet_summary', 'data': data});
      });

      _socket!.on('wallet_summary', (data) {
        debugPrint('SocketService: wallet_summary received: $data');
        _balanceController.add({'type': 'wallet_summary', 'data': data});
      });

      _socket!.on('balance_update', (data) {
        debugPrint('SocketService: Balance update received: $data');
        _balanceController.add({'type': 'balance_update', 'data': data});
      });

      _socket!.on('auth_ok', (data) {
        debugPrint('SocketService: Authenticated successfully');
      });

      _socket!.on('book', (data) {
        final processedData = _ensureSymbol(data, 'book');
        _orderbookController.add(processedData);
      });

      _socket!.on('trade', (data) {
        final processedData = _ensureSymbol(data, 'trade');
        _tradesController.add(processedData);
      });

      _socket!.on('order_update', (data) {
        _ordersController.add({'type': 'order_update', 'data': data});
      });

      _socket!.on('fill', (data) {
        _fillsController.add({'type': 'fill', 'data': data});
      });

      _socket!.connect();
    } catch (e) {
      debugPrint('SocketService Connection Error: $e');
      _isConnecting = false;
      _reconnect();
    }
  }

  static Future<void> _joinWalletRoom() async {
    final userId = await _getUserId();
    // Emit 'join' like web app does
    _socket?.emit("join", userId);
    debugPrint('SocketService: Join emitted for user $userId');
  }

  static Map<String, dynamic> _ensureSymbol(dynamic data, String type) {
    if (data is Map) {
      final processedData = Map<String, dynamic>.from(data);
      processedData['type'] = type;
      if (processedData['symbol'] == null &&
          processedData['data'] != null &&
          processedData['data']['symbol'] != null) {
        processedData['symbol'] = processedData['data']['symbol'];
      }
      return processedData;
    }
    return {'type': type, 'data': data};
  }

  static void subscribe(String symbol) {
    _socket?.emit('subscribe', {'symbol': symbol});
    debugPrint('SocketService: Subscribed to $symbol');
  }

  // Request wallet balance from socket
  static void requestWalletBalance() {
    _socket?.emit('get_wallet_balance');
    debugPrint('SocketService: Requested wallet balance');
  }

  // Request wallet summary from socket
  static void requestWalletSummary() {
    _socket?.emit('get_wallet_summary');
    debugPrint('SocketService: Requested wallet summary');
  }

  static void _reconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('SocketService: Max reconnect attempts ($_maxReconnectAttempts) reached. Stopping.');
      return;
    }
    _reconnectAttempts++;
    _socket = null;
    _isConnecting = false;
    final delay = Duration(seconds: (5 * _reconnectAttempts).clamp(5, 60));
    debugPrint('SocketService: Reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts in ${delay.inSeconds}s');
    Future.delayed(delay, () => connect());
  }

  static void disconnect() {
    _reconnectAttempts = 0; // Reset on manual disconnect
    _socket?.disconnect();
    _socket = null;
  }

  static Future<String> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id') ?? prefs.getInt('user_id')?.toString() ?? '1';
  }
}
