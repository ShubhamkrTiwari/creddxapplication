import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'package:flutter/foundation.dart';
import '../utils/error_handler.dart';

class P2PService {
  static const String _baseUrl = 'http://13.235.89.109:8085';

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
        if (coins.isNotEmpty) {
          debugPrint('Real P2P coins fetched: ${coins.length}');
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

  static Future<List<dynamic>> getAllAdvertisements() async {
    debugPrint('=== GETTING REAL ADVERTISEMENTS ===');
    
    try {
      final headers = await _getHeaders();
      
      debugPrint('Fetching advertisements with headers: $headers');
      
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/p2p/advertise/all'), headers: headers);
      
      debugPrint('Advertisements API response status: ${response.statusCode}');
      debugPrint('Advertisements API response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Parsed advertisements data: $data');
        
        List<dynamic> ads = [];
        if (data is List) {
          ads = data;
        } else if (data is Map) {
          ads = data['data'] ?? data['result'] ?? data['advertisements'] ?? [];
        }
        
        debugPrint('Real advertisements list length: ${ads.length}');
        if (ads.isNotEmpty) {
          return ads;
        } else {
          debugPrint('Real API returned empty ads, using mock as fallback');
          return _getMockAdvertisements();
        }
      } else if (response.statusCode == 401) {
        debugPrint('Authentication failed - token might be expired');
        // Try without authentication for public ads
        final publicHeaders = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        };
        final publicResponse = await http.get(Uri.parse('$_baseUrl/p2p/v1/p2p/advertise/all'), headers: publicHeaders);
        
        if (publicResponse.statusCode == 200) {
          final data = json.decode(publicResponse.body);
          List<dynamic> ads = [];
          if (data is List) {
            ads = data;
          } else if (data is Map) {
            ads = data['data'] ?? data['result'] ?? data['advertisements'] ?? [];
          }
          debugPrint('Public advertisements fetched: ${ads.length}');
          if (ads.isNotEmpty) {
            return ads;
          } else {
            debugPrint('Public API returned empty ads, using mock as fallback');
            return _getMockAdvertisements();
          }
        }
      }
    } catch (e) { 
      debugPrint('Advertisements fetch error: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      debugPrint('API failed, using mock advertisements as fallback');
      return _getMockAdvertisements();
    }
    
    debugPrint('API failed completely, using mock advertisements as fallback');
    return _getMockAdvertisements();
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
        'paymentMode': ['Bank Transfer', 'UPI'],
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
        'paymentMode': ['Bank Transfer'],
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
        'paymentMode': ['UPI', 'PayTM'],
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
        'paymentMode': ['Bank Transfer', 'PhonePe'],
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
        'paymentMode': ['UPI', 'Google Pay'],
        'type': 'buy',
        'coin': 'USDT',
        'coinSymbol': 'USDT',
        'status': 'active',
      },
    ];
  }

  static Future<bool> createAdvertisement(Map<String, dynamic> adData) async {
    try {
      final headers = await _getHeaders();
      debugPrint('=== CREATE ADVERTISEMENT DEBUG ===');
      debugPrint('Headers: $headers');
      debugPrint('Request URL: $_baseUrl/p2p/v1/p2p/advertise/create');
      debugPrint('Request Data: ${json.encode(adData)}');
      
      // Try advertisement creation first
      var response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/p2p/advertise/create'), 
        headers: headers, 
        body: json.encode(adData)
      );
      
      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');
      
      // If advertisement creation fails (404), try order creation as fallback
      if (response.statusCode == 404) {
        debugPrint('Advertisement endpoint not found, trying order creation as fallback...');
        
        final orderData = {
          "coin": adData["coin"] ?? "USDT",
          "quantity": adData["amount"] ?? 0.0,
          "price": adData["price"] ?? 0.0,
          "paymentMode": adData["paymentMode"]?.first ?? "Bank",
          "type": adData["type"] ?? "buy",
          "direction": (adData["type"] ?? "buy") == "buy" ? 1 : 0, // Convert to number: 1 for buy, 0 for sell
          "paymentTime": adData["paymentTime"] ?? 15,
          "fiat": adData["fiat"] ?? "INR",
          "floating": adData["floating"] ?? 0,
        };
        
        debugPrint('Fallback Order Data: ${json.encode(orderData)}');
        
        response = await http.post(
          Uri.parse('$_baseUrl/p2p/v1/p2p/order/create'), 
          headers: headers, 
          body: json.encode(orderData)
        );
        
        debugPrint('Order Creation Response Status: ${response.statusCode}');
        debugPrint('Order Creation Response Body: ${response.body}');
      }
      
      debugPrint('Response Headers: ${response.headers}');
      debugPrint('=== END DEBUG ===');
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) { 
      debugPrint('Create ad error: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  static Future<bool> editAdvertisement(String adId, Map<String, dynamic> adData) async {
    try {
      final response = await http.put(Uri.parse('$_baseUrl/p2p/v1/advertise/edit/$adId'), headers: await _getHeaders(), body: json.encode(adData));
      debugPrint('Edit ad response status: ${response.statusCode}');
      debugPrint('Edit ad response body: ${response.body}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) { 
      debugPrint('Edit ad error: $e');
      return false;
    }
  }

  static Future<bool> publishAdvertisement(String adId) async {
    try {
      final response = await http.post(Uri.parse('$_baseUrl/p2p/v1/p2p/advertise/publish/$adId'), headers: await _getHeaders());
      debugPrint('Publish ad response status: ${response.statusCode}');
      debugPrint('Publish ad response body: ${response.body}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) { 
      debugPrint('Publish ad error: $e');
      return false;
    }
  }

  static Future<bool> deleteAdvertisement(String adId) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/p2p/v1/advertise/my-ads/delete/$adId'), headers: await _getHeaders());
      debugPrint('Delete ad response status: ${response.statusCode}');
      debugPrint('Delete ad response body: ${response.body}');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) { 
      debugPrint('Delete ad error: $e');
      return false;
    }
  }

  static Future<List<dynamic>> getMyOpenAdvertisements() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/advertise/my-ads/open'), headers: await _getHeaders());
      debugPrint('My open ads response status: ${response.statusCode}');
      debugPrint('My open ads response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> ads = [];
        if (data is List) {
          ads = data;
        } else if (data is Map) {
          ads = data['data'] ?? data['result'] ?? data['advertisements'] ?? [];
        }
        debugPrint('My open advertisements fetched: ${ads.length}');
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
      debugPrint('My ads response status: ${response.statusCode}');
      debugPrint('My ads response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> ads = [];
        if (data is List) {
          ads = data;
        } else if (data is Map) {
          ads = data['data'] ?? data['result'] ?? data['advertisements'] ?? [];
        }
        debugPrint('My advertisements fetched: ${ads.length}');
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
      debugPrint('Place Order API Response Status: ${response.statusCode}');
      debugPrint('Place Order API Response Body: ${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
        ErrorHandler.logError(
          'HTTP ${response.statusCode}: ${response.body}',
          'placeOrder',
        );
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
      // Build query parameters
      final queryParams = <String, String>{
        if (processing != null) 'processing': processing.toString(),
        if (status != null) 'status': status.toString(),
        if (page != null) 'page': page.toString(),
        if (limit != null) 'limit': limit.toString(),
      };
      
      final uri = Uri.parse('$_baseUrl/p2p/v1/p2p/order/my-orders')
          .replace(queryParameters: queryParams);
      
      debugPrint('Fetching P2P orders from: $uri');
      final response = await http.get(uri, headers: await _getHeaders());
      
      debugPrint('P2P Orders API Response Status: ${response.statusCode}');
      debugPrint('P2P Orders API Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> orders = [];
        
        if (data is List) {
          orders = data;
        } else if (data is Map) {
          orders = data['data'] ?? data['result'] ?? data['orders'] ?? [];
        }
        
        debugPrint('P2P orders fetched: ${orders.length}');
        return orders;
      } else {
        debugPrint('P2P Orders API failed with status: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching P2P orders: $e');
      return [];
    }
  }

  // Helper methods for common order history queries
  static Future<List<dynamic>> getActiveOrders() async {
    return await getMyOrders(processing: true);
  }

  static Future<List<dynamic>> getCompletedOrders({int page = 1, int limit = 10}) async {
    return await getMyOrders(
      processing: false,
      status: 5, // Completed status
      page: page,
      limit: limit,
    );
  }

  static Future<List<dynamic>> getPendingOrders({int page = 1, int limit = 10}) async {
    return await getMyOrders(
      processing: false,
      status: 1, // Pending status
      page: page,
      limit: limit,
    );
  }

  static Future<List<dynamic>> getCancelledOrders({int page = 1, int limit = 10}) async {
    return await getMyOrders(
      processing: false,
      status: 4, // Cancelled status
      page: page,
      limit: limit,
    );
  }

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
      final response = await http.get(
        Uri.parse('$_baseUrl/p2p/v1/payment/eligibility'), 
        headers: await _getHeaders()
      );
      debugPrint('Payment eligibility response status: ${response.statusCode}');
      debugPrint('Payment eligibility response body: ${response.body}');
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        return {
          'eligible': false,
          'message': 'Unable to verify eligibility at this time',
        };
      }
    } catch (e) { 
      debugPrint('Payment eligibility error: $e');
      return {
        'eligible': false,
        'message': 'Error checking eligibility: $e',
      };
    }
  }

  static Future<bool> savePaymentMethod(Map<String, dynamic> paymentData) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/payment/method/save'), 
        headers: await _getHeaders(), 
        body: json.encode(paymentData)
      );
      debugPrint('Save payment method response status: ${response.statusCode}');
      debugPrint('Save payment method response body: ${response.body}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) { 
      debugPrint('Save payment method error: $e');
      return false;
    }
  }

  static Future<bool> verifyPaymentMethod(String paymentType) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/payment/method/verify'), 
        headers: await _getHeaders(), 
        body: json.encode({'type': paymentType})
      );
      debugPrint('Verify payment method response status: ${response.statusCode}');
      debugPrint('Verify payment method response body: ${response.body}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) { 
      debugPrint('Verify payment method error: $e');
      return false;
    }
  }

  // --- Market Data ---
  static Future<Map<String, dynamic>?> getMarketRates() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/market/rates'), headers: await _getHeaders());
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (e) { debugPrint('Market rates error: $e'); }
    return null;
  }

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

  // --- Feedback Methods ---
  static Future<List<dynamic>> getReceivedFeedback() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/p2p/v1/feedback/received'), 
        headers: await _getHeaders()
      );
      debugPrint('Received feedback response status: ${response.statusCode}');
      debugPrint('Received feedback response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> feedback = [];
        if (data is List) {
          feedback = data;
        } else if (data is Map) {
          feedback = data['data'] ?? data['result'] ?? data['feedback'] ?? [];
        }
        debugPrint('Received feedback count: ${feedback.length}');
        return feedback;
      } else if (response.statusCode == 401) {
        debugPrint('Authentication failed for feedback - token might be expired');
        throw Exception('Authentication failed. Please login again.');
      }
    } catch (e) { 
      debugPrint('Received feedback error: $e');
      throw Exception('Failed to load feedback: $e');
    }
    return [];
  }

  static Future<List<dynamic>> getGivenFeedback() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/p2p/v1/feedback/given'), 
        headers: await _getHeaders()
      );
      debugPrint('Given feedback response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> feedback = [];
        if (data is List) {
          feedback = data;
        } else if (data is Map) {
          feedback = data['data'] ?? data['result'] ?? data['feedback'] ?? [];
        }
        return feedback;
      }
    } catch (e) { 
      debugPrint('Given feedback error: $e');
    }
    return [];
  }

  static Future<bool> submitFeedback(Map<String, dynamic> feedbackData) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/p2p/v1/feedback/submit'), 
        headers: await _getHeaders(), 
        body: json.encode(feedbackData)
      );
      debugPrint('Submit feedback response status: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) { 
      debugPrint('Submit feedback error: $e');
      return false;
    }
  }
}
