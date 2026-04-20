import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SocketService {
  // NEXT_PUBLIC_SOCKET_URL=https://api11.hathmetech.com
  static const String _baseUrl = 'https://api11.hathmetech.com';
  static const String _socketPath = '/wallet-socket.io';
  static IO.Socket? _socket;
  static final StreamController<Map<String, dynamic>> _balanceController = StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _orderbookController = StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _tradesController = StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _ordersController = StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _fillsController = StreamController<Map<String, dynamic>>.broadcast();
  static bool _isConnecting = false;

  static Stream<Map<String, dynamic>> get balanceStream => _balanceController.stream;
  static Stream<Map<String, dynamic>> get orderbookStream => _orderbookController.stream;
  static Stream<Map<String, dynamic>> get tradesStream => _tradesController.stream;
  static Stream<Map<String, dynamic>> get ordersStream => _ordersController.stream;
  static Stream<Map<String, dynamic>> get fillsStream => _fillsController.stream;

  static Future<void> connect() async {
    if (_socket != null && _socket!.connected || _isConnecting) return;
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
            .setTransports(['websocket'])
            .setPath(_socketPath)
            .disableAutoConnect()

            .build(),
      );

      _socket!.onConnect((_) {
        debugPrint('SocketService: Connected to server');
        _isConnecting = false;
        _authenticate();
      });

      _socket!.onDisconnect((_) {
        debugPrint('SocketService: Disconnected from server');
        _reconnect();
      });

      _socket!.onConnectError((error) {
        debugPrint('SocketService Connection Error: $error');
        _isConnecting = false;
        _reconnect();
      });

      _socket!.onError((error) {
        debugPrint('SocketService Error: $error');
      });

      // Handle incoming events
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

  static Future<void> _authenticate() async {
    final userId = await _getUserId();
    _socket?.emit('auth', {'user_id': userId});
    debugPrint('SocketService: Auth sent for user $userId');
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

  static void _reconnect() {
    _socket = null;
    _isConnecting = false;
    Future.delayed(const Duration(seconds: 5), () => connect());
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  static Future<String> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id') ?? prefs.getInt('user_id')?.toString() ?? '1';
  }
}
