import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'package:flutter/foundation.dart';
import '../utils/error_handler.dart';

class P2PService {
  static const String _baseUrl = 'http://65.0.196.122:8085';

  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
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
    } on SocketException {
      ErrorHandler.logError('No internet connection', context);
      throw Exception('No internet connection. Please check your network.');
    } on FormatException {
      ErrorHandler.logError('Invalid response format', context);
      throw Exception('Invalid response from server. Please try again.');
    } catch (e) {
      ErrorHandler.logError(e.toString(), context);
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
      {'coinSymbol': 'USDT', 'coinName': 'Tether', 'icon': ''},
      {'coinSymbol': 'BTC', 'coinName': 'Bitcoin', 'icon': ''},
      {'coinSymbol': 'ETH', 'coinName': 'Ethereum', 'icon': ''},
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
    
    try {
      final headers = await _getHeaders();
      
      // Build query parameters
      final queryParams = <String, String>{
        if (coin != null) 'coinId': coin,
        if (direction != null) 'direction': direction.toString(),
        if (currency != null) 'currency': currency,
        if (amount != null) 'amount': amount.toString(),
        if (payMode != null) 'payMode': payMode,
        if (limit != null) 'limit': limit.toString(),
        if (page != null) 'page': page.toString(),
      };
      
      // Build URI with query parameters
      final uri = Uri.parse('$_baseUrl/p2p/v1/p2p/advertise/all').replace(queryParameters: queryParams);
      debugPrint('Fetching from: $uri');
      
      final response = await http.get(uri, headers: headers);
      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body Length: ${response.body.length}');
      if (response.body.isNotEmpty) {
        debugPrint('Response Body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
      } else {
        debugPrint('Response Body: EMPTY');
      }
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Response Data Type: ${data.runtimeType}');
        
        // Print full response for debugging
        debugPrint('=== FULL RESPONSE ===');
        if (response.body.length > 1000) {
          debugPrint('${response.body.substring(0, 1000)}...');
        } else {
          debugPrint(response.body);
        }
        debugPrint('=== END RESPONSE ===');
        
        List<dynamic> ads = [];
        
        if (data is List) {
          ads = data;
        } else if (data is Map) {
          // Debug: Print all keys and their types
          debugPrint('Response keys: ${data.keys.toList()}');
          for (var key in data.keys) {
            debugPrint('Key: $key, Type: ${data[key].runtimeType}');
          }
          
          // Direct extraction of finalData which contains the ads list
          if (data['finalData'] != null && data['finalData'] is List) {
            ads = data['finalData'] as List<dynamic>;
            debugPrint('finalData extracted as List, count: ${ads.length}');
          } else if (data['data'] != null && data['data'] is List) {
            ads = data['data'] as List<dynamic>;
          } else if (data['result'] != null && data['result'] is List) {
            ads = data['result'] as List<dynamic>;
          } else {
            // Try any list in the response
            for (var key in data.keys) {
              if (data[key] is List) {
                ads = data[key] as List<dynamic>;
                debugPrint('Found List in key: $key, count: ${ads.length}');
                break;
              }
            }
          }
        }
        
        if (ads.isNotEmpty) {
          debugPrint('Advertisements fetched: ${ads.length}');
          debugPrint('First ad sample: ${ads[0]}');
          return ads;
        } else {
          debugPrint('Ads list is empty after parsing. Checking all keys in response:');
          if (data is Map) {
            for (var key in data.keys) {
              debugPrint('Key: $key, Value type: ${data[key].runtimeType}');
            }
          }
        }
      }
      
      debugPrint('No ads found from API, returning empty list');
      return [];
      
    } catch (e, stackTrace) { 
      debugPrint('=== ADVERTISEMENTS FETCH ERROR ===');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stackTrace');
      debugPrint('====================================');
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
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
        throw Exception(errorData['message'] ?? errorData['error'] ?? 'Failed to place order');
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

  static Future<Map<String, dynamic>?> getChatDetails(String appealId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/p2p/chat/details?appealId=$appealId'), headers: await _getHeaders());
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (e) { return null; }
    return null;
  }

  static Future<String?> uploadChatImage(File imageFile) async {
    try {
      final token = await AuthService.getToken();
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/p2p/v1/p2p/chat/image-upload'));
      request.headers.addAll({if (token != null) 'Authorization': 'Bearer $token'});
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['imageUrl'] ?? data['data']?['url'];
      }
    } catch (e) { return null; }
    return null;
  }

  static Future<bool> blockUser(String blockUserId, String remark) async {
    try {
      final response = await http.post(Uri.parse('$_baseUrl/p2p/v1/p2p/block/create'), headers: await _getHeaders(), 
        body: json.encode({'blockUserId': blockUserId, 'remark': remark}));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) { return false; }
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

  static Future<bool> reportUser(Map<String, dynamic> reportData) async {
    try {
      final response = await http.post(Uri.parse('$_baseUrl/p2p/v1/user/report'), headers: await _getHeaders(), 
        body: json.encode(reportData));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) { return false; }
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

  static Future<Map<String, dynamic>?> getPaymentModes(String country) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/p2p/payment/modes?country=$country'), headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      }
    } catch (e) { debugPrint('Payment modes error: $e'); }
    return null;
  }
}
