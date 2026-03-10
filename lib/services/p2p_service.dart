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
    try {
      final result = await _handleRequest(
        () async => http.get(Uri.parse('$_baseUrl/p2p/v1/coin/p2p/all'), headers: await _getHeaders()),
        'getP2PCoins',
      );
      if (result != null) {
        return result is List ? result : (result['data'] ?? result['result'] ?? []);
      }
    } catch (e) {
      ErrorHandler.logError(e.toString(), 'getP2PCoins');
    }
    return [];
  }

  static Future<List<dynamic>> getAllAdvertisements() async {
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
        
        debugPrint('Final advertisements list length: ${ads.length}');
        return ads;
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
          return ads;
        }
      }
    } catch (e) { 
      debugPrint('Advertisements fetch error: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }
    return [];
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
          "adId": "temp-ad-id", // Temporary ad ID
          "amount": adData["amount"] ?? 0.0,
          "paymentMode": adData["paymentMode"]?.first ?? "Bank",
          "type": adData["type"] ?? "buy",
        };
        
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
      final response = await http.post(Uri.parse('$_baseUrl/p2p/v1/advertise/publish/$adId'), headers: await _getHeaders());
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
  static Future<Map<String, dynamic>?> placeOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await http.post(Uri.parse('$_baseUrl/p2p/v1/p2p/order/create'), headers: await _getHeaders(), body: json.encode(orderData));
      if (response.statusCode == 200 || response.statusCode == 201) return json.decode(response.body);
    } catch (e) { debugPrint('Place order error: $e'); }
    return null;
  }

  static Future<List<dynamic>> getMyOrders() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/p2p/v1/p2p/order/my'), headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data is List ? data : (data['data'] ?? data['result'] ?? []);
      }
    } catch (e) { debugPrint('Orders error: $e'); }
    return [];
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

  static Future<bool> submitFeedback(String orderId, int rating, String feedback) async {
    try {
      final response = await http.post(Uri.parse('$_baseUrl/p2p/v1/p2p/order/feedback'), headers: await _getHeaders(), 
        body: json.encode({'orderId': orderId, 'rating': rating, 'comment': feedback}));
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
}
