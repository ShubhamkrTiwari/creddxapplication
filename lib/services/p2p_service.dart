import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'auth_service.dart';
import 'package:flutter/foundation.dart';
import '../utils/error_handler.dart';

class P2PService {
  static const String _baseUrl = 'https://api11.hathmetech.com/api';

  static get _selectedCrypto => null;

  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>?> _handleRequest(
    Future<http.Response> Function() requestFunction,
    String context,
  ) async {
    try {
      final response = await requestFunction();
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body);
      } else {
        final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
        ErrorHandler.logError(
          'HTTP ${response.statusCode}: ${response.body}',
          context,
        );
        throw Exception(errorData['message'] ?? errorData['error'] ?? 'Request failed');
      }
    } on FormatException {
      ErrorHandler.logError('Invalid response format', context);
      throw Exception('Invalid response from server. Please try again.');
    } catch (e) {
      ErrorHandler.logError(e.toString(), context);
      if (e.toString().contains('SocketException')) {
        throw Exception('No internet connection. Please check your network.');
      }
      rethrow;
    }
  }

  // --- OTP Verification for Payment Methods ---
  static Future<Map<String, dynamic>> sendPaymentMethodOTP() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/p2p/payment/method/send-otp'),
        headers: await _getHeaders(),
      );
      debugPrint('Send OTP response status: ${response.statusCode}');
      debugPrint('Send OTP response body: ${response.body}');
      
      return json.decode(response.body);
    } catch (e) {
      debugPrint('Send OTP error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> verifyPaymentMethodOTP(String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/p2p/payment/method/verify-otp'),
        headers: await _getHeaders(),
        body: json.encode({'otp': otp}),
      );
      debugPrint('Verify OTP response status: ${response.statusCode}');
      debugPrint('Verify OTP response body: ${response.body}');
      return json.decode(response.body);
    } catch (e) {
      debugPrint('Verify OTP error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // --- Merchant Specific ---
  static Future<Map<String, dynamic>> sendMerchantPaymentOTP() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/p2p/payment/method/send-otp'),
        headers: await _getHeaders(),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> verifyMerchantPaymentOTP(String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/p2p/payment/method/verify-otp'),
        headers: await _getHeaders(),
        body: json.encode({'otp': otp}),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // --- Advertisements & Coins ---
  static Future<List<dynamic>> getP2PCoins() async {
    debugPrint('=== GETTING REAL P2P COINS ===');
    
    try {
      final result = await _handleRequest(
        () async => http.get(Uri.parse('$_baseUrl/p2p/v1/coin/p2p/all'), headers: await _getHeaders()),
        'getP2PCoins',
      );
      if (result != null) {
        final coins = result is List ? result : (result['docs'] ?? result['data'] ?? result['result'] ?? []);
        debugPrint('Coin API raw result: $result');
        debugPrint('Coin API parsed coins: $coins');
        if (coins.isNotEmpty) {
          debugPrint('Real P2P coins fetched: ${coins.length}');
          debugPrint('First coin: ${coins[0]}');
          return coins;
        } else {
          debugPrint('Real API returned empty coins, using mock as fallback');
          return _getMockP2PCoins();
        }
      }
    } catch (e) {
      ErrorHandler.logError(e.toString(), 'getP2PCoins');
      debugPrint('Real P2P coins fetch error: $e');
      debugPrint('API failed, using mock P2P coins as fallback');
    }
    
    // Always return mock data as fallback
    final mockCoins = _getMockP2PCoins();
    debugPrint('Mock coins count: ${mockCoins.length}');
    return mockCoins;
  }

  // Mock P2P coins for development/testing
  static List<dynamic> _getMockP2PCoins() {
    return [
      {'_id': '65a1234567890abcdef12345', 'coinSymbol': 'USDT', 'coinName': 'Tether', 'icon': ''},
      {'_id': '65a1234567890abcdef12346', 'coinSymbol': 'BTC', 'coinName': 'Bitcoin', 'icon': ''},
      {'_id': '65a1234567890abcdef12347', 'coinSymbol': 'ETH', 'coinName': 'Ethereum', 'icon': ''},
    ];
  }

  // Mock fiat currencies for development/testing
  static List<dynamic> _getMockFiatCurrencies() {
    return [
      {'code': 'INR', 'name': 'Indian Rupee', 'symbol': '\u20B9', 'country': 'India'},
      {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$', 'country': 'United States'},
      {'code': 'EUR', 'name': 'Euro', 'symbol': '\u20AC', 'country': 'European Union'},
      {'code': 'GBP', 'name': 'British Pound', 'symbol': '\u00A3', 'country': 'United Kingdom'},
      {'code': 'AUD', 'name': 'Australian Dollar', 'symbol': 'A\$', 'country': 'Australia'},
    ];
  }

  static Future<List<dynamic>> getFiatCurrencies() async {
    debugPrint('=== GETTING FIAT CURRENCIES ===');
    
    // Try multiple possible endpoints
    final endpoints = [
      '$_baseUrl/p2p/v1/fiat/currencies',
      '$_baseUrl/v1/fiat/currencies',
      '$_baseUrl/fiat/currencies',
    ];
    
    for (String endpoint in endpoints) {
      try {
        debugPrint('Trying endpoint: $endpoint');
        final result = await _handleRequest(
          () async => http.get(Uri.parse(endpoint), headers: await _getHeaders()),
          'getFiatCurrencies',
        );
        if (result != null) {
          final currencies = result is List ? result : (result['docs'] ?? result['data'] ?? result['result'] ?? []);
          if (currencies.isNotEmpty) {
            debugPrint('Fiat currencies fetched from $endpoint: ${currencies.length}');
            return currencies;
          }
        }
      } catch (e) {
        debugPrint('Failed to fetch from $endpoint: $e');
        continue;
      }
    }
    
    debugPrint('All fiat currency endpoints failed, using mock data');
    return _getMockFiatCurrencies();
  }

  // --- Debug Function to Create Multiple Test Advertisements ---
  static Future<bool> createMultipleTestAdvertisements() async {
    debugPrint('=== CREATING MULTIPLE TEST ADVERTISEMENTS ===');
    
    final testAds = [
      {
        'coin': 'USDT',
        'coinSymbol': 'USDT',
        'amount': 1000.0,
        'quantity': 1000.0,
        'price': 85.50,
        'min': 500,
        'minOrder': 500,
        'max': 10000,
        'maxOrder': 10000,
        'payModes': ['Bank Transfer', 'UPI'],
        'type': 'sell',
        'fiat': 'INR',
        'currency': 'INR',
        'floating': 0,
        'payTime': 15,
      },
      {
        'coin': 'USDT',
        'coinSymbol': 'USDT',
        'amount': 500.0,
        'quantity': 500.0,
        'price': 86.00,
        'min': 1000,
        'minOrder': 1000,
        'max': 20000,
        'maxOrder': 20000,
        'payModes': ['Bank Transfer'],
        'type': 'buy',
        'fiat': 'INR',
        'currency': 'INR',
        'floating': 0,
        'payTime': 15,
      },
      {
        'coin': 'BTC',
        'coinSymbol': 'BTC',
        'amount': 0.01,
        'quantity': 0.01,
        'price': 4500000.0,
        'min': 10000,
        'minOrder': 10000,
        'max': 100000,
        'maxOrder': 100000,
        'payModes': ['UPI', 'PayTM'],
        'type': 'sell',
        'fiat': 'INR',
        'currency': 'INR',
        'floating': 0,
        'payTime': 15,
      },
    ];
    
    bool anySuccess = false;
    for (int i = 0; i < testAds.length; i++) {
      debugPrint('Creating test ad ${i + 1}: ${json.encode(testAds[i])}');
      
      try {
        final result = await createAdvertisement(testAds[i]);
        debugPrint('Test ad ${i + 1} creation result: $result');
        if (result['success'] == true) anySuccess = true;
        
        // Add small delay between creations
        await Future.delayed(Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('Error creating test ad ${i + 1}: $e');
      }
    }
    
    debugPrint('Multiple test ads creation completed. Any success: $anySuccess');
    return anySuccess;
  }

  // --- Debug Function to Create Test Advertisement ---
  static Future<Object> createTestAdvertisement() async {
    debugPrint('=== CREATING TEST ADVERTISEMENT ===');
    
    try {
      final testAd = {
        'coin': 'USDT',
        'coinSymbol': 'USDT',
        'amount': 1000.0,
        'quantity': 1000.0,
        'price': 85.50,
        'min': 500,
        'minOrder': 500,
        'max': 10000,
        'maxOrder': 10000,
        'payModes': ['Bank Transfer', 'UPI'],
        'type': 'sell',
        'fiat': 'INR',
        'currency': 'INR',
        'floating': 0,
        'payTime': 15,
      };
      
      debugPrint('Creating test ad: ${json.encode(testAd)}');
      
      final result = await createAdvertisement(testAd);
      debugPrint('Test ad creation result: $result');
      
      return result;
    } catch (e) {
      debugPrint('Error creating test ad: $e');
      return false;
    }
  }

  static Future<List<dynamic>> getAllAdvertisements({
    String? coin,
    int? direction,
    String? currency,
    double? amount,
    String? payMode,
    int? limit,
    int? page,
  }) async {
    debugPrint('=== GETTING REAL ADVERTISEMENTS ===');
    debugPrint('Filters: coin=$coin, direction=$direction, currency=$currency, amount=$amount');
    
    try {
      final headers = await _getHeaders();
      
      Future<List<dynamic>> fetchAds(Map<String, String> params) async {
        final uri = Uri.parse('$_baseUrl/p2p/v1/p2p/advertise/all').replace(queryParameters: params);
        debugPrint('Fetching from: $uri');
        final response = await http.get(uri, headers: await _getHeaders());
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data is List) return data;
          if (data is Map) {
            final ads = data['finalData'] ?? data['data'] ?? data['result'] ?? data['docs'];
            if (ads is List) return ads;
            // Try any list in the response
            for (var val in data.values) {
              if (val is List) return val;
            }
          }
        }
        return [];
      }

      // 1. Try with coin symbol first (API expects coin symbol like 'USDT', not coinId)
      final queryParams = <String, String>{
        if (coin != null && coin.isNotEmpty) 'coin': coin,  // Use 'coin' not 'coinId'
        if (direction != null) 'direction': direction.toString(),
        if (currency != null) 'currency': currency,
        if (amount != null) 'amount': amount.toString(),
        if (payMode != null) 'payMode': payMode,
      };
      
      debugPrint('Query params: $queryParams');
      List<dynamic> ads = await fetchAds(queryParams);
      
      // 2. Fallback: Try without coin if empty
      if (ads.isEmpty && coin != null) {
        debugPrint('Empty results with coin, trying without coin (direction only)');
        final params = <String, String>{
          if (direction != null) 'direction': direction.toString(),
        };
        ads = await fetchAds(params);
      }

      // 3. Fallback: Try without any filters if still empty (Absolute fallback)
      if (ads.isEmpty) {
        debugPrint('Still empty, trying absolute fallback (no filters)');
        ads = await fetchAds({});
      }
      
      debugPrint('Final advertisements count: ${ads.length}');
      return ads;
      
    } catch (e) { 
      debugPrint('=== ADVERTISEMENTS FETCH ERROR: $e ===');
      return [];
    }
  }

  // Mock advertisements for development/testing
  static List<dynamic> _getMockAdvertisements() {
    return [
      {
        '_id': '1',
        'advertiserName': 'John Doe',
        'price': 85.50,
        'min': 1000,
        'max': 50000,
        'amount': 25000,
        'payModes': ['Bank Transfer', 'UPI'],
        'type': 'sell',
        'coin': 'USDT',
        'coinSymbol': 'USDT',
        'status': 'active',
      },
      {
        '_id': '2',
        'advertiserName': 'Jane Smith',
        'price': 86.25,
        'min': 500,
        'max': 25000,
        'amount': 15000,
        'payModes': ['Bank Transfer'],
        'type': 'sell',
        'coin': 'USDT',
        'coinSymbol': 'USDT',
        'status': 'active',
      },
      {
        '_id': '3',
        'advertiserName': 'Mike Johnson',
        'price': 84.75,
        'min': 2000,
        'max': 75000,
        'amount': 30000,
        'payModes': ['UPI', 'PayTM'],
        'type': 'buy',
        'coin': 'USDT',
        'coinSymbol': 'USDT',
        'status': 'active',
      },
      {
        '_id': '4',
        'advertiserName': 'Sarah Williams',
        'price': 87.00,
        'min': 1500,
        'max': 60000,
        'amount': 20000,
        'payModes': ['Bank Transfer', 'PhonePe'],
        'type': 'sell',
        'coin': 'USDT',
        'coinSymbol': 'USDT',
        'status': 'active',
      },
      {
        '_id': '5',
        'advertiserName': 'Robert Brown',
        'price': 85.90,
        'min': 800,
        'max': 30000,
        'amount': 12000,
        'payModes': ['UPI', 'Google Pay'],
        'type': 'buy',
        'coin': 'USDT',
        'coinSymbol': 'USDT',
        'status': 'active',
      },
    ];
  }

  static Future<Map<String, dynamic>> createAdvertisement(Map<String, dynamic> adData) async {
    try {
      final headers = await _getHeaders();
      debugPrint('=== CREATE ADVERTISEMENT DEBUG ===');
      
      // Use the publish endpoint to post advertisement
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/p2p/advertise/publish'),
        headers: headers,
        body: json.encode(adData)
      );
      
      debugPrint('Create Ad Response Status: ${response.statusCode}');
      debugPrint('Create Ad Response Body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': response.body};
      } else if (response.statusCode == 400 && response.body.contains('Wallet did not setup correctly')) {
        // Wallet not set up - try to set it up first
        debugPrint('Wallet not set up. Attempting to setup wallet...');
        final setupResult = await setupWallet();
        if (setupResult['success'] == true) {
          // Retry creating advertisement
          debugPrint('Wallet setup successful. Retrying advertisement creation...');
          final retryResponse = await http.post(
            Uri.parse('$_baseUrl/p2p/v1/p2p/advertise/publish'),
            headers: headers,
            body: json.encode(adData)
          );
          if (retryResponse.statusCode == 200 || retryResponse.statusCode == 201) {
            return {'success': true, 'data': retryResponse.body};
          } else {
            return {
              'success': false, 
              'error': 'API Error ${retryResponse.statusCode}: ${retryResponse.body}'
            };
          }
        } else {
          return {'success': false, 'error': 'Wallet setup failed: ${setupResult['error']}'};
        }
      } else {
        // Return error message for display
        return {
          'success': false, 
          'error': 'API Error ${response.statusCode}: ${response.body}'
        };
      }
    } catch (e) { 
      debugPrint('Create ad error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<bool> editAdvertisement(String adId, Map<String, dynamic> adData) async {
    try {
      final response = await http.put(Uri.parse('$_baseUrl/p2p/v1/advertise/edit/$adId'), headers: await _getHeaders(), body: json.encode(adData));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) { 
      return false;
    }
  }

  static Future<bool> publishAdvertisement(String adId) async {
    try {
      final response = await http.post(Uri.parse('$_baseUrl/p2p/v1/p2p/advertise/publish/$adId'), headers: await _getHeaders());
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) { 
      return false;
    }
  }

  static Future<bool> deleteAdvertisement(String adId) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/p2p/v1/advertise/my-ads/delete/$adId'), headers: await _getHeaders());
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) { 
      return false;
    }
  }

  static Future<List<dynamic>> getMyOpenAdvertisements() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/advertise/my-ads/open'), headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> ads = [];
        if (data is List) {
          ads = data;
        } else if (data is Map) {
          ads = data['finalData'] ?? data['data'] ?? data['result'] ?? data['docs'] ?? [];
        }
        return ads;
      }
    } catch (e) { 
      debugPrint('My open ads error: $e');
    }
    return [];
  }

  static Future<List<dynamic>> getMyAdvertisements() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/p2p/advertise/my'), headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> ads = [];
        if (data is List) {
          ads = data;
        } else if (data is Map) {
          ads = data['finalData'] ?? data['data'] ?? data['result'] ?? data['docs'] ?? [];
        }
        return ads;
      }
    } catch (e) { 
      debugPrint('My ads error: $e');
    }
    return [];
  }

  // --- Orders & Trade Flow ---
  static Future<Map<String, dynamic>?> placeOrder({
    required String adId,
    required double quantity,
    required int direction,
    required String payMethod,
  }) async {
    try {
      final orderData = {
        'adId': adId,
        'quantity': quantity,
        'direction': direction,
        'payMethod': payMethod,
      };
      debugPrint('Placing P2P order with data: ${json.encode(orderData)}');
      final response = await http.post(Uri.parse('$_baseUrl/p2p/v1/p2p/order/create'),
          headers: await _getHeaders(), body: json.encode(orderData));

      debugPrint('Place order response status: ${response.statusCode}');
      debugPrint('Place order response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
        final errorMessage = errorData['message'] ?? errorData['error'] ?? 'Failed to place order (HTTP ${response.statusCode})';
        debugPrint('Place order error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      ErrorHandler.logError(e.toString(), 'placeOrder');
      rethrow;
    }
  }

  static Future<List<dynamic>> getMyOrders({
    bool? processing,
    int? status,
    int? page,
    int? limit,
  }) async {
    try {
      final queryParams = <String, String>{
        if (processing != null) 'processing': processing.toString(),
        if (status != null) 'status': status.toString(),
        if (page != null) 'page': page.toString(),
        if (limit != null) 'limit': limit.toString(),
      };
      
      final uri = Uri.parse('$_baseUrl/p2p/v1/p2p/order/my-orders').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: await _getHeaders());
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> orders = [];
        if (data is List) {
          orders = data;
        } else if (data is Map) {
          orders = data['data'] ?? data['result'] ?? data['docs'] ?? [];
        }
        return orders;
      }
    } catch (e) {
      debugPrint('Error fetching P2P orders: $e');
    }
    return [];
  }

  // Helper methods for order history
  static Future<List<dynamic>> getActiveOrders() => getMyOrders(processing: true);
  static Future<List<dynamic>> getCompletedOrders({int page = 1, int limit = 10}) => getMyOrders(processing: false, status: 5, page: page, limit: limit);
  static Future<List<dynamic>> getPendingOrders({int page = 1, int limit = 10}) => getMyOrders(processing: false, status: 1, page: page, limit: limit);
  static Future<List<dynamic>> getCancelledOrders({int page = 1, int limit = 10}) => getMyOrders(processing: false, status: 4, page: page, limit: limit);

  static Future<Map<String, dynamic>?> getOrderDetails(String orderId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/p2p/order/$orderId'), headers: await _getHeaders());
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (e) { debugPrint('Order details error: $e'); }
    return null;
  }

  static Future<bool> confirmPayment(String orderId, String utr, String screenshot) async {
    try {
      final response = await http.post(Uri.parse('$_baseUrl/p2p/v1/p2p/order/confirm-payment'), headers: await _getHeaders(), 
        body: json.encode({'orderId': orderId, 'utr': utr, 'screenshot': screenshot}));
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<bool> releaseCrypto(String orderId) async {
    try {
      final response = await http.post(Uri.parse('$_baseUrl/p2p/v1/p2p/order/release'), headers: await _getHeaders(), 
        body: json.encode({'orderId': orderId}));
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<bool> cancelOrder(String orderId, String reason) async {
    try {
      final response = await http.post(Uri.parse('$_baseUrl/p2p/v1/p2p/order/cancel'), headers: await _getHeaders(), 
        body: json.encode({'orderId': orderId, 'reason': reason}));
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      final response = await http.patch(Uri.parse('$_baseUrl/p2p/v1/p2p/order/status'), headers: await _getHeaders(),
        body: json.encode({'orderId': orderId, 'status': status}));
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<Map<String, dynamic>> makePayment({
    required String orderId,
    required String paymentMethod,
    String? utrNumber,
    String? screenshot,
  }) async {
    try {
      final body = {
        'orderId': orderId,
        'paymentMethod': paymentMethod,
        if (utrNumber != null) 'utrNumber': utrNumber,
        if (screenshot != null) 'screenshot': screenshot,
      };
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/p2p/order/make-payment'),
        headers: await _getHeaders(),
        body: json.encode(body),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
        return {'success': false, 'error': errorData['message'] ?? errorData['error'] ?? 'Payment failed'};
      }
    } catch (e) {
      debugPrint('Make payment error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Chats ---
  static Future<List<dynamic>> getLastChats() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/p2p/chat/p2p-last-chat'), headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data is List ? data : (data['data'] ?? []);
      }
    } catch (e) { return []; }
    return [];
  }

  static Future<List<dynamic>> getChatMessages(String id1, String id2) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/p2p/chat/p2p-get-chats/$id1/$id2'), headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data is List ? data : (data['data'] ?? []);
      }
    } catch (e) { return []; }
    return [];
  }

  static Future<bool> sendMessage(Map<String, dynamic> messageData) async {
    try {
      final response = await http.post(Uri.parse('$_baseUrl/p2p/v1/p2p/message/send'), headers: await _getHeaders(), body: json.encode(messageData));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) { return false; }
  }

  static Future<List<dynamic>> getChatUsers() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/p2p/chat/chat-users'), headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data is List ? data : (data['data'] ?? []);
      }
    } catch (e) { return []; }
    return [];
  }

  static Future<List<dynamic>> getChatMessagesByOrderId(String orderId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/p2p/chat/messages?orderId=$orderId'), headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data is List ? data : (data['data'] ?? data['messages'] ?? []);
      }
    } catch (e) { debugPrint('Chat messages error: $e'); }
    return [];
  }

  // --- P2P User Profile Details ---
  static Future<Map<String, dynamic>?> getP2PUserDetails({required String userId}) async {
    try {
      debugPrint('=== P2P getP2PUserDetails called ===');
      debugPrint('UserId: $userId');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/p2p/v1/p2p/user/user-details?userId=$userId'),
        headers: await _getHeaders(),
      );
      
      debugPrint('P2P User Details API Status: ${response.statusCode}');
      debugPrint('P2P User Details API Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Handle both wrapped and unwrapped responses
        if (data is Map<String, dynamic>) {
          if (data.containsKey('data')) {
            return data['data'] as Map<String, dynamic>;
          } else if (data.containsKey('user') || data.containsKey('stats')) {
            return data;
          }
        }
        return data is Map<String, dynamic> ? data : null;
      } else {
        debugPrint('P2P User Details API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('P2P User Details fetch error: $e');
    }
    return null;
  }

  // --- Trusted Devices & Security ---
  static Future<List<dynamic>> getTrustedDevices() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/user/trusted-devices'), headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data is List ? data : (data['data'] ?? []);
      }
    } catch (e) { debugPrint('Trusted devices error: $e'); }
    return [];
  }

  static Future<Map<String, dynamic>?> getCurrentDeviceInfo() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/user/current-device'), headers: await _getHeaders());
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (e) { debugPrint('Current device info error: $e'); }
    return null;
  }

  // --- User Profile & KYC ---
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/user/profile'), headers: await _getHeaders());
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (e) { debugPrint('Profile error: $e'); }
    return null;
  }

  static Future<bool> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final response = await http.put(Uri.parse('$_baseUrl/p2p/v1/user/profile'), headers: await _getHeaders(), 
        body: json.encode(profileData));
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<bool> submitKYC(Map<String, dynamic> kycData) async {
    try {
      final response = await http.post(Uri.parse('$_baseUrl/p2p/v1/user/kyc'), headers: await _getHeaders(), 
        body: json.encode(kycData));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) { return false; }
  }

  static Future<Map<String, dynamic>?> getKYCStatus() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/user/kyc/status'), headers: await _getHeaders());
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (e) { debugPrint('KYC status error: $e'); }
    return null;
  }

  // --- Wallet Operations ---
  static Future<Map<String, dynamic>> setupWallet() async {
    try {
      // Use P2P wallet endpoint with POST for setup
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/p2p/p2pwallet'),
        headers: await _getHeaders(),
      );
      debugPrint('P2P Wallet setup response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        return {'success': false, 'error': 'P2P Wallet setup failed: ${response.body}'};
      }
    } catch (e) {
      debugPrint('P2P Wallet setup error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>?> getWalletBalance() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/wallet/balance'), headers: await _getHeaders());
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (e) { debugPrint('Wallet balance error: $e'); }
    return null;
  }

  static Future<List<dynamic>> getWalletTransactions() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/wallet/transactions'), headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data is List ? data : (data['data'] ?? []);
      }
    } catch (e) { debugPrint('Wallet transactions error: $e'); }
    return [];
  }

  static Future<bool> withdrawCrypto(Map<String, dynamic> withdrawData) async {
    try {
      final response = await http.post(Uri.parse('$_baseUrl/p2p/v1/wallet/withdraw'), headers: await _getHeaders(),
        body: json.encode(withdrawData));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) { return false; }
  }

  // --- P2P Payment Methods ---
  static Future<Map<String, dynamic>> addPaymentMethod(Map<String, dynamic> paymentData) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/p2p/payment/add-method'),
        headers: await _getHeaders(),
        body: json.encode(paymentData),
      );
      debugPrint('Add payment method response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'error': 'Failed to add payment method: ${response.body}'};
      }
    } catch (e) {
      debugPrint('Add payment method error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Dispute Management ---
  static Future<bool> createDispute(Map<String, dynamic> disputeData) async {
    try {
      final response = await http.post(Uri.parse('$_baseUrl/p2p/v1/dispute/create'), headers: await _getHeaders(), 
        body: json.encode(disputeData));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) { return false; }
  }

  static Future<List<dynamic>> getMyDisputes() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/dispute/my'), headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data is List ? data : (data['data'] ?? []);
      }
    } catch (e) { debugPrint('Disputes error: $e'); }
    return [];
  }

  static Future<Map<String, dynamic>?> getDisputeDetails(String disputeId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/dispute/$disputeId'), headers: await _getHeaders());
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (e) { debugPrint('Dispute details error: $e'); }
    return null;
  }

  static Future<bool> respondToDispute(String disputeId, String disputeResponse) async {
    try {
      final response = await http.post(Uri.parse('$_baseUrl/p2p/v1/dispute/respond'), headers: await _getHeaders(), 
        body: json.encode({'disputeId': disputeId, 'response': disputeResponse}));
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<Map<String, dynamic>?> getTradeStatistics() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/user/trade-statistics'), headers: await _getHeaders());
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (e) { debugPrint('Trade statistics error: $e'); }
    return null;
  }

  static Future<Map<String, dynamic>?> getUser30dTrades({required String userId}) async {
    try {
      debugPrint('=== Fetching User 30d Trades ===');
      debugPrint('UserId: $userId');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/p2p/v1/p2p/user/30d-trades?userId=$userId'),
        headers: await _getHeaders(),
      );
      
      debugPrint('30d Trades API Status: ${response.statusCode}');
      debugPrint('30d Trades API Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          if (data.containsKey('data')) {
            return data['data'] as Map<String, dynamic>;
          }
          return data;
        }
      }
    } catch (e) {
      debugPrint('30d trades fetch error: $e');
    }
    return null;
  }

  // --- Rating & Feedback ---
  static Future<List<dynamic>> getUserRatings(String userId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/user/$userId/ratings'), headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data is List ? data : (data['data'] ?? []);
      }
    } catch (e) { debugPrint('User ratings error: $e'); }
    return [];
  }

  static Future<Map<String, dynamic>> checkPaymentMethodEligibility() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/payment/eligibility'), headers: await _getHeaders());
      if (response.statusCode == 200) return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) { debugPrint('Payment eligibility error: $e'); }
    return {'eligible': false, 'message': 'Unable to verify eligibility'};
  }

  static Future<bool> savePaymentMethod(Map<String, dynamic> paymentData) async {
    try {
      debugPrint('Saving payment method with data: ${json.encode(paymentData)}');
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/p2p/payment/add-method'), 
        headers: await _getHeaders(), 
        body: json.encode(paymentData)
      );
      debugPrint('Save payment method response: ${response.statusCode} - ${response.body}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) { 
      debugPrint('Save payment method error: $e');
      return false; 
    }
  }

  static Future<Map<String, dynamic>?> getPaymentUserDetails({List<String>? payModes}) async {
    try {
      final body = payModes != null && payModes.isNotEmpty 
          ? json.encode({'payModes': payModes}) 
          : null;
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/p2p/payment/user-details'), 
        headers: await _getHeaders(),
        body: body,
      );
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (e) { debugPrint('Payment user details error: $e'); }
    return null;
  }

  static Future<bool> deletePaymentMethod(String paymentMethodId) async {
    try {
      final response = await http.post(Uri.parse('$_baseUrl/p2p/v1/p2p/payment/delete-method'), headers: await _getHeaders(), body: json.encode({'_id': paymentMethodId}));
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<List<dynamic>> getReceivedFeedback() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/feedback/received'), headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data is List ? data : (data['data'] ?? data['result'] ?? []);
      }
    } catch (e) { debugPrint('Received feedback error: $e'); }
    return [];
  }

  static Future<List<dynamic>> getGivenFeedback() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/feedback/given'), headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data is List ? data : (data['data'] ?? data['result'] ?? []);
      }
    } catch (e) { debugPrint('Given feedback error: $e'); }
    return [];
  }

  static Future<bool> submitFeedback(Map<String, dynamic> feedbackData) async {
    try {
      final response = await http.post(Uri.parse('$_baseUrl/p2p/v1/feedback/submit'), headers: await _getHeaders(), body: json.encode(feedbackData));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) { return false; }
  }

  // --- Payment Methods ---
  static Future<List<dynamic>> getPaymentMethods() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/payment/methods'), headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data is List ? data : (data['data'] ?? []);
      }
    } catch (e) { debugPrint('Payment methods error: $e'); }
    return [];
  }

  static Future<Map<String, dynamic>?> getPaymentModes({String? country}) async {
    try {
      final uri = country != null 
          ? Uri.parse('$_baseUrl/p2p/v1/p2p/payment/modes?country=$country')
          : Uri.parse('$_baseUrl/p2p/v1/p2p/payment/modes');
      final response = await http.get(uri, headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      }
    } catch (e) { debugPrint('Payment modes error: $e'); }
    return null;
  }

  // ============================================================================
  // AUTHENTICATION APIs
  // ============================================================================

  /// Get the latest login activity for a user by login activity ID
  static Future<Map<String, dynamic>> getLoginActivity(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/p2p/v1/p2p/loginactivity/$id'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to get login activity'};
    } catch (e) {
      debugPrint('Get login activity error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ============================================================================
  // COINS APIs
  // ============================================================================

  /// Get coin details along with ticker data and user wallet balance
  static Future<Map<String, dynamic>> getCoinDetails(String coinIdOrSymbol) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/p2p/v1/coin/get/$coinIdOrSymbol'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to get coin details'};
    } catch (e) {
      debugPrint('Get coin details error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ============================================================================
  // P2P ADVERTISEMENT APIs (Additional)
  // ============================================================================

  /// Get all active P2P ads of a specific user
  static Future<Map<String, dynamic>> getUserAds(String userId, {int? limit, int? page}) async {
    try {
      final queryParams = <String, String>{
        if (limit != null) 'limit': limit.toString(),
        if (page != null) 'page': page.toString(),
      };
      final uri = Uri.parse('$_baseUrl/p2p/v1/p2p/advertise/user-ads/$userId')
          .replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: await _getHeaders());
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to get user ads'};
    } catch (e) {
      debugPrint('Get user ads error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get logged-in user's P2P advertisements (with filters)
  static Future<Map<String, dynamic>> getMyAdsWithFilters({
    String? status,
    int? direction,
    String? coin,
    int? limit,
    int? page,
  }) async {
    try {
      final queryParams = <String, String>{
        if (status != null) 'status': status,
        if (direction != null) 'direction': direction.toString(),
        if (coin != null) 'coin': coin,
        if (limit != null) 'limit': limit.toString(),
        if (page != null) 'page': page.toString(),
      };
      final uri = Uri.parse('$_baseUrl/p2p/v1/p2p/advertise/my-ads')
          .replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: await _getHeaders());
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to get my ads'};
    } catch (e) {
      debugPrint('Get my ads with filters error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Close P2P ad
  static Future<Map<String, dynamic>> closeAdvertisement(String adId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/p2p/advertise/my-ads/close'),
        headers: await _getHeaders(),
        body: json.encode({'id': adId}),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to close advertisement'};
    } catch (e) {
      debugPrint('Close advertisement error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Open a closed P2P advertisement
  static Future<Map<String, dynamic>> openAdvertisement(String adId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/p2p/advertise/my-ads/open'),
        headers: await _getHeaders(),
        body: json.encode({'id': adId}),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to open advertisement'};
    } catch (e) {
      debugPrint('Open advertisement error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ============================================================================
  // P2P ORDER APIs (Additional)
  // ============================================================================

  /// Fetch the highest or lowest bid based on direction
  static Future<Map<String, dynamic>> getBestBid({
    required int direction,
    required String currency,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/p2p/v1/p2p/order/bid').replace(queryParameters: {
        'direction': direction.toString(),
        'currency': currency,
      });
      final response = await http.get(uri, headers: await _getHeaders());
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to get best bid'};
    } catch (e) {
      debugPrint('Get best bid error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Fetch completed (status = 5) P2P orders
  static Future<Map<String, dynamic>> getOrderHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/p2p/v1/p2p/order/history'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to get order history'};
    } catch (e) {
      debugPrint('Get order history error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get OTP to verify release coin
  static Future<Map<String, dynamic>> sendCoinOTP(String orderId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/p2p/order/send-coin-otp'),
        headers: await _getHeaders(),
        body: json.encode({'orderId': orderId}),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to send coin OTP'};
    } catch (e) {
      debugPrint('Send coin OTP error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Verify OTP and allow seller to release coin
  static Future<Map<String, dynamic>> verifyCoinOTP({
    required String orderId,
    required String otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/p2p/order/verify-coin-otp'),
        headers: await _getHeaders(),
        body: json.encode({'orderId': orderId, 'otp': otp}),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to verify coin OTP'};
    } catch (e) {
      debugPrint('Verify coin OTP error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Submit rating and review for completed P2P order
  static Future<Map<String, dynamic>> rateOrder({
    required String orderId,
    required int rating,
    required String reviewNote,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/p2p/order/rating'),
        headers: await _getHeaders(),
        body: json.encode({
          'orderId': orderId,
          'rating': rating,
          'reviewNote': reviewNote,
        }),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to rate order'};
    } catch (e) {
      debugPrint('Rate order error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get rating details and statistics of logged-in user
  static Future<Map<String, dynamic>> getUserRated({String? feedback}) async {
    try {
      final queryParams = <String, String>{
        if (feedback != null) 'feedback': feedback,
      };
      final uri = Uri.parse('$_baseUrl/p2p/v1/p2p/order/user-rated')
          .replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: await _getHeaders());
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to get user ratings'};
    } catch (e) {
      debugPrint('Get user rated error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ============================================================================
  // P2P CHAT APIs (Additional)
  // ============================================================================

  /// Find existing chat by orderId or create new conversation
  static Future<Map<String, dynamic>> createOrGetChatConversation({
    required String receiverId,
    required String senderId,
    required String orderId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/p2p/chat/chat-users'),
        headers: await _getHeaders(),
        body: json.encode({
          'receiverId': receiverId,
          'senderId': senderId,
          'orderId': orderId,
        }),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to create/get chat'};
    } catch (e) {
      debugPrint('Create/get chat conversation error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get chat details by chatId
  static Future<Map<String, dynamic>> getChatDetails(String chatId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/p2p/chat/details'),
        headers: await _getHeaders(),
        body: json.encode({'chatId': chatId}),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to get chat details'};
    } catch (e) {
      debugPrint('Get chat details error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get paginated chat messages
  static Future<Map<String, dynamic>> getPaginatedChatMessages({
    required String chatId,
    int? limit,
    int? page,
  }) async {
    try {
      final body = {
        'chatId': chatId,
        if (limit != null) 'limit': limit,
        if (page != null) 'page': page,
      };
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/p2p/chat/messages'),
        headers: await _getHeaders(),
        body: json.encode(body),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to get chat messages'};
    } catch (e) {
      debugPrint('Get paginated chat messages error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Store a chat message in a conversation
  static Future<Map<String, dynamic>> storeChatMessage({
    required String senderId,
    required String conversationId,
    required String text,
    String? messageStatus,
  }) async {
    try {
      final body = {
        'senderId': senderId,
        'conversationId': conversationId,
        'text': text,
        if (messageStatus != null) 'messageStatus': messageStatus,
      };
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/p2p/chat/p2p-last-chat'),
        headers: await _getHeaders(),
        body: json.encode(body),
      );
      if (response.statusCode == 200) return {'success': true, 'data': json.decode(response.body)};
      return {'success': false, 'message': 'Failed to store chat message'};
    } catch (e) {
      debugPrint('Store chat message error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ============================================================================
  // P2P APPEAL APIs (Additional)
  // ============================================================================

  /// Create an appeal for an existing P2P order
  static Future<Map<String, dynamic>> createAppeal({
    required String orderNum,
    required String email,
    String? reason,
    String? description,
    File? image,
  }) async {
    try {
      final token = await AuthService.getToken();
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/p2p/v1/p2p/p2p-appeal/create'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['orderNum'] = orderNum;
      request.fields['email'] = email;
      if (reason != null) request.fields['reason'] = reason;
      if (description != null) request.fields['description'] = description;
      if (image != null) {
        request.files.add(await http.MultipartFile.fromPath('image', image.path));
      }
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to create appeal'};
    } catch (e) {
      debugPrint('Create appeal error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Approve a P2P appeal (Sub-admin only)
  static Future<Map<String, dynamic>> approveAppeal({
    required String appealId,
    required String reason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/sub-admin/v1/p2p-appeal/approve-appeal'),
        headers: await _getHeaders(),
        body: json.encode({'_id': appealId, 'reason': reason}),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to approve appeal'};
    } catch (e) {
      debugPrint('Approve appeal error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Cancel a P2P appeal (Admin only)
  static Future<Map<String, dynamic>> cancelAppeal({
    required String appealId,
    required String reason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/admin/p2p-appeal/cancel-appeal'),
        headers: await _getHeaders(),
        body: json.encode({'_id': appealId, 'reason': reason}),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to cancel appeal'};
    } catch (e) {
      debugPrint('Cancel appeal error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get appeal details by order number
  static Future<Map<String, dynamic>> getAppealDetailsByOrder(String orderNumber) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/p2p/admin/p2p-appeal/p2p-appeal/p2p-get-ss/$orderNumber'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to get appeal details'};
    } catch (e) {
      debugPrint('Get appeal details error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get P2P appeals with optional filters
  static Future<Map<String, dynamic>> getP2PAppeals({
    String? orderNum,
    String? startDate,
    String? endDate,
    bool? appealStatus,
  }) async {
    try {
      final queryParams = <String, String>{
        if (orderNum != null) 'orderNum': orderNum,
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        if (appealStatus != null) 'appealStatus': appealStatus.toString(),
      };
      final uri = Uri.parse('$_baseUrl/p2p/admin/p2p-appeal/all').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: await _getHeaders());
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to get appeals'};
    } catch (e) {
      debugPrint('Get P2P appeals error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get P2P transaction history
  static Future<Map<String, dynamic>> getTransactionHistory({
    String? status,
    String? txnType,
  }) async {
    try {
      final queryParams = <String, String>{
        if (status != null) 'status': status,
        if (txnType != null) 'txnType': txnType,
      };
      final uri = Uri.parse('$_baseUrl/p2p/admin/p2pOrder/transaction-history')
          .replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: await _getHeaders());
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to get transaction history'};
    } catch (e) {
      debugPrint('Get transaction history error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// View P2P appeal details
  static Future<Map<String, dynamic>> viewAppeal(String orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/p2p/admin/p2p-appeal/view-appeal/$orderId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to view appeal'};
    } catch (e) {
      debugPrint('View appeal error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Store appeal chat message (Admin)
  static Future<Map<String, dynamic>> storeAppealChatMessage({
    required String conversationId,
    required String senderId,
    required String text,
    String? messageStatus,
  }) async {
    try {
      final body = {
        'conversationId': conversationId,
        'senderId': senderId,
        'text': text,
        if (messageStatus != null) 'messageStatus': messageStatus,
      };
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/admin/p2p-appeal/p2p-last-chat'),
        headers: await _getHeaders(),
        body: json.encode(body),
      );
      if (response.statusCode == 200) return {'success': true, 'data': json.decode(response.body)};
      return {'success': false, 'message': 'Failed to store appeal chat'};
    } catch (e) {
      debugPrint('Store appeal chat error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get appeal chat messages (Admin)
  static Future<Map<String, dynamic>> getAppealChatMessages({
    required String conversationId,
    required String currentUserId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/p2p/admin/p2p-appeal/p2p-get-chats/$conversationId/$currentUserId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to get appeal chat messages'};
    } catch (e) {
      debugPrint('Get appeal chat messages error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ============================================================================
  // P2P TRADE APIs (Additional)
  // ============================================================================

  /// Get average buyer payment time
  static Future<Map<String, dynamic>> getAveragePayTime(String buyerId) async {
    try {
      final uri = Uri.parse('$_baseUrl/p2p/v1/p2p/user/average-pay-time')
          .replace(queryParameters: {'buyerId': buyerId});
      final response = await http.get(uri, headers: await _getHeaders());
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to get average pay time'};
    } catch (e) {
      debugPrint('Get average pay time error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get average seller release time
  static Future<Map<String, dynamic>> getAverageReleaseTime(String sellerId) async {
    try {
      final uri = Uri.parse('$_baseUrl/p2p/v1/p2p/user/average-release-time')
          .replace(queryParameters: {'sellerId': sellerId});
      final response = await http.get(uri, headers: await _getHeaders());
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to get average release time'};
    } catch (e) {
      debugPrint('Get average release time error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ============================================================================
  // P2P USER APIs (Additional)
  // ============================================================================

  /// Block a user
  static Future<Map<String, dynamic>> blockUser({
    required String blockedUserId,
    String? reason,
    String? message,
  }) async {
    try {
      final body = {
        'blockedUserId': blockedUserId,
        if (reason != null) 'reason': reason,
        if (message != null) 'message': message,
      };
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/p2p/user/block-user'),
        headers: await _getHeaders(),
        body: json.encode(body),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to block user'};
    } catch (e) {
      debugPrint('Block user error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Unblock a user
  static Future<Map<String, dynamic>> unblockUser(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/p2p/user/unblock-user'),
        headers: await _getHeaders(),
        body: json.encode({'userId': userId}),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to unblock user'};
    } catch (e) {
      debugPrint('Unblock user error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get blocked users list
  static Future<Map<String, dynamic>> getBlockedUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/p2p/v1/p2p/user/list/blocked-user'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to get blocked users'};
    } catch (e) {
      debugPrint('Get blocked users error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get user all trades summary
  static Future<Map<String, dynamic>> getUserAllTradesSummary() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/p2p/v1/p2p/user/all-trades'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to get trades summary'};
    } catch (e) {
      debugPrint('Get all trades summary error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get user feedback statistics
  static Future<Map<String, dynamic>> getUserFeedbackStatistics({String? userId}) async {
    try {
      final queryParams = <String, String>{
        if (userId != null) '_id': userId,
      };
      final uri = Uri.parse('$_baseUrl/p2p/v1/p2p/user/feedback')
          .replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: await _getHeaders());
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to get feedback statistics'};
    } catch (e) {
      debugPrint('Get feedback statistics error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get user registration days
  static Future<Map<String, dynamic>> getUserRegistrationDays(String userId) async {
    try {
      final uri = Uri.parse('$_baseUrl/p2p/v1/p2p/user/user-registration')
          .replace(queryParameters: {'userId': userId});
      final response = await http.get(uri, headers: await _getHeaders());
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to get registration days'};
    } catch (e) {
      debugPrint('Get registration days error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Report a user
  static Future<Map<String, dynamic>> reportUser({
    required String blockedUserId,
    String? reason,
    String? description,
  }) async {
    try {
      final body = {
        'blockedUserId': blockedUserId,
        if (reason != null) 'reason': reason,
        if (description != null) 'description': description,
      };
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/p2p/user/report-user'),
        headers: await _getHeaders(),
        body: json.encode(body),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to report user'};
    } catch (e) {
      debugPrint('Report user error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ============================================================================
  // USER ADMIN APIs
  // ============================================================================

  /// Enable or disable P2P trading for a specific user
  static Future<Map<String, dynamic>> changeP2PTradeStatus({
    required String userId,
    String? reason,
  }) async {
    try {
      final body = {
        '_id': userId,
        if (reason != null) 'reason': reason,
      };
      final response = await http.post(
        Uri.parse('$_baseUrl/admin/user/change/p2p-trade-status'),
        headers: await _getHeaders(),
        body: json.encode(body),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to change P2P trade status'};
    } catch (e) {
      debugPrint('Change P2P trade status error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get P2P trade disable reason
  static Future<Map<String, dynamic>> getP2PTradeDisableReason(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/admin/user/p2p/trade/disable-reason/$userId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to get disable reason'};
    } catch (e) {
      debugPrint('Get P2P trade disable reason error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get average P2P rating of a specific user
  static Future<Map<String, dynamic>> getUserP2PRating(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/admin/user/user-rating/$userId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to get user rating'};
    } catch (e) {
      debugPrint('Get user P2P rating error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get user pay details (Admin)
  static Future<Map<String, dynamic>> getUserPayDetails(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/admin/user/pay-detail/$userId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to get user pay details'};
    } catch (e) {
      debugPrint('Get user pay details error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ============================================================================
  // USERS APIs
  // ============================================================================

  /// Retrieve a P2P user snapshot by user ID
  static Future<Map<String, dynamic>> getUserById(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/p2p/v1/p2p/user-data/$userId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to get user data'};
    } catch (e) {
      debugPrint('Get user by ID error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ============================================================================
  // WALLET APIs
  // ============================================================================

  /// Get all P2P wallets for the authenticated user
  static Future<Map<String, dynamic>> getP2PWallets() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/p2p/p2pwallet'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to get P2P wallets'};
    } catch (e) {
      debugPrint('Get P2P wallets error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ============================================================================
  // P2P TRADE ADMIN APIs
  // ============================================================================

  /// Block P2P trades of all users (Admin)
  static Future<Map<String, dynamic>> blockAllP2PTrades() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/admin/user/block-trades'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to block trades'};
    } catch (e) {
      debugPrint('Block all P2P trades error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Unblock P2P trades of all users (Admin)
  static Future<Map<String, dynamic>> unblockAllP2PTrades() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/admin/user/unblock-trades'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to unblock trades'};
    } catch (e) {
      debugPrint('Unblock all P2P trades error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Cancel order (Sub-admin)
  static Future<Map<String, dynamic>> adminCancelOrder({
    File? image,
    String? link,
    String? marque,
  }) async {
    try {
      final token = await AuthService.getToken();
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/sub-admin/v1/p2p/cancel-order'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      if (image != null) {
        request.files.add(await http.MultipartFile.fromPath('image', image.path));
      }
      if (link != null) request.fields['link'] = link;
      if (marque != null) request.fields['marque'] = marque;
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to cancel order'};
    } catch (e) {
      debugPrint('Admin cancel order error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get list of all P2P reported users (Sub-admin)
  static Future<Map<String, dynamic>> getReportList() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/sub-admin/v1/p2p/report-list'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to get report list'};
    } catch (e) {
      debugPrint('Get report list error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Release coin after payment received (Admin)
  static Future<Map<String, dynamic>> adminReleaseCoin(String orderId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/admin/v1/p2p/release-coin'),
        headers: await _getHeaders(),
        body: json.encode({'orderId': orderId}),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to release coin'};
    } catch (e) {
      debugPrint('Admin release coin error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ============================================================================
  // IMAGE UPLOAD APIs
  // ============================================================================

  /// Upload appeal image (Admin)
  static Future<Map<String, dynamic>> uploadAppealImage({
    required File file,
    required String conversationId,
    required String senderId,
    required String receiverId,
    String? messageStatus,
  }) async {
    try {
      final token = await AuthService.getToken();
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/p2p/admin/p2p-appeal/image-upload'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      request.fields['conversationId'] = conversationId;
      request.fields['senderId'] = senderId;
      request.fields['receiverId'] = receiverId;
      if (messageStatus != null) request.fields['messageStatus'] = messageStatus;
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to upload appeal image'};
    } catch (e) {
      debugPrint('Upload appeal image error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Upload chat image
  static Future<Map<String, dynamic>> uploadChatImage({
    required File file,
    required String conversationId,
    required String senderId,
    String? messageStatus,
  }) async {
    try {
      final token = await AuthService.getToken();
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/p2p/v1/p2p/chat/image-upload'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      request.fields['conversationId'] = conversationId;
      request.fields['senderId'] = senderId;
      if (messageStatus != null) request.fields['messageStatus'] = messageStatus;
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to upload chat image'};
    } catch (e) {
      debugPrint('Upload chat image error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}
