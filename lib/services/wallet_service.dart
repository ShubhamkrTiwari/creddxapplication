import 'dart:convert';
import 'dart:core';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'spot_service.dart';
import 'auth_service.dart';
import 'notification_service.dart';

class WalletService {
  static const String baseUrl = 'http://65.0.196.122:8085';
  
  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // Fetch all wallet balances from the API
  static Future<Map<String, dynamic>> getAllWalletBalances() async {
    try {
      debugPrint('Fetching wallet balances from: $baseUrl/wallet/v1/wallet/all-wallet-balance');
      final response = await http.get(
        Uri.parse('$baseUrl/wallet/v1/wallet/all-wallet-balance'),
        headers: await _getHeaders(),
      );
      
      debugPrint('Balance API Response Status: ${response.statusCode}');
      debugPrint('Balance API Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Parsed Balance Data: $data');
        if (data['success'] == true) {
          return {
            'success': true,
            'data': data['data'] ?? data,
          };
        } else {
          debugPrint('Balance API returned success: false');
          return {
            'success': false,
            'error': data['message'] ?? 'Failed to fetch wallet balances',
          };
        }
      } else {
        debugPrint('Balance API failed with status: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching all wallet balances: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Fetch withdraw available balance from the API
  static Future<Map<String, dynamic>> getWithdrawAvailableBalance() async {
    try {
      debugPrint('Fetching withdraw available balance from: $baseUrl/wallet/v1/withdraw/available-balance');
      final response = await http.get(
        Uri.parse('$baseUrl/wallet/v1/withdraw/available-balance'),
        headers: await _getHeaders(),
      );

      debugPrint('Withdraw Available Balance API Response Status: ${response.statusCode}');
      debugPrint('Withdraw Available Balance API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'data': data['data'],
          };
        } else {
          debugPrint('Withdraw Available Balance API returned success: false');
          return {
            'success': false,
            'error': data['message'] ?? 'Failed to fetch withdraw available balance',
          };
        }
      } else {
        debugPrint('Withdraw Available Balance API failed with status: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching withdraw available balance: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Primary method to fetch wallet balance using /wallet/v1/wallet/get
  static Future<Map<String, dynamic>> getWalletBalance() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/wallet/v1/wallet/get'),
        headers: await _getHeaders(),
      );
      
      debugPrint('Wallet Get Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {'success': true, 'data': data['data']};
        }
      }
      
      // Fallback: If /wallet/v1/wallet/get fails, use /wallet/v1/wallet/all-wallet-balance
      return await getAllWalletBalances();
    } catch (e) {
      debugPrint('Error in getWalletBalance: $e');
      return await getAllWalletBalances(); // Try fallback on error too
    }
  }

  // Calculate total AVAILABLE USDT balance across all wallet types (not total, only available)
  static Future<double> getTotalAvailableUSDTBalance() async {
    double availableTotal = 0.0;
    try {
      // Try Wallet Service API (8085)
      final result = await getWalletBalance();
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        availableTotal = _calculateAvailableSumFromData(data);
      }
      
      // If Wallet Service failed or returned 0, try Spot Service Balance API (9000)
      if (availableTotal <= 0) {
        final spotResult = await SpotService.getBalance();
        if (spotResult['success'] == true && spotResult['data'] != null) {
          final spotData = spotResult['data'];
          
          // Handle 'assets' list format
          if (spotData['assets'] != null && spotData['assets'] is List) {
            final List assetsList = spotData['assets'];
            for (var assetItem in assetsList) {
              if (assetItem['asset']?.toString().toUpperCase() == 'USDT') {
                double available = double.tryParse(assetItem['available']?.toString() ?? '0') ?? 0.0;
                double free = double.tryParse(assetItem['free']?.toString() ?? '0') ?? 0.0;
                
                // Use available or free (whichever is greater)
                availableTotal = available > free ? available : free;
                break;
              }
            }
          }
          
          // If still 0, try direct fields
          if (availableTotal <= 0) {
            availableTotal = double.tryParse(spotData['usdt_available']?.toString() ?? '0') ?? 0.0;
          }
        }
      }
    } catch (e) {
      debugPrint('Error calculating total available USDT balance: $e');
    }
    return availableTotal;
  }

  // Helper to parse and sum AVAILABLE USDT from complex wallet data structures
  static double _calculateAvailableSumFromData(dynamic data) {
    double total = 0.0;
    if (data is Map) {
      // Check for specific wallet types
      final walletTypes = ['spot', 'p2p', 'bot', 'demo_bot', 'main'];
      bool foundInTypes = false;
      for (String type in walletTypes) {
        if (data[type] != null && data[type]['balances'] != null) {
          foundInTypes = true;
          final balances = data[type]['balances'] as List;
          for (var b in balances) {
            if (b['coin']?.toString().toUpperCase() == 'USDT') {
              // Add only AVAILABLE balance, not total
              total += double.tryParse(b['available']?.toString() ?? '0') ?? 0.0;
            }
          }
        }
      }
      
      // If not found in categorized types, look for a flat balances list
      if (!foundInTypes && data['balances'] != null) {
        final balances = data['balances'] as List;
        for (var b in balances) {
          if (b['coin']?.toString().toUpperCase() == 'USDT') {
            total += double.tryParse(b['available']?.toString() ?? '0') ?? 0.0;
          }
        }
      }

      // Check for common available fields
      if (total == 0) {
        total = double.tryParse(data['available_balance']?.toString() ?? 
                           data['available']?.toString() ?? 
                           data['free']?.toString() ?? '0.0') ?? 0.0;
      }
    } else if (data is List) {
      for (var wallet in data) {
        if (wallet['balances'] != null) {
          for (var b in (wallet['balances'] as List)) {
            if (b['coin']?.toString().toUpperCase() == 'USDT') {
              total += double.tryParse(b['available']?.toString() ?? '0') ?? 0.0;
            }
          }
        }
      }
    }
    return total;
  }

  // Calculate total USDT balance across all wallet types using multiple API sources
  static Future<double> getTotalUSDTBalance() async {
    double grandTotal = 0.0;
    try {
      // 1. Try Wallet Service API (8085)
      final result = await getWalletBalance();
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        grandTotal = _calculateSumFromData(data);
      }
      
      // 2. If Wallet Service failed or returned 0, try Spot Service Balance API (9000)
      if (grandTotal <= 0) {
        final spotResult = await SpotService.getBalance();
        if (spotResult['success'] == true && spotResult['data'] != null) {
          final spotData = spotResult['data'];
          
          // Handle 'assets' list format (common in your logs)
          if (spotData['assets'] != null && spotData['assets'] is List) {
            final List assetsList = spotData['assets'];
            for (var assetItem in assetsList) {
              if (assetItem['asset']?.toString().toUpperCase() == 'USDT') {
                double available = double.tryParse(assetItem['available']?.toString() ?? '0') ?? 0.0;
                double locked = double.tryParse(assetItem['locked']?.toString() ?? '0') ?? 0.0;
                double free = double.tryParse(assetItem['free']?.toString() ?? '0') ?? 0.0;
                
                // Use the maximum identified value to be safe
                double manualSum = free + locked;
                grandTotal = available > manualSum ? available : manualSum;
                break;
              }
            }
          }
          
          // If still 0, try direct fields
          if (grandTotal <= 0) {
            double available = double.tryParse(spotData['usdt_available']?.toString() ?? '0') ?? 0.0;
            double locked = double.tryParse(spotData['usdt_locked']?.toString() ?? '0') ?? 0.0;
            double total = double.tryParse(spotData['total']?.toString() ?? '0') ?? 0.0;
            
            grandTotal = total > (available + locked) ? total : (available + locked);
          }
        }
      }
    } catch (e) {
      debugPrint('Error calculating total USDT balance: $e');
    }
    return grandTotal;
  }

  // Helper to parse and sum USDT from complex wallet data structures
  static double _calculateSumFromData(dynamic data) {
    double total = 0.0;
    if (data is Map) {
      // Check for specific wallet types
      final walletTypes = ['spot', 'p2p', 'bot', 'demo_bot'];
      bool foundInTypes = false;
      for (String type in walletTypes) {
        if (data[type] != null && data[type]['balances'] != null) {
          foundInTypes = true;
          final balances = data[type]['balances'] as List;
          for (var b in balances) {
            if (b['coin']?.toString().toUpperCase() == 'USDT') {
              total += double.tryParse(b['total']?.toString() ?? '0') ?? 0.0;
            }
          }
        }
      }
      
      // If not found in categorized types, look for a flat balances list
      if (!foundInTypes && data['balances'] != null) {
        final balances = data['balances'] as List;
        for (var b in balances) {
          if (b['coin']?.toString().toUpperCase() == 'USDT') {
            total += double.tryParse(b['total']?.toString() ?? '0') ?? 0.0;
          }
        }
      }

      // Check for common total fields
      if (total == 0) {
        total = double.tryParse(data['total_balance']?.toString() ?? 
                           data['balance']?.toString() ?? 
                           data['total']?.toString() ?? '0.0') ?? 0.0;
      }
    } else if (data is List) {
      for (var wallet in data) {
        if (wallet['balances'] != null) {
          for (var b in (wallet['balances'] as List)) {
            if (b['coin']?.toString().toUpperCase() == 'USDT') {
              total += double.tryParse(b['total']?.toString() ?? '0') ?? 0.0;
            }
          }
        }
      }
    }
    return total;
  }

  // Get USDT balance from all wallet types: Spot, P2P, Bot, Demo Bot
  static Future<Map<String, dynamic>> getUSDTBalanceFromAllWallets() async {
    try {
      final result = await getAllWalletBalances();
      
      if (result['success'] != true) {
        return result;
      }
      
      final data = result['data'];
      final Map<String, dynamic> usdtBalances = {};
      
      final walletTypes = ['spot', 'p2p', 'bot', 'demo_bot', 'main'];
      
      for (String walletType in walletTypes) {
        if (data[walletType] != null) {
          final wallet = data[walletType];
          if (wallet['balances'] != null) {
            final balances = wallet['balances'] as List;
            final usdtBalance = balances.firstWhere(
              (balance) => balance['coin']?.toString().toUpperCase() == 'USDT',
              orElse: () => null,
            );
            
            if (usdtBalance != null) {
              usdtBalances[walletType] = {
                'available': usdtBalance['available']?.toString() ?? '0.00',
                'locked': usdtBalance['locked']?.toString() ?? '0.00',
                'total': usdtBalance['total']?.toString() ?? '0.00',
              };
            } else {
              usdtBalances[walletType] = {'available': '0.00', 'locked': '0.00', 'total': '0.00'};
            }
          } else {
            usdtBalances[walletType] = {'available': '0.00', 'locked': '0.00', 'total': '0.00'};
          }
        } else {
          usdtBalances[walletType] = {'available': '0.00', 'locked': '0.00', 'total': '0.00'};
        }
      }
      
      return {
        'success': true,
        'data': usdtBalances,
      };
    } catch (e) {
      debugPrint('Error extracting USDT balances: $e');
      return {
        'success': false,
        'error': 'Error extracting USDT balances: $e',
      };
    }
  }

  // Admin wallet transactions API
  static Future<Map<String, dynamic>> getAdminWalletTransactions({
    String? userId,
    String? walletType,
    String? coin,
    String? transactionType,
    int? page,
    int? limit,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{
        if (userId != null) 'userId': userId,
        if (walletType != null) 'walletType': walletType,
        if (coin != null) 'coin': coin,
        if (transactionType != null) 'transactionType': transactionType,
        if (page != null) 'page': page.toString(),
        if (limit != null) 'limit': limit.toString(),
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
      };
      
      final uri = Uri.parse('$baseUrl/admin/wallet-log/transactions')
          .replace(queryParameters: queryParams);
      
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data'] ?? data,
        };
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching admin wallet transactions: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // User wallet transactions API
  static Future<Map<String, dynamic>> getWalletTransactions({
    String? walletType,
    String? coin,
    String? transactionType,
    int? page,
    int? limit,
    String? startDate,
    String? endDate,
    bool includeAdminLogs = false,
  }) async {
    try {
      final queryParams = <String, String>{
        if (walletType != null) 'walletType': walletType,
        if (coin != null) 'coin': coin,
        if (transactionType != null) 'transactionType': transactionType,
        if (page != null) 'page': page.toString(),
        if (limit != null) 'limit': limit.toString(),
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
      };
      
      final endpoint = includeAdminLogs 
          ? '$baseUrl/admin/wallet-log/transactions'
          : '$baseUrl/wallet/v1/wallet/transactions';
      
      final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);
      
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data'] ?? data,
          'isFromAdminLog': includeAdminLogs,
        };
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching wallet transactions: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Combined transaction history from both user and admin logs
  static Future<Map<String, dynamic>> getCompleteTransactionHistory({
    String? walletType,
    String? coin,
    String? transactionType,
    int? page = 1,
    int? limit = 50,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final userResult = await getWalletTransactions(
        walletType: walletType,
        coin: coin,
        transactionType: transactionType,
        page: page,
        limit: limit,
        startDate: startDate,
        endDate: endDate,
        includeAdminLogs: false,
      );
      
      final adminResult = await getWalletTransactions(
        walletType: walletType,
        coin: coin,
        transactionType: transactionType,
        page: page,
        limit: limit,
        startDate: startDate,
        endDate: endDate,
        includeAdminLogs: true,
      );
      
      List<Map<String, dynamic>> allTransactions = [];
      
      if (userResult['success'] == true && userResult['data'] != null) {
        final userData = userResult['data'];
        if (userData['transactions'] != null) {
          allTransactions.addAll(List<Map<String, dynamic>>.from(userData['transactions']));
        } else if (userData is List) {
          allTransactions.addAll(List<Map<String, dynamic>>.from(userData));
        }
      }
      
      if (adminResult['success'] == true && adminResult['data'] != null) {
        final adminData = adminResult['data'];
        if (adminData['transactions'] != null) {
          allTransactions.addAll(List<Map<String, dynamic>>.from(adminData['transactions']));
        } else if (adminData is List) {
          allTransactions.addAll(List<Map<String, dynamic>>.from(adminData));
        }
      }
      
      allTransactions.sort((a, b) {
        final aDate = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime.now();
        final bDate = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime.now();
        return bDate.compareTo(aDate);
      });
      
      return {
        'success': true,
        'data': {
          'transactions': allTransactions,
          'total': allTransactions.length,
        },
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Wallet transfer history API
  static Future<Map<String, dynamic>> getWalletTransferHistory({
    String? fromWallet,
    String? toWallet,
    String? coin,
    int? page,
    int? limit,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{
        if (fromWallet != null) 'fromWallet': fromWallet,
        if (toWallet != null) 'toWallet': toWallet,
        if (coin != null) 'coin': coin,
        if (page != null) 'page': page.toString(),
        if (limit != null) 'limit': limit.toString(),
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
      };
      
      final uri = Uri.parse('$baseUrl/wallet/v1/wallet/transfer-history')
          .replace(queryParameters: queryParams);
      
      debugPrint('Fetching transfer history from: $uri');
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );
      
      debugPrint('Transfer History API Response Status: ${response.statusCode}');
      debugPrint('Transfer History API Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Parsed Transfer History Data: $data');
        final resultData = data['data'] ?? data;
        debugPrint('Transfer History Result Data: $resultData');
        return {
          'success': true,
          'data': resultData,
        };
      } else {
        debugPrint('Transfer History API failed with status: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching wallet transfer history: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Internal transfer history API
  static Future<Map<String, dynamic>> getInternalTransferHistory({
    int? page,
    int? limit,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{
        if (page != null) 'page': page.toString(),
        if (limit != null) 'limit': limit.toString(),
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
      };

      final uri = Uri.parse('$baseUrl/wallet/v1/wallet/internal-transfer-history')
          .replace(queryParameters: queryParams);

      debugPrint('Fetching internal transfer history from: $uri');
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      debugPrint('Internal Transfer History API Response Status: ${response.statusCode}');
      debugPrint('Internal Transfer History API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Parsed Internal Transfer History Data: $data');
        final resultData = data['data'] ?? data;
        return {
          'success': true,
          'data': resultData,
        };
      } else {
        debugPrint('Internal Transfer History API failed with status: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching internal transfer history: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Wallet transfer API - Updated to match API specification
  static Future<Map<String, dynamic>> transferBetweenWallets({
    required String coinId,
    required int from,
    required int to,
    required double amount,
    String? otp,
  }) async {
    try {
      final requestBody = {
        '_id': coinId, // Coin ID (API expects _id field)
        'from': from, // Source wallet type: 1=Spot, 2=P2P, 3=Bot, 4=Main
        'to': to, // Destination wallet type: 1=Spot, 2=P2P, 3=Bot, 4=Main
        'amount': amount,
      };
      
      debugPrint('Transfer Request: $requestBody');
      debugPrint('Transfer API URL: $baseUrl/wallet/v1/wallet/transfer');
      
      final response = await http.post(
        Uri.parse('$baseUrl/wallet/v1/wallet/transfer'),
        headers: await _getHeaders(),
        body: json.encode(requestBody),
      );
      
      debugPrint('Transfer API Response Status: ${response.statusCode}');
      debugPrint('Transfer API Response Body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        
        // Log wallet transfer notification
        await NotificationService.addNotification(
          title: 'Wallet Transfer',
          message: 'Transferred $amount USDT from ${_getWalletTypeName(from)} to ${_getWalletTypeName(to)}.',
          type: NotificationType.transaction,
        );

        return {
          'success': true,
          'data': data['data'] ?? data,
          'message': data['message'] ?? 'Transfer successful',
        };
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'error': error['message'] ?? error['error'] ?? 'Transfer failed',
          'details': error,
        };
      }
    } catch (e) {
      debugPrint('Error transferring between wallets: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
  
  // Helper method to convert wallet names to API numbers
  static int _getWalletTypeNumber(String walletType) {
    switch (walletType.toLowerCase()) {
      case 'spot':
        return 1;
      case 'p2p':
        return 2;
      case 'bot':
        return 3;
      case 'main':
        return 4; // Main wallet type
      case 'demo_bot':
        return 5; // Demo bot wallet type
      default:
        return 1; // Default to Spot
    }
  }

  // Helper method to convert API numbers to wallet names
  static String _getWalletTypeName(int walletType) {
    switch (walletType) {
      case 1:
        return 'Spot Wallet';
      case 2:
        return 'P2P Wallet';
      case 3:
        return 'Bot Wallet';
      case 4:
        return 'Main Wallet';
      case 5:
        return 'Demo Bot Wallet';
      default:
        return 'Unknown Wallet';
    }
  }
  
  static Future<List<Map<String, dynamic>>> getAllCoins() async {
    try {
      debugPrint('Fetching coins from: $baseUrl/wallet/v1/coin/all');
      final response = await http.get(
        Uri.parse('$baseUrl/wallet/v1/coin/all'),
        headers: await _getHeaders(),
      );
      debugPrint('Coins API Response Status: ${response.statusCode}');
      debugPrint('Coins API Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Parsed coins data: $data');
        
        // Handle different response formats
        if (data is List) return List<Map<String, dynamic>>.from(data);
        if (data is Map) {
          // Check for docs field first (as seen in logs)
          var list = data['docs'] ?? data['data'] ?? data['coins'] ?? data['result'] ?? [];
          if (list is List) {
            debugPrint('Found coins list with ${list.length} items');
            return List<Map<String, dynamic>>.from(list);
          }
        }
      }
      debugPrint('No coins data found in API response');
      return [];
    } catch (e) {
      debugPrint('Error fetching coins: $e');
      return [];
    }
  }
  
  static Future<List<Map<String, dynamic>>> getAllNetworks() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/wallet/v1/coin/all'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        var coins = (data is List) ? data : (data['data'] ?? data['coins'] ?? []);
        List<Map<String, dynamic>> allNetworks = [];
        Set<String> seenIds = {};
        if (coins is List) {
          for (var coin in coins) {
            var networks = coin['networks'] ?? [];
            if (networks is List) {
              for (var net in networks) {
                String id = (net['_id'] ?? net['id'] ?? '').toString();
                if (id.isNotEmpty && !seenIds.contains(id)) {
                  seenIds.add(id);
                  allNetworks.add(Map<String, dynamic>.from(net));
                }
              }
            }
          }
        }
        return allNetworks;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Fetch networks from sub-admin API
  static Future<List<Map<String, dynamic>>> getSubAdminNetworks() async {
    try {
      debugPrint('Fetching sub-admin networks from: $baseUrl/sub-admin/v1/network/all');
      final response = await http.get(
        Uri.parse('$baseUrl/sub-admin/v1/network/all'),
        headers: await _getHeaders(),
      );
      debugPrint('Sub-admin Networks API Response Status: ${response.statusCode}');
      debugPrint('Sub-admin Networks API Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Parsed sub-admin networks data: $data');
        
        // Handle different response formats
        if (data is List) return List<Map<String, dynamic>>.from(data);
        if (data is Map) {
          var list = data['docs'] ?? data['data'] ?? data['networks'] ?? data['result'] ?? [];
          if (list is List) {
            debugPrint('Found networks list with ${list.length} items');
            return List<Map<String, dynamic>>.from(list);
          }
        }
      }
      debugPrint('No networks data found in API response');
      return [];
    } catch (e) {
      debugPrint('Error fetching sub-admin networks: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> getDepositAddress({
    required String coin,
    required String coinId,
    required String networkId,
  }) async {
    try {
      debugPrint('Getting deposit address for coin: $coin, coinId: $coinId, networkId: $networkId');
      final response = await http.post(
        Uri.parse('$baseUrl/wallet/v1/wallet/deposit/get-erc20-bep20-address'),
        headers: await _getHeaders(),
        body: json.encode({'coin': coin, 'coinId': coinId, 'networkId': networkId}),
      );
      debugPrint('Deposit Address API Response: ${response.body}');
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        debugPrint('Deposit address retrieved successfully');
        return {'success': true, 'data': data['data'] ?? data['doc']};
      } else {
        debugPrint('Deposit address API failed: ${data['message']}');
        return {'success': false, 'error': data['message'] ?? 'Failed to fetch deposit address'};
      }
    } catch (e) {
      debugPrint('Error getting deposit address: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>?> getAvailableBalance({required String coin, required String network}) async {
    try {
      final balanceResult = await SpotService.getBalance();
      if (balanceResult['success'] == true && balanceResult['data'] != null) {
        final balanceData = balanceResult['data'];
        if (coin.toUpperCase() == 'USDT') {
          return {
            'balance': balanceData['usdt_available']?.toString() ?? '0.00',
            'locked': balanceData['usdt_locked']?.toString() ?? '0.00',
            'total': ((double.tryParse(balanceData['usdt_available']?.toString() ?? '0') ?? 0.0) + 
                     (double.tryParse(balanceData['usdt_locked']?.toString() ?? '0') ?? 0.0)).toStringAsFixed(2),
          };
        } else {
          return {
            'balance': balanceData['free']?.toString() ?? '0.00',
            'locked': balanceData['locked']?.toString() ?? '0.00',
            'total': balanceData['total']?.toString() ?? '0.00',
          };
        }
      }
      return {'balance': '0.00'};
    } catch (e) {
      return {'balance': '0.00'};
    }
  }

  static Future<Map<String, dynamic>> getUserBalance() async {
    try {
      final balanceResult = await SpotService.getBalance();
      if (balanceResult['success'] == true && balanceResult['data'] != null) {
        return {'success': true, 'data': balanceResult['data']};
      } else {
        return {'success': false, 'error': balanceResult['error'] ?? 'Failed to get balance'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>?> getWithdrawalFees({required String coin, required String network, required double amount}) async {
    return {'fee': '0.00'};
  }

  static Future<Map<String, dynamic>?> withdrawCrypto({required String coin, required String network, required String address, required double amount, String? otp}) async {
    try {
      debugPrint('Submitting crypto withdraw: coin=$coin, network=$network, amount=$amount');

      final requestBody = {
        'coin': coin,
        'network': network,
        'address': address,
        'amount': amount,
        if (otp != null && otp.isNotEmpty) 'otp': otp,
      };

      debugPrint('Withdraw request body: $requestBody');

      final response = await http.post(
        Uri.parse('$baseUrl/wallet/v1/withdraw/crypto-withdraw'),
        headers: await _getHeaders(),
        body: json.encode(requestBody),
      );

      debugPrint('Withdraw API Response Status: ${response.statusCode}');
      debugPrint('Withdraw API Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {'success': true, 'data': data['data']};
        } else {
          return {'success': false, 'error': data['message'] ?? 'Withdrawal failed'};
        }
      } else {
        final error = json.decode(response.body);
        return {'success': false, 'error': error['message'] ?? error['error'] ?? 'Error ${response.statusCode}'};
      }
    } catch (e) {
      debugPrint('Error in withdrawCrypto: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Fetch INR/USDT conversion history
  // type: 1 = INR to USDT, 2 = USDT to INR, null = all conversions
  static Future<Map<String, dynamic>> getConversionHistory({
    int? type,
    int? page = 1,
    int? limit = 50,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{
        if (type != null) 'type': type.toString(),
        if (page != null) 'page': page.toString(),
        if (limit != null) 'limit': limit.toString(),
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
      };

      final uri = Uri.parse('$baseUrl/v1/wallet/inr/conversion-history')
          .replace(queryParameters: queryParams);

      debugPrint('Fetching conversion history from: $uri');
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      debugPrint('Conversion History API Response Status: ${response.statusCode}');
      debugPrint('Conversion History API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Parsed Conversion History Data: $data');
        final resultData = data['data'] ?? data;
        return {
          'success': true,
          'data': resultData,
        };
      } else {
        debugPrint('Conversion History API failed with status: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching conversion history: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>?> submitInrWithdrawal({
    required double amount,
    required String paymentMode,
    String? accountHolderName,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    String? upiId,
    String? token,
  }) async {
    try {
      final withdrawType = paymentMode == 'bank' ? 'BANK' : paymentMode == 'upi' ? 'UPI' : paymentMode.toUpperCase();
      final requestBody = {
        'amount': amount,
        'withdrawType': withdrawType,
        if (accountHolderName != null) 'accountHolderName': accountHolderName,
        if (bankName != null) 'bankName': bankName,
        if (accountNumber != null) 'accountNumber': accountNumber,
        if (ifscCode != null) 'ifscCode': ifscCode,
        if (upiId != null) 'upiId': upiId,
      };
      
      debugPrint('Submitting INR withdrawal: $requestBody');
      
      final url = '$baseUrl/wallet/v1/wallet/deposit/inr-withdraw-request'; 
      final response = await http.post(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: json.encode(requestBody),
      );
      
      debugPrint('INR Withdrawal Response: ${response.statusCode} - ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = json.decode(response.body);
        return {'success': false, 'error': error['message'] ?? error['error'] ?? 'Error ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Internal transfer - send crypto to another CreddX user
  static Future<Map<String, dynamic>> internalTransfer({
    required String receiverUid,
    required double amount,
  }) async {
    try {
      final requestBody = {
        'receiverUid': receiverUid,
        'amount': amount,
      };

      debugPrint('Internal Transfer Request: $requestBody');
      debugPrint('Internal Transfer API URL: $baseUrl/wallet/v1/wallet/internal-transfer');

      final response = await http.post(
        Uri.parse('$baseUrl/wallet/v1/wallet/internal-transfer'),
        headers: await _getHeaders(),
        body: json.encode(requestBody),
      );

      debugPrint('Internal Transfer API Response Status: ${response.statusCode}');
      debugPrint('Internal Transfer API Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        // Log notification
        await NotificationService.addNotification(
          title: 'Internal Transfer',
          message: 'Sent $amount USDT to user $receiverUid.',
          type: NotificationType.transaction,
        );

        return {
          'success': true,
          'data': data['data'] ?? data,
          'message': data['message'] ?? 'Transfer successful',
        };
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'error': error['message'] ?? error['error'] ?? 'Transfer failed',
          'details': error,
        };
      }
    } catch (e) {
      debugPrint('Error in internalTransfer: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
}

class Coin {
  final String id, name, symbol, icon;
  final List<Network> networks;
  Coin({required this.id, required this.name, required this.symbol, required this.icon, required this.networks});
  
  factory Coin.fromJson(Map<String, dynamic> json) {
    debugPrint('Parsing coin from JSON: $json');
    
    var netList = json['networks'] ?? [];
    String symbol = (json['coinSymbol'] ?? json['symbol'] ?? json['shortName'] ?? 'COIN').toString();
    String name = (json['coinName'] ?? json['name'] ?? json['fullName'] ?? symbol).toString();
    String icon = (json['coinIcon'] ?? json['icon'] ?? '').toString();
    
    // Handle different ID formats
    String id = (json['_id'] ?? json['id'] ?? json['coinId'] ?? symbol).toString();
    
    // Parse networks properly
    List<Network> networks = [];
    if (netList is List) {
      networks = netList.map((n) => Network.fromJson(n)).toList();
    }
    
    debugPrint('Parsed coin: $name ($symbol) with ${networks.length} networks');
    
    return Coin(
      id: id,
      name: name, 
      symbol: symbol,
      icon: icon,
      networks: networks,
    );
  }

}

class Network {
  final String id, name, type;
  final bool isActive;
  final double? fee;
  Network({required this.id, required this.name, required this.type, required this.isActive, this.fee});
  
  factory Network.fromJson(Map<String, dynamic> json) {
    debugPrint('Parsing network from JSON: $json');
    
    String name = (json['networkName'] ?? json['name'] ?? 'Unknown').toString();
    String type = (json['networkType'] ?? json['type'] ?? 'NETWORK').toString();
    String id = (json['_id'] ?? json['id'] ?? name).toString();
    
    // Handle different active field names
    bool isActive = false;
    if (json['active'] != null) {
      isActive = json['active'] is bool ? json['active'] : json['active'].toString().toLowerCase() == 'true';
    } else if (json['isActive'] != null) {
      isActive = json['isActive'] is bool ? json['isActive'] : json['isActive'].toString().toLowerCase() == 'true';
    } else if (json['status'] != null) {
      isActive = json['status'].toString().toLowerCase() == 'active';
    } else {
      isActive = true; // Default to active if not specified
    }
    
    // Parse fee if available - handle both numeric and string formats like "1 USD"
    double? fee;
    String? feeRaw = json['fee']?.toString() ?? json['withdrawalFee']?.toString() ?? json['networkFee']?.toString();
    if (feeRaw != null && feeRaw.isNotEmpty) {
      // Extract numeric part from strings like "1 USD" or "5 USD"
      final match = RegExp(r'^(\d+(?:\.\d+)?)').firstMatch(feeRaw);
      if (match != null) {
        fee = double.tryParse(match.group(1)!);
      } else {
        fee = double.tryParse(feeRaw);
      }
    }
    
    debugPrint('Parsed network: $name ($type) - active: $isActive, fee: $fee');
    
    return Network(
      id: id,
      name: name,
      type: type,
      isActive: isActive,
      fee: fee,
    );
  }
}

class WalletBalance {
  final String coin, available, locked, total;
  WalletBalance({required this.coin, required this.available, required this.locked, required this.total});
  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    return WalletBalance(
      coin: json['coin']?.toString() ?? '',
      available: json['available']?.toString() ?? '0.00',
      locked: json['locked']?.toString() ?? '0.00',
      total: json['total']?.toString() ?? '0.00',
    );
  }
  Map<String, dynamic> toJson() => {'coin': coin, 'available': available, 'locked': locked, 'total': total};
}

class WalletInfo {
  final String type;
  final List<WalletBalance> balances;
  WalletInfo({required this.type, required this.balances});
  factory WalletInfo.fromJson(Map<String, dynamic> json) {
    List<WalletBalance> balances = [];
    if (json['balances'] != null) balances = (json['balances'] as List).map((b) => WalletBalance.fromJson(b)).toList();
    return WalletInfo(type: json['type']?.toString() ?? '', balances: balances);
  }
  WalletBalance? getBalance(String coin) {
    try {
      return balances.firstWhere((b) => b.coin.toUpperCase() == coin.toUpperCase());
    } catch (e) { return null; }
  }
}

class WalletUtils {
  static const List<String> walletTypes = ['spot', 'p2p', 'bot', 'demo_bot', 'main'];
  static String formatAmount(double amount, {int decimals = 8}) => amount.toStringAsFixed(decimals).replaceAll(RegExp(r'\.?0+$'), '');
}
