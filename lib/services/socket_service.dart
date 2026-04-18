import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SocketService {
  static const String _wsUrl = 'wss://api4.creddx.com/ws';
  static WebSocketChannel? _channel;
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
    if (_channel != null || _isConnecting) return;
    _isConnecting = true;

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        debugPrint('SocketService: No auth token found');
        _isConnecting = false;
        return;
      }

      debugPrint('SocketService: Connecting to $_wsUrl');
      _channel = WebSocketChannel.connect(
        Uri.parse('$_wsUrl/ws'),
        protocols: ['websocket'],
      );

      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          debugPrint('SocketService Error: $error');
          _reconnect();
        },
        onDone: () {
          debugPrint('SocketService: Connection closed');
          _reconnect();
        },
      );

      // Authenticate
      await _authenticate();
      _isConnecting = false;
    } catch (e) {
      debugPrint('SocketService Connection Error: $e');
      _isConnecting = false;
      _reconnect();
    }
  }

  static Future<void> _authenticate() async {
    final userId = await _getUserId();
    final authMessage = {
      'type': 'auth',
      'user_id': userId,
    };
    _send(authMessage);
    debugPrint('SocketService: Auth sent for user $userId');
  }

  static void _handleMessage(dynamic message) {
    try {
      final data = json.decode(message);
      final type = data['type'];

      switch (type) {
        case 'balance_update':
          debugPrint('SocketService: Balance update received: $message');
          _balanceController.add(data);
          break;
        case 'auth_ok':
          debugPrint('SocketService: Authenticated successfully');
          break;
        case 'book':
          // Ensure symbol is present in the data for filtering
          if (data['symbol'] == null && data['data'] != null && data['data']['symbol'] != null) {
            data['symbol'] = data['data']['symbol'];
          }
          _orderbookController.add(data);
          break;
        case 'trade':
          if (data['symbol'] == null && data['data'] != null && data['data']['symbol'] != null) {
            data['symbol'] = data['data']['symbol'];
          }
          _tradesController.add(data);
          break;
        case 'order_update':
          _ordersController.add(data);
          break;
        case 'fill':
          _fillsController.add(data);
          break;
        default:
          debugPrint('SocketService: Unknown message type: $type');
      }
    } catch (e) {
      debugPrint('SocketService: Error parsing message: $e');
    }
  }

  static void subscribe(String symbol) {
    _send({'subscribe': symbol});
    debugPrint('SocketService: Subscribed to $symbol');
  }

  static void _send(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(json.encode(message));
    }
  }

  static void _reconnect() {
    _channel = null;
    _isConnecting = false;
    Future.delayed(const Duration(seconds: 5), () => connect());
  }

  static void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  static Future<String> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id') ?? prefs.getInt('user_id')?.toString() ?? '1';
  }
}
