import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

/// A professional-grade service for Spot Trading operations.
/// Handles order placement, market data, and account balances via the :9000 REST API.
class SpotService {
  static const String _baseUrl = 'http://api4.creddx.com:9000';
  
  // Persistence for UI state (used by SpotScreen to maintain lists across rebuilds)
  static List<Map<String, dynamic>> userBuyOrders = [];
  static List<Map<String, dynamic>> userSellOrders = [];
  static List<Map<String, dynamic>> userTrades = [];
  static String currentSymbol = 'BTCUSDT';

  /// Fetches a standard set of headers for authenticated requests.
  static Future<Map<String, String>> _getHeaders({String? userId}) async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      if (userId != null) 'X-User-Id': userId,
    };
  }

  // --- Market Data Endpoints ---

  /// Get ticker data (price, 24h change, etc.) for a specific symbol.
  static Future<Map<String, dynamic>> getTicker(String symbol) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/ticker/$symbol'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data['data'] ?? data};
      }
      return {'success': false, 'error': 'Failed to load ticker: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get L2 Order Book snapshot for a symbol.
  /// GET /book/:symbol - Returns top 20 levels of bids and asks
  static Future<Map<String, dynamic>> getOrderBook(String symbol) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/book/$symbol'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // API returns: { "success": true, "data": { "bids": [[price, qty], ...], "asks": [[price, qty], ...] } }
        return {'success': true, 'data': data['data'] ?? data};
      }
      return {'success': false, 'error': 'Order book unavailable'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get all tradeable symbols and their properties.
  static Future<Map<String, dynamic>> getSymbols() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/symbols'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data['data'] ?? data};
      }
      return {'success': false, 'error': 'Failed to fetch symbols'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get recent market trades for a symbol.
  static Future<Map<String, dynamic>> getRecentTrades(String symbol) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/trades/$symbol'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data['data'] ?? data};
      }
      return {'success': false, 'error': 'Failed to fetch trades'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Trading Endpoints ---

  /// Places a new spot order (Limit or Market).
  static Future<Map<String, dynamic>> placeOrder({
    required String symbol,
    required String side, // 'Buy' or 'Sell'
    required String orderType, // 'Limit' or 'Market'
    required double qty,
    double price = 0.0,
  }) async {
    try {
      final userId = await _getUserId();
      final Map<String, dynamic> requestBody = {
        'user_id': userId,
        'symbol': symbol,
        'side': side,
        'qty': qty,
        'order_type': orderType,
        'reduce_only': false,
      };
      
      // Add price field for all orders (0.0 for Market orders)
      requestBody['price'] = orderType == 'Market' ? 0.0 : price;
      
      final body = jsonEncode(requestBody);
      print('SpotService.placeOrder: requestBody=$requestBody');
      print('SpotService.placeOrder: body=$body');

      final response = await http.post(
        Uri.parse('$_baseUrl/order/new'),
        headers: await _getHeaders(userId: userId),
        body: body,
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Handle both bool and String types for success field
        final success = data['success'] is bool ? data['success'] : data['success']?.toString() == 'true';
        if (success) {
          return {'success': true, 'data': data['data']};
        }
      }
      return {'success': false, 'error': data['message']?.toString() ?? data['error']?.toString() ?? 'Order placement failed'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Cancels an existing open order.
  static Future<Map<String, dynamic>> cancelOrder({
    required String orderId,
    required String symbol,
    required double price,
    required String side,
  }) async {
    try {
      final userId = await _getUserId();
      final body = jsonEncode({
        'user_id': userId,
        'symbol': symbol,
        'order_id': int.tryParse(orderId) ?? 0,
        'price': price,
        'side': side,
      });

      final response = await http.post(
        Uri.parse('$_baseUrl/order/cancel'),
        headers: await _getHeaders(userId: userId),
        body: body,
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data['data']};
      }
      return {'success': false, 'error': data['error'] ?? 'Cancellation failed'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Account Endpoints ---

  /// Get user balance for all assets.
  static Future<Map<String, dynamic>> getBalance({bool forceRefresh = false}) async {
    try {
      final userId = await _getUserId();
      // Add cache-busting timestamp to ensure fresh data
      final cacheBuster = forceRefresh ? '&t=${DateTime.now().millisecondsSinceEpoch}' : '';
      final response = await http.get(
        Uri.parse('$_baseUrl/balance/$userId?_=${DateTime.now().millisecondsSinceEpoch}$cacheBuster'),
        headers: await _getHeaders(userId: userId),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Process assets into a more usable map for the UI
          final assetsList = data['data']?['assets'] as List? ?? [];
          final Map<String, dynamic> formattedAssets = {};
          
          for (var asset in assetsList) {
            final name = asset['asset']?.toString().toUpperCase() ?? '';
            formattedAssets[name] = {
              'available': double.tryParse(asset['available']?.toString() ?? '0') ?? 0.0,
              'locked': double.tryParse(asset['locked']?.toString() ?? '0') ?? 0.0,
              'free': double.tryParse(asset['free']?.toString() ?? '0') ?? 0.0,
            };
          }

          // Compatibility fields for existing UI components
          final usdt = formattedAssets['USDT'] ?? {'available': 0.0, 'locked': 0.0, 'free': 0.0};
          final btc = formattedAssets['BTC'] ?? {'available': 0.0, 'locked': 0.0, 'free': 0.0};

          return {
            'success': true,
            'data': {
              'user_id': userId,
              'assets': formattedAssets,
              'raw_assets': assetsList,
              // Legacy support fields
              'usdt_available': usdt['available'],
              'usdt_locked': usdt['locked'],
              'free': btc['available'],
              'btc_locked': btc['locked'],
            }
          };
        }
      }
      return {'success': false, 'error': 'Failed to load balance'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get all currently open orders for the user.
  static Future<Map<String, dynamic>> getOpenOrders({String? symbol}) async {
    try {
      final userId = await _getUserId();
      String url = '$_baseUrl/orders/open/$userId';
      if (symbol != null) url += '?symbol=$symbol';

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(userId: userId),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data['data'] ?? []};
      }
      return {'success': false, 'error': 'Failed to load open orders'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get user's specific trade history.
  static Future<Map<String, dynamic>> getUserTradeHistory({String? symbol}) async {
    try {
      final userId = await _getUserId();
      String url = '$_baseUrl/trades/user/$userId';
      if (symbol != null) url += '?symbol=$symbol';

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(userId: userId),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data['data'] ?? []};
      }
      return {'success': false, 'error': 'Failed to load trade history'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Helper Methods ---

  /// Retrieves the current User ID from local storage.
  static Future<String> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id') ?? '1';
  }
  
  /// Get 24hr statistics for all symbols.
  static Future<Map<String, dynamic>> get24hrTickerStats() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/ticker/24hr'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data['data'] ?? data};
      }
      return {'success': false, 'error': 'Market stats unavailable'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get the current server time (useful for sync).
  static Future<Map<String, dynamic>> getServerTime() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/time'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(response.body)};
      }
      return {'success': false, 'error': 'Sync failed'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get health status of the spot engine.
  static Future<Map<String, dynamic>> getHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 5));

      return {'success': response.statusCode == 200, 'data': json.decode(response.body)};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get trading fees for the user.
  static Future<Map<String, dynamic>> getFees() async {
    try {
      // Mock fee data for now as per professional standards if endpoint not ready
      // Usually 0.1% maker/taker
      return {
        'success': true, 
        'data': {
          'maker': 0.001,
          'taker': 0.001,
          'discount_asset': 'CRD',
          'has_discount': false
        }
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
