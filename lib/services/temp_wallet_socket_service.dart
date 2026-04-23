import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_config.dart';

class TempWalletSocketService {
  static final String _baseUrl = ApiConfig.socketUrl;
  static final String _socketPath = ApiConfig.socketPath;
  static IO.Socket? _socket;
  static final StreamController<Map<String, dynamic>> _walletController = StreamController<Map<String, dynamic>>.broadcast();
  static bool _isConnecting = false;

  static Stream<Map<String, dynamic>> get walletStream => _walletController.stream;

  static Future<void> connect() async {
    if (_socket != null && _socket!.connected || _isConnecting) return;
    _isConnecting = true;

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        debugPrint('TempWalletSocket: No auth token');
        _isConnecting = false;
        return;
      }

      debugPrint('TempWalletSocket: Connecting to $_baseUrl path: $_socketPath');

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
        debugPrint('TempWalletSocket: Connected');
        _isConnecting = false;
        _joinWalletRoom();
      });

      _socket!.onDisconnect((reason) {
        debugPrint('TempWalletSocket: Disconnected - reason: $reason');
        _isConnecting = false;
        _reconnect();
      });

      _socket!.onConnectError((error) {
        debugPrint('TempWalletSocket Connect Error: $error');
        _isConnecting = false;
        Future.delayed(const Duration(seconds: 10), () => _reconnect());
      });

      _socket!.onError((error) {
        debugPrint('TempWalletSocket Error: $error');
      });

      _socket!.onConnectTimeout((_) {
        debugPrint('TempWalletSocket: Connection timeout');
        _isConnecting = false;
        _reconnect();
      });

      _socket!.on('wallet summary update socket', (data) {
        debugPrint('TempWalletSocket: wallet summary update socket received: $data');
        _walletController.add({'type': 'wallet_summary', 'data': data});
      });

      _socket!.on('wallet_summary', (data) {
        debugPrint('TempWalletSocket: wallet_summary received: $data');
        _walletController.add({'type': 'wallet_summary', 'data': data});
      });

      _socket!.on('balance_update', (data) {
        debugPrint('TempWalletSocket: balance_update received: $data');
        _walletController.add({'type': 'balance_update', 'data': data});
      });

      _socket!.on('auth_ok', (data) {
        debugPrint('TempWalletSocket: Auth OK');
        _requestWalletSummary();
      });

      _socket!.connect();
    } catch (e) {
      debugPrint('TempWalletSocket Error: $e');
      _isConnecting = false;
    }
  }

  static Future<void> _joinWalletRoom() async {
    final userId = await _getUserId();
    final token = await AuthService.getToken();
    // Emit 'join' like web app does
    _socket?.emit('join', {'user_id': userId, 'token': token});
    debugPrint('TempWalletSocket: Join emitted for user $userId');
  }

  static void _requestWalletSummary() {
    _socket?.emit('get_wallet_summary');
    debugPrint('TempWalletSocket: Requested wallet summary');
  }

  static Future<String> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id') ?? prefs.getInt('user_id')?.toString() ?? '1';
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
}
